import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: habit-tracker-prototype <path-to-loop.db>")
    exit(2)
}
let dbPath = args[1]

let backup: LoopBackup
do {
    backup = try LoopImporter.read(path: dbPath)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

let utc = Calendar.utc

print("Loaded \(backup.habits.count) habits, \(backup.entriesByHabitId.values.map(\.count).reduce(0, +)) entries\n")

let today = utc.startOfDay(for: Date())
// Show only active habits sorted by position
for habit in backup.habits.filter({ !$0.isArchived }) {
    let entries = backup.entriesByHabitId[habit.loopId] ?? []
    guard let first = entries.first else {
        print("• \(habit.name) — no data")
        continue
    }

    let entriesByDate: [Date: Int] = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.date, $0.value) }
    )
    let yesCount = entries.filter { $0.value == EntryValue.yesManual || $0.value == EntryValue.yesAuto }.count
    let noCount  = entries.filter { $0.value == EntryValue.no }.count

    let series = Score.recompute(
        frequency: habit.frequency,
        entriesByDate: entriesByDate,
        from: first.date,
        to: today,
        calendar: utc
    )
    let currentScore = series.last?.score ?? 0

    let f = habit.frequency
    let freqStr = f.numerator == f.denominator ? "daily" : "\(f.numerator)/\(f.denominator)d"
    let scoreStr = String(format: "%5.1f%%", currentScore * 100)
    let name = habit.name.padding(toLength: 26, withPad: " ", startingAt: 0)
    let freq = freqStr.padding(toLength: 8, withPad: " ", startingAt: 0)
    print("• \(name)  freq=\(freq)  entries=\(String(format: "%4d", entries.count)) (yes=\(String(format: "%4d", yesCount)) no=\(String(format: "%3d", noCount)))  score=\(scoreStr)")
}
