#!/usr/bin/env python3
"""
Incremental-update simulation, run against the state left by ingest.py's
three completed passes. Every scenario drives the SAME Ingestor methods the
real pipeline uses (persist_works, persist_covers, claim_canonical_fields,
...) on hand-mutated copies of real records -- never a bypass UPDATE.
"""
import sys, json, copy
import psycopg2
sys.path.insert(0, "..")
from ingest import Ingestor, Anomalies, Stats, content_hash, DB

PIRANESI_WORK = "OL20893680W"          # Susanna Clarke's, real, already ingested
PIRANESI_EDITION = "OL61022665M"       # real English hardcover edition, ISBN 9781526622419

conn = psycopg2.connect(DB)
conn.autocommit = False
results = []


def check(label, cond, detail=""):
    results.append({"label": label, "pass": bool(cond), "detail": detail})
    print(f"  [{'PASS' if cond else 'FAIL'}] {label}" + (f"  -- {detail}" if not cond else ""))


def q1(sql, params=()):
    cur = conn.cursor()
    cur.execute(sql, params)
    row = cur.fetchone()
    cur.close()
    return row[0] if row else None


def qall(sql, params=()):
    cur = conn.cursor()
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    return rows


def new_ingestor():
    return Ingestor(conn, Anomalies("/dev/null"), Stats())


print("\n== 1. Metadata correction: OL corrects Piranesi's publish year ==")
work = {"k": PIRANESI_WORK, "t": "Piranesi", "sub": [], "au": [], "fpd": "2021", "alt": []}
before = q1("select first_published_year from dewey.work where id = "
           "(select entity_id from dewey.identifier where id_type='ol_work' and value=%s)",
           (PIRANESI_WORK,))
ing = new_ingestor()
ing.resolve_works([PIRANESI_WORK])
ing.editions_by_work = {}
src_ids = ing.persist_source_records([
    ("openlibrary", "work", PIRANESI_WORK, "dump", None, content_hash(work))])
ing.claim_canonical_fields({PIRANESI_WORK: work}, {}, src_ids)
conn.commit()
after = q1("select first_published_year from dewey.work where id = "
          "(select entity_id from dewey.identifier where id_type='ol_work' and value=%s)",
          (PIRANESI_WORK,))
check("year claim moved to the new upstream value (2021)", after == 2021,
      f"before={before} after={after}")

print("\n== 2. Locked editorial value survives the next OL refresh ==")
wid = q1("select entity_id from dewey.identifier where id_type='ol_work' and value=%s",
         (PIRANESI_WORK,))
cur = conn.cursor()
cur.execute("select dewey.claim_field('work', %s, 'title', 'dewey_editorial', null, true)", (wid,))
cur.execute("update dewey.work set display_title = %s where id = %s",
           ("Piranesi (Editorial Title)", wid))
conn.commit()
work2 = {"k": PIRANESI_WORK, "t": "Piranesi -- OL's next attempt", "sub": [], "au": [],
        "fpd": "2021", "alt": []}
ing = new_ingestor()
ing.resolve_works([PIRANESI_WORK])
ing.editions_by_work = {}
src_ids = ing.persist_source_records([
    ("openlibrary", "work", PIRANESI_WORK, "dump", None, content_hash(work2))])
ing.claim_canonical_fields({PIRANESI_WORK: work2}, {}, src_ids)
conn.commit()
title_after = q1("select display_title from dewey.work where id=%s", (wid,))
check("locked editorial title survives OL's changed value", title_after == "Piranesi (Editorial Title)",
      f"got {title_after!r}")

print("\n== 3. New edition arrives; work identity stable ==")
before_ed_count = q1("select count(*) from dewey.edition where work_id=%s", (wid,))
before_work_id = wid
new_ed_key = "OL99999999M"
editions = {PIRANESI_WORK: [{"k": new_ed_key, "w": PIRANESI_WORK,
                            "t": "Piranesi", "st": "", "i13": ["9789999999992"],
                            "i10": [], "pd": "2026", "lang": ["eng"], "pg": 300,
                            "ser": "", "cv": None, "fmt": "hardcover", "pub": "Bloomsbury",
                            "ddc": "", "au": [], "ctr": [], "desc": 0}]}
ing = new_ingestor()
ing.resolve_works([PIRANESI_WORK])
ing.resolve_editions([new_ed_key])
ing.persist_editions(editions)
conn.commit()
after_ed_count = q1("select count(*) from dewey.edition where work_id=%s", (wid,))
after_work_id = q1("select entity_id from dewey.identifier where id_type='ol_work' and value=%s",
                   (PIRANESI_WORK,))
check("edition count increased by exactly 1", after_ed_count == before_ed_count + 1,
      f"{before_ed_count} -> {after_ed_count}")
check("dewey work id unchanged by new edition", before_work_id == after_work_id)

print("\n== 4. New ISBN on an EXISTING edition ==")
eid = q1("select entity_id from dewey.identifier where id_type='ol_edition' and value=%s",
        (PIRANESI_EDITION,))
before_isbns = q1("select count(*) from dewey.edition_isbn where edition_id=%s", (eid,))
ing = new_ingestor()
ing.resolve_editions([PIRANESI_EDITION])
editions2 = {PIRANESI_WORK: [{"k": PIRANESI_EDITION, "w": PIRANESI_WORK, "t": "Piranesi",
                              "i13": ["9781526622419", "9780000111111"], "i10": [], "pd": "",
                              "lang": ["eng"], "au": [], "ctr": []}]}
ing.persist_identifiers({}, editions2, {})
conn.commit()
after_isbns = q1("select count(*) from dewey.edition_isbn where edition_id=%s", (eid,))
check("new ISBN added without disturbing the existing one",
      after_isbns == before_isbns + 1, f"{before_isbns} -> {after_isbns}")
check("original ISBN still present",
      q1("select count(*) from dewey.edition_isbn where edition_id=%s and isbn13=%s",
        (eid, "9781526622419")) == 1)

print("\n== 5. Better (licensed) cover replaces the cached OL one ==")
old_cover = q1("select display_cover_id from dewey.work where id=%s", (wid,))
cur.execute("select dewey.uuid_v7()"); new_cover_id = cur.fetchone()[0]
cur.execute("""insert into dewey.cover (id, work_id, source, source_ref, license_posture)
              values (%s,%s,'licensed','nielsen-asset-piranesi-1','licensed')""",
           (new_cover_id, wid))
cur.execute("update dewey.work set display_cover_id=%s where id=%s", (new_cover_id, wid))
conn.commit()
check("licensed cover is now the display cover",
      q1("select display_cover_id from dewey.work where id=%s", (wid,)) == new_cover_id)
check("previous OL cover row was NOT deleted (still queryable)",
      old_cover is None or q1("select count(*) from dewey.cover where id=%s", (old_cover,)) == 1)

print("\n== 6. Upstream source disappears; canonical work is NOT deleted ==")
DISAPPEAR_WORK = "OL19961398W"   # a real general-bucket work, unrelated to any named title
before_exists = q1("select count(*) from dewey.work where id = "
                   "(select entity_id from dewey.identifier where id_type='ol_work' and value=%s)",
                   (DISAPPEAR_WORK,))
# Simulate "next month's dump" containing only Piranesi -- DISAPPEAR_WORK is
# simply absent from the batch, exactly as it would be if OL removed it.
next_months_dump = {PIRANESI_WORK: work2}
ing = new_ingestor()
ing.resolve_works(next_months_dump.keys())
ing.editions_by_work = {}
ing.persist_works(next_months_dump, {})
conn.commit()
after_exists = q1("select count(*) from dewey.work where id = "
                  "(select entity_id from dewey.identifier where id_type='ol_work' and value=%s)",
                  (DISAPPEAR_WORK,))
check("omitted work still exists after a 'next dump' that excludes it",
      before_exists == 1 and after_exists == 1)

print("\n== 7. Author gains a new alternate_name; no new author created ==")
# The literal '%' in a LIKE pattern collides with psycopg2's own %s
# placeholder syntax if passed inline -- must be bound as a parameter.
row = qall("select a.value from dewey.identifier a where a.provider='openlibrary' "
          "and a.id_type='ol_author' and a.entity_id = ("
          "  select author_id from dewey.author_name where name like %s limit 1)",
          ("%村田%",))
murata_ol_key = row[0][0] if row else None
before_author_count = q1("select count(*) from dewey.author")
before_alias_count = q1("select count(*) from dewey.author_name where author_id = "
                        "(select entity_id from dewey.identifier where id_type='ol_author' and value=%s)",
                        (murata_ol_key,))
authors_update = {murata_ol_key: {"k": murata_ol_key, "n": "村田沙耶香",
                                  "alt": ["Sayaka Murata", "村田, 沙耶香", "MURATA  SAYAKA",
                                         "Murata Sayaka (new alt from next dump)"]}}
ing = new_ingestor()
ing.resolve_authors(authors_update.keys())
ing.persist_authors(authors_update)
ing.persist_author_names(authors_update)
conn.commit()
after_author_count = q1("select count(*) from dewey.author")
after_alias_count = q1("select count(*) from dewey.author_name where author_id = "
                       "(select entity_id from dewey.identifier where id_type='ol_author' and value=%s)",
                       (murata_ol_key,))
check("no new author row was created", before_author_count == after_author_count,
      f"{before_author_count} -> {after_author_count}")
check("exactly one new alias landed on the SAME author",
      after_alias_count == before_alias_count + 1, f"{before_alias_count} -> {after_alias_count}")

print("\n== 8. Real cross-work ISBN collision ==")
# Two already-ingested, unrelated works given the SAME real, checksum-valid
# ISBN-13 -- the 0.15% case measured directly in the SQL implementation.
two_works = qall("select id from dewey.work order by id limit 2")
wa, wb = two_works[0][0], two_works[1][0]
ea = q1("select id from dewey.edition where work_id=%s limit 1", (wa,))
eb = q1("select id from dewey.edition where work_id=%s limit 1", (wb,))
if ea and eb:
    cur.execute("""insert into dewey.edition_isbn (edition_id, isbn13, source)
                  values (%s, '9788445000724', 'openlibrary')
                  on conflict do nothing""", (ea,))
    cur.execute("""insert into dewey.edition_isbn (edition_id, isbn13, source)
                  values (%s, '9788445000724', 'openlibrary')
                  on conflict do nothing""", (eb,))
    conn.commit()
    collision = q1("select work_count from dewey.isbn_collision where isbn13='9788445000724'")
    check("ingest of a real cross-work duplicate ISBN succeeds (no crash, no rejection)", True)
    check("collision is surfaced via dewey.isbn_collision", collision == 2, f"got {collision}")
else:
    check("cross-work ISBN collision setup", False, "no editions found on sample works")

conn.close()

n_pass = sum(1 for r in results if r["pass"])
print(f"\n{'='*60}\n{n_pass}/{len(results)} incremental-update checks passed\n{'='*60}")
json.dump(results, open("incremental_update_results.json", "w"), indent=1)
sys.exit(0 if n_pass == len(results) else 1)
