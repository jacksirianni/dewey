-- Executable verification for `0002_catalog.sql`.
--
-- Same discipline as `01-verify.sql`: every check *exercises* the schema by
-- running a real statement and asserting on what Postgres did, rather than
-- inspecting catalogs to confirm an object exists. A unique index that exists
-- but does not fire is a passing inspection and a failing schema.
--
-- Where a statement is expected to fail, the test asserts on the SQLSTATE, not
-- merely that something went wrong: a check violation (23514), a unique
-- violation (23505), a foreign-key violation (23503) and a raised
-- data_exception (22000) are different outcomes, and a test that accepted any
-- of them would pass while the schema was wrong in an interesting way.
--
-- Run with:  psql -d dewey_catalog_test -f supabase/0002_catalog.sql
--            psql -d dewey_catalog_test -f supabase/test/03-catalog.sql
--
-- The fixture uses real data from the search-index spike: the Piranesi
-- title collision, the Percival Everett duplicate author records, and
-- 村田沙耶香's Open Library alternate_names.

\set ON_ERROR_STOP on
\pset pager off

create schema if not exists test;

create table if not exists test.results (
    id      serial primary key,
    section text,
    label   text,
    outcome text,
    detail  text
);
truncate test.results restart identity;

create or replace function test.ok(section text, label text, cond boolean, detail text default '')
returns void language plpgsql as $$
begin
    insert into test.results(section,label,outcome,detail)
    values (section, label, case when cond then 'PASS' else 'FAIL' end,
            case when cond then '' else detail end);
end $$;

-- Run `stmt`; assert it either succeeds ('ok') or raises the given SQLSTATE.
create or replace function test.check(section text, label text, stmt text, expect text default 'ok')
returns void language plpgsql as $$
declare got text := 'ok'; msg text := '';
begin
    begin
        execute stmt;
    exception when others then
        got := sqlstate; msg := sqlerrm;
    end;
    insert into test.results(section,label,outcome,detail)
    values (section, label,
            case when got = expect then 'PASS' else 'FAIL' end,
            case when got = expect then ''
                 else format('expected %s, got %s (%s)', expect, got, msg) end);
end $$;

-- Fixture ====================================================================
--
-- ids are fixed rather than random so failures name the same row every run.
create or replace function test.seed() returns void language plpgsql as $$
declare
    w_clarke   uuid := '0190f8a2-0001-7000-8000-000000000001';
    w_giovanni uuid := '0190f8a2-0002-7000-8000-000000000002';
    w_james    uuid := '0190f8a2-0003-7000-8000-000000000003';
    w_csw      uuid := '0190f8a2-0004-7000-8000-000000000004';
    a_clarke   uuid := '0190f8a2-1001-7000-8000-000000000001';
    a_giovanni uuid := '0190f8a2-1002-7000-8000-000000000002';
    a_everett1 uuid := '0190f8a2-1003-7000-8000-000000000003';
    a_everett2 uuid := '0190f8a2-1004-7000-8000-000000000004';
    a_murata   uuid := '0190f8a2-1005-7000-8000-000000000005';
    a_trans    uuid := '0190f8a2-1006-7000-8000-000000000006';
    a_narr     uuid := '0190f8a2-1007-7000-8000-000000000007';
    e_c1       uuid := '0190f8a2-2001-7000-8000-000000000001';
    e_c2       uuid := '0190f8a2-2002-7000-8000-000000000002';
    e_c3       uuid := '0190f8a2-2003-7000-8000-000000000003';
    src        bigint;
begin
    delete from dewey.work_search;
    delete from dewey.work_signal;
    delete from dewey.field_provenance;
    delete from dewey.identifier;
    delete from dewey.work_redirect;
    delete from dewey.edition_redirect;
    delete from dewey.author_redirect;
    delete from dewey.edition_isbn;
    delete from dewey.edition_contributor;
    delete from dewey.work_contributor;
    delete from dewey.work_subject;
    delete from dewey.work_title;
    update dewey.work set display_cover_id = null, canonical_edition_id = null;
    update dewey.edition set cover_id = null;
    delete from dewey.cover;
    delete from dewey.edition;
    update dewey.work set merged_into = null;
    update dewey.author set merged_into = null;
    delete from dewey.work;
    delete from dewey.author;
    delete from dewey.subject;
    delete from dewey.source_record;

    insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                     source_version, content_hash)
    values ('openlibrary','work','OL20893680W','dump','2026-07-31','h1')
    returning id into src;

    -- Authors
    insert into dewey.author (id, display_name) values
        (a_clarke,   'Susanna Clarke'),
        (a_giovanni, 'Giovanni Battista Piranesi'),
        (a_everett1, 'Percival Everett'),
        (a_everett2, 'Percival L. Everett'),
        (a_murata,   'Sayaka Murata'),
        (a_trans,    'Ginny Tapley Takemori'),
        (a_narr,     'Nancy Wu');

    -- Author names, exactly as Open Library supplies them. The Murata record's
    -- canonical name is Japanese and its alternate_names carry the romanised
    -- form; ingesting alternate_names is what makes the English query work.
    insert into dewey.author_name (author_id, name, kind, script, source) values
        (a_clarke,   'Susanna Clarke',              'canonical',      'Latn', 'openlibrary'),
        (a_giovanni, 'Giovanni Battista Piranesi',  'canonical',      'Latn', 'openlibrary'),
        (a_everett1, 'Percival Everett',            'canonical',      'Latn', 'openlibrary'),
        (a_everett2, 'Percival L. Everett',         'canonical',      'Latn', 'openlibrary'),
        (a_murata,   '村田沙耶香',                    'canonical',      'Jpan', 'openlibrary'),
        (a_murata,   'Sayaka Murata',               'romanization',   'Latn', 'openlibrary'),
        (a_murata,   '村田, 沙耶香',                  'source_variant', 'Jpan', 'openlibrary'),
        (a_murata,   'MURATA  SAYAKA',              'alias',          'Latn', 'openlibrary');

    -- Works: the real Piranesi collision, plus two more from the spike.
    insert into dewey.work (id, work_type, display_title, first_published_year,
                            original_language, ddc, slug)
    values (w_clarke,   'book',       'Piranesi',               2020, 'en', '823.92', 'piranesi'),
           (w_giovanni, 'collection', 'Piranesi',               1910, 'en', null,     null),
           (w_james,    'book',       'James',                  2024, 'en', null,     null),
           (w_csw,      'book',       'Convenience Store Woman',2016, 'ja', null,     null);

    insert into dewey.work_title (work_id, kind, title, source, is_display) values
        (w_clarke,   'canonical', 'Piranesi',                'openlibrary', true),
        (w_giovanni, 'canonical', 'Piranesi',                'openlibrary', true),
        (w_james,    'canonical', 'James',                   'openlibrary', true),
        (w_csw,      'canonical', 'Convenience Store Woman', 'openlibrary', true);
    insert into dewey.work_title (work_id, kind, title, language, source) values
        (w_csw, 'original', 'コンビニ人間', 'ja', 'openlibrary');

    insert into dewey.work_contributor (work_id, author_id, role, position, source) values
        (w_clarke,   a_clarke,   'author', 0, 'openlibrary'),
        (w_giovanni, a_giovanni, 'author', 0, 'openlibrary'),
        (w_james,    a_everett2, 'author', 0, 'openlibrary'),
        (w_csw,      a_murata,   'author', 0, 'openlibrary');

    -- Three editions of one work: print, translated print, audiobook.
    insert into dewey.edition (id, work_id, title, language, publisher,
                               published_date, published_year, page_count, format)
    values (e_c1, w_clarke, 'Piranesi', 'en', 'Bloomsbury',  '2020',       2020, 272, 'hardcover'),
           (e_c2, w_clarke, 'Piranesi', 'it', 'Fazi',        'March 2021', 2021, 280, 'paperback'),
           (e_c3, w_clarke, 'Piranesi', 'en', 'Bloomsbury',  '2020',       2020, null,'audiobook');

    insert into dewey.edition_isbn (edition_id, isbn13, isbn10, source) values
        (e_c1, '9781526622426', '1526622424', 'openlibrary'),
        (e_c2, '9788893257619', null,         'openlibrary');

    -- Edition-level credits. A narrator on the audiobook and a translator on
    -- the Italian edition — neither can reach work-level credit, because
    -- `work_role` has no value for them.
    insert into dewey.edition_contributor (edition_id, author_id, role, position, source) values
        (e_c3, a_narr,  'narrator',   0, 'openlibrary'),
        (e_c2, a_trans, 'translator', 0, 'openlibrary');

    insert into dewey.work_signal (work_id, edition_count, recent_edition_count,
                                   ol_readers, popularity)
    values (w_clarke,   23, 23, 41000, 0.92),
           (w_giovanni, 25,  2,    30, 0.11),
           (w_james,     8,  8,  1200, 0.55),
           (w_csw,      31, 31,  9000, 0.71);

    -- Identifiers, including the prototype's own id for the seeded book.
    insert into dewey.identifier (entity_type, entity_id, provider, id_type, value, is_primary) values
        ('work',   w_clarke,   'openlibrary','ol_work',      'OL20893680W', true),
        ('work',   w_giovanni, 'openlibrary','ol_work',      'OL2827133W',  true),
        ('work',   w_james,    'openlibrary','ol_work',      'OL36506504W', true),
        ('work',   w_csw,      'openlibrary','ol_work',      'OL19744024W', true),
        ('work',   w_clarke,   'dewey_legacy','local_book_id','piranesi',   false),
        ('author', a_everett1, 'openlibrary','ol_author',    'OL_EVERETT_A',true),
        ('author', a_everett2, 'openlibrary','ol_author',    'OL_EVERETT_B',true),
        ('author', a_murata,   'openlibrary','ol_author',    'OL6573124A',  true);

    perform dewey.claim_field('work', w_clarke, 'description', 'openlibrary', src);
end $$;

select test.seed();

-- ===========================================================================
-- A. Core construction
-- ===========================================================================
do $$
declare n int; w uuid := '0190f8a2-0001-7000-8000-000000000001';
begin
    select count(*) into n from dewey.work where merged_into is null;
    perform test.ok('A. core', '4 live works created', n = 4, 'got '||n);

    select count(*) into n from dewey.edition where work_id = w;
    perform test.ok('A. core', 'work has multiple editions (3)', n = 3, 'got '||n);

    select count(*) into n from dewey.edition where work_id = w and format = 'audiobook';
    perform test.ok('A. core', 'audiobook edition distinguishable', n = 1, 'got '||n);

    -- The free-form original is kept alongside the parsed year.
    select count(*) into n from dewey.edition
     where work_id = w and published_date = 'March 2021' and published_year = 2021;
    perform test.ok('A. core', 'free-form publish_date preserved beside parsed year',
                    n = 1, 'got '||n);
end $$;

-- Exactly one display title per work.
select test.check('A. core', 'second is_display title on a work is rejected',
    $$insert into dewey.work_title (work_id, kind, title, source, is_display)
      values ('0190f8a2-0001-7000-8000-000000000001','alternate','Piranesi Two','openlibrary',true)$$,
    '23505');

-- ===========================================================================
-- B. Edition-level contributors
-- ===========================================================================
do $$
declare n int; w uuid := '0190f8a2-0001-7000-8000-000000000001';
begin
    select count(*) into n
      from dewey.edition_contributor ec
      join dewey.edition e on e.id = ec.edition_id
     where e.work_id = w and ec.role = 'translator';
    perform test.ok('B. contributors', 'edition-level translator recorded', n = 1, 'got '||n);

    select count(*) into n
      from dewey.edition_contributor ec
      join dewey.edition e on e.id = ec.edition_id
     where e.work_id = w and ec.role = 'narrator';
    perform test.ok('B. contributors', 'edition-level narrator recorded', n = 1, 'got '||n);

    -- The Red Rising bug, made structurally impossible: the narrator is not a
    -- work contributor, so work-level credit cannot pick them up.
    select count(*) into n
      from dewey.work_contributor
     where work_id = w and author_id = '0190f8a2-1007-7000-8000-000000000007';
    perform test.ok('B. contributors',
                    'narrator does NOT appear in work-level credits', n = 0, 'got '||n);
end $$;

-- `work_role` has no 'narrator' value at all — the type system refuses it.
select test.check('B. contributors', 'narrator is not expressible as a work role',
    $$insert into dewey.work_contributor (work_id, author_id, role, source)
      values ('0190f8a2-0001-7000-8000-000000000001',
              '0190f8a2-1007-7000-8000-000000000007','narrator','openlibrary')$$,
    '22P02');

-- ===========================================================================
-- C. Author names, romanization, diacritics
-- ===========================================================================
do $$
declare n int; m uuid := '0190f8a2-1005-7000-8000-000000000005'; got uuid;
begin
    select count(*) into n from dewey.author_name where author_id = m;
    perform test.ok('C. names', 'Murata has canonical + alternate names', n = 4, 'got '||n);

    -- THE case the spike failed on.
    select an.author_id into got from dewey.author_name an
     where an.folded = dewey.fold('Sayaka Murata') limit 1;
    perform test.ok('C. names',
        'searching "Sayaka Murata" reaches the 村田沙耶香 record',
        got = m, coalesce(got::text,'no match'));

    -- And the reverse still works.
    select an.author_id into got from dewey.author_name an
     where an.folded = dewey.fold('村田沙耶香') limit 1;
    perform test.ok('C. names', 'native-script name still resolves', got = m,
                    coalesce(got::text,'no match'));

    perform test.ok('C. names', 'diacritics fold (Hernán Díaz → hernan diaz)',
        dewey.fold('Hernán Díaz') = 'hernan diaz', dewey.fold('Hernán Díaz'));
    perform test.ok('C. names', 'apostrophes vanish rather than split',
        dewey.fold('The Handmaid''s Tale') = 'the handmaids tale',
        dewey.fold('The Handmaid''s Tale'));
    perform test.ok('C. names', 'article dropped for title_key',
        dewey.title_key('The Hobbit') = 'hobbit', dewey.title_key('The Hobbit'));
    perform test.ok('C. names', 'punctuation collapses (Tomorrow, and Tomorrow…)',
        dewey.title_key('Tomorrow, and Tomorrow, and Tomorrow')
          = 'tomorrow and tomorrow and tomorrow',
        dewey.title_key('Tomorrow, and Tomorrow, and Tomorrow'));
end $$;

-- Duplicate aliases are idempotent, not an ingest failure.
select test.check('C. names', 'duplicate alias insert is rejected by unique index',
    $$insert into dewey.author_name (author_id, name, kind, source)
      values ('0190f8a2-1005-7000-8000-000000000005','Sayaka Murata','romanization','openlibrary')$$,
    '23505');
select test.check('C. names', 'duplicate alias insert is idempotent with on-conflict',
    $$insert into dewey.author_name (author_id, name, kind, source)
      values ('0190f8a2-1005-7000-8000-000000000005','Sayaka Murata','romanization','openlibrary')
      on conflict do nothing$$,
    'ok');

-- ===========================================================================
-- D. Author merge (Percival Everett)
-- ===========================================================================
do $$
declare
    a1 uuid := '0190f8a2-1003-7000-8000-000000000003';  -- Percival Everett
    a2 uuid := '0190f8a2-1004-7000-8000-000000000004';  -- Percival L. Everett
    w  uuid := '0190f8a2-0003-7000-8000-000000000003';  -- James
    n int; got uuid;
begin
    perform dewey.merge_authors(a2, a1, 'duplicate');

    select count(*) into n from dewey.work_contributor where work_id = w and author_id = a1;
    perform test.ok('D. author merge', 'work now credits the surviving author', n = 1, 'got '||n);

    select count(*) into n from dewey.work_contributor where author_id = a2;
    perform test.ok('D. author merge', 'no relationships left on the loser', n = 0, 'got '||n);

    perform test.ok('D. author merge', 'old author id still resolves',
                    dewey.resolve_author(a2) = a1, dewey.resolve_author(a2)::text);

    select count(*) into n from dewey.author_name
     where author_id = a1 and name = 'Percival L. Everett';
    perform test.ok('D. author merge', 'losing name retained on the survivor', n >= 1, 'got '||n);

    -- Both spellings now find the work — the actual product outcome.
    select count(*) into n
      from dewey.author_name an
      join dewey.work_contributor wc on wc.author_id = an.author_id
     where wc.work_id = w
       and an.folded in (dewey.fold('Percival Everett'), dewey.fold('Percival L. Everett'));
    perform test.ok('D. author merge', 'both spellings reach "James"', n >= 2, 'got '||n);

    select entity_id into got from dewey.identifier
     where entity_type='author' and value='OL_EVERETT_B';
    perform test.ok('D. author merge', 'loser''s OL author id re-points to survivor',
                    got = a1, coalesce(got::text,'missing'));

    perform test.ok('D. author merge', 'merge is auditable (tombstone recorded)',
        (select merged_into from dewey.author where id = a2) = a1);
end $$;

select test.check('D. author merge', 'self-merge refused',
    $$select dewey.merge_authors('0190f8a2-1003-7000-8000-000000000003',
                                 '0190f8a2-1003-7000-8000-000000000003')$$, '22000');

-- ===========================================================================
-- E. Work merge, redirects, chains, cycles
-- ===========================================================================
do $$
declare
    w1 uuid := '0190f8a2-0001-7000-8000-000000000001';  -- Clarke
    w3 uuid := '0190f8a2-0003-7000-8000-000000000003';  -- James
    tmp uuid := '0190f8a2-00ff-7000-8000-0000000000ff';
    n int;
begin
    -- A duplicate work record arrives, then merges into Clarke.
    insert into dewey.work (id, display_title) values (tmp, 'Piranesi (dup)');
    insert into dewey.work_title (work_id, kind, title, source, is_display)
        values (tmp, 'canonical', 'Piranesi (dup)', 'openlibrary', true);
    insert into dewey.identifier (entity_type, entity_id, provider, id_type, value)
        values ('work', tmp, 'openlibrary', 'ol_work', 'OL_DUP_W');

    perform dewey.merge_works(tmp, w1, 'duplicate');

    perform test.ok('E. work merge', 'old work id resolves to survivor',
                    dewey.resolve_work(tmp) = w1, dewey.resolve_work(tmp)::text);

    select count(*) into n from dewey.identifier
     where entity_type='work' and value='OL_DUP_W' and entity_id = w1;
    perform test.ok('E. work merge', 'loser''s external identifier still resolves', n = 1, 'got '||n);

    select count(*) into n from dewey.work_title
     where work_id = w1 and title = 'Piranesi (dup)';
    perform test.ok('E. work merge', 'loser''s title survives as an alternate', n = 1, 'got '||n);

    select count(*) into n from dewey.work_title where work_id = w1 and is_display;
    perform test.ok('E. work merge', 'survivor still has exactly one display title', n = 1, 'got '||n);

    perform test.ok('E. work merge', 'canonical work NOT deleted by the merge',
        exists (select 1 from dewey.work where id = w1 and merged_into is null));
    perform test.ok('E. work merge', 'loser kept as an auditable tombstone',
        (select merged_into from dewey.work where id = tmp) = w1);
end $$;

-- Chained redirect: A→B then B→C must collapse so A→C is one hop.
do $$
declare
    a uuid := '0190f8a2-0aaa-7000-8000-00000000000a';
    b uuid := '0190f8a2-0bbb-7000-8000-00000000000b';
    c uuid := '0190f8a2-0ccc-7000-8000-00000000000c';
    hops int;
begin
    insert into dewey.work (id, display_title) values (a,'A'),(b,'B'),(c,'C');
    perform dewey.merge_works(a, b, 'duplicate');
    perform dewey.merge_works(b, c, 'duplicate');

    perform test.ok('E. work merge', 'chained redirect A→B→C resolves to C',
                    dewey.resolve_work(a) = c, dewey.resolve_work(a)::text);

    -- Collapsed at write time: A points directly at C, not at B.
    select count(*) into hops from dewey.work_redirect where old_id = a and new_id = c;
    perform test.ok('E. work merge', 'chain collapsed to a single hop at write time',
                    hops = 1, 'direct A→C rows: '||hops);
end $$;

select test.check('E. work merge', 'cycle-forming merge refused (C→A when A→C exists)',
    $$select dewey.merge_works('0190f8a2-0ccc-7000-8000-00000000000c',
                               '0190f8a2-0aaa-7000-8000-00000000000a')$$, '22000');
select test.check('E. work merge', 'self-redirect rejected by check constraint',
    $$insert into dewey.work_redirect (old_id, new_id, reason)
      values ('0190f8a2-0001-7000-8000-000000000001',
              '0190f8a2-0001-7000-8000-000000000001','duplicate')$$, '23514');

-- ===========================================================================
-- F. Legacy prototype id resolution
-- ===========================================================================
do $$
declare w1 uuid := '0190f8a2-0001-7000-8000-000000000001'; got uuid;
begin
    -- The path the whole ID decision rests on:
    --   'piranesi' → identifier(dewey_legacy) → uuid → resolve_work() → live uuid
    got := dewey.resolve_external_work('local_book_id','piranesi');
    perform test.ok('F. legacy ids', '"piranesi" resolves to the canonical work uuid',
                    got = w1, coalesce(got::text,'unresolved'));

    got := dewey.resolve_external_work('ol_work','OL20893680W');
    perform test.ok('F. legacy ids', 'OL work id resolves through the same path',
                    got = w1, coalesce(got::text,'unresolved'));

    got := dewey.resolve_external_work('local_book_id','no-such-slug');
    perform test.ok('F. legacy ids', 'unknown legacy id returns null, not an error',
                    got is null, coalesce(got::text,'null'));

    -- A legacy id pointing at a merged work must follow the redirect too.
    got := dewey.resolve_external_work('ol_work','OL_DUP_W');
    perform test.ok('F. legacy ids', 'legacy id of a merged work resolves to survivor',
                    got = w1, coalesce(got::text,'unresolved'));
end $$;

-- One external id maps to one entity: the constraint that keeps ingest idempotent.
select test.check('F. legacy ids', 'duplicate OL identifier rejected',
    $$insert into dewey.identifier (entity_type, entity_id, provider, id_type, value)
      values ('work','0190f8a2-0002-7000-8000-000000000002','openlibrary','ol_work','OL20893680W')$$,
    '23505');

-- ===========================================================================
-- G. ISBN
-- ===========================================================================
do $$
begin
    perform test.ok('G. isbn', 'ISBN-10 → ISBN-13 conversion',
        dewey.isbn_to_13('1526622424') = '9781526622426',
        coalesce(dewey.isbn_to_13('1526622424'),'null'));
    perform test.ok('G. isbn', 'hyphenated ISBN-13 normalises',
        dewey.isbn_to_13('978-1-5266-2242-6') = '9781526622426',
        coalesce(dewey.isbn_to_13('978-1-5266-2242-6'),'null'));
    perform test.ok('G. isbn', 'ISBN-10 with X check digit',
        dewey.isbn_to_13('043942089X') = '9780439420891',
        coalesce(dewey.isbn_to_13('043942089X'),'null'));
    perform test.ok('G. isbn', 'malformed ISBN returns null, does not raise',
        dewey.isbn_to_13('not-an-isbn') is null);
    perform test.ok('G. isbn', 'bad ISBN-13 checksum returns null',
        dewey.isbn_to_13('9781526622427') is null);
    perform test.ok('G. isbn', 'bad ISBN-10 checksum returns null',
        dewey.isbn_to_13('1526622425') is null);
end $$;

-- Checksum enforcement at the storage layer: a malformed ISBN cannot be stored
-- even if the ingest forgets to validate.
select test.check('G. isbn', 'malformed ISBN-13 rejected by check constraint',
    $$insert into dewey.edition_isbn (edition_id, isbn13, source)
      values ('0190f8a2-2001-7000-8000-000000000001','9781526622427','openlibrary')$$, '23514');
select test.check('G. isbn', 'non-numeric ISBN-13 rejected',
    $$insert into dewey.edition_isbn (edition_id, isbn13, source)
      values ('0190f8a2-2001-7000-8000-000000000001','ABCDEFGHIJKLM','openlibrary')$$, '23514');
select test.check('G. isbn', 'same ISBN twice on one edition rejected',
    $$insert into dewey.edition_isbn (edition_id, isbn13, source)
      values ('0190f8a2-2001-7000-8000-000000000001','9781526622426','openlibrary')$$, '23505');

-- The decided behaviour: a duplicate ISBN across editions is ACCEPTED.
-- Measured at 2.17% of real ISBNs in the spike corpus; a global unique index
-- would reject thousands of legitimate editions at ingest.
select test.check('G. isbn', 'duplicate ISBN across two editions is ACCEPTED (by design)',
    $$insert into dewey.edition_isbn (edition_id, isbn13, source)
      values ('0190f8a2-2002-7000-8000-000000000002','9781526622426','openlibrary')$$, 'ok');

do $$
declare n int; r record;
begin
    -- Same work, so not a collision worth reporting.
    select count(*) into n from dewey.isbn_collision where isbn13 = '9781526622426';
    perform test.ok('G. isbn', 'same-work duplicate ISBN is not flagged as a collision',
                    n = 0, 'got '||n);

    -- Cross-work duplicate: the 0.15% case, and a genuine duplicate-work signal.
    insert into dewey.edition (id, work_id, title)
      values ('0190f8a2-2009-7000-8000-000000000009',
              '0190f8a2-0002-7000-8000-000000000002','Piranesi etchings');
    insert into dewey.edition_isbn (edition_id, isbn13, source)
      values ('0190f8a2-2009-7000-8000-000000000009','9781526622426','openlibrary');

    select count(*) into n from dewey.isbn_collision where isbn13 = '9781526622426';
    perform test.ok('G. isbn', 'cross-work ISBN collision IS surfaced for review',
                    n = 1, 'got '||n);

    -- Exact lookup remains deterministic despite the collision.
    select * into r from dewey.resolve_isbn('978-1-5266-2242-6') limit 1;
    perform test.ok('G. isbn', 'ISBN lookup is deterministic, highest popularity first',
                    r.work_id = '0190f8a2-0001-7000-8000-000000000001',
                    coalesce(r.work_id::text,'none'));

    select count(*) into n from dewey.resolve_isbn('9999999999999');
    perform test.ok('G. isbn', 'unknown ISBN returns no rows', n = 0, 'got '||n);

    delete from dewey.edition where id = '0190f8a2-2009-7000-8000-000000000009';
end $$;

-- ===========================================================================
-- H. Edition merge
-- ===========================================================================
do $$
declare
    e1 uuid := '0190f8a2-2001-7000-8000-000000000001';
    e2 uuid := '0190f8a2-2002-7000-8000-000000000002';
    n int;
begin
    perform dewey.merge_editions(e2, e1, 'duplicate');
    perform test.ok('H. edition merge', 'old edition id resolves to survivor',
                    dewey.resolve_edition(e2) = e1, dewey.resolve_edition(e2)::text);

    select count(*) into n from dewey.edition_isbn where edition_id = e2;
    perform test.ok('H. edition merge', 'ISBNs moved off the loser', n = 0, 'got '||n);

    select count(*) into n from dewey.edition_isbn where edition_id = e1;
    perform test.ok('H. edition merge', 'survivor carries both ISBNs', n = 2, 'got '||n);

    select count(*) into n from dewey.edition_contributor where edition_id = e2;
    perform test.ok('H. edition merge', 'edition contributors moved', n = 0, 'got '||n);
end $$;

-- ===========================================================================
-- I. Field provenance
-- ===========================================================================
do $$
declare
    w uuid := '0190f8a2-0001-7000-8000-000000000001';
    src_ol bigint; src_ni bigint; cur record; okflag boolean;
begin
    select id into src_ol from dewey.source_record where provider='openlibrary' limit 1;
    insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                     source_version, payload)
    values ('nielsen','work','9781526622426','api','2026-08-10','{"description":"publisher copy"}')
    returning id into src_ni;

    -- 1. OL owns the field.
    select * into cur from dewey.field_provenance
     where entity_type='work' and entity_id=w and field='description';
    perform test.ok('I. provenance', 'OL initially owns description',
                    cur.provider = 'openlibrary', cur.provider::text);

    -- 2. Nielsen supersedes it.
    okflag := dewey.claim_field('work', w, 'description', 'nielsen', src_ni);
    perform test.ok('I. provenance', 'Nielsen supersedes OL', okflag);
    select * into cur from dewey.field_provenance
     where entity_type='work' and entity_id=w and field='description';
    perform test.ok('I. provenance', 'provenance now records Nielsen',
                    cur.provider = 'nielsen', cur.provider::text);
    perform test.ok('I. provenance', 'provenance cites the Nielsen source record',
                    cur.source_record_id = src_ni);

    -- 3. Dewey work id is unchanged by the provider switch.
    perform test.ok('I. provenance', 'work id unchanged after provider switch',
                    exists (select 1 from dewey.work where id = w and merged_into is null));

    -- 4. A later OL refresh must NOT overwrite the higher-ranked value.
    okflag := dewey.claim_field('work', w, 'description', 'openlibrary', src_ol);
    perform test.ok('I. provenance', 'later OL refresh is refused', not okflag);
    select * into cur from dewey.field_provenance
     where entity_type='work' and entity_id=w and field='description';
    perform test.ok('I. provenance', 'Nielsen value survives the OL refresh',
                    cur.provider = 'nielsen', cur.provider::text);

    -- 5. Editorial lock survives everything.
    okflag := dewey.claim_field('work', w, 'description', 'dewey_editorial', null, true);
    perform test.ok('I. provenance', 'editorial override accepted', okflag);
    okflag := dewey.claim_field('work', w, 'description', 'nielsen', src_ni);
    perform test.ok('I. provenance', 'locked field refuses Nielsen', not okflag);
    okflag := dewey.claim_field('work', w, 'description', 'openlibrary', src_ol);
    perform test.ok('I. provenance', 'locked field refuses OL', not okflag);
    select * into cur from dewey.field_provenance
     where entity_type='work' and entity_id=w and field='description';
    perform test.ok('I. provenance', 'locked editorial value still in place',
                    cur.provider = 'dewey_editorial' and cur.locked, cur.provider::text);

    -- Same-rank refresh is allowed, so a monthly run can update its own value.
    okflag := dewey.claim_field('work', w, 'series_name', 'openlibrary', src_ol);
    perform test.ok('I. provenance', 'new field claimed by OL', okflag);
    okflag := dewey.claim_field('work', w, 'series_name', 'openlibrary', src_ol);
    perform test.ok('I. provenance', 'same-provider refresh permitted', okflag);
end $$;

-- ===========================================================================
-- J. Source records
-- ===========================================================================
select test.check('J. source', 'dump-acquired record may not carry a payload',
    $$insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                       source_version, payload)
      values ('openlibrary','work','OL_X','dump','2026-07-31','{"a":1}')$$, '23514');
select test.check('J. source', 'API-acquired record MAY carry a payload',
    $$insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                       source_version, payload)
      values ('openlibrary','work','OL_Y','api','2026-08-10','{"a":1}')$$, 'ok');
select test.check('J. source', 'same provider record re-imported in a new dump version is allowed',
    $$insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                       source_version, content_hash)
      values ('openlibrary','work','OL20893680W','dump','2026-08-31','h2')$$, 'ok');
select test.check('J. source', 'same provider record twice in one dump version rejected',
    $$insert into dewey.source_record (provider, record_type, provider_id, acquisition,
                                       source_version, content_hash)
      values ('openlibrary','work','OL20893680W','dump','2026-07-31','h1')$$, '23505');

-- ===========================================================================
-- K. Covers
-- ===========================================================================
do $$
declare
    w  uuid := '0190f8a2-0001-7000-8000-000000000001';
    c1 uuid := '0190f8a2-3001-7000-8000-000000000001';
    c2 uuid := '0190f8a2-3002-7000-8000-000000000002';
    n int;
begin
    insert into dewey.cover (id, work_id, source, source_ref, license_posture, fetched_at)
    values (c1, w, 'openlibrary', '8225261', 'unlicensed_cached', now());
    update dewey.work set display_cover_id = c1 where id = w;
    perform test.ok('K. covers', 'OL cover attached as display cover',
        (select display_cover_id from dewey.work where id = w) = c1);

    -- A licensed cover arrives and takes over.
    insert into dewey.cover (id, work_id, source, source_ref, license_posture)
    values (c2, w, 'licensed', 'nielsen-asset-991', 'licensed');
    update dewey.work set display_cover_id = c2 where id = w;
    perform test.ok('K. covers', 'licensed cover replaces it',
        (select display_cover_id from dewey.work where id = w) = c2);
    perform test.ok('K. covers', 'previous cover row retained for provenance',
        exists (select 1 from dewey.cover where id = c1));

    -- Purge every unlicensed cover — one indexed statement.
    update dewey.cover set purged_at = now() where source = 'openlibrary';
    select count(*) into n from dewey.cover where source='openlibrary' and purged_at is not null;
    perform test.ok('K. covers', 'purge by source marks rows purged', n = 1, 'got '||n);

    -- Removing the display cover entirely must NOT delete the work: the
    -- deterministic typeset palette becomes the cover.
    update dewey.work set display_cover_id = null where id = w;
    delete from dewey.cover where id = c2;
    perform test.ok('K. covers', 'work survives losing every external cover',
        exists (select 1 from dewey.work where id = w and merged_into is null));
    perform test.ok('K. covers', 'display_cover_id is null, ready for typeset fallback',
        (select display_cover_id from dewey.work where id = w) is null);
end $$;

select test.check('K. covers', 'cover must target exactly one of work/edition',
    $$insert into dewey.cover (id, work_id, edition_id, source, source_ref, license_posture)
      values (dewey.uuid_v7(),'0190f8a2-0001-7000-8000-000000000001',
              '0190f8a2-2001-7000-8000-000000000001','openlibrary','x','unlicensed_cached')$$,
    '23514');

-- Deleting a cover that a work points at must null the pointer, not cascade.
do $$
declare w uuid := '0190f8a2-0001-7000-8000-000000000001'; c3 uuid := dewey.uuid_v7();
begin
    insert into dewey.cover (id, work_id, source, source_ref, license_posture)
      values (c3, w, 'publisher', 'pub-1', 'unlicensed_cached');
    update dewey.work set display_cover_id = c3 where id = w;
    delete from dewey.cover where id = c3;
    perform test.ok('K. covers', 'cover delete nulls the pointer (on delete set null)',
        exists (select 1 from dewey.work where id = w and display_cover_id is null));
end $$;

-- ===========================================================================
-- L. Work signals
-- ===========================================================================
do $$
declare w uuid := '0190f8a2-0001-7000-8000-000000000001'; g uuid := '0190f8a2-0002-7000-8000-000000000002';
    r_clarke real; r_giov real; n int;
begin
    -- The Piranesi inversion, stated as an assertion.
    select edition_count into n from dewey.work_signal where work_id = g;
    perform test.ok('L. signals', 'etchings genuinely have MORE editions (25 > 23)',
        n = 25 and (select edition_count from dewey.work_signal where work_id = w) = 23);

    select popularity into r_clarke from dewey.work_signal where work_id = w;
    select popularity into r_giov  from dewey.work_signal where work_id = g;
    perform test.ok('L. signals',
        'reading-activity popularity still ranks the novel first',
        r_clarke > r_giov, format('clarke=%s giovanni=%s', r_clarke, r_giov));

    -- Upsert, the shape a nightly aggregate uses.
    insert into dewey.work_signal (work_id, edition_count, ol_readers, popularity)
    values (w, 24, 42000, 0.94)
    on conflict (work_id) do update
       set edition_count = excluded.edition_count,
           ol_readers    = excluded.ol_readers,
           popularity    = excluded.popularity,
           computed_at   = now();
    select ol_readers into n from dewey.work_signal where work_id = w;
    perform test.ok('L. signals', 'signal upsert refreshes in place', n = 42000, 'got '||n);
end $$;

select test.check('L. signals', 'completeness out of range rejected',
    $$insert into dewey.work_signal (work_id, completeness)
      values ('0190f8a2-0004-7000-8000-000000000004', 250)
      on conflict (work_id) do update set completeness = 250$$, '23514');

-- ===========================================================================
-- M. Cascade / restrict behaviour
-- ===========================================================================
do $$
declare
    w uuid := '0190f8a2-0004-7000-8000-000000000004';   -- Convenience Store Woman
    a uuid := '0190f8a2-1005-7000-8000-000000000005';   -- Murata
    n int;
begin
    -- An author still credited on a work cannot be deleted: restrict, not
    -- cascade. Losing a work because an author row was tidied away would be a
    -- catastrophic silent failure.
    begin
        delete from dewey.author where id = a;
        perform test.ok('M. cascade', 'author with credits cannot be deleted', false,
                        'delete unexpectedly succeeded');
    exception when foreign_key_violation then
        perform test.ok('M. cascade', 'author with credits cannot be deleted (23503)', true);
    end;

    -- Deleting a work does cascade to its own subordinate rows.
    insert into dewey.work (id, display_title) values
        ('0190f8a2-0eee-7000-8000-00000000000e','Disposable');
    insert into dewey.work_title (work_id, kind, title, source, is_display)
        values ('0190f8a2-0eee-7000-8000-00000000000e','canonical','Disposable','openlibrary',true);
    delete from dewey.work where id = '0190f8a2-0eee-7000-8000-00000000000e';
    select count(*) into n from dewey.work_title
     where work_id = '0190f8a2-0eee-7000-8000-00000000000e';
    perform test.ok('M. cascade', 'work delete cascades to its titles', n = 0, 'got '||n);
end $$;

-- ===========================================================================
-- N. Upstream disappearance must not delete canonical data
-- ===========================================================================
do $$
declare w uuid := '0190f8a2-0004-7000-8000-000000000004'; n int;
begin
    -- Simulate the record vanishing upstream: the ingest stops seeing the OL
    -- id and marks the identifier stale. The work, its editions and every
    -- user reference to it must survive untouched — this is the Letterboxd
    -- guarantee, and it is the single most important row in this file.
    update dewey.identifier
       set last_seen_at = now() - interval '90 days'
     where entity_type = 'work' and entity_id = w;

    perform test.ok('N. durability', 'work survives its upstream record disappearing',
        exists (select 1 from dewey.work where id = w and merged_into is null));

    select count(*) into n from dewey.identifier
     where entity_type='work' and entity_id=w and last_seen_at < now() - interval '30 days';
    perform test.ok('N. durability', 'stale identifier is detectable, not deleted', n = 1, 'got '||n);

    -- Deleting the source record must not take the catalog with it.
    delete from dewey.source_record where provider = 'openlibrary' and provider_id = 'OL_Y';
    perform test.ok('N. durability', 'deleting a source record leaves the work intact',
        exists (select 1 from dewey.work where id = w));

    -- And provenance survives a source record deletion, degraded not destroyed.
    perform test.ok('N. durability', 'provenance rows survive source deletion (set null)',
        exists (select 1 from dewey.field_provenance
                 where entity_type='work' and entity_id='0190f8a2-0001-7000-8000-000000000001'));
end $$;

-- ===========================================================================
-- O. Identity discipline
-- ===========================================================================
do $$
declare n int;
begin
    -- No canonical id column may default to a random uuid: a silent v4
    -- fallback is exactly what the design forbids.
    select count(*) into n
      from information_schema.columns
     where table_schema='dewey' and column_name='id'
       and table_name in ('work','edition','author','cover')
       and column_default is not null;
    perform test.ok('O. identity', 'no canonical id column has a server-side default',
                    n = 0, n||' column(s) default to something');

    select count(*) into n
      from information_schema.columns
     where table_schema='dewey' and table_name in ('work','edition','author','cover')
       and column_name='id' and data_type <> 'uuid';
    perform test.ok('O. identity', 'all canonical ids are uuid, not text',
                    n = 0, n||' non-uuid id column(s)');

    perform test.ok('O. identity', 'uuid_v7() produces a version-7 uuid',
        substr(dewey.uuid_v7()::text, 15, 1) = '7', dewey.uuid_v7()::text);

    -- v7 is time-ordered; two successive values must sort in creation order.
    perform test.ok('O. identity', 'uuid_v7() is time-ordered',
        dewey.uuid_v7() < dewey.uuid_v7());
end $$;

-- ===========================================================================
-- P. Search projection + indexes
-- ===========================================================================
do $$
declare target_id uuid := '0190f8a2-0004-7000-8000-000000000004'; n int;
begin
    insert into dewey.work_search (work_id, display_title, display_authors, title_key,
                                   title_folded, alt_title_keys, authors_folded,
                                   authors_blob, year, work_type, popularity, tsv)
    select wk.id, wk.display_title, 'Sayaka Murata',
           dewey.title_key(wk.display_title), dewey.fold(wk.display_title),
           array(select t.title_key from dewey.work_title t where t.work_id = wk.id),
           array(select distinct an.folded
                   from dewey.work_contributor wc
                   join dewey.author_name an on an.author_id = wc.author_id
                  where wc.work_id = wk.id),
           (select string_agg(distinct an.folded, ' ')
              from dewey.work_contributor wc
              join dewey.author_name an on an.author_id = wc.author_id
             where wc.work_id = wk.id),
           wk.first_published_year, wk.work_type, 0.71,
           setweight(to_tsvector('simple', unaccent(wk.display_title)), 'A')
        || setweight(to_tsvector('simple', unaccent('Sayaka Murata')), 'B')
      from dewey.work wk where wk.id = target_id
      on conflict (work_id) do nothing;

    -- The romanised alias reached the search projection — the whole point.
    select count(*) into n from dewey.work_search
     where work_id = target_id and dewey.fold('Sayaka Murata') = any(authors_folded);
    perform test.ok('P. search', 'romanised author alias lands in the search projection',
                    n = 1, 'got '||n);

    select count(*) into n from dewey.work_search
     where work_id = target_id and dewey.fold('村田沙耶香') = any(authors_folded);
    perform test.ok('P. search', 'native-script author name also indexed', n = 1, 'got '||n);

    select count(*) into n from dewey.work_search
     where work_id = target_id and tsv @@ plainto_tsquery('simple','convenience store woman');
    perform test.ok('P. search', 'tsvector matches the title', n = 1, 'got '||n);

    -- The original Japanese title is a searchable alternate.
    select count(*) into n from dewey.work_search
     where work_id = target_id and dewey.title_key('コンビニ人間') = any(alt_title_keys);
    perform test.ok('P. search', 'original-language title indexed as an alternate',
                    n = 1, 'got '||n);
end $$;

do $$
declare n int;
begin
    select count(*) into n from pg_indexes
     where schemaname='dewey' and indexdef like '%gin%' and indexdef like '%trgm%';
    perform test.ok('P. search', 'trigram indexes exist for typo tolerance', n >= 3, 'got '||n);

    select count(*) into n from pg_indexes
     where schemaname='dewey' and tablename='work_search' and indexdef like '%gin (tsv)%';
    perform test.ok('P. search', 'tsvector GIN index exists', n = 1, 'got '||n);

    select count(*) into n from pg_indexes
     where schemaname='dewey' and tablename='work_search' and indexdef like '%isbns%';
    perform test.ok('P. search', 'ISBN array GIN index exists', n = 1, 'got '||n);
end $$;

-- ===========================================================================
-- Q. RLS posture
-- ===========================================================================
do $$
declare n int;
begin
    select count(*) into n from pg_tables
     where schemaname='dewey' and not rowsecurity;
    perform test.ok('Q. rls', 'every catalog table has RLS enabled', n = 0,
                    n||' table(s) without RLS');

    select count(*) into n from information_schema.role_table_grants
     where table_schema='dewey' and table_name in ('identifier','source_record','field_provenance')
       and grantee in ('anon','authenticated');
    perform test.ok('Q. rls', 'operational tables are not granted to API roles',
                    n = 0, n||' grant(s) leaked');

    select count(*) into n from information_schema.role_table_grants
     where table_schema='dewey' and table_name='work'
       and grantee='authenticated' and privilege_type='SELECT';
    perform test.ok('Q. rls', 'authenticated can read the catalog', n = 1, 'got '||n);

    select count(*) into n from information_schema.role_table_grants
     where table_schema='dewey' and grantee in ('anon','authenticated')
       and privilege_type in ('INSERT','UPDATE','DELETE');
    perform test.ok('Q. rls', 'API roles hold no write privilege anywhere in the catalog',
                    n = 0, n||' write grant(s)');
end $$;

-- Report =====================================================================
\echo ''
\echo '================ CATALOG VERIFICATION RESULTS ================'
select section, label, outcome, detail from test.results order by id;

\echo ''
select outcome, count(*) from test.results group by outcome order by outcome;

select case when count(*) = 0
            then 'ALL CHECKS PASSED'
            else count(*)||' FAILURE(S) — see above' end as summary
from test.results where outcome = 'FAIL';
