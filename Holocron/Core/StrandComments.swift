import Foundation

// MARK: - Report comments from Essential Assessment
//
// Essential Assessment's Report Comments export lists, for one strand, each student's Areas of
// Success, Areas of Growth and Areas for Improvement. They are kept with the semester and used
// as the main source when drafting the Mathematics or English dot points.

struct StrandCommentsFile {
    struct Item {
        /// The row in the file, so an item can be matched back to its student.
        var row: [String]
        var name: String
        var success: String
        var growth: String
        var improve: String
    }

    var strand: String
    var substrand: String
    var className: String
    var items: [Item]
    var table: ResultsTable

    /// Whether a table is this export: a Student column and an Areas of Success column.
    static func matches(_ t: ResultsTable) -> Bool {
        let h = t.header.map(ColumnMap.normalised)
        return h.contains("student") && h.contains("areas of success")
    }

    init?(_ t: ResultsTable) {
        guard StrandCommentsFile.matches(t) else { return nil }
        let h = t.header.map(ColumnMap.normalised)
        func col(_ n: String) -> Int? { h.firstIndex(of: n) }
        guard let name = col("student"), let success = col("areas of success") else { return nil }
        let growth = col("areas of growth"), improve = col("areas for improvement")
        // "Strand: Number" and the like sit above the header, in one cell or as "Strand:" then the value.
        func meta(_ key: String) -> String {
            for row in t.preamble {
                for (i, cell) in row.enumerated() where cell.lowercased().hasPrefix(key.lowercased() + ":") {
                    let inCell = String(cell.dropFirst(key.count + 1)).trimmed
                    if !inCell.isEmpty { return inCell }
                    return row.dropFirst(i + 1).first { !$0.trimmed.isEmpty }?.trimmed ?? ""
                }
            }
            return ""
        }
        strand = meta("Strand")
        substrand = meta("Substrand")
        // Without a strand the comments could not be told apart from another file's.
        guard !strand.isEmpty else { return nil }
        className = meta("Class")
        table = t
        items = t.rows.compactMap { r in
            let n = t.value(r, name)
            guard !n.isEmpty else { return nil }
            return Item(row: r, name: n, success: StrandCommentsFile.concepts(t.value(r, success)),
                        growth: StrandCommentsFile.concepts(t.value(r, growth)), improve: StrandCommentsFile.concepts(t.value(r, improve)))
        }
    }

    /// "Amelia has demonstrated understanding of the following concepts; compare and order …" becomes
    /// "compare and order …". Text without that lead-in is kept as it is.
    static func concepts(_ text: String) -> String {
        let t = text.trimmed
        if let semi = t.firstIndex(where: { $0 == ";" || $0 == ":" }), t[..<semi].lowercased().contains("following") {
            return String(t[t.index(after: semi)...]).trimmed
        }
        return t
    }

    /// Which report comment the strand feeds.
    var kind: ReportComment { StrandCommentsFile.kindOf(strand) }

    /// "Number" or "Number (General All)".
    var label: String { substrand.isEmpty ? strand : "\(strand) (\(substrand))" }
}

extension Database {
    /// A student's imported strand comments for a semester, for one report comment.
    func strandComments(_ sid: String, sem: String, for kind: ReportComment) -> [Row] {
        rows(.strandcomments).filter { r in
            r.s("student_id") == sid && r.s("sem") == sem
                && (StrandCommentsFile.kindOf(r.s("strand")) == kind)
        }
        .sorted { $0.s("strand") + $0.s("substrand") < $1.s("strand") + $1.s("substrand") }
    }

    /// Saves comments for the students matched, replacing earlier ones for the same student,
    /// semester, strand and substrand. Returns how many were added and how many replaced.
    func saveStrandComments(_ file: StrandCommentsFile, sem: String, students: [(item: StrandCommentsFile.Item, sid: String)]) -> (added: Int, replaced: Int) {
        var added = 0, replaced = 0
        let today = todayISO()
        var seen = Set<String>()
        for (item, sid) in students where seen.insert(sid).inserted && !(item.success + item.growth + item.improve).trimmed.isEmpty {
            let match: (Row) -> Bool = {
                $0.s("student_id") == sid && $0.s("sem") == sem && $0.s("strand") == file.strand && $0.s("substrand") == file.substrand
            }
            let values: Row = ["success": item.success, "growth": item.growth, "improve": item.improve, "imported": today]
            if rows(.strandcomments).contains(where: match) {
                update(.strandcomments, where: match) { r in for (k, v) in values { r[k] = v } }
                replaced += 1
            } else {
                var r = values
                r["id"] = uid(); r["student_id"] = sid; r["sem"] = sem; r["strand"] = file.strand; r["substrand"] = file.substrand
                append(.strandcomments, r)
                added += 1
            }
        }
        touch(.strandcomments)
        return (added, replaced)
    }
}

extension StrandCommentsFile {
    static func kindOf(_ strand: String) -> ReportComment {
        let s = strand.lowercased()
        return ReportComment.english.covers(s) || ["language", "literature", "reading", "writing", "speaking"].contains { s.contains($0) } ? .english : .maths
    }
}
