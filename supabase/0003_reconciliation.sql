-- Dewey — reconciliation/anomaly queues, stage one.
--
-- ADDITIVE ONLY. Nothing in `0002_catalog.sql` is touched or referenced by
-- constraint from here — this file adds operational tooling for the
-- ingestion pipeline, not catalog structure. The distinction matters: the
-- catalog schema is frozen; how the ingest job reports its own findings
-- about upstream data quality is not catalog structure, it's ops tooling,
-- and is free to evolve as the pipeline does.
--
-- BOUNDARY THIS FILE ENFORCES: source truth vs Dewey normalization vs Dewey
-- editorial reconciliation are three different things and this schema keeps
-- them in three different places on purpose:
--   SOURCE TRUTH               dewey.source_record (0002) — what the
--                               provider actually said, unmodified
--   DEWEY NORMALIZATION        dewey.work / .edition / .author (0002) — what
--                               the ingest pipeline mechanically derived from
--                               source truth, including faithfully-ingested
--                               upstream mistakes (the Red Rising / Renee
--                               Joiner case: OL's own duplicate work record
--                               really does say that, and normalization
--                               reproduces it rather than silently fixing it)
--   DEWEY EDITORIAL             dewey.anomaly (this file) + dewey.claim_field
--   RECONCILIATION              with provider='dewey_editorial' (0002) — a
--                               human or a deliberate, auditable heuristic
--                               decides to merge, lock, or correct something
-- No table in this file writes to a canonical column. It only records what
-- ingestion noticed, for a human (or a later, separate, deliberate process)
-- to act on through the existing merge_*/claim_field mechanisms.

create schema if not exists dewey;

do $$
begin
    if not exists (select 1 from pg_type where typname = 'anomaly_kind') then
        create type dewey.anomaly_kind as enum (
            'isbn_collision',              -- surfaced via the 0002 view too; mirrored
                                            -- here so it can carry a resolved/dismissed
                                            -- status like every other anomaly kind
            'duplicate_work_candidate',
            'duplicate_author_candidate',
            'suspicious_work_authorship',  -- e.g. a narrator credited as work co-author
                                            -- in the SOURCE data itself (Red Rising)
            'malformed_identifier',
            'unknown_contributor_role',
            'unresolved_contributor_name',
            'dangling_source_reference',
            'missing_author',
            'impossible_date',
            'impossible_page_count',
            'empty_title',
            -- Found only at ~1M-work scale, never at 7k or 300k: some OL
            -- 'subjects' entries are not subject headings at all -- a
            -- semicolon-joined list of author names and birth/death years,
            -- a spam hashtag string, a multi-language glossary paragraph.
            -- One such string (1,009 characters) exceeded Postgres's btree
            -- index row limit outright and stopped the reconcile function
            -- with a hard error, not a graceful rejection -- so this is a
            -- REQUIRED guard, not a nice-to-have.
            'oversized_subject'
        );
    end if;
    if not exists (select 1 from pg_type where typname = 'anomaly_disposition') then
        create type dewey.anomaly_disposition as enum (
            'reject_field', 'reject_record', 'ingest_with_warning', 'review_queue');
    end if;
    if not exists (select 1 from pg_type where typname = 'anomaly_status') then
        create type dewey.anomaly_status as enum ('open', 'dismissed', 'resolved');
    end if;
end $$;

-- One table, not eleven. Every queue the brief listed (ISBN collision,
-- duplicate-looking works/authors, suspicious authorship, malformed
-- identifiers, unknown roles, dangling references) is a row here,
-- distinguished by `kind`, with `context` carrying whatever that kind needs
-- (OL keys, raw role strings, the two colliding work ids...) rather than a
-- separate table per kind with mostly-overlapping columns.
create table if not exists dewey.anomaly (
    id            bigint generated always as identity primary key,
    kind          dewey.anomaly_kind not null,
    disposition   dewey.anomaly_disposition not null,
    status        dewey.anomaly_status not null default 'open',
    entity_type   dewey.entity_type,          -- null when the anomaly predates any entity
    entity_id     uuid,                       -- e.g. the work a bad ISBN was rejected from
    source_provider dewey.provider,
    source_key    text,                       -- the OL key involved, when there is one
    context       jsonb not null default '{}',
    run_id        text,                       -- which ingest run recorded this
    detected_at   timestamptz not null default now(),
    resolved_at   timestamptz,
    resolved_by   text,                       -- free text: who/what closed it
    resolution    text
);
create index if not exists anomaly_open_kind_idx
    on dewey.anomaly (kind) where status = 'open';
create index if not exists anomaly_entity_idx
    on dewey.anomaly (entity_type, entity_id) where entity_id is not null;
create index if not exists anomaly_run_idx on dewey.anomaly (run_id);
-- The same (kind, source_key, run) shouldn't be logged twice within one run —
-- cheap idempotency for the anomaly log itself, mirroring the idempotency
-- discipline the catalog tables already have.
create unique index if not exists anomaly_dedup_idx
    on dewey.anomaly (kind, coalesce(source_key, ''), coalesce(run_id, ''));

-- ---------------------------------------------------------------------------
-- Pipeline run manifest — the resumability backbone.
-- ---------------------------------------------------------------------------
--
-- One row per ingest run. `source_hash` proves which exact dump a run
-- consumed (the brief's "a phase should be able to prove which source
-- version it consumed"). `phase` + `completed_batches` is the checkpoint: a
-- crashed run resumes by reading this row, not by guessing.
create table if not exists dewey.pipeline_run (
    run_id             text primary key,
    provider           dewey.provider not null,
    source_version     text not null,
    source_hash        text not null,       -- hash of the exact input file(s) consumed
    phase              text not null,       -- current/last stage name
    status             text not null default 'running',  -- running|completed|failed|aborted
    total_batches      int,
    completed_batches  text[] not null default '{}',  -- "phase:batch_index" entries
    started_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    finished_at        timestamptz,
    stats              jsonb not null default '{}'
);
create index if not exists pipeline_run_status_idx on dewey.pipeline_run (status);

grant usage on schema dewey to anon, authenticated;
-- Deliberately NOT granted to anon/authenticated: these are operator/ingest
-- tooling, same posture as source_record/identifier/field_provenance in
-- 0002 — internal, never client-readable.
alter table dewey.anomaly enable row level security;
alter table dewey.pipeline_run enable row level security;
revoke all on dewey.anomaly from anon, authenticated;
revoke all on dewey.pipeline_run from anon, authenticated;
