# Dewey — Walking Prototype

A small, locally-running SwiftUI prototype. No backend, no accounts, no network. Everything is seeded in `Store/SeedData.swift` and persisted to a single JSON file in the app's Documents directory.

Its job is to make Dewey tangible and establish the interaction rhythm — not to be the research instrument, and not to be v1.

**What it communicates:** *Dewey helps me understand whose taste matters, find a compelling next book through human context, and preserve who inspired the discovery.*

---

## Running it

### On the simulator, from Xcode

1. `open Dewey/Dewey.xcodeproj`
2. Pick an iPhone simulator in the toolbar (the deployment target is iOS 17.0, so anything from iPhone SE 3rd-gen upward works).
3. ⌘R.

> **If Xcode says "iOS 26.5 is not installed"** — that is a host setup issue, not a project one. Xcode 26.6 here has the SDKs but not the iOS platform support files, which breaks scheme-based destination resolution. Fix it in **Xcode → Settings → Components → install the iOS platform**. It is a large download. Until then, the command-line route below works and is what the prototype was verified with.

### On the simulator, from the command line

```bash
cd /Users/jacksirianni/dewey/Dewey && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Dewey.xcodeproj -target Dewey -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Then install and launch on a booted simulator:

```bash
xcrun simctl boot "iPhone 17 Pro"; xcrun simctl install booted /Users/jacksirianni/dewey/Dewey/build/Debug-iphonesimulator/Dewey.app && xcrun simctl launch booted com.jacksirianni.dewey
```

### On your own iPhone

1. Plug the phone in and trust the Mac.
2. In Xcode, select the project in the navigator → the **Dewey** target → **Signing & Capabilities**.
3. Set **Team** to your personal Apple ID (add it under Xcode → Settings → Accounts if it isn't there). Xcode will provision automatically.
4. The bundle identifier is `com.jacksirianni.dewey`; change it if that collides with one you already own.
5. Select your iPhone as the run destination and ⌘R.
6. First launch only: on the phone, **Settings → General → VPN & Device Management → Developer App → Trust**.

With a free Apple ID the build expires after 7 days; re-run from Xcode to refresh it.

---

## The walkthrough

1. **Weekly Edition** — five cards, then a designed ending. Each is a different kind of human context: a direct recommendation, a book from a list with a premise, a reflection, a book several readers hold, and a reader worth exploring.
2. **Tap Priya's name** → her profile. The overlap section names the five books you actually share, shows both ratings, and calls out where you disagree hardest. No percentage anywhere.
3. **Tap a book** → the page opens with *why it reached you*, then who has it, then the provenance chain.
4. **Save it** → provenance is captured silently. Check the Library tab: the line "Priya Raghunathan sent you this" sits *above* the author.
5. **Recommend to someone** → pick one person, pick or write a reason (required), send.
6. **Wait ~6 seconds** → the closure banner appears: *"Priya started it."* It asks for nothing. That is the point.
7. **Reaction and reply** — on a recommendation you have answered. One mark, never a count; one private reply, not a thread.

**Prototype controls** — the slider icon, top-right of either tab. Triggers simulated states (recommendation received/sent, recipient started it, reaction received, reply received) and resets everything. See [WALKTHROUGH.md](WALKTHROUGH.md) for the full guided pass and the device-install steps.

---

## Structure

```
Dewey/
  Models/       Book · ReaderProfile · Recommendation · EditionCard · LibraryEntry · Provenance
  Store/        DeweyStore (@Observable) · SeedData
  Design/       Theme (type, space, colour, motion) · Components
  Features/     Edition · Reader · Book · Library · Recommend
```

Six domain types, one store, no abstraction layers. The Xcode project uses a synchronized folder group, so new Swift files are picked up automatically — you never have to register them.

## Design decisions worth knowing

- **Covers are typeset, not fetched.** No network, no image rights, and it gives the library a house style instead of a wall of mismatched jacket art.
- **Serif for anything a person wrote or a book is called; sans for chrome.** The single strongest signal that Dewey is not a tracker.
- **No percentage match.** Overlap is shown as named books and both ratings. A single score would claim a precision eight ratings cannot support, and would be actively wrong for someone whose taste splits by genre.
- **Disagreement is shown, not hidden.** A surface that only ever agrees with you reads as a sales pitch.
- **Closure flows to the giver, never the receiver.** "Someone started the book you recommended" is a gift. "You started Elena's book — tell her?" is a debt. The second one is not built.
- **Weekly, not daily.** ~30 follows × 20 books/year ≈ 11.5 finish-events per week and ~1.6 per day. A daily surface is empty most days; a weekly one is an edition.

## Not built, deliberately

Accounts, sync, CloudKit, any backend, catalog search, Goodreads import, OCR, notifications, moderation, analytics, follower counts, public threads, statistics, goals, streaks, infinite scroll.

## Verification status

Clean builds for **both** `iphonesimulator` and `iphoneos` — zero errors, zero warnings in app code. Verified running on an iPhone 17 Pro simulator: the Weekly Edition, the reader profile with live overlap arithmetic, the book detail with its three-hop provenance chain, the library with attributed rows, and the prototype controls with live counts. Light and dark both checked.

The `iphoneos` build succeeding means the code compiles for real device architectures — the only remaining barriers to installing on a phone are the iOS platform download and signing, both covered in [WALKTHROUGH.md](WALKTHROUGH.md) §2.

Not yet verified by a human tapping through it. Simulator automation could not be granted device access in this session, so the interactive paths (send, closure timing, reaction, reply) are compile- and logic-verified but not click-tested. Run the walkthrough and they will either work or fail loudly.
