# MyLoop iOS — Dev Plan

A personal-use iOS port of [Loop Habit Tracker](https://github.com/iSoron/uhabits), with import of the existing Android `.db` backup.

## Context & decision

### What's in the upstream repo
- Active code is Kotlin + Java on Android, Gradle multi-module: `uhabits-core` (logic) + `uhabits-android` (UI).
- A **2019 Swift prototype** existed at commit `1abc041d8` under `ios/uhabits.xcodeproj` — abandoned, removed from `dev`, no live `ios` branch today. Owner stated "the app is still unusable."
- Open architectural issues that would enable a clean port: **#486** Kotlin Multiplatform, **#487** iOS version, **#1075** remove Java deps from core, **#1076** move custom views to core. None complete.
- License: **GPL-3.0** — derivative works must also be GPL-3.0 open source. Fine for personal/sideload use; App Store distribution of GPL has historical friction (not relevant here).

### Options considered
- **A. Resurrect 2019 Swift port** — 6 years stale, abandoned, dead code. Rejected.
- **B. Kotlin Multiplatform + SwiftUI** — right long path, what maintainer would accept upstream; overkill for personal use, steep toolchain learning curve.
- **C. Fresh SwiftUI rewrite + Loop `.db` importer** — **chosen.** Maintainer explicitly blessed reading Loop's backup format in #486.

### Constraints driving the plan
- Goal: personal use, fast.
- iOS experience: new to iOS dev.
- Data: must import existing Android Loop `.db`.

---

## Phase -1 — Verify Mac + Xcode compatibility (15 min)

Check before anything else — Xcode versions are strict about macOS.

- **macOS version**: Apple menu → About This Mac. Need macOS 14 Sonoma or newer for current Xcode 16. If you're on macOS 13 Ventura, you can install Xcode 15 instead; on macOS 12 or older, upgrade macOS first.
- **Disk space**: Xcode + simulators eat ~25 GB. Make sure you have at least 40 GB free.
- **Xcode**: install from the Mac App Store (free). It's a multi-GB download — start this in the background while you read the rest of the plan.
- **Apple ID**: any normal Apple ID works for sideload. No paid Developer Program needed.

## Phase 0 — Toolchain & data (½ day)

- Open Xcode once after install to accept the license and let it download additional components.
- Xcode → Settings → Accounts → add your Apple ID (this enables free-tier signing).
- Export from Android Loop: Settings → Export full backup → `.db` file. Copy to Mac.
- Inspect with `sqlite3` CLI or DB Browser for SQLite. Run `.schema` and document the `Habits` and `Repetitions` tables (plus any `Score`/`Streak` if present).

### Device vs. simulator workflow

You do **not** need your iPhone connected to develop. Day-to-day work happens in the **iOS Simulator** (built into Xcode — pick "iPhone 15 Pro" in Xcode's top bar and Run; a virtual iPhone window opens on your Mac).

Use the real iPhone for:
1. First-time pairing (~5 min, one-time).
2. Installing the app to actually use it.
3. Weekly cert refresh (free Apple ID signing expires every 7 days).
4. Anything the simulator can't do — not relevant for a habit tracker.

After first pairing, enable Xcode → Window → Devices and Simulators → "Connect via network" so weekly re-signs work over Wi-Fi without the cable.

## Phase 1 — Understand Loop's data model (1 day)

Read (don't port) these files in `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/models/`:
- `Habit.kt` — fields, types (boolean vs numerical), frequency
- `Repetition.kt` / `Entry.kt` — check-in storage (timestamp + value)
- `Score.kt` — exponential-moving-average scoring formula. This is Loop's signature behavior; port it faithfully.
- `Streak.kt`, `Frequency.kt`

Deliverable: a plain-text notes file with:
- Habit fields and their semantics
- Entry value encoding (yes/no/skip)
- Score formula written as math, not code
- Streak rules

## Phase 2 — SwiftUI app skeleton (2–3 days for iOS beginner)

- New Xcode project: iOS App, SwiftUI, Swift, **SwiftData** for storage.
- Models mirroring Loop: `Habit`, `Entry`, computed `score(at: date)`, `streak`.
- Three screens for v1:
  1. **Habit list** — rows with name + horizontal strip of last 7 days as tappable circles (Loop's signature UI). Tap toggles done/not-done.
  2. **Add/edit habit** — name, color, frequency (X times per Y days), type (yes/no only; numerical later).
  3. **Habit detail** — score history chart (SwiftUI `Chart`), streak, calendar grid.

Out of scope for v1: widgets, notifications, themes, numerical habits.

## Phase 3 — Loop backup importer (1 day)

- Add SQLite.swift, or use `sqlite3` C API directly, to read the `.db`.
- Settings → "Import Loop backup" → file picker → read `Habits` and `Repetitions` → create SwiftData objects.
- Verify scores on a few habits match Loop's display before trusting the import.

## Phase 4 — Polish for personal use (½ day)

- App icon (any image works for sideload).
- Sideload: plug iPhone into Mac, set your free Apple ID as signing team in Xcode, Run. Trust the dev cert on the phone: Settings → General → VPN & Device Management.
- Re-sideload weekly (free cert) or pay $99/yr.

## What v1 explicitly skips

Widgets, complications, notifications, reminders, multiple themes, cloud sync, numerical habits, iPad layout. Add after you're using it daily.

## Realistic time budget

iOS beginner: **2–3 focused weekends**. Most of the time is learning SwiftUI + SwiftData; the Loop-specific logic is a few hundred lines.

## Next concrete step

Pull `Habit.kt`, `Entry.kt`, `Score.kt` from `uhabits-core` and write down the score/streak formulas. Everything downstream depends on getting these right.
