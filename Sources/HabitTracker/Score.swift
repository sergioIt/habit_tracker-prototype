import Foundation

// Direct port of uhabits-core/src/commonMain/kotlin/.../models/Score.kt
//
// score_today = α · score_prev + (1 − α) · checkmark
// α = 0.5 ^ ( √f / 13 )
enum Score {
    static func step(frequency: Double, previousScore: Double, checkmarkValue: Double) -> Double {
        let multiplier = pow(0.5, sqrt(frequency) / 13.0)
        return previousScore * multiplier + checkmarkValue * (1.0 - multiplier)
    }

    /// Map Loop's integer entry value to the EMA input in [0, 1].
    /// SKIP returns nil → caller carries the previous score forward unchanged.
    static func checkmarkValue(forEntryValue v: Int) -> Double? {
        switch v {
        case EntryValue.yesManual, EntryValue.yesAuto: return 1.0
        case EntryValue.no, EntryValue.unknown:        return 0.0
        case EntryValue.skip:                          return nil
        default:                                       return 0.0
        }
    }

    /// Walk forward day-by-day from the first entry to `endDate`, applying the EMA.
    /// `entriesByDate` must contain only days where the user touched the habit
    /// (Loop's persistence model). All other days are treated as NO.
    ///
    /// Note: this is a simplified version. The real Loop algorithm fills in
    /// YES_AUTO for days within a frequency window — see Open Questions in
    /// loop-data-model.md. We'll cross-check against real Loop output below.
    static func recompute(
        frequency: Frequency,
        entriesByDate: [Date: Int],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .utc
    ) -> [(date: Date, score: Double)] {
        var result: [(Date, Double)] = []
        var score = 0.0
        var day = startDate
        let f = frequency.asDouble
        while day <= endDate {
            let raw = entriesByDate[day] ?? EntryValue.no
            if let cm = checkmarkValue(forEntryValue: raw) {
                score = step(frequency: f, previousScore: score, checkmarkValue: cm)
            }
            // SKIP: carry forward
            result.append((day, score))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}

extension Calendar {
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
}
