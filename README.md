# habit-tracker-prototype

CLI Swift prototype that validates a port of [Loop Habit Tracker](https://github.com/iSoron/uhabits) (Android, GPL-3.0) to iOS. Reads a Loop SQLite backup, computes habit scores using Loop's algorithm, and prints a summary per habit.

Companion to a planned SwiftUI iPhone app — see `docs/ios-dev-plan.md`.

## Status

Phases -1, 0, 1 of the dev plan are complete. The Swift implementation of Loop's scoring formula (`α = 0.5^(√f / 13)`) runs against real backup data.

**Ongoing iOS-app development now lives in [`../habit-tracker-ios`](../habit-tracker-ios/)**. As of 2026-06-23 the SwiftUI app skeleton and Loop `.db` importer are working there end-to-end. See that repo's `docs/dev-plan.md` and `CHANGELOG.md`.

## Usage

```sh
swift build
swift run habit-tracker-prototype /path/to/Loop\ Habits\ Backup.db
```

Requires macOS with Xcode Command Line Tools (`/usr/bin/swift` 5.9+). System SQLite is linked via a module-map shim under `Sources/CSQLite`.

## Layout

- `Sources/HabitTracker/` — Swift sources: models, score algorithm, SQLite importer, CLI entrypoint.
- `Sources/CSQLite/` — module-map shim for the system `sqlite3` library.
- `Tests/HabitTrackerTests/` — XCTest cases for the score algorithm (require full Xcode to run; build-only on CLT).
- `docs/ios-dev-plan.md` — phased dev plan for the iOS app.
- `docs/loop-data-model.md` — Loop's data model, formulas, real SQLite schema, importer spec.
- `docs/loop-kotlin-refs/` — original Kotlin sources from `uhabits-core` for reference.

## License

This prototype ports algorithms from `iSoron/uhabits`, which is GPL-3.0. Any public derivative must also be GPL-3.0.
