# Setting up Dewey accounts

Everything in this document is a step I could not perform for you: it needs your
Supabase dashboard, your Apple Developer account, or your Xcode signing identity.

**Without configuration the app does not invent an account system.** It opens on
a developer configuration screen naming the file to create. A debug build offers
one alternative there — *Use local test accounts* — which is an explicit,
reversible choice that stores two accounts in `UserDefaults` on the device, and
announces itself with a banner everywhere it could be mistaken for the real
thing. It proves the first-run flow and account-scoped local storage. It proves
nothing about Supabase: no shared uniqueness, no Row Level Security, no real
Apple identity, no second device.

Work through it in order. It takes about twenty minutes, most of which is Apple's
portal.

## Verifying the schema before you run it

The migration and its policies have been executed and exercised against a local
PostgreSQL — 89 assertions covering handle shape, case-insensitive uniqueness,
the concurrent-signup race, and cross-account Row Level Security for two users.
You can re-run that yourself in about ten seconds, and should if you change the
SQL:

```bash
createdb dewey_verify && psql -q -d dewey_verify -f supabase/test/00-supabase-stub.sql && psql -q -d dewey_verify -f supabase/0001_identity.sql && psql -d dewey_verify -f supabase/test/01-verify.sql
```

The last line prints `ALL CHECKS PASSED` or a list of failures.
`supabase/test/02-race.sh` runs the two-session handle race separately.

---

## Before you start

| Thing | Why | Cost |
|---|---|---|
| A Supabase project | Identity, follows, Favorite Books | Free tier is fine |
| **Paid** Apple Developer Program membership | Sign in with Apple cannot be enabled on a free account | $99/yr |
| A bundle identifier you own | Currently `com.dewey.prototype`, which you probably want to change | — |

If you do not have the paid membership yet, do steps 1–3 anyway. Supabase will
be live, and the simulator's debug path keeps working until Apple is sorted.

---

## 1. Create the Supabase project

1. <https://supabase.com/dashboard> → **New project**.
2. Name it `dewey`, pick a region near you, save the database password somewhere
   (you will not need it for this task, but you will later).
3. Wait for provisioning to finish — roughly two minutes.

## 2. Run the schema

1. Dashboard → **SQL Editor** → **New query**.
2. Paste the entire contents of [`supabase/0001_identity.sql`](../supabase/0001_identity.sql)
   and hit **Run**.
3. It is written to be re-runnable, so if you are unsure whether it applied, run
   it again — every object is `create … if not exists` or `create or replace`,
   and every policy is dropped before it is created.

**Verify it worked.** Dashboard → **Table Editor**. You should see four tables:
`profiles`, `follows`, `seed_follows`, `favorite_books`. Each should show a
green **RLS enabled** badge. If any of them says RLS is disabled, stop — that
table is world-writable and the migration did not finish.

Then in the SQL editor:

```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public';
select proname from pg_proc where proname = 'handle_available';
```

All four tables should report `rowsecurity = true`, and `handle_available`
should come back as one row.

## 3. Point the app at the project

1. Dashboard → **Project Settings** → **Data API**. Copy the **Project URL** and
   the **anon** / **publishable** key.
2. In the repo:

```bash
cp Dewey/Dewey/Account/SupabaseConfig.example.plist Dewey/Dewey/Account/SupabaseConfig.plist
```

3. Open `Dewey/Dewey/Account/SupabaseConfig.plist` and fill in both values.
   `SupabaseURL` accepts either the full URL or the bare host.

`SupabaseConfig.plist` is already in `.gitignore`. The anon key is **not** a
secret — it ships inside the app binary and is readable by anyone who unzips the
`.ipa`. Row Level Security is what protects the data, which is why step 2 is not
optional.

**Verify:** build and run. Prototype controls (the slider icon, top right of the
Edition) → **Account** → **Backend** should now read `Supabase` rather than
`Local (debug)`. The "Continue with a local debug account" button disappears from
the sign-in screen the moment configuration exists.

---

## 4. Apple Developer portal

1. <https://developer.apple.com/account> → **Certificates, Identifiers & Profiles**
   → **Identifiers**.
2. Find or create the App ID for your bundle identifier. If you are keeping
   `com.dewey.prototype`, create that; if you are changing it, do that first in
   Xcode (step 6) and create the matching identifier here.
3. Edit the App ID → tick **Sign In with Apple** → **Save**.
   - Leave it as a **primary** App ID. The "group with an existing primary" option
     is for sharing one Apple ID relationship across several apps, which Dewey
     does not need.

That is all Apple needs for the **native** flow. You do **not** need a Services
ID, a private key, or a return URL — those are for browser-based OAuth, which
Dewey deliberately does not use.

## 5. Enable the Apple provider in Supabase

1. Dashboard → **Authentication** → **Sign In / Providers** → **Apple**.
2. Toggle **Enable Sign in with Apple**.
3. In **Client IDs**, enter your bundle identifier — `com.dewey.prototype`, or
   whatever you changed it to. This is the field that matters; Supabase verifies
   the `aud` claim of Apple's identity token against it.
4. Leave **Secret Key (for OAuth)** empty. It is only used by the web flow.
5. **Save**.

> If sign-in fails with something about an audience mismatch, it is almost
> always this field disagreeing with `PRODUCT_BUNDLE_IDENTIFIER`.

## 6. Xcode — Signing & Capabilities

1. Open `Dewey/Dewey.xcodeproj`, select the **Dewey** target → **Signing &
   Capabilities**.
2. Set **Team** to your Apple Developer team.
3. Confirm **Bundle Identifier** matches what you registered in step 4.
4. **Sign in with Apple should already be listed as a capability** — the
   entitlements file (`Dewey/Dewey.entitlements`) is committed and wired up via
   `CODE_SIGN_ENTITLEMENTS`. If it is not showing, hit **+ Capability** and add
   it; Xcode will merge into the existing file.

Nothing else needs adding. The Supabase package is already declared in the
project file and resolves on first build.

---

## Testing on a real device

Sign in with Apple needs an Apple Account signed into the device. On a
**simulator**, that means Settings → Sign in to your iPhone; without it the sheet
returns "You need to sign in to your Apple Account in Settings", which the app
surfaces as *Sign in with Apple didn't complete.*

To confirm the round trip actually reached Supabase, sign in on the device and
then check the dashboard:

- **Authentication → Users** — one row, provider `apple`.
- **Table Editor → profiles** — one row with your display name and handle.
- **Table Editor → seed_follows** — one row per reader you followed during the
  taste steps.
- **Table Editor → favorite_books** — up to four rows, `position` 1–4.

### Confirming RLS actually bites

Worth doing once, because a policy that is wrong looks exactly like a policy that
is right until someone else's data is involved. In the SQL editor:

```sql
-- Should return 0 rows: the anon key has no read policy on profiles.
set local role anon;
select count(*) from public.profiles;
reset role;
```

---

## What is and is not on the server

This stage is **identity, not sync**. Be precise about it, because the
distinction is invisible from inside the app on a single device.

**On Supabase:** your account, display name, handle, whether setup and taste
onboarding are complete, which seeded readers you follow, and your four Favorite
Books.

**Still local, on the device only:** your library, diary, ratings, rankings,
lists, and imported book metadata.

A second device that signs into the same account gets your identity, your follows
and your four — and an **empty diary**. That is expected. Signing out
deliberately leaves all local reading data in place, so signing back in on the
same device finds everything where you left it.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| App opens on "Accounts are not configured" | Expected without `SupabaseConfig.plist`. That is the designed state, not a failure |
| Backend still says `Local test accounts` after adding the plist | Still holding the `YOUR-PROJECT-REF` placeholder — `AccountConfig` treats an unedited copy as unconfigured. Adding real config also overrides local mode automatically |
| Every request fails *permission denied for table profiles* | The migration was run before the explicit `GRANT` block existed. Re-run it |
| *Sign in with Apple didn't complete* on a simulator | No Apple Account signed into the simulator |
| Sign-in succeeds, then an error about audience | Bundle ID in Supabase's **Client IDs** does not match `PRODUCT_BUNDLE_IDENTIFIER` |
| *Couldn't reach Dewey* | Wrong project URL, or the project is paused (free-tier projects pause after a week idle) |
| Handle always reports available, then fails on Continue | `handle_available` did not get created — re-run the migration |
| Every profile write fails | RLS is on but the policies did not apply — re-run the migration |
| Xcode: "Sign in with Apple" provisioning error | App ID missing the capability (step 4), or the team is not set (step 6) |
