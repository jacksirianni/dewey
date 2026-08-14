# Dewey — Founder Walkthrough

Everything you need to get the prototype onto your own iPhone and put it through every implemented flow.

---

## 1. Project facts (verified)

| | |
|---|---|
| **Project file** | `/Users/jacksirianni/dewey/Dewey/Dewey.xcodeproj` |
| **Scheme** | `Dewey` — the only one |
| **Target** | `Dewey` |
| **Bundle identifier** | `com.jacksirianni.dewey` |
| **Deployment target** | iOS 17.0 |
| **Signing style** | Automatic, with **no team set** — you set it once, in step 4 |

## 2. Setup, in order

### 2.1 Install the missing iOS platform support

Your Xcode 26.6 has the SDKs but not the iOS platform support files, which is why scheme-based destination resolution currently fails with *"iOS 26.5 is not installed."* Until this is fixed you cannot build to a device at all.

1. Open Xcode.
2. **Xcode → Settings…** (⌘,) → **Components**.
3. Find **iOS 26.5** (or whatever the latest iOS row is) and click **Get** / the download arrow.
4. It is several GB. Let it finish, then quit and reopen Xcode.

To confirm it worked, run this — it should list simulator destinations rather than one placeholder with an error:

```bash
cd /Users/jacksirianni/dewey/Dewey && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Dewey.xcodeproj -scheme Dewey -showdestinations
```

### 2.2 Open the project

```bash
open /Users/jacksirianni/dewey/Dewey/Dewey.xcodeproj
```

Wait for the activity indicator in the toolbar to finish before doing anything else.

### 2.3 Add your Apple ID, if it isn't there

**Xcode → Settings… → Accounts → +** → **Apple ID** → sign in. A free Apple ID is enough; you do not need a paid developer account.

### 2.4 Select your team and resolve signing

1. Click **Dewey** at the very top of the left-hand file navigator (the blue project icon).
2. In the editor, select the **Dewey** target under TARGETS.
3. Open the **Signing & Capabilities** tab.
4. Tick **Automatically manage signing** if it isn't already.
5. Set **Team** to your personal team — it appears as *"Jack Sirianni (Personal Team)"*.

**If you see "Failed to register bundle identifier":** `com.jacksirianni.dewey` is already taken on Apple's side (unlikely, but possible if someone else registered it first). Change **Bundle Identifier** to a variant you own and the error clears.

That is the whole signing setup. There is nothing else to configure.

### 2.5 Select your iPhone

1. Connect the iPhone by cable. Unlock it. Tap **Trust** on the "Trust This Computer?" prompt and enter your passcode.
2. In Xcode's toolbar, click the run-destination dropdown (next to the scheme name, top-left) and pick your iPhone under **iOS Device**.
3. If the phone shows as unavailable, give it a minute — Xcode is preparing debug support for your iOS version the first time.

### 2.6 Build and install

Press **⌘R**.

On first install only, the app will refuse to launch until you trust the certificate:

**On the iPhone:** Settings → General → **VPN & Device Management** → under *Developer App*, tap your Apple ID → **Trust**.

Then press ⌘R again, or just tap the Dewey icon on your home screen.

> With a free Apple ID the build expires after **7 days**. Re-run from Xcode to refresh it. Nothing is lost — your saved state persists.

## 3. Environment requirements

**Swift Package Manager resolves them on first open.** Xcode fetches Supabase and its dependencies itself; there is nothing to install by hand, no CocoaPods, no Carthage, no `.xcconfig`, no environment variables, no code generation step.

**Accounts are the one thing that needs a decision.** Without `Dewey/Dewey/Account/SupabaseConfig.plist` the app opens on a developer configuration screen and will not invent an account system. For a local walkthrough, tap **Use local test accounts** — a debug-only stand-in, announced by a banner everywhere it applies, that exercises the first-run flow and per-account local storage and proves nothing about a server.

Everything the app shows comes from `Store/SeedData.swift`, plus anything you import from Open Library through Search. Reading state persists to a JSON file under `Documents/accounts/<your-account>/`.

---

## 4. The walkthrough

Nine flows. Roughly fifteen minutes. **Do it once straight through without stopping to take notes** — you are testing how it feels, and stopping to write breaks the thing you are measuring. Then do it again with the checklist in §7.

The prototype controls are behind the **slider icon** (top-right, on the Edition and Library tabs). You should not need them for the first pass — the seeded state already has Priya's recommendation waiting.

### ① Weekly Edition

Launch the app. You land on **This week**.

Scroll to the bottom, all the way, without tapping anything.

- Five cards, each a different kind of human context.
- It **ends** — "That's the week." There is no infinite scroll, no pull-to-refresh-for-more, no unread count anywhere.

*Ask yourself: does reaching the end feel like completion, or like running out?*

### ② Reader profile

Tap **Priya Raghunathan** at the top of the first card.

- One line about *how she reads*, not what she does for work.
- **Between you** — five named books, with both ratings under each cover (yours first, hers second).
- The disagreement line: you gave Tenth of December a 5, she gave it a 3.
- Her four Favorite Books, her list with its premise, and one thing she wrote.

*There is no percentage anywhere on this screen. Ask yourself: do you miss it, or is the evidence better?*

### ③ Book detail

From Priya's profile, tap any book — or go back and tap **Temporary** on the first card.

- The page opens with the **Dewey Score** — the crowd's number, drawn large — then the one action, then **Your relationship** as a read-only summary you can tap to edit.
- **Why it reached you** sits directly under those: the sender's reason, then **How it got here**, the provenance chain.
- Further down: the readers you follow who have rated it, what they wrote, the lists holding it, and a collapsed **Details** table with the Dewey Decimal in it.

### ④ Save with provenance

On **Temporary**, tap **Save it**.

- Note that you were never asked *where you found it*. Dewey already knew.
- The chain now reads: **A bookseller in Lisbon → Priya Raghunathan → You**.
- Tap **Add a private note** and write something. It is never prompted for.

Also try **Not for me** on a different book. Nothing happens socially — no confirmation, no notification to anyone. That is deliberate.

### ⑤ Library

Switch to the **Library** tab.

- The provenance line sits **above the author**: *"Priya Raghunathan sent you this."*
- Five statuses, as wrapping chips — Want to Read, Reading, Finished, Paused, Did Not Finish. Paused and Did Not Finish are separate because abandoning a book is a real act of taste.
- Your own rating sits in a fixed column at the trailing edge, so the shelf is scannable for "what did I think of this" in one pass.
- **Diary** is the second mode, behind the same control: the same books as dated acts of reading. Swipe a diary entry right to open its book, left to delete it.
- Open the book again and change its status from the log sheet.

*Ask yourself: in six months, is "who sent me this" the thing you'd want to see first?*

### ⑥ Direct recommendation

On any book page, tap **Recommend to someone**.

- Pick **one** person. There is no multi-select.
- Pick a reason chip, or write your own. **You cannot send without one.**
- Tap **Send**.

*Ask yourself: was requiring the reason annoying, or did the chips make it costless?*

### ⑦ Recommendation closure

**Wait about twenty seconds** after sending — go back to the Edition, browse, put the phone down. The delay is deliberate: at six seconds it landed while the send confirmation was still on screen and read as the system echoing your own tap rather than a person acting. It has to arrive after you've moved on. (Impatient? Prototype controls → *Recipient started the book*.)

A banner drops in: *"Ana started it."*

- It asks for nothing. No reply field, no "send another", no counter.
- Dismiss it with the ✕.
- Open that book again — a **You sent this** block now shows what you said and that they started it.

**This is the single most important moment in the prototype.** It is the mechanic the whole product may end up resting on.

*Ask yourself, honestly: was that a small gift, or was it noise?*

### ⑧ Reaction

Go back to the Edition and find a recommendation you have **saved** (Priya's Temporary, if you saved it).

- Three marks: Noted / Already loved it / Exactly right.
- Tap one. Tap it again to clear it.
- **There is no count and no total anywhere.** One mark, and only the two of you see it.

To see it from the other side: prototype controls → **Reaction received** → open the book you sent.

### ⑨ Private reply

On the same saved recommendation, tap **Reply privately**.

- Write a line, send it.
- It appears inline, under the recommendation. There is no thread, no public view, no way for a stranger to find it.

From the other side: prototype controls → **Private reply received** → open the book you sent.

---

## 5. The rating pass — physical device only

**Do this one on the phone. Not the simulator.** There is no Taptic Engine in the simulator, so every tick described below is silent there, and the 0.1 scale (§12.2 of the overview) is the one decision in this build that cannot be evaluated by looking at it. That is the entire reason this pass exists.

Allow fifteen minutes. Ten steps, then seven questions.

**Where the controls are.** The **slider icon**, top-right of the **Edition** tab and the **Library** tab (it is not on Search). The three sections this pass uses are at the top of that sheet: **Try it**, **Haptic feel**, **Rating scale**.

**These two settings are scaffolding, not settings.** Haptic preset and rating scale exist only so you can compare options side by side. They are held in memory, they are never written to the saved state, they reset to **Balanced / Tenths** on every relaunch, and choosing one changes nothing about ratings that already exist. Both come out of the code in one pass once you have decided.

### ① Drag slowly through ten increments

Library → **Bluets** → *Your rating*. Move the thumb about a tenth at a time, a second or so per step, from around 8.0 up to 9.0.

Watch for: one tick per tenth and a stronger one at 9.0; a tenth you crossed that fired nothing; two ticks for one tenth. The numeral beside *Your rating* updates in place — nothing floats under your thumb any more.

### ② Drag quickly across several whole numbers

Same slider. Flick from the floor to the ceiling in under a second, then back.

Watch for: whether whole numbers you skip past still fire strong, and whether the run of ticks reads as texture or as a buzz. One exception to know before you judge it: under the **Minimal** preset (step ⑦) nothing fires unless the drag lands on x.0 or x.5, so skipped wholes are silent there by design. The other three presets fire on a skipped whole.

### ③ Reverse direction mid-drag

Drag up to about 7.5, stop without lifting your finger, drag back down to 6.5, then up again — all one gesture.

Watch for: 7.0 firing on the way down as well as on the way up; a dead patch immediately after the turn; anything that fires when you *leave* a whole number, which it should not.

### ④ Land on a precise tenth

Pick the number before you touch the screen — 8.4 — and try to hit it in one gesture with no correction. Do it three times with three different targets.

Watch for: how often you had to nudge, and by how much. This is the objection recorded in §12.2.7 of the overview, and it is unresolved on purpose.

### ⑤ Clear a score and restore it

On a rated book, tap **Clear**. Then drag a new value in. Then clear it again, force-quit the app from the app switcher, and reopen.

Watch for: the thumb staying visible at the floor when unrated, faintly stroked, so the control still offers itself. And, after the relaunch, that the book is **still unrated**. A cleared rating that comes back as a number is the bug fixed in this pass; if you see one, that is a regression and it is the most important thing you will find.

### ⑥ Compare the three scale modes

Controls → **Rating scale** → Tenths / Halves / Wholes.

The fastest comparison is the **Try it** slider at the top of the same sheet — it belongs to no book, saves nothing, and the *Lands on* row underneath tells you exactly what your drag snapped to. Then take the mode you prefer to a real book.

Watch for: the mode changes only what a **new** drag can land on. A book already sitting at 7.8 is still 7.8 under Wholes. Nothing is converted, rounded or rewritten — if you see an existing rating change, that is a bug.

### ⑦ Compare the four haptic presets

Controls → **Haptic feel** → Quiet (barely there) / Balanced (what is built today) / Mechanical (a ratchet with detents) / Minimal (ticks only at the halves).

Run step ① and step ② once under each.

Watch for: which one you stop noticing — that is the good outcome — and which one you start resenting. Try at least one of them somewhere with background noise; haptics read differently when the room is not silent.

### ⑧ Read a book page top to bottom

**Do this on a book that was actually recommended to you** — Temporary, from Priya.

The A/B ordering harness is gone. It existed to compare two arrangements of a region that also held a *second, competing* editor — a Log button with an inline status picker and rating slider stacked under it — and once that duplicate editor was removed there was nothing left to reorder against. The page now runs: Dewey Score, one action, your relationship, why it reached you.

Watch for: whether opening with the Dewey Score makes the crowd feel like the authority on the page. That is the §12.1 argument, and it is the one position in this build still asserted rather than tested.

### ⑨ Relaunch

Rate three books and write the numbers down. Force-quit from the app switcher — do not just background it — and reopen.

Watch for: all three numbers exactly as you left them, including a 10 rendering as **10** and not 9.9. Then check that the two settings above have gone back to Balanced / Tenths. That is intended: they are in memory only.

### ⑩ Rate several books consecutively

Five in a row from the Library without stopping. Open, drag, back, next.

Watch for: whether by the fifth book you were still choosing a number or just reproducing the fourth one, and whether the preset you liked in step ⑦ is still tolerable at five in a row. This is the only step that measures the scale as a habit rather than as a control.

---

### Record your answers

**Which haptic preset feels best?**

&nbsp;

**At what point does the feedback become annoying?**

&nbsp;

**Do tenths feel useful, or falsely precise?**

&nbsp;

**Can you land on the number you meant?**

&nbsp;

**Does the rating mark feel iconic or decorative?**

&nbsp;

**Any surface where ratings dominate too much?**

&nbsp;

---

## 6. Prototype controls

Slider icon, top-right of the Edition and Library tabs.

| Control | What it does |
|---|---|
| **Recommendation received** | A reader sends you a book. Appears in the Edition. Cycles through four real pairings. |
| **Recommendation sent** | Fabricates one you sent, and saves the book so you can reach its page from the Library. |
| **Recipient started the book** | Fires the closure banner immediately instead of after twenty seconds. |
| **Reaction received** | They mark your most recent sent recommendation. |
| **Private reply received** | They reply to your most recent sent recommendation. |
| **Reset prototype** | Clears library, recommendations, and all saved state; restores Priya's opening recommendation. Asks for confirmation. |

Above those sit the three comparison sections used by §5 — **Try it**, **Haptic feel**, **Rating scale**. Those two choices are in memory only and reset on relaunch; the actions in the table above change saved state.

The State section shows live counts so you can see what state you are in.

**Reset is always available from inside the app** — you never have to delete and reinstall to run the walkthrough again for someone else.

These controls are scaffolding and are styled to look like it. They live in `Store/DebugActions.swift`, `Features/Debug/DebugMenuView.swift`, `Features/Debug/DebugSettings.swift`, and two `debugAppend`/`debugUpdate` methods on the store. The comparison settings reach into product code at five commented call sites, all in `Models/Rating.swift` (haptics and snapping), so deleting the harness is one pass plus five line deletions.

---

## 7. What to record

Keep this short. Record **reactions, not fixes** — the design decisions are mine to make; what I need from you is what the thing felt like.

**The three questions that decide the next move:**

1. **The closure moment (§4 ⑦)** — gift, or noise? If it was noise, that is the most valuable finding in this session and it changes the roadmap.
2. **The end of the edition (§4 ①)** — completion, or running out?
3. **Overlap without a percentage (§4 ②)** — did the named books feel more credible than a score, or did you want a number?

The rating pass has its own answer block at the end of §5. Fill that in there, not here.

**Then, as you go:**

- **Anything you tried to tap that did nothing.** Every one of these is either a missing feature or a misleading affordance, and I need to know which.
- **Any moment you had to think about what a word meant.** "Provenance", "edition", "reflection" — if any of them made you pause, the copy is wrong.
- **Any screen that felt like admin.** The single biggest risk in this product is reading turning into filing.
- **Where you'd have wanted a number and there wasn't one** — and whether that absence felt principled or evasive.
- **Anything that felt slow, janky, or off** — scroll stutter, an animation that fought you, text that clipped at your Dynamic Type size.
- **What you wanted to do next and couldn't.** Especially at the end of the edition.
- **Whether you'd open it on a Tuesday.** Be honest. This is the open strategic question and the prototype does not yet answer it.

**Not worth recording:** thin content, the four readers being fictional, no settings screen. All known and deliberate. Search and Open Library import *do* exist now — a book the catalogue has but Dewey does not is worth reporting as a data problem, not as a missing feature.

---

## 8. Known gaps in this build

- Sending a recommendation always resolves to *started* after twenty seconds. There is no "they declined" or "they never responded" state, and real life is mostly the third one.
- The provenance chain's first hop ("A bookseller in Lisbon") is authored, not derived — a real chain needs a network that does not exist yet.
- Reactions and replies are one-way in the seeded world: you can react and reply to incoming recommendations, and the controls simulate the reverse, but there is no live back-and-forth.
- **Only identity is on the server.** Accounts, handles, follows and your four Favorite Books are in Supabase; your library, diary, ratings, rankings, lists and imported book metadata are still on the device only. A second device signing into the same account gets your identity, follows and four — and an empty diary. This is a known limit of the current stage, not a bug.
- The `follows` table exists and is empty, and will stay empty until there are two real accounts. Every reader you can currently follow is a seeded fixture, so those follows live in `seed_follows` instead.
- Signing out lives in the prototype controls, because there is no settings screen yet.
- **Local reading data is filed per account** (`Documents/accounts/<uuid>/`). Signing out leaves it on the device and signing back in finds it; a different account signing in on the same phone cannot see it.
- **Your pre-account library can be recovered.** If `dewey-prototype-v4.json` is on the device, the prototype controls open with a *Pre-account save file* section stating what is in it and which world it was written in, and a one-time **Adopt into this account**. Nothing is deleted either way: the account's current record is kept as `state-v5.replaced.json` and the source is renamed to `dewey-prototype-v4.adopted.json`. It replaces rather than merges — there is no honest way to merge two diaries — so read the counts before tapping.
- Without `SupabaseConfig.plist` the app opens on a developer configuration screen. It will not silently substitute a fake account system; local test accounts are an explicit, banner-announced choice.
- Following a seeded reader still leaves their follower count where it was. They have no back end to gain a follower in.
- Seed covers are typeset rather than real jacket art. Deliberate — consistent house style. Books imported from Open Library layer the catalogue's jacket over the typeset cover when it has one.
