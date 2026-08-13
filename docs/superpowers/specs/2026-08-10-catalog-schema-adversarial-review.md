# Catalog Schema — Adversarial Review (Final Before SQL)

**Date:** 2026-08-10 · **Status:** Two decisions resolved. Schema ready for SQL.
**Reviews:** [catalog schema design](2026-08-10-catalog-schema-design.md)

Two questions, both expensive to change post-implementation. Both now resolved
against evidence rather than convenience.

---

## 1. Final recommendation on the canonical Dewey ID type

### **Recommendation: Option B — native `uuid` (UUIDv7), with legacy IDs demoted to `identifier` rows and human-readable slugs kept as a separate mutable column.**

**I was wrong in the previous document, and the reason I was wrong is
instructive.** I chose `TEXT` because prototype data already contained
`"piranesi"` and `"dw-<UUID>"`, and I treated avoiding a migration as a
constraint. It isn't one — it's a preference, and a cheap one to give up at
prototype scale. Weighing a one-time migration of a few dozen local rows
against a permanently heterogeneous primary key was the wrong trade, and the
challenge is correct.

### The evaluation

| Criterion | A — TEXT forever | B — UUIDv7 + identifier mapping | Winner |
|---|---|---|---|
| **FK/index size** | ~26–30 B + varlena header per key, variable width. Across ~20M FK rows and their indexes ≈ **1–2 GB extra** | 16 B fixed | **B** |
| **Join/index behavior** | collation-aware string compares; variable-length keys pack worse per btree page | fixed-width compares; UUIDv7 is time-ordered, so inserts land at the index tail instead of scattering (the classic UUIDv4 page-split problem is avoided) | **B** |
| **API ergonomics** | `"piranesi"` reads nicely in JSON | `"0190f8a2-…"` is unremarkable but fine; clients treat IDs as opaque anyway | A, marginally |
| **URL concerns** | tempts you to route on the PK — and then a slug can never change | slug is a separate mutable column; `/works/piranesi` works and can be re-pointed | **B** |
| **Debugging** | genuinely easier to eyeball | mitigated: UUIDv7 encodes creation time in its prefix, and every log line carries the slug alongside | A |
| **Offline IDs / creation before sync** | client can mint `dw-<UUID>` | client mints UUIDv7 locally; no round trip; collision-safe | tie |
| **Merges / redirects** | identical machinery | identical machinery | tie |
| **Provider independence** | **legacy Dewey slugs become identity** — a prototype-era artifact welded into the PK | *every* external reference (OL, ISBN, Nielsen, legacy Dewey) is a row in `identifier`. One mechanism, uniformly applied | **B, decisively** |
| **Future migrations** | keyspace holds three ID shapes forever; every future reader must learn the history | homogeneous, opaque, no history to learn | **B** |
| **Human-readable slugs** | conflated with identity | separate, mutable, uniquely indexed — what a slug actually is | **B** |
| **Prototype compatibility** | zero migration | one-time, scriptable, verifiable, at trivial scale | A |

### The argument that settles it

Option A embeds **three different ID shapes in the primary key forever** —
hand-written seed slugs, `dw-`-prefixed UUIDs, and newly minted IDs — to avoid
migrating a few dozen prototype rows.

Worse, it is *architecturally inconsistent with the design's own central
principle*. The schema already says: a provider's identifier is never
identity; it is a row in `identifier`. Under Option A, one provider — the
2026 prototype — gets an exemption and its IDs become the primary key. Option
B removes the exemption. `"piranesi"` becomes exactly what `OL20893680W` is:
an alias that resolves to the canonical work.

That also means Option B **loses nothing**. The legacy ID is not discarded —
it is preserved permanently as an `identifier` row, so an old client, an old
backup, or an old deep link still resolves. The guarantee "a provider swap
must never orphan a diary" is *strengthened*, because the resolution path is
now the same one used for every other external ID rather than a second,
implicit one hidden in the PK.

### Concrete form

- **UUIDv7**, stored in Postgres's native `uuid` type (16 bytes). Time-ordered
  for index locality, random-tailed for collision safety, client-generatable
  offline.
- **Practical note:** `uuidv7()` is built in from **PostgreSQL 18**. Supabase
  currently runs 15/16/17, so v1 generates UUIDv7 **application-side** (or via
  the `pg_uuidv7` extension). This is a one-line concern, not an architectural
  one — the column type is `uuid` either way, so adopting the built-in later
  changes nothing stored.
- **Do not** use UUIDv4: random insertion order causes btree page splits and
  poor cache locality on every one of the ~18 tables keyed on these IDs.
- **ULID-as-text is rejected**: it is time-ordered like UUIDv7 but 26 bytes of
  text, surrendering the size and comparison wins that motivated the change.

---

## 2. Migration strategy for current local IDs

Prototype scale: 41 seed books plus whatever each device has imported. This is
a script, not a project.

**Server side, once:**

1. Build the catalog with fresh UUIDv7 ids.
2. For every seed book, insert
   `identifier(provider='dewey_legacy', id_type='local_book_id', value='piranesi', entity_id=<uuid>)`.
   The 41 seed slugs are known and stable, and each already carries a verified
   OL work id — so both paths resolve to the same work.
3. Expose a batch resolve endpoint: `POST /v1/resolve/legacy` taking
   `["piranesi", "dw-4F2A…"]` and returning `{legacy_id → work_id}`, with
   explicit `null` for anything unresolvable.

**Client side, once, on first launch of the new build:**

1. Collect every local reference: `LibraryEntry.bookID`, `DiaryEntry.bookID`,
   `BookList.items[].bookID`, `Ranking.order[]` and `Ranking.placements` keys,
   favorites, notes, and the `importedBooks` dictionary keys.
2. **Write the pre-migration state to a backup file before touching anything.**
3. Batch-resolve. For any legacy ID the server does not know — a book imported
   on this device and never seen by the server — upload it: the device already
   holds the full `Book` plus its `openLibraryWorkID`, which is enough for the
   server to mint or match a work and return its UUID.
4. **Refuse a partial migration.** If any reference is still unresolved after
   step 3, abort and leave local data untouched rather than half-rewritten.
   A diary that half-points at UUIDs and half at slugs is worse than one that
   hasn't migrated yet.
5. Rewrite references in place, atomically, then mark the migration complete.

**Properties that make this safe:**

- **Idempotent** — a completed migration is a no-op on relaunch.
- **Reversible** — the backup file plus the permanent `dewey_legacy`
  identifier rows mean the mapping can be replayed or undone.
- **Verifiable** — reference count before must equal reference count after;
  zero unresolved is a precondition, not an outcome to inspect afterwards.
- **Permanent server-side fallback** — `dewey_legacy` rows are never deleted,
  so a backup restored in 2029 still resolves.

**One design consequence worth stating: offline-created works.** When a user
saves a book with no network, the client mints a UUIDv7 locally. On sync the
server may find that OL work already exists under a different canonical UUID.
Resolution reuses machinery that already exists: the server returns the
canonical ID, the client rewrites its local references, and a
`work_redirect(client_uuid → canonical_uuid)` row makes the client's original
ID resolve forever. Offline ID minting therefore needs **no new mechanism** —
it is a merge, and merges are already designed.

---

## 3. Wikidata recommendation

### **Recommendation: NO for v1 ingestion. Yes later, as a narrowly-scoped enrichment job.**

### What the investigation found

**OL's Wikidata linkage is real and high quality — where it exists.**
`remote_ids.wikidata` is present on OL author records (Jane Austen → Q36322).
The dump `ol_dump_wikidata_2026-07-31.txt.gz` is **813 MB**, format
`Qid \t <CSV-quoted entity JSON> \t timestamp`, and is **99.3% humans (P31=Q5)**
— it is effectively an author-enrichment file. Extrapolated size:
**~154,600 entities**, i.e. **~1.0% of OL's 15,378,301 author records.**

**The label/alias data is genuinely excellent.** Tested directly:

| Author | QID | `en` label | Native | Notable aliases |
|---|---|---|---|---|
| Sayaka Murata | Q11523472 | **Sayaka Murata** | 村田沙耶香 (ja) | — (42 languages) |
| Haruki Murakami | Q134798 | Haruki Murakami | 村上春樹 | **"Murakami Haruki"** (surname-first) |
| Olga Tokarczuk | Q254032 | Olga Tokarczuk | Ольга Токарчук (ru) | 138 languages |
| Lyudmila Ulitskaya | Q266661 | Lyudmila Ulitskaya | **Улицкая, Людмила Евгеньевна** (sort form) | "Lyudmila Evgenyevna Ulitskaya" |
| Liu Cixin | Q607588 | Liu Cixin | 刘慈欣 | **"Cixin Liu"** (Western order), "Da Liu" |
| Gabriel García Márquez | Q5878 | **`null`** | ガブリエル・ガルシア＝マルケス | — |

**Licensing is a non-issue.** Wikidata structured data — labels, aliases,
descriptions, statements — is **CC0**, with no attribution requirement.
Nothing to negotiate, nothing to display.

### Two findings that argue against v1

**(a) Never resolve Wikidata by name.** Searching Wikidata for `"Han Kang"`
returns **Q55500 — the Han River**, not the novelist. Any name-based linkage
would silently attach a river's multilingual labels to a Booker winner. Only
OL's explicit `remote_ids.wikidata` QID is safe. That is the right constraint
anyway ("don't treat Wikidata as canonical identity"), but it has a
consequence: Wikidata adds value *only where OL has already linked*, and OL
links precisely the records that are already enriched.

Also note Gabriel García Márquez has **no `en` label at all** — even Wikidata's
English coverage is not guaranteed, so any consumer needs a fallback chain
(`en` → any Latin-script label → transliteration) rather than assuming `en`.

**(b) The case that motivated this is already solved by data we ingest.**
This is the decisive finding. OL's own `alternate_names` for
`村田沙耶香` (OL6573124A) already contains:

```
['村田, 沙耶香', 'Sayaka Murata', 'MURATA  SAYAKA']
```

**"Sayaka Murata" was in the data all along.** The spike's search projection
discarded `alternate_names` and indexed only the canonical `name` — so the
spike's finding 4c was, in part, *my bug, not an Open Library gap.* Ingesting
`alternate_names` into `author_name` — which the schema already specifies —
fixes the observed failure with **zero new infrastructure.**

### But measure honestly, because `alternate_names` is not a general fix

Measured across the full author dump and the catalog subset:

| Population | Non-Latin canonical name | …of those, has a Latin `alternate_name` |
|---|---|---|
| All 15,378,301 OL authors | 541,126 (3.52%) | **38,855 (7.2%)** — 92.8% have no alternates at all |
| 89,286 authors attached to catalog works | 2,287 (2.56%) | **205 (9.0%)** |

So `alternate_names` covers only ~9% of non-Latin authors in a real catalog —
but coverage correlates strongly with prominence. Murata has it (28 works);
the long tail of one-work records does not. **For the authors readers actually
search for, OL's own data is usually sufficient; for the tail, nothing is.**

Separately, canonical author records are near-universally Wikidata-linked
(6/6 tested: Toni Morrison Q72334, Margaret Atwood Q183492, Han Kang Q5646626,
村田沙耶香 Q11523472, J. K. Rowling Q34660, Stephen King Q39829) — but this
**correlates with having `alternate_names`**, which is exactly why Wikidata's
*marginal* contribution is much smaller than its raw quality suggests.

*(A methodological note: an initial coverage measurement of benchmark authors
gave a misleading 9/19, because name-matching landed on OL's duplicate author
records — Margaret Atwood has both a 685-work record and a 0-work record; Han
Kang has four. The canonical records are the linked ones. This is the same
author-duplication problem the schema's merge design exists to solve, and it
means Wikidata harvesting is only reliable **after** author merge, not before.)*

### Verdict

| | v1 | Later |
|---|---|---|
| Ingest OL `alternate_names` → `author_name` | **Yes — required** | |
| Wikidata dump ingestion | **No** | Yes, as a bounded enrichment job |

Deferring costs almost nothing and avoids: an 813 MB monthly file, a second
ingest path, a QID-linkage table, and a dependency whose value cannot be
realised until author merge is working anyway.

**When to revisit** — a Phase-2 batch job over a set numbering in the low
thousands, not millions: authors that **(a)** have a non-Latin canonical name,
**(b)** lack any Latin-script `alternate_name`, **(c)** carry an OL
`remote_ids.wikidata` QID, and **(d)** are attached to works with real reading
activity (`work_signal.ol_readers > 0`). Harvest `labels` + `aliases`, insert
as `author_name` rows of kind `romanization` with `source='wikidata'`, and
never let them touch identity. The schema already supports this with no
changes — which is the point.

---

## 4. Schema changes caused by these decisions

Small and mechanical. Nothing structural moves.

**From the ID decision:**

1. `work.id`, `edition.id`, `author.id`, `cover.id` → **`uuid`** (UUIDv7),
   replacing `text`.
2. `identifier.entity_id`, `field_provenance.entity_id` → `uuid`.
3. `work_redirect`, `edition_redirect`, `author_redirect` → `uuid → uuid`,
   now with **real FKs** to their targets (previously impossible to guarantee
   across a heterogeneous text keyspace).
4. All social-schema references → `dewey_work_id uuid`,
   `dewey_edition_id uuid null`.
5. Offline snapshots → `dewey_work_id uuid`.
6. **New:** `identifier.provider` gains `dewey_legacy`, `id_type` gains
   `local_book_id`. No new table — legacy IDs use the existing mechanism,
   which is the whole argument for Option B.
7. **New:** `work.slug text unique null` — mutable, nullable, populated only
   for curated/seed works, used for public URLs. Explicitly **not** identity.
   Consider `author.slug` on the same terms.
8. §3.2 of the design document ("why `id` is text, not uuid") is **withdrawn
   and replaced** by this section.

**From the Wikidata decision:**

9. `author_name.source` must accept `openlibrary_alternate` in v1 — and the
   ingest **must** populate `author_name` from OL `alternate_names`. This is
   now a **required v1 behavior**, not an optional enrichment: it is the fix
   for the spike's observed Murata failure.
10. `author_name.kind` keeps `romanization`; `source` keeps room for
    `wikidata` later. No structural change.
11. `identifier` already accommodates a future `wikidata` / `qid` row. No
    change needed now.

**Client-side consequence (not schema):** iOS `Book.id` remains a Swift
`String` holding a UUID string, so the type does not change — only the values,
once, at migration.

---

## 5. Re-check of the accepted decisions

Reviewed for structural problems. **Thirteen of fourteen unchanged.**

| Decision | Verdict |
|---|---|
| Work / Edition split | Unchanged |
| Edition-level contributors | Unchanged — and reinforced: the audiobook-narrator case stays structurally impossible to leak into work credits |
| `author_name` aliases / romanizations | **Strengthened.** Populating from OL `alternate_names` is now mandatory in v1, not optional. This is the one place the review changed a requirement rather than a type |
| Explicit author merge / redirect | Unchanged — and now *load-bearing for enrichment too*, since reliable Wikidata harvesting depends on merged authors |
| Provider-independent identifiers | **Strengthened** by Option B: legacy Dewey IDs stop being an exception to the rule |
| One winning `field_provenance` row per field | Unchanged |
| `locked` editorial overrides | Unchanged |
| `source_record` | Unchanged |
| Raw dump payloads not duplicated in Postgres | Unchanged |
| API force-import payload retention | Unchanged |
| Covers modeled separately | Unchanged |
| ISBN exact lookup | Unchanged |
| `work_signal` using reading activity over `edition_count` | Unchanged |
| Social/user data outside catalog | Unchanged |
| Offline snapshots separate from canonical catalog | Unchanged (field type only) |

---

## 6. Remaining open questions

Of the four open questions in the schema design, **two are now closed**:

- ~~Author romanization source~~ → **closed.** OL `alternate_names` in v1;
  Wikidata deferred to a bounded Phase-2 job.
- ~~`work.id` type~~ → **closed.** UUIDv7.

Two remain, and **neither blocks SQL**:

1. **`edition_isbn` uniqueness.** Recommendation stands: non-unique with a
   violation report, because the same ISBN genuinely does appear on multiple
   upstream edition records and blocking ingest on bad provider data is the
   wrong failure mode. This is a constraint choice made when the table is
   written, reversible either direction with one migration.
2. **`work_type = study_guide` classification.** The title-regex heuristic is
   known-incomplete (it missed a plainly-titled companion volume in the
   spike). The publisher-denylist supplement is recommended. **This is a
   classifier, not a schema question** — the column and its provenance already
   exist, and the classifier can improve indefinitely without a migration.

---

## Verdict

**The schema is ready for SQL implementation.**

Both expensive-to-change decisions are resolved with firm recommendations:
`uuid`/UUIDv7 canonical identity with legacy IDs demoted to `identifier` rows
and slugs separated, and no Wikidata in v1. The two remaining open questions
are a constraint choice and a classifier — both cheap to change later, neither
a reason to delay.
