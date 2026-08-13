-- Staging tables for the production ingestion pipeline.
--
-- UNLOGGED: no WAL for these tables at all. They hold nothing durable --
-- every row here is reproducible by re-reading the source dump, so paying
-- WAL-write cost to protect them against a crash is pure waste. This is the
-- single biggest lever in "COPY vs execute_values vs staging tables" (see
-- the implementation notes): WAL is often the dominant cost of bulk load,
-- and UNLOGGED staging removes it entirely for the intermediate step.
--
-- BATCH-TAGGED, not one-table-per-batch: a `batch_id` column lets many
-- batches share one staging table, filtered reconciliation SQL processes one
-- batch's rows at a time, and rows are deleted after a batch reconciles
-- successfully -- so staging never grows unbounded across a long run, and a
-- resumed run's first action (delete any half-loaded batch, reload it) is
-- cheap regardless of how many batches came before.
create schema if not exists stg;

drop table if exists stg.author;
create unlogged table stg.author (
    batch_id  int not null,
    ol_key    text not null,
    name      text,
    alt_names text[] not null default '{}'
);
create index on stg.author (batch_id);

drop table if exists stg.work;
create unlogged table stg.work (
    batch_id     int not null,
    ol_key       text not null,
    title        text,
    subtitle     text,
    alt_titles   text[] not null default '{}',
    author_keys  text[] not null default '{}',
    subjects     text[] not null default '{}',
    first_pub_date text,
    cover_ol_id  bigint,
    has_desc     boolean not null default false,
    revision     int
);
create index on stg.work (batch_id);

drop table if exists stg.edition;
create unlogged table stg.edition (
    batch_id     int not null,
    ol_key       text not null,
    work_key     text not null,
    title        text,
    subtitle     text,
    isbn13       text[] not null default '{}',
    isbn10       text[] not null default '{}',
    publish_date text,
    languages    text[] not null default '{}',
    pages        int,
    series       text,
    cover_ol_id  bigint,
    format_raw   text,
    publisher    text,
    ddc          text,
    author_keys  text[] not null default '{}',
    contributors jsonb not null default '[]',   -- [{"name":..,"role":..}, ...]
    has_desc     boolean not null default false
);
create index on stg.edition (batch_id);
create index on stg.edition (work_key);
