-- build_work_search v2: set-based aggregation instead of per-row correlated
-- subqueries.
--
-- WHY THIS EXISTS. v1 (in reconcile.sql) computes each work's authors,
-- alt-titles, ISBNs, languages and subject blob with a correlated subquery
-- in the SELECT list -- six of them, each re-executed once per work row.
-- That is fine at 300k works (95s measured) and pathological at 1.5M:
-- the same function ran >23 minutes without completing before being
-- terminated. Not a stale-statistics problem this time (an explicit
-- ANALYZE of all eight input tables runs immediately before it) -- a
-- genuinely superlinear query shape, since each correlated subquery's
-- per-row index lookup gets more expensive as the tables it probes grow.
--
-- v2 computes each aggregate ONCE for the whole catalog as a grouped CTE,
-- then hash-joins the results onto `work`. Same output columns, same
-- guarded upsert, no correlated subqueries anywhere.

create or replace function dewey.build_work_search_v2()
returns int
language sql
as $$
    with authors_agg as (
        select wc.work_id,
               string_agg(distinct an_canon.name, ', ')      as display_authors,
               array_agg(distinct an_all.folded)             as authors_folded,
               string_agg(distinct an_all.folded, ' ')       as authors_blob,
               string_agg(distinct an_canon.name, ' ')       as authors_tsv_src
          from dewey.work_contributor wc
          join dewey.author_name an_all   on an_all.author_id   = wc.author_id
          left join dewey.author_name an_canon
                 on an_canon.author_id = wc.author_id and an_canon.kind = 'canonical'
         group by wc.work_id
    ),
    alt_titles_agg as (
        select work_id, array_agg(distinct title_key) as alt_title_keys
          from dewey.work_title where not is_display group by work_id
    ),
    isbn_agg as (
        select e.work_id, array_agg(distinct ei.isbn13) as isbns
          from dewey.edition e join dewey.edition_isbn ei on ei.edition_id = e.id
         group by e.work_id
    ),
    lang_agg as (
        select work_id, array_agg(distinct language) as languages
          from dewey.edition where language is not null group by work_id
    ),
    subj_agg as (
        select ws.work_id, string_agg(distinct sj.label, ' ') as subject_blob
          from dewey.work_subject ws join dewey.subject sj on sj.id = ws.subject_id
         group by ws.work_id
    ),
    cover_agg as (
        select id as cover_id, source || ':' || source_ref as cover_ref from dewey.cover
    ),
    ins as (
        insert into dewey.work_search
            (work_id, display_title, display_authors, title_key, title_folded,
             alt_title_keys, authors_folded, authors_blob, isbns, year, languages,
             work_type, is_derivative, popularity, completeness, cover_ref, tsv)
        select
            w.id, w.display_title, a.display_authors,
            dewey.title_key(w.display_title), dewey.fold(w.display_title),
            coalesce(t.alt_title_keys, '{}'),
            coalesce(a.authors_folded, '{}'),
            coalesce(a.authors_blob, ''),
            coalesce(i.isbns, '{}'),
            w.first_published_year,
            coalesce(l.languages, '{}'),
            w.work_type, coalesce(s.is_derivative, false),
            coalesce(s.popularity, ln(1 + coalesce(s.edition_count, 0)) * 0.1),
            coalesce(s.completeness, 0),
            c.cover_ref,
            setweight(to_tsvector('simple', unaccent(w.display_title)), 'A')
         || setweight(to_tsvector('simple', unaccent(coalesce(a.authors_tsv_src, ''))), 'B')
         || setweight(to_tsvector('simple', unaccent(coalesce(w.display_subtitle, ''))), 'C')
         || setweight(to_tsvector('simple', unaccent(coalesce(w.series_name, ''))), 'C')
         || setweight(to_tsvector('simple', unaccent(coalesce(sb.subject_blob, ''))), 'D')
          from dewey.work w
          left join dewey.work_signal s on s.work_id = w.id
          left join authors_agg    a  on a.work_id  = w.id
          left join alt_titles_agg t  on t.work_id  = w.id
          left join isbn_agg       i  on i.work_id  = w.id
          left join lang_agg       l  on l.work_id  = w.id
          left join subj_agg       sb on sb.work_id = w.id
          left join cover_agg      c  on c.cover_id = w.display_cover_id
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
           or dewey.work_search.title_key    is distinct from excluded.title_key
           or dewey.work_search.isbns        is distinct from excluded.isbns
           or dewey.work_search.popularity   is distinct from excluded.popularity
           or dewey.work_search.authors_folded is distinct from excluded.authors_folded
        returning 1
    )
    select count(*)::int from ins;
$$;

revoke all on function dewey.build_work_search_v2 from anon, authenticated;
