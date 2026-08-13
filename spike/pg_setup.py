#!/usr/bin/env python3
"""Load docs.jsonl into Postgres and build FTS + trigram indexes."""
import json, sys, time, subprocess, io

DB = "dewey_spike"
PSQL = "/opt/homebrew/opt/postgresql@15/bin/psql"

SCHEMA = """
drop table if exists doc cascade;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

create table doc (
  id                text primary key,
  title             text not null,
  -- NOT NULL deliberately omitted: fold()/title_key() can legitimately
  -- return "" for titles in scripts where diacritic-stripping removes
  -- everything (observed on a Gurmukhi title) — that's real data, not
  -- an ingest error, and the COPY encoder maps "" -> NULL for every column.
  title_key         text,
  title_folded      text,
  subtitle          text,
  alt_titles        text[],
  authors           text[],
  authors_folded    text[],
  series            text,
  isbn13            text[],
  isbn10            text[],
  year              int,
  edition_count     int not null default 0,
  work_record_count int not null default 1,
  languages         text[],
  pages             int,
  subjects          text[],
  ddc               text,
  cover_id          bigint,
  has_description   int not null default 0,
  has_cover         int not null default 0,
  is_derivative     int not null default 0,
  authors_blob      text,
  tsv               tsvector
);
"""

# NOTE: a functional GIN index over array_to_string(...) is rejected — the
# function is STABLE, not IMMUTABLE — so authors_blob is a real column.
INDEXES = """
update doc set authors_blob = coalesce(array_to_string(authors_folded,' '),'');

-- Weighting encodes the prototype's lesson: a title match outranks an author
-- match, but author tokens still count so 'Piranesi Susanna Clarke' resolves.
-- Subjects sit at D so folksonomy noise can never drive a result.
update doc set tsv =
    setweight(to_tsvector('simple', unaccent(coalesce(title,''))), 'A')
  || setweight(to_tsvector('simple', unaccent(coalesce(array_to_string(authors,' '),''))), 'B')
  || setweight(to_tsvector('simple', unaccent(coalesce(array_to_string(alt_titles,' '),''))), 'B')
  || setweight(to_tsvector('simple', unaccent(coalesce(subtitle,''))), 'C')
  || setweight(to_tsvector('simple', unaccent(coalesce(series,''))), 'C')
  || setweight(to_tsvector('simple', unaccent(coalesce(array_to_string(subjects,' '),''))), 'D');

create index doc_tsv_idx    on doc using gin(tsv);
create index doc_tkey_trgm  on doc using gin(title_key gin_trgm_ops);
create index doc_auth_trgm  on doc using gin(authors_blob gin_trgm_ops);
create index doc_isbn13     on doc using gin(isbn13);
create index doc_isbn10     on doc using gin(isbn10);
create index doc_edcount    on doc(edition_count desc);
analyze doc;
"""


def psql(sql, db=DB):
    p = subprocess.run([PSQL, "-d", db, "-v", "ON_ERROR_STOP=1", "-c", sql],
                       capture_output=True, text=True)
    if p.returncode != 0:
        print(p.stderr[:2000], file=sys.stderr)
        sys.exit(1)
    return p.stdout


def main():
    subprocess.run([PSQL, "-d", "postgres", "-c", f"drop database if exists {DB}"],
                   capture_output=True, text=True)
    subprocess.run([PSQL, "-d", "postgres", "-c", f"create database {DB}"],
                   capture_output=True, text=True)
    psql(SCHEMA)

    def arr(xs):
        if not xs:
            return "{}"
        return "{" + ",".join('"' + str(x).replace("\\", "\\\\").replace('"', '\\"') + '"'
                              for x in xs) + "}"

    def cell(v):
        if v is None or v == "":
            return "\\N"
        return (str(v).replace("\\", "\\\\").replace("\t", " ")
                .replace("\n", " ").replace("\r", " "))

    cols = ("id,title,title_key,title_folded,subtitle,alt_titles,authors,authors_folded,"
            "series,isbn13,isbn10,year,edition_count,work_record_count,languages,pages,"
            "subjects,ddc,cover_id,has_description,has_cover,is_derivative")

    t0 = time.time()
    buf = io.StringIO()
    n = 0
    for line in open("docs.jsonl"):
        d = json.loads(line)
        buf.write("\t".join([
            cell(d["id"]), cell(d["title"]), cell(d["title_key"]), cell(d["title_folded"]),
            cell(d.get("subtitle")), cell(arr(d.get("alt_titles"))), cell(arr(d.get("authors"))),
            cell(arr(d.get("authors_folded"))), cell(d.get("series")),
            cell(arr(d.get("isbn13"))), cell(arr(d.get("isbn10"))),
            cell(d.get("year")), cell(d.get("edition_count", 0)),
            cell(d.get("work_record_count", 1)), cell(arr(d.get("languages"))),
            cell(d.get("pages")), cell(arr(d.get("subjects"))), cell(d.get("ddc")),
            cell(d.get("cover_id")), cell(d.get("has_description", 0)),
            cell(d.get("has_cover", 0)), cell(d.get("is_derivative", 0)),
        ]) + "\n")
        n += 1
    p = subprocess.run([PSQL, "-d", DB, "-v", "ON_ERROR_STOP=1",
                        "-c", f"copy doc ({cols}) from stdin"],
                       input=buf.getvalue(), capture_output=True, text=True)
    if p.returncode != 0:
        print(p.stderr[:3000], file=sys.stderr)
        sys.exit(1)
    t_copy = time.time() - t0
    print(f"copied {n:,} rows in {t_copy:.1f}s", file=sys.stderr)

    t1 = time.time()
    psql(INDEXES)
    t_idx = time.time() - t1
    print(f"indexed in {t_idx:.1f}s", file=sys.stderr)

    size = psql("select pg_size_pretty(pg_total_relation_size('doc'))").strip().splitlines()[2].strip()
    print(f"table+index size: {size}", file=sys.stderr)
    json.dump({"engine": "postgres", "docs": n, "load_s": round(t_copy, 1),
               "index_s": round(t_idx, 1), "size": size},
              open("stats_postgres.json", "w"))


if __name__ == "__main__":
    main()
