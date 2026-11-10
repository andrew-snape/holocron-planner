import Foundation

/// The report progress board: where each student's report stands, worked out from the saved text.
/// Foundation only, so it can be tested on its own.
enum ReportBoard {
    /// The word range the report rules ask for in the general comment.
    static let wordRange = 100...150
    /// Dot points: 4 to 6 achievements and 3 to 6 next steps, so 7 to 12 in all.
    static let pointRange = 7...12

    enum Status: String {
        case none = "None"
        case draft = "Draft"
        case ready = "Ready"
    }

    /// None when empty, Ready when inside the word range, otherwise Draft.
    static func generalStatus(_ text: String) -> Status {
        let n = text.split(whereSeparator: { $0.isWhitespace }).count
        if n == 0 { return .none }
        return wordRange.contains(n) ? .ready : .draft
    }

    static func words(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// Lines that start with "- ", the way dot points are kept.
    static func pointCount(_ text: String) -> Int {
        text.split(separator: "\n").filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") }.count
    }

    static func pointsStatus(_ text: String) -> Status {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .none }
        return pointRange.contains(pointCount(text)) ? .ready : .draft
    }

    /// How many of the subjects have an achievement judgement.
    static func judged(_ subjects: [String], achievement: (String) -> String) -> Int {
        subjects.filter { !achievement($0).trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
}
