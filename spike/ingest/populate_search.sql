-- Populate dewey.work_search from the ingested catalog. Search tuning is
-- explicitly out of scope here; this only proves the normalized rows expose
-- everything the approved Postgres FTS + trigram path requires.
truncate dewey.work_search;

insert into dewey.work_search
    (work_id, display_title, display_authors, title_key, title_folded,
     alt_title_keys, authors_folded, authors_blob, isbns, year, languages,
     work_type, is_derivative, popularity, completeness, cover_ref, tsv)
select
    w.id,
    w.display_title,
    (select string_agg(distinct an.name, ', ')
       from dewey.work_contributor wc
       join dewey.author_name an on an.author_id = wc.author_id and an.kind = 'canonical'
      where wc.work_id = w.id),
    dewey.title_key(w.display_title),
    dewey.fold(w.display_title),
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
    w.work_type,
    coalesce(s.is_derivative, false),
    coalesce(s.popularity, ln(1 + coalesce(s.edition_count, 0)) * 0.1),
    coalesce(s.completeness, 0),
    (select c.source || ':' || c.source_ref from dewey.cover c where c.id = w.display_cover_id),
    setweight(to_tsvector('simple', unaccent(w.display_title)), 'A')
 || setweight(to_tsvector('simple', unaccent(coalesce(
       (select string_agg(distinct an.name, ' ')
          from dewey.work_contributor wc
          join dewey.author_name an on an.author_id = wc.author_id
         where wc.work_id = w.id), ''))), 'B')
 || setweight(to_tsvector('simple', unaccent(coalesce(
       (select string_agg(distinct t.title, ' ') from dewey.work_title t
         where t.work_id = w.id and not t.is_display), ''))), 'B')
 || setweight(to_tsvector('simple', unaccent(coalesce(w.display_subtitle, ''))), 'C')
 || setweight(to_tsvector('simple', unaccent(coalesce(w.series_name, ''))), 'C')
 || setweight(to_tsvector('simple', unaccent(coalesce(
       (select string_agg(distinct sj.label, ' ') from dewey.work_subject ws
          join dewey.subject sj on sj.id = ws.subject_id
         where ws.work_id = w.id), ''))), 'D')
from dewey.work w
left join dewey.work_signal s on s.work_id = w.id
where w.merged_into is null;

select count(*) as work_search_rows from dewey.work_search;
