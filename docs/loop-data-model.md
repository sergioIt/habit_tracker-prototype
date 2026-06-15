# Loop Habit Tracker — Data Model Notes (Phase 1)

Extracted from `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/` on the `dev` branch (2026-06).

## Habit (the top-level entity)

Fields you'll need in MyLoop iOS (skipping reminders/widgets for v1):

| Kotlin field        | Type / values                                              | Notes |
|---------------------|------------------------------------------------------------|-------|
| `id`                | `Long?`                                                    | DB primary key (Loop uses Long; Swift use `UUID` instead and keep the Loop id only for import mapping). |
| `uuid`              | `String` (hex)                                             | Stable identifier across exports. Preserve on import. |
| `name`              | `String`                                                   | Display name. |
| `description`       | `String`                                                   | Long-form. |
| `question`          | `String`                                                   | "Did you ...?" prompt shown in UI. |
| `color`             | `PaletteColor` (Int 0..18)                                 | Palette index, not RGB. Map to a fixed palette. |
| `frequency`         | `Frequency(num, denom)`                                    | See below. |
| `type`              | `HabitType` — `YES_NO` or `NUMERICAL`                      | v1: YES_NO only. |
| `targetType`        | `AT_LEAST` / `AT_MOST`                                     | Numerical only. v2. |
| `targetValue`       | `Double`                                                   | Numerical only. v2. |
| `unit`              | `String`                                                   | Numerical only. v2. |
| `isArchived`        | `Bool`                                                     | Hide from main list. |
| `position`          | `Int`                                                      | Manual ordering. |
| `reminder`          | nullable                                                   | v2. |

## Entry (a single check-in)

```
Entry(date: LocalDate, value: Int, notes: String)
```

Value is an Int with these magic constants:

| Constant      | Int  | Meaning |
|---------------|------|---------|
| `YES_MANUAL`  |  2   | User explicitly checked off the habit. |
| `YES_AUTO`    |  1   | User wasn't expected to do it today (frequency says not due), counts as done. |
| `NO`          |  0   | Expected to do it, didn't. |
| `SKIP`        |  3   | Not applicable (e.g. sick, traveling) — neutral for scoring. |
| `UNKNOWN`     | -1   | No data. |

For **numerical** habits, `value` is `(actualNumber * 1000)` — stored as integer milli-units. v1 ignores this.

### Toggle cycle (tap a circle)
```
YES_AUTO -> YES_MANUAL -> [SKIP if enabled, else NO]
SKIP     -> NO
NO       -> [UNKNOWN if "?" enabled, else YES_MANUAL]
UNKNOWN  -> YES_MANUAL
```

For MyLoop v1 keep it simple: just NO ↔ YES_MANUAL on tap.

## Frequency

`Frequency(numerator, denominator)` = "do it `numerator` times per `denominator` days."

Examples in the code:
- `DAILY = (1, 1)` — every day
- `THREE_TIMES_PER_WEEK = (3, 7)`
- `TWO_TIMES_PER_WEEK = (2, 7)`
- `WEEKLY = (1, 7)`

As a double: `f = num / denom`. Used in the score formula below.

Special case: if `numerator == denominator` (any X-times-in-X-days), it's normalized to `(1, 1)`.

## Score — Loop's signature algorithm

From `Score.kt`:

```kotlin
fun compute(frequency: Double, previousScore: Double, checkmarkValue: Double): Double {
    val multiplier = 0.5.pow(sqrt(frequency) / 13.0)
    var score = previousScore * multiplier
    score += checkmarkValue * (1 - multiplier)
    return score
}
```

In plain math:

```
α = 0.5 ^ ( √f / 13 )                       // decay multiplier, depends on frequency
score_today = α · score_yesterday + (1 − α) · checkmarkValue_today
```

This is an **exponential moving average** of daily check-in values. Properties:

- Score is a float in `[0, 1]`.
- Higher-frequency habits decay slower per missed day (smaller f → α closer to 1 → more inertia is wrong, actually it's the opposite: small f means α is closer to 0.5^(small/13) which is closer to 1, so daily habits decay/grow slower per *step*, but they get many more steps). Net effect tuned so daily and weekly habits feel comparable.
- Half-life intuition: with `f = 1` (daily), α ≈ 0.5^(1/13) ≈ 0.9481, so ~13 days for score to halve toward zero on continuous misses. Weekly habit `f = 1/7`: α ≈ 0.5^(0.378/13) ≈ 0.9801, ~35 days half-life.

### What `checkmarkValue` means here

This is the value fed to the EMA per day. It's a continuous `Double`, not the raw `Int` constants:

- `YES_MANUAL` / `YES_AUTO` → `1.0`
- `NO` → `0.0`
- `SKIP` → score is **not updated** that day (carried forward unchanged)
- `UNKNOWN` → treat as `NO` for scoring (verify against `ScoreList` impl if you need exact behavior)

For numerical habits: `checkmarkValue = clamp(actualValue / targetValue, 0, 1)`.

### Recomputation pass

`Score.recompute(..., from, to)` walks days forward from `from` to `to`, calling `compute` once per day with the previous day's score as input. Initial `previousScore` for the very first day = `0.0`.

## Streak

```
Streak(start: LocalDate, end: LocalDate)
length = start.daysUntil(end) + 1
```

A streak is a maximal contiguous range of days where the habit was done (YES_MANUAL/YES_AUTO) **or** skipped. `NO` breaks it. `UNKNOWN` — check against `StreakList` impl; safest is to treat as breaking.

For numerical habits a day is "done" if it met the `targetType`/`targetValue` rule.

`compareLonger` picks the longer streak, tie-break by recency (`compareNewer` = which one ended later).

## Recompute pipeline (when something changes)

From `Habit.recompute()`:

1. `computedEntries.recomputeFrom(originalEntries, frequency, isNumerical)`
   — fills in `YES_AUTO` for days the user wasn't expected to act, based on frequency.
2. `scores.recompute(frequency, isNumerical, targetType, targetValue, computedEntries, from, to)`
   — runs the EMA from the earliest known entry forward.
3. `streaks.recompute(computedEntries, from, to, isNumerical, targetValue, targetType)`
   — scans for contiguous done/skip runs.

In Swift you'll do the same: store raw `Entry`s as the source of truth, derive `computedEntries`, then derive scores and streaks. Recompute lazily (when a habit is viewed) or on-write.

## Actual SQLite backup schema (verified against real export)

From a backup exported 2026-06-15. Loop stores everything in 3 tables (+ Android metadata).

```sql
CREATE TABLE Habits (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  archived        INTEGER,                 -- 0/1
  color           INTEGER,                 -- PaletteColor index 0..18
  description     TEXT,
  freq_den        INTEGER,                 -- frequency denominator (days)
  freq_num        INTEGER,                 -- frequency numerator
  highlight       INTEGER,                 -- pin/star flag, undocumented; skip v1
  name            TEXT,
  position        INTEGER,                 -- manual ordering
  reminder_hour   INTEGER,                 -- nullable
  reminder_min    INTEGER,                 -- nullable
  reminder_days   INTEGER NOT NULL DEFAULT 127,  -- bitmask, bit per weekday (127 = all)
  type            INTEGER NOT NULL DEFAULT 0,    -- 0=YES_NO, 1=NUMERICAL
  target_type     INTEGER NOT NULL DEFAULT 0,    -- numerical only
  target_value    REAL    NOT NULL DEFAULT 0,    -- numerical only
  unit            TEXT    NOT NULL DEFAULT "",   -- numerical only
  question        TEXT,
  uuid            TEXT
);

CREATE TABLE Repetitions (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  habit     INTEGER NOT NULL REFERENCES habits(id),
  timestamp INTEGER NOT NULL,              -- epoch MILLIS at UTC midnight
  value     INTEGER NOT NULL,              -- 0=NO, 1=YES_AUTO, 2=YES_MANUAL, 3=SKIP
  notes     TEXT
);
CREATE UNIQUE INDEX idx_repetitions_habit_timestamp ON Repetitions(habit, timestamp);

CREATE TABLE Events (id, timestamp, message, server_id);   -- audit log; ignore
```

### Observations from real backup

- **`Repetitions.timestamp`** is epoch *milliseconds* aligned to **UTC midnight** of the calendar day. Convert to a `Date` at UTC midnight on import; display in local time.
- **Loop only persists user-touched entries.** Your backup contains only `value=0` (NO) and `value=2` (YES_MANUAL). `YES_AUTO`, `SKIP`, `UNKNOWN` are derived at view/score time — Loop fills them in via `EntryList.recomputeFrom(frequency)`. This confirms the source-of-truth/derived split assumed in the Swift schema below.
- **`description` and `question` are separate columns.** Earlier draft conflated them.
- **`reminder_days`** is a 7-bit weekday bitmask (default 127 = all days set). Skip v1.
- **`highlight`** is undocumented in the source — appears to be a pin/star. Safe to ignore for v1; preserve on import as opaque field if you want round-trip fidelity later.
- **`uuid`** is a hex string; preserve on import as the stable identity.
- **`type=0` (YES_NO)** is all your habits use. `target_*`/`unit` columns will be defaults. Numerical path can be omitted from v1.

## Importer plan (for the Swift side)

```
1. Open Loop .db with SQLite.
2. SELECT * FROM Habits WHERE archived=0 (or include archived behind a toggle).
   For each: create a Swift Habit with uuid, name, question, description as notes,
   colorIndex=color, freqNum=freq_num, freqDenom=freq_den, position=position.
3. SELECT habit, timestamp, value, notes FROM Repetitions
   ORDER BY habit, timestamp.
   For each: create Entry(date: Date(millisFromEpoch: timestamp), value: value, notes: notes).
   Skip rows where habit not in imported set.
4. Recompute scores on demand when a habit is viewed.
```

Idempotency: keyed by `(habit.uuid, entry.date)` — re-import overwrites instead of duplicating. Use the unique constraint Loop has on `(habit, timestamp)` as the model.

## Open questions before writing Swift

These need either reading the `*List` files or testing against the Android app:

1. **YES_AUTO derivation**: how does `EntryList.recomputeFrom` decide which days get YES_AUTO? Almost certainly: look at any rolling `denominator`-day window; if `numerator` actions exist in it, fill the rest of that window with YES_AUTO. Verify before porting.
2. **UNKNOWN in scoring**: is it `0` or treated like SKIP? Check `ScoreList`.
3. **First-day score**: confirm it starts at 0.0 and not some seed value.
4. **Score sampling**: stored daily or only on changes? UI shows daily values.

To answer these, next step would be pulling `EntryList.kt`, `ScoreList.kt`, `StreakList.kt`. Doable but probably not blocking v1 — we can match Loop's behavior empirically against your real backup data once the importer works.

## What this means for the Swift schema

```swift
@Model class Habit {
    @Attribute(.unique) var uuid: String      // matches Loop's hex uuid
    var loopId: Int64?                        // Loop's Long id, for import only
    var name: String
    var question: String = ""
    var notes: String = ""                    // = description in Loop
    var colorIndex: Int = 8                   // PaletteColor
    var freqNum: Int = 1
    var freqDenom: Int = 1
    var isArchived: Bool = false
    var position: Int = 0
    // numerical fields: skip for v1
    @Relationship(deleteRule: .cascade) var entries: [Entry] = []
}

@Model class Entry {
    var date: Date                            // store as midnight UTC
    var value: Int                            // 2/1/0/3/-1 per Loop constants
    var notes: String = ""
    var habit: Habit?
}
```

Scores and streaks are **not stored** — compute on demand from `entries` + `frequency`. Cache the result in memory while a habit detail screen is open.
