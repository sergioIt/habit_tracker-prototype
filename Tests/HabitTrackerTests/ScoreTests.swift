import XCTest
@testable import habit_tracker_prototype

final class ScoreTests: XCTestCase {

    /// Reference values come from porting Loop's Score.kt directly.
    /// α = 0.5^(√f / 13)
    func testMultiplierDaily() {
        // f = 1.0, α = 0.5^(1/13)
        let s = Score.step(frequency: 1.0, previousScore: 0.0, checkmarkValue: 1.0)
        // After 1 check-in from 0: score = 1 - α
        let alpha = pow(0.5, 1.0 / 13.0)
        XCTAssertEqual(s, 1.0 - alpha, accuracy: 1e-12)
    }

    func testMonotonicGrowthAllYes() {
        // Daily habit, 100 consecutive YES → score must climb monotonically toward 1.
        var score = 0.0
        for _ in 0..<100 {
            let next = Score.step(frequency: 1.0, previousScore: score, checkmarkValue: 1.0)
            XCTAssertGreaterThan(next, score)
            score = next
        }
        XCTAssertGreaterThan(score, 0.99)
    }

    func testMonotonicDecayAllNo() {
        // Start at 1.0, all NO → must decay monotonically toward 0.
        var score = 1.0
        for _ in 0..<100 {
            let next = Score.step(frequency: 1.0, previousScore: score, checkmarkValue: 0.0)
            XCTAssertLessThan(next, score)
            score = next
        }
        XCTAssertLessThan(score, 0.01)
    }

    func testWeeklyHabitDecaysSlowerThanDaily() {
        // After 14 days of NO starting from 1.0, weekly habit should retain more.
        let daily = decayedScore(f: 1.0, days: 14, start: 1.0)
        let weekly = decayedScore(f: 1.0/7.0, days: 14, start: 1.0)
        XCTAssertGreaterThan(weekly, daily)
    }

    func testSkipDoesNotChangeScore() {
        XCTAssertNil(Score.checkmarkValue(forEntryValue: EntryValue.skip))
        XCTAssertEqual(Score.checkmarkValue(forEntryValue: EntryValue.yesManual), 1.0)
        XCTAssertEqual(Score.checkmarkValue(forEntryValue: EntryValue.no), 0.0)
    }

    func testRecomputeProducesOneEntryPerDay() {
        let cal = Calendar.utc
        let start = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2025, month: 1, day: 10))!
        let entries: [Date: Int] = [start: EntryValue.yesManual]
        let series = Score.recompute(
            frequency: .daily, entriesByDate: entries,
            from: start, to: end, calendar: cal
        )
        XCTAssertEqual(series.count, 10)
        // Day 1 is YES → score jumps; day 2..10 are implicit NO → score must monotonically decrease.
        for i in 2..<series.count {
            XCTAssertLessThan(series[i].score, series[i-1].score)
        }
    }

    private func decayedScore(f: Double, days: Int, start: Double) -> Double {
        var s = start
        for _ in 0..<days {
            s = Score.step(frequency: f, previousScore: s, checkmarkValue: 0.0)
        }
        return s
    }
}
