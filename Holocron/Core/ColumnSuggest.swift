import Foundation
import FoundationModels

// MARK: - Suggesting columns with Apple Intelligence
//
// When a spreadsheet's headers do not say clearly which column is which, the on-device model
// reads the headers and one example from each column and suggests the columns. It runs on this
// Mac only, nothing is sent anywhere, and the teacher still checks every column before importing.

@Generable
struct SuggestedColumns {
    @Guide(description: "Exact header of the column with each student's whole name, or empty if names are split into first name and surname")
    var studentName: String
    @Guide(description: "Exact header of the first name column, or empty")
    var firstName: String
    @Guide(description: "Exact header of the surname or last name column, or empty")
    var surname: String
    @Guide(description: "Exact header of a student ID or code column, or empty")
    var studentID: String
    @Guide(description: "Exact header of the date the assessment was done, or empty")
    var date: String
    @Guide(description: "Exact header of the subject, learning area or strand, or empty")
    var subject: String
    @Guide(description: "Exact header naming the test, task or topic, or empty")
    var task: String
    @Guide(description: "Exact header saying pre test or post test, or empty")
    var phase: String
    @Guide(description: "Exact header of the main score, percentage or result for the student, or empty")
    var result: String
    @Guide(description: "Exact headers of up to three other columns worth keeping in a teacher's comment, such as a level, grade, stanine or growth")
    var notes: [String]
}

enum ColumnSuggest {
    static var isAvailable: Bool { Intelligence.isAvailable }

    private static let instructions = """
        You help a primary school teacher in Australia import assessment results from a spreadsheet \
        exported by another program. Match the spreadsheet's columns to what is asked. Answer only \
        with headers copied exactly from the list. Leave a field empty when no column fits.
        """
    private static let promptPrefix = "The spreadsheet's columns are:\n"

    /// Loads the model while a results file is being read, so a suggestion starts sooner.
    static func prewarm() {
        guard isAvailable else { return }
        let session = LanguageModelSession(instructions: instructions)
        WarmSessions.put("columns", session: session, instructions: instructions)
        Intelligence.prewarm(session, prefix: promptPrefix)
    }

    /// Suggested columns for a table. Headers the model names that are not in the table are ignored.
    static func suggest(_ table: ResultsTable) async throws -> ColumnMap {
        let example = table.rows.first { $0.filter { !$0.isEmpty }.count >= table.header.count / 2 } ?? table.rows.first ?? []
        let lines = table.header.enumerated().map { i, h in
            let v = i < example.count ? String(example[i].prefix(30)) : ""
            return "- \(h)" + (v.isEmpty ? "" : " (for example: \(v))")
        }
        let session = WarmSessions.take("columns", instructions: instructions)?.session ?? LanguageModelSession(instructions: instructions)
        let prompt = promptPrefix + lines.joined(separator: "\n")
        let s = try await session.respond(to: prompt, generating: SuggestedColumns.self).content

        var m = ColumnMap(source: "Apple Intelligence")
        func col(_ h: String) -> Int? {
            let k = ColumnMap.normalised(h)
            return k.isEmpty ? nil : table.header.firstIndex { ColumnMap.normalised($0) == k }
        }
        m[.name] = col(s.studentName); m[.first] = col(s.firstName); m[.surname] = col(s.surname)
        m[.ref] = col(s.studentID); m[.date] = col(s.date); m[.subject] = col(s.subject)
        m[.task] = col(s.task); m[.phase] = col(s.phase); m[.result] = col(s.result)
        if m[.name] != nil && m[.first] != nil && m[.surname] != nil { m[.name] = nil }
        let used = Set(m.roles.values)
        m.notes = Array(s.notes.compactMap(col).filter { !used.contains($0) }.prefix(3))
        return m
    }
}
