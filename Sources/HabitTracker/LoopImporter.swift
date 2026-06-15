import Foundation
import CSQLite

enum ImportError: Error {
    case open(String)
    case prepare(String)
    case step(String)
}

struct LoopBackup {
    let habits: [Habit]
    let entriesByHabitId: [Int64: [Entry]]
}

enum LoopImporter {
    static func read(path: String) throws -> LoopBackup {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw ImportError.open(msg)
        }
        defer { sqlite3_close(db) }

        let habits = try readHabits(db: db)
        let entries = try readEntries(db: db)
        return LoopBackup(habits: habits, entriesByHabitId: entries)
    }

    private static func readHabits(db: OpaquePointer?) throws -> [Habit] {
        let sql = """
            SELECT id, uuid, name, question, description, color,
                   freq_num, freq_den, archived, position
            FROM Habits ORDER BY position
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var out: [Habit] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id      = sqlite3_column_int64(stmt, 0)
            let uuid    = colText(stmt, 1) ?? ""
            let name    = colText(stmt, 2) ?? ""
            let qst     = colText(stmt, 3) ?? ""
            let desc    = colText(stmt, 4) ?? ""
            let color   = Int(sqlite3_column_int(stmt, 5))
            let fnum    = Int(sqlite3_column_int(stmt, 6))
            let fden    = Int(sqlite3_column_int(stmt, 7))
            let arch    = sqlite3_column_int(stmt, 8) != 0
            let pos     = Int(sqlite3_column_int(stmt, 9))
            out.append(Habit(
                uuid: uuid, loopId: id, name: name, question: qst, notes: desc,
                colorIndex: color,
                frequency: Frequency(numerator: max(1, fnum), denominator: max(1, fden)),
                isArchived: arch, position: pos
            ))
        }
        return out
    }

    private static func readEntries(db: OpaquePointer?) throws -> [Int64: [Entry]] {
        let sql = "SELECT habit, timestamp, value, notes FROM Repetitions ORDER BY habit, timestamp"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var out: [Int64: [Entry]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let habitId = sqlite3_column_int64(stmt, 0)
            let tsMs    = sqlite3_column_int64(stmt, 1)
            let value   = Int(sqlite3_column_int(stmt, 2))
            let notes   = colText(stmt, 3) ?? ""
            let date    = Date(timeIntervalSince1970: TimeInterval(tsMs) / 1000.0)
            out[habitId, default: []].append(Entry(date: date, value: value, notes: notes))
        }
        return out
    }

    private static func colText(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cstr)
    }
}
