import Foundation

/// What a brand new data folder starts with, so a first-time user sees a working day instead of an
/// empty screen. Used only when a file does not exist yet; existing files are never touched.
/// Everything here can be edited in Settings.
enum Starter {
    static func rows(for t: TableName) -> [Row] {
        switch t {
        case .periods:
            return [
                ["period": "1", "name": "Morning circle", "start": "08:55", "end": "09:30"],
                ["period": "2", "name": "Period 1", "start": "09:30", "end": "10:15"],
                ["period": "3", "name": "Period 2", "start": "10:15", "end": "11:00"],
                ["period": "4", "name": "Period 3", "start": "11:30", "end": "12:15"],
                ["period": "5", "name": "Period 4", "start": "12:15", "end": "13:00"],
                ["period": "6", "name": "Period 5", "start": "13:45", "end": "14:30"],
                ["period": "7", "name": "Period 6", "start": "14:30", "end": "15:15"],
            ]
        case .subjects:
            let teach: [(String, String)] = [
                ("Circle Time", "#A2845E"), ("Devotion", "#5856D6"), ("Maths", "#34C759"), ("Literacy", "#FF9500"),
                ("Spelling", "#FFCC00"), ("TDL", "#00C7BE"), ("Classroom Sport", "#64D2FF"), ("Library", "#32ADE6"),
            ]
            let release: [(String, String)] = [
                ("PE", "#FF2D55"), ("Art", "#AF52DE"), ("Music", "#FF6482"), ("STEM", "#30B0C7"), ("French", "#007AFF"),
            ]
            return teach.map { ["subject": $0.0, "kind": "teach", "colour": $0.1] }
                + release.map { ["subject": $0.0, "kind": "release", "colour": $0.1] }
        default:
            return []
        }
    }
}
