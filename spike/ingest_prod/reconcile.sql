-- Set-based reconciliation: staging -> canonical, one batch at a time.
--
-- Every function here fixes the three carry-forward defects the medium-scale
-- task named explicitly:
--
--   1. GUARDED UPSERTS. Every ON CONFLICT DO UPDATE below carries a WHERE
--      clause comparing incoming to existing values. An unchanged row is not
--      just logically a no-op -- Postgres's own executor skips writing a new
--      tuple version for it, so a repeat ingest does not bloat the table the
--      way the prototype's unconditional upserts did (17MB -> 7.2MB after
--      VACUUM FULL on just 7k works, three runs).
--   2. CHEAP last_seen_at. Only touched when it is more than a day stale --
--      not on every single re-ingest. Staleness detection still works at the
--      granularity that matters (which OL keys stopped appearing across
--      MONTHS), without the write amplification of touching all 27,980+
--      identifier rows on every run regardless of whether anything changed.
--   3. WIDENED author resolution. Author identity is resolved from every
--      author-KEYED reference across BOTH stg.work and stg.edition before
--      anything else runs, so an author only present via an edition's own
--      `authors` field is not silently dropped the way the prototype's
--      missing_author anomaly (9 cases) showed. Contributor NAME matching
--      (translator/narrator -- OL gives no key for these, only free text) is
--      widened to the FULL already-loaded author_name table, not just the
--      current batch's authors, which is what actually improves the
--      unresolved-contributor-name rate at scale (see the report).

create schema if not exists dewey;

-- ---------------------------------------------------------------------------
-- Conservative, explicit role mapping. Unknown roles are never guessed.
-- ---------------------------------------------------------------------------
create table if not exists stg.role_synonym (raw text primary key, role dewey.edition_role);
insert into stg.role_synonym (raw, role) values
    ('translator','translator'), ('translated by','translator'), ('translation','translator'),
    ('narrator','narrator'), ('narrator/reader','narrator'), ('read by','narrator'),
    ('reader','narrator'), ('performed by','narrator'),
    ('illustrator','illustrator'), ('illustrated by','illustrator'), ('cover art','illustrator'),
    ('editor','editor'), ('edited by','editor'), ('compiler','editor'),
    ('afterword','afterword'), ('afterword by','afterword'),
    ('introduction','introduction'), ('introduction by','introduction'), ('foreword','introduction')
on conflict (raw) do nothing;

-- ===========================================================================
-- Author identity: resolved from EVERY author-keyed reference in the batch,
-- work-level and edition-level, in one pass -- this is the "expand author
-- resolution" fix. A single set-based statement, not a Python loop.
-- ===========================================================================
create or replace function dewey.reconcile_batch_authors(p_batch int, p_run text)
returns table(minted int, matched int, name_rows int)
language plpgsql
as $$
declare
    v_minted int; v_matched int; v_names int;
begin
    analyze stg.author;

    -- Every author key this batch references, from BOTH sources.
    create temp table if not exists tmp_author_keys (ol_key text primary key) on commit drop;
    delete from tmp_author_keys;
    insert into tmp_author_keys
    select distinct k from (
        select unnest(author_keys) as k from stg.work where batch_id = p_batch
        union
        select unnest(author_keys) as k from stg.edition where batch_id = p_batch
        union
        select ol_key as k from stg.author where batch_id = p_batch
    ) u where k is not null and k <> '';
    analyze tmp_author_keys;  -- see the implementation notes: an un-ANALYZEd
                              -- temp table has no statistics, and Postgres's
                              -- default row-count guess for the NOT EXISTS
                              -- anti-join below picks a plan that is fine at
                              -- ~2,000 rows and catastrophic at ~20,000 --
                              -- measured directly: 96s for one 19,838-row
                              -- batch vs 5.5s for the same total volume
                              -- split across ten 2,000-row batches.

    -- Mint identifiers for keys never seen before. Volatile function, called
    -- once per row in a set-based INSERT -- no per-row Python round trip.
    insert into dewey.identifier (entity_type, entity_id, provider, id_type, value, is_primary)
    select 'author', dewey.uuid_v7(), 'openlibrary', 'ol_author', t.ol_key, true
      from tmp_author_keys t
     where not exists (
         select 1 from dewey.identifier i
          where i.entity_type='author' and i.id_type='ol_author' and i.value=t.ol_key)
    on conflict (provider, id_type, value, entity_type) do nothing;
    get diagnostics v_minted = row_count;

    -- Cheap staleness: only touch last_seen_at when it is actually stale.
    -- Within one ingest run (minutes), or a same-day re-run, this WHERE
    -- clause is false for every row and Postgres writes nothing.
    update dewey.identifier i
       set last_seen_at = now()
      from tmp_author_keys t
     where i.entity_type='author' and i.id_type='ol_author' and i.value=t.ol_key
       and i.last_seen_at < now() - interval '1 day';
    get diagnostics v_matched = row_count;

    -- Author rows: insert-once. display_name is not re-claimed here (author
    -- provenance beyond canonical/alternate name is out of v1 scope, same as
    -- the prototype) -- an existing author row is never overwritten by a
    -- later batch, so a manual correction to display_name cannot be
    -- clobbered by re-ingest.
    insert into dewey.author (id, display_name)
    select i.entity_id, coalesce(s.name, '(unnamed)')
      from tmp_author_keys t
      join dewey.identifier i on i.entity_type='author' and i.id_type='ol_author' and i.value=t.ol_key
      left join stg.author s on s.batch_id = p_batch and s.ol_key = t.ol_key
    on conflict (id) do nothing;

    -- Canonical + alternate names, guarded: the unique index on
    -- (author_id, kind, name) already made this idempotent in the prototype;
    -- ON CONFLICT DO NOTHING never rewrites an existing row, so there is
    -- nothing to guard further here -- unlike identifier/source_record,
    -- this path never had a churn problem, because DO NOTHING never issues
    -- a tuple rewrite in the first place. Stated explicitly rather than
    -- assumed: not every upsert needed the same fix.
    insert into dewey.author_name (author_id, name, kind, script, source)
    select i.entity_id, x.name, x.kind,
           case when x.name ~ '[^\x00-\x7F]' then 'nonlatin' else 'latin' end,
           'openlibrary'
      from stg.author s
      join dewey.identifier i on i.entity_type='author' and i.id_type='ol_author' and i.value=s.ol_key
      cross join lateral (
          select s.name as name, 'canonical'::dewey.name_kind as kind
           where s.name is not null and s.name <> ''
          union all
          select alt, case when s.name ~ '[^\x00-\x7F]' and alt !~ '[^\x00-\x7F]'
                           then 'romanization' else 'alias' end::dewey.name_kind
            from unnest(s.alt_names) alt
           where alt is not null and alt <> '' and alt <> s.name
      ) x
     where s.batch_id = p_batch
    on conflict (author_id, kind, name) do nothing;
    get diagnostics v_names = row_count;

    return query select v_minted, v_matched, v_names;
end $$;

-- ===========================================================================
-- Work identity, canonical row, titles, contributor (author) links.
-- ===========================================================================
create or replace function dewey.reconcile_batch_works(p_batch int, p_run text, p_source_version text)
returns table(minted int, titles int, contributors int, subjects int)
language plpgsql
as $$
declare v_minted int; v_titles int; v_contrib int; v_subj int;
begin
    -- stg.work is UNLOGGED, not TEMP, but the same statistics problem
    -- applies: autovacuum's background ANALYZE has not necessarily caught
    -- up with rows COPYed in this transaction moments ago, and the same
    -- catastrophic-plan failure mode reproduced here at large batch sizes
    -- (reconcile_batch_works alone: 2+ minutes and still running on a
    -- single 20,000-row batch) until this explicit ANALYZE was added.
    analyze stg.work;

    insert into dewey.identifier (entity_type, entity_id, provider, id_type, value, is_primary)
    select 'work', dewey.uuid_v7(), 'openlibrary', 'ol_work', s.ol_key, true
      from stg.work s
     where s.batch_id = p_batch and s.title is not null and s.title <> ''
       and not exists (
           select 1 from dewey.identifier i
            where i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key)
    on conflict (provider, id_type, value, entity_type) do nothing;
    get diagnostics v_minted = row_count;

    update dewey.identifier i set last_seen_at = now()
      from stg.work s
     where s.batch_id=p_batch and i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key
       and i.last_seen_at < now() - interval '1 day';

    -- Empty-title works are logged and never given a work row at all --
    -- reject_record, not reject_field, matching the prototype's policy.
    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'empty_title', 'reject_record', 'openlibrary', s.ol_key, p_run, '{}'::jsonb
      from stg.work s where s.batch_id = p_batch and (s.title is null or s.title = '')
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    insert into dewey.work (id, work_type, display_title, first_published_year, ddc)
    select i.entity_id,
           case when s.title ~* '(study guide|sparknotes|summary of|companion to|cliffsnotes)'
                then 'study_guide'::dewey.work_type else 'book' end,
           s.title,
           nullif(substring(s.first_pub_date from '(1[0-9]{3}|20[0-9]{2})'), '')::int,
           null
      from stg.work s
      join dewey.identifier i on i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key
     where s.batch_id = p_batch and s.title is not null and s.title <> ''
    on conflict (id) do nothing;

    insert into dewey.work_title (work_id, kind, title, source, is_display)
    select i.entity_id, 'canonical', s.title, 'openlibrary', true
      from stg.work s
      join dewey.identifier i on i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key
     where s.batch_id = p_batch and s.title is not null and s.title <> ''
    on conflict (work_id, kind, title, coalesce(language,'')) do nothing;

    insert into dewey.work_title (work_id, kind, title, source, is_display)
    select i.entity_id, 'alternate', a.alt, 'openlibrary', false
      from stg.work s
      join dewey.identifier i on i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key
      cross join lateral unnest(s.alt_titles) a(alt)
     where s.batch_id = p_batch and a.alt is not null and a.alt <> '' and a.alt <> s.title
    on conflict (work_id, kind, title, coalesce(language,'')) do nothing;
    get diagnostics v_titles = row_count;

    insert into dewey.work_contributor (work_id, author_id, role, position, source)
    select wi.entity_id, ai.entity_id, 'author', ord.ordinality - 1, 'openlibrary'
      from stg.work s
      join dewey.identifier wi on wi.entity_type='work' and wi.id_type='ol_work' and wi.value=s.ol_key
      cross join lateral unnest(s.author_keys) with ordinality as ord(ak, ordinality)
      join dewey.identifier ai on ai.entity_type='author' and ai.id_type='ol_author' and ai.value=ord.ak
     where s.batch_id = p_batch
    on conflict (work_id, author_id, role) do nothing;
    get diagnostics v_contrib = row_count;

    -- Subjects: dictionary insert (idempotent, ON CONFLICT DO NOTHING is
    -- already cheap for the same reason as author_name above), then link.
    --
    -- LENGTH GUARD, found necessary only at ~1M-work scale: some OL
    -- 'subjects' entries are not subject headings at all -- a
    -- semicolon-joined list of author names and dates, a spam hashtag
    -- string, a bilingual glossary paragraph. One (1,009 characters)
    -- exceeded Postgres's btree index row limit outright and stopped
    -- reconcile_batch_works with a hard error rather than a graceful
    -- rejection. 250 characters is generous for a real subject heading
    -- (even long combined headings run under 150) and comfortably clears
    -- the btree limit even for 4-byte-per-character scripts.
    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'oversized_subject', 'reject_field', 'openlibrary', s.ol_key, p_run,
           jsonb_build_object('length', length(subj), 'preview', left(subj, 120))
      from stg.work s cross join lateral unnest(s.subjects[1:15]) subj
     where s.batch_id = p_batch and subj is not null and length(subj) > 250
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    insert into dewey.subject (label, vocabulary)
    select distinct subj, 'ol_folksonomy'::dewey.subject_vocabulary
      from stg.work s cross join lateral unnest(s.subjects[1:15]) subj
     where s.batch_id = p_batch and subj is not null and subj <> '' and length(subj) <= 250
    on conflict (vocabulary, label) do nothing;

    insert into dewey.work_subject (work_id, subject_id, source)
    select wi.entity_id, sub.id, 'openlibrary'
      from stg.work s
      join dewey.identifier wi on wi.entity_type='work' and wi.id_type='ol_work' and wi.value=s.ol_key
      cross join lateral unnest(s.subjects[1:15]) subj
      join dewey.subject sub on sub.vocabulary='ol_folksonomy' and sub.label=subj
     where s.batch_id = p_batch
    on conflict (work_id, subject_id) do nothing;
    get diagnostics v_subj = row_count;

    -- Covers: one per work, insert-once (replacement is a deliberate,
    -- separate operation -- §5's "better cover" scenario -- not something a
    -- routine re-ingest should silently do).
    insert into dewey.cover (id, work_id, source, source_ref, license_posture)
    select dewey.uuid_v7(), i.entity_id, 'openlibrary', s.cover_ol_id::text, 'unlicensed_cached'
      from stg.work s
      join dewey.identifier i on i.entity_type='work' and i.id_type='ol_work' and i.value=s.ol_key
     where s.batch_id = p_batch and s.cover_ol_id is not null
    on conflict (source, source_ref, coalesce(work_id, edition_id)) do nothing;

    update dewey.work w set display_cover_id = c.id
      from dewey.cover c
     where c.work_id = w.id and w.display_cover_id is null and c.source = 'openlibrary';

    return query select v_minted, v_titles, v_contrib, v_subj;
end $$;

-- ===========================================================================
-- Editions, edition_isbn (with malformed-ISBN + cross-work-collision
-- anomaly logging), edition_contributor (role-classified, name-resolved
-- against the FULL author_name table -- the widened resolution).
-- ===========================================================================
create or replace function dewey.reconcile_batch_editions(p_batch int, p_run text)
returns table(minted int, isbns int, contributors_resolved int, contributors_queued int)
language plpgsql
as $$
declare v_minted int; v_isbns int; v_cres int; v_cq int;
begin
    analyze stg.edition;

    insert into dewey.identifier (entity_type, entity_id, provider, id_type, value, is_primary)
    select 'edition', dewey.uuid_v7(), 'openlibrary', 'ol_edition', e.ol_key, true
      from stg.edition e
     where e.batch_id = p_batch
       and exists (select 1 from dewey.identifier wi
                    where wi.entity_type='work' and wi.id_type='ol_work' and wi.value=e.work_key)
       and not exists (
           select 1 from dewey.identifier i
            where i.entity_type='edition' and i.id_type='ol_edition' and i.value=e.ol_key)
    on conflict (provider, id_type, value, entity_type) do nothing;
    get diagnostics v_minted = row_count;

    update dewey.identifier i set last_seen_at = now()
      from stg.edition e
     where e.batch_id=p_batch and i.entity_type='edition' and i.id_type='ol_edition' and i.value=e.ol_key
       and i.last_seen_at < now() - interval '1 day';

    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'dangling_source_reference', 'reject_record', 'openlibrary', e.ol_key, p_run,
           jsonb_build_object('work_key', e.work_key)
      from stg.edition e
     where e.batch_id = p_batch
       and not exists (select 1 from dewey.identifier wi
                         where wi.entity_type='work' and wi.id_type='ol_work' and wi.value=e.work_key)
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    insert into dewey.edition (id, work_id, title, subtitle, language, publisher,
                               published_date, published_year, page_count, format)
    select ei.entity_id, wi.entity_id, e.title, e.subtitle, (e.languages)[1], e.publisher,
           e.publish_date,
           nullif(substring(e.publish_date from '(1[0-9]{3}|20[0-9]{2})'), '')::int,
           case when e.pages between 1 and 50000 then e.pages else null end,
           case when e.format_raw ~* 'audio' then 'audiobook'
                when e.format_raw ~* 'hardcover|hardback' then 'hardcover'
                when e.format_raw ~* 'paperback|softcover' then 'paperback'
                when e.format_raw ~* 'ebook|electronic' then 'ebook'
                when e.format_raw is not null and e.format_raw <> '' then 'other'
                else null end::dewey.edition_format
      from stg.edition e
      join dewey.identifier wi on wi.entity_type='work' and wi.id_type='ol_work' and wi.value=e.work_key
      join dewey.identifier ei on ei.entity_type='edition' and ei.id_type='ol_edition' and ei.value=e.ol_key
     where e.batch_id = p_batch
    on conflict (id) do nothing;

    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'impossible_page_count', 'reject_field', 'openlibrary', e.ol_key, p_run,
           jsonb_build_object('pages', e.pages)
      from stg.edition e where e.batch_id = p_batch and e.pages is not null
       and e.pages not between 1 and 50000
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    -- ISBNs: normalised through the SAME SQL function resolve_isbn relies on
    -- at query time. Malformed strings rejected at the field, logged, never
    -- silently dropped. No global uniqueness -- see the SQL implementation
    -- notes for why (2.17% of real ISBNs collide across editions).
    create temp table if not exists tmp_isbn (ol_key text, raw text, isbn13 text) on commit drop;
    delete from tmp_isbn;
    insert into tmp_isbn (ol_key, raw, isbn13)
    select e.ol_key, raw, dewey.isbn_to_13(raw)
      from stg.edition e cross join lateral unnest(e.isbn13 || e.isbn10) raw
     where e.batch_id = p_batch;
    analyze tmp_isbn;

    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'malformed_identifier', 'reject_field', 'openlibrary', t.ol_key, p_run,
           jsonb_build_object('raw_isbn', t.raw)
      from tmp_isbn t where t.isbn13 is null
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    insert into dewey.edition_isbn (edition_id, isbn13, source)
    select distinct ei.entity_id, t.isbn13, 'openlibrary'::dewey.provider
      from tmp_isbn t
      join dewey.identifier ei on ei.entity_type='edition' and ei.id_type='ol_edition' and ei.value=t.ol_key
     where t.isbn13 is not null
    on conflict (edition_id, isbn13) do nothing;
    get diagnostics v_isbns = row_count;

    -- Cross-work collisions surfaced as a reviewable anomaly, not just left
    -- to the standing dewey.isbn_collision view -- this gives them a
    -- run_id and a dismiss/resolve workflow the view alone doesn't.
    insert into dewey.anomaly (kind, disposition, source_key, run_id, context)
    select 'isbn_collision', 'review_queue', c.isbn13, p_run,
           jsonb_build_object('work_count', c.work_count, 'work_ids', c.work_ids)
      from dewey.isbn_collision c
      join tmp_isbn t on t.isbn13 = c.isbn13
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    -- Contributors: role classified via the conservative synonym table;
    -- unmapped roles rejected at the field with the raw string preserved.
    -- Name resolution is against the FULL dewey.author_name table -- every
    -- author loaded by ANY batch so far, not just this one -- which is the
    -- concrete difference from the prototype's per-batch-only matching.
    create temp table if not exists tmp_contrib (ol_key text, name text, role_raw text, pos int) on commit drop;
    delete from tmp_contrib;
    insert into tmp_contrib (ol_key, name, role_raw, pos)
    select e.ol_key, c->>'name', c->>'role', (ord.ordinality-1)::int
      from stg.edition e cross join lateral jsonb_array_elements(e.contributors) with ordinality as ord(c, ordinality)
     where e.batch_id = p_batch;
    analyze tmp_contrib;

    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'unknown_contributor_role', 'reject_field', 'openlibrary', t.ol_key, p_run,
           jsonb_build_object('raw_role', t.role_raw, 'name', t.name)
      from tmp_contrib t
      where t.role_raw is not null and t.role_raw <> ''
        and lower(t.role_raw) not in (select raw from stg.role_synonym)
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;

    insert into dewey.edition_contributor (edition_id, author_id, role, position, source)
    select distinct ei.entity_id, an.author_id, rs.role, t.pos, 'openlibrary'::dewey.provider
      from tmp_contrib t
      join stg.role_synonym rs on rs.raw = lower(t.role_raw)
      join dewey.identifier ei on ei.entity_type='edition' and ei.id_type='ol_edition' and ei.value=t.ol_key
      join dewey.author_name an on an.folded = dewey.fold(t.name)
    on conflict (edition_id, author_id, role) do nothing;
    get diagnostics v_cres = row_count;

    insert into dewey.anomaly (kind, disposition, source_provider, source_key, run_id, context)
    select 'unresolved_contributor_name', 'review_queue', 'openlibrary', t.ol_key, p_run,
           jsonb_build_object('name', t.name, 'role', rs.role)
      from tmp_contrib t
      join stg.role_synonym rs on rs.raw = lower(t.role_raw)
     where not exists (select 1 from dewey.author_name an where an.folded = dewey.fold(t.name))
    on conflict (kind, coalesce(source_key, ''), coalesce(run_id, '')) do nothing;
    get diagnostics v_cq = row_count;

    return query select v_minted, v_isbns, v_cres, v_cq;
end $$;

-- ===========================================================================
-- work_signal upsert, GUARDED -- the "no-op MVCC churn" fix applied to a
-- table that would otherwise be rewritten on every re-ingest even when
-- nothing about a work's editions changed.
-- ===========================================================================
create or replace function dewey.reconcile_batch_signals(p_batch int)
returns int
language plpgsql
as $$
declare v int;
begin
    insert into dewey.work_signal (work_id, edition_count, recent_edition_count, is_derivative, completeness)
    select wi.entity_id,
           count(e.id),
           count(e.id) filter (where e.published_year >= extract(year from now())::int - 25),
           w.work_type = 'study_guide',
           (case when w.description is not null then 20 else 0 end
          + case when w.display_cover_id is not null then 20 else 0 end
          + case when count(e.id) > 0 then 20 else 0 end
          + case when w.first_published_year is not null then 20 else 0 end
          + case when exists (select 1 from dewey.work_subject ws where ws.work_id=w.id) then 20 else 0 end)
      from stg.work s
      join dewey.identifier wi on wi.entity_type='work' and wi.id_type='ol_work' and wi.value=s.ol_key
      join dewey.work w on w.id = wi.entity_id
      left join dewey.edition e on e.work_id = w.id
     where s.batch_id = p_batch
     group by wi.entity_id, w.work_type, w.description, w.display_cover_id, w.first_published_year, w.id
    on conflict (work_id) do update
       set edition_count = excluded.edition_count,
           recent_edition_count = excluded.recent_edition_count,
           is_derivative = excluded.is_derivative,
           completeness = excluded.completeness,
           computed_at = now()
     where dewey.work_signal.edition_count is distinct from excluded.edition_count
        or dewey.work_signal.recent_edition_count is distinct from excluded.recent_edition_count
        or dewey.work_signal.is_derivative is distinct from excluded.is_derivative
        or dewey.work_signal.completeness is distinct from excluded.completeness;
    get diagnostics v = row_count;
    return v;
end $$;

-- ===========================================================================
-- Canonical field claims, GUARDED. claim_field() itself still refreshes
-- set_at on every same-provider reclaim -- that's correct, approved
-- precedence behaviour, not churn (see the SQL implementation notes). What
-- IS guarded here is the canonical column write that follows a WON claim:
-- if the value didn't change, the column is not rewritten.
-- ===========================================================================
-- Pure set-based: claim_field() is a scalar function, so calling it once per
-- row inside a CTE's SELECT list is a single statement Postgres executes
-- row-at-a-time internally (as any scalar function call in a projection
-- is), not a PL/pgSQL FOR-loop issuing N separate round trips. The
-- distinction matters at scale: no per-row PL/pgSQL loop overhead, and the
-- whole batch's claims run as one planned statement per field.
create or replace function dewey.reconcile_batch_claims(p_batch int, p_source_version text)
returns table(won int, refused int)
language sql
as $$
    with candidates as (
        select wi.entity_id as work_id, s.title,
               nullif(substring(s.first_pub_date from '(1[0-9]{3}|20[0-9]{2})'), '')::int as year,
               sr.id as source_record_id
          from stg.work s
          join dewey.identifier wi on wi.entity_type='work' and wi.id_type='ol_work' and wi.value=s.ol_key
          left join dewey.source_record sr
                 on sr.provider='openlibrary' and sr.record_type='work'
                and sr.provider_id=s.ol_key and sr.source_version=p_source_version
         where s.batch_id = p_batch
    ),
    title_claims as (
        select work_id, title,
               dewey.claim_field('work', work_id, 'title', 'openlibrary', source_record_id, false) as won
          from candidates where title is not null
    ),
    year_claims as (
        select work_id, year,
               dewey.claim_field('work', work_id, 'first_published_year', 'openlibrary',
                                 source_record_id, false) as won
          from candidates where year is not null
    ),
    title_applied as (
        update dewey.work w set display_title = c.title
          from title_claims c
         where c.won and w.id = c.work_id and w.display_title is distinct from c.title
        returning w.id
    ),
    year_applied as (
        update dewey.work w set first_published_year = c.year
          from year_claims c
         where c.won and w.id = c.work_id and w.first_published_year is distinct from c.year
        returning w.id
    )
    select
        (select count(*) from title_claims where won) + (select count(*) from year_claims where won),
        (select count(*) from title_claims where not won) + (select count(*) from year_claims where not won);
$$;

-- ===========================================================================
-- Search projection build. Whole-catalog, not batched: see the
-- implementation notes for the index-timing comparison (indexes exist
-- throughout for incremental correctness; this bulk step is measured
-- separately from per-batch reconciliation because it is a genuinely
-- different write pattern -- one full-table rewrite vs many small upserts).
-- ===========================================================================
create or replace function dewey.build_work_search()
returns int
language sql
as $$
    with ins as (
        insert into dewey.work_search
            (work_id, display_title, display_authors, title_key, title_folded,
             alt_title_keys, authors_folded, authors_blob, isbns, year, languages,
             work_type, is_derivative, popularity, completeness, cover_ref, tsv)
        select
            w.id, w.display_title,
            (select string_agg(distinct an.name, ', ')
               from dewey.work_contributor wc
               join dewey.author_name an on an.author_id = wc.author_id and an.kind = 'canonical'
              where wc.work_id = w.id),
            dewey.title_key(w.display_title), dewey.fold(w.display_title),
            coalesce(array(select distinct t.title_key from dewey.work_title t
                            where t.work_id = w.id and not t.is_display), '{}'),
            coalesce(array(select distinct an.folded
                             from dewey.work_contributor wc
                             join dewey.author_name an on an.author_id = wc.author_id
                            where wc.work_id = w.id), '{}'),
            coalesce((select string_agg(distinct an.folded, ' ')
                        from dewey.work_contributor wc
                        join dewey.author_name an on an.author_id = wc.author_id
                       where wc.work_id = w.id), ''),
            coalesce(array(select distinct ei.isbn13
                             from dewey.edition e join dewey.edition_isbn ei on ei.edition_id = e.id
                            where e.work_id = w.id), '{}'),
            w.first_published_year,
            coalesce(array(select distinct e.language from dewey.edition e
                            where e.work_id = w.id and e.language is not null), '{}'),
            w.work_type, coalesce(s.is_derivative, false),
            coalesce(s.popularity, ln(1 + coalesce(s.edition_count, 0)) * 0.1),
            coalesce(s.completeness, 0),
            (select c.source || ':' || c.source_ref from dewey.cover c where c.id = w.display_cover_id),
            setweight(to_tsvector('simple', unaccent(w.display_title)), 'A')
         || setweight(to_tsvector('simple', unaccent(coalesce(
               (select string_agg(distinct an.name, ' ')
                  from dewey.work_contributor wc
                  join dewey.author_name an on an.author_id = wc.author_id
                 where wc.work_id = w.id), ''))), 'B')
         || setweight(to_tsvector('simple', unaccent(coalesce(w.display_subtitle, ''))), 'C')
         || setweight(to_tsvector('simple', unaccent(coalesce(w.series_name, ''))), 'C')
         || setweight(to_tsvector('simple', unaccent(coalesce(
               (select string_agg(distinct sj.label, ' ') from dewey.work_subject ws
                  join dewey.subject sj on sj.id = ws.subject_id
                 where ws.work_id = w.id), ''))), 'D')
          from dewey.work w
          left join dewey.work_signal s on s.work_id = w.id
         where w.merged_into is null
        on conflict (work_id) do update set
            display_title = excluded.display_title, display_authors = excluded.display_authors,
            title_key = excluded.title_key, title_folded = excluded.title_folded,
            alt_title_keys = excluded.alt_title_keys, authors_folded = excluded.authors_folded,
            authors_blob = excluded.authors_blob, isbns = excluded.isbns, year = excluded.year,
            languages = excluded.languages, work_type = excluded.work_type,
            is_derivative = excluded.is_derivative, popularity = excluded.popularity,
            completeness = excluded.completeness, cover_ref = excluded.cover_ref,
            tsv = excluded.tsv, updated_at = now()
        where dewey.work_search.display_title is distinct from excluded.display_title
           or dewey.work_search.title_key is distinct from excluded.title_key
           or dewey.work_search.isbns is distinct from excluded.isbns
           or dewey.work_search.popularity is distinct from excluded.popularity
           or dewey.work_search.authors_folded is distinct from excluded.authors_folded
        returning 1
    )
    select count(*) from ins;
$$;

revoke all on function dewey.reconcile_batch_authors, dewey.reconcile_batch_works,
    dewey.reconcile_batch_editions, dewey.reconcile_batch_signals, dewey.reconcile_batch_claims,
    dewey.build_work_search
    from anon, authenticated;
