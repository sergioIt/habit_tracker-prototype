import Foundation

// MARK: - Entry values (mirror Loop's Entry.kt constants)
enum EntryValue {
    static let skip       =  3
    static let yesManual  =  2
    static let yesAuto    =  1
    static let no         =  0
    static let unknown    = -1
}

struct Frequency: Equatable {
    let numerator: Int
    let denominator: Int

    var asDouble: Double { Double(numerator) / Double(denominator) }

    static let daily = Frequency(numerator: 1, denominator: 1)
}

struct Habit {
    let uuid: String
    let loopId: Int64
    var name: String
    var question: String
    var notes: String          // Loop's "description"
    var colorIndex: Int
    var frequency: Frequency
    var isArchived: Bool
    var position: Int
}

struct Entry {
    let date: Date             // UTC midnight of the calendar day
    let value: Int             // EntryValue.*
    let notes: String
}
