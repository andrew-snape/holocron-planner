import Foundation

// MARK: - Importing results from a spreadsheet
//
// Brings assessment results from another program's export (Essential Assessment, PAT, a colleague's
// spreadsheet) into assessments.csv. The columns are matched to what Holocron needs, the students
// to the roll, and the teacher checks both before anything is saved. Students who are not on the
// roll are left out, so a whole-school export only brings in your own class.

/// A spreadsheet's first sheet: the header and the rows under it, as text.
struct ResultsTable {
    var name: String
    var header: [String]
    var rows: [[String]]
    /// Rows above the header, such as a title or "Strand: Number".
    var preamble: [[String]] = []

    func value(_ row: [String], _ col: Int?) -> String {
        guard let c = col, c < row.count else { return "" }
        return row[c].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum Failure: Error, Equatable {
        case unreadable(String)
        case empty
    }

    /// Reads an .xlsx, .csv or .tsv file. Nothing is changed.
    static func load(_ url: URL) throws -> ResultsTable {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw Failure.unreadable("\(url.lastPathComponent) could not be opened. If it is in iCloud Drive, wait for it to download, then try again.")
        }
        var grid: [[String]]
        switch url.pathExtension.lowercased() {
        case "xlsx", "xlsm":
            do { grid = try XLSX.firstSheet(data) }
            catch XLSX.Failure.unsupported(let why) { throw Failure.unreadable(why) }
            catch { throw Failure.unreadable("\(url.lastPathComponent) does not look like an Excel workbook.") }
        case "xls":
            throw Failure.unreadable("Holocron cannot read the old .xls format. Export it again as .xlsx or .csv.")
        default:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
                throw Failure.unreadable("\(url.lastPathComponent) could not be read as text.")
            }
            grid = delimited(text, tab: url.pathExtension.lowercased() == "tsv")
        }
        grid = grid.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        // Some exports put a title or report date above the real header. Take the fullest of the
        // first few rows as the header.
        // The fullest row wins, and of rows equally full the first.
        var top: (offset: Int, element: [String])? = nil
        for (i, r) in grid.prefix(8).enumerated() where r.filter({ !$0.isEmpty }).count > (top?.element.filter { !$0.isEmpty }.count ?? 0) {
            top = (i, r)
        }
        guard let h = top, h.element.filter({ !$0.isEmpty }).count >= 2, grid.count > h.offset + 1 else { throw Failure.empty }
        return ResultsTable(name: url.lastPathComponent,
                            header: h.element.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                            rows: Array(grid.dropFirst(h.offset + 1)),
                            preamble: Array(grid.prefix(h.offset)))
    }

    /// Splits CSV or tab separated text into rows, keeping every column in order. Quoted fields
    /// may hold the separator, quotes ("") and line breaks. Lines may end in CRLF, LF or CR.
    static func delimited(_ text: String, tab: Bool) -> [[String]] {
        let sep: Character = tab ? "\t" : ","
        let chars = Array(text)
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if quoted {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false }
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                quoted = true
            } else if ch == sep {
                row.append(field); field = ""
            } else if ch == "\n" || ch == "\r" || ch == "\r\n" {
                row.append(field); field = ""
                rows.append(row); row = []
                if ch == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else if ch != "\u{FEFF}" {
                field.append(ch)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

// MARK: Columns

/// What a column holds, as far as importing results goes.
enum ColumnRole: String, CaseIterable, Identifiable {
    case name, first, surname, ref, date, subject, task, detail, phase, result

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Student name"
        case .first: return "First name"
        case .surname: return "Surname"
        case .ref: return "Student ID"
        case .date: return "Date"
        case .subject: return "Subject or strand"
        case .task: return "Task"
        case .detail: return "Task detail"
        case .phase: return "Pre or post"
        case .result: return "Result"
        }
    }

    /// Header words that suggest the role. Exact matches count most.
    fileprivate var keywords: [String] {
        switch self {
        case .name: return ["student name", "full name", "name", "student"]
        case .first: return ["first name", "given name", "preferred name", "firstname", "first"]
        case .surname: return ["surname", "last name", "family name", "lastname"]
        case .ref: return ["student id", "student code", "student number", "id"]
        case .date: return ["assessment date", "test date", "date completed", "date"]
        case .subject: return ["subject", "learning area", "strand", "domain"]
        case .task: return ["focus area", "assessment name", "task", "test", "topic", "assessment"]
        case .detail: return []
        case .phase: return ["type of assessment", "pre post", "phase"]
        case .result: return ["percentage", "percent", "score", "result", "mark", "scale"]
        }
    }
}

struct ColumnMap: Equatable {
    var roles: [ColumnRole: Int] = [:]
    /// Columns added to each result's comment, such as an achievement level or growth.
    var notes: [Int] = []
    /// Where the matching came from, shown to the teacher ("Essential Assessment").
    var source = ""

    subscript(_ r: ColumnRole) -> Int? {
        get { roles[r] }
        set { roles[r] = newValue }
    }

    /// Enough to import: someone to give the result to, and a result.
    var isComplete: Bool {
        (self[.name] != nil || (self[.first] != nil && self[.surname] != nil)) && self[.result] != nil
    }

    static func normalised(_ h: String) -> String {
        String(h.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ").joined(separator: " ")
    }

    /// Works out the columns from the header alone.
    static func guess(_ header: [String]) -> ColumnMap {
        let h = header.map(normalised)
        func col(_ name: String) -> Int? { h.firstIndex(of: name) }

        // Essential Assessment exports have a fixed set of columns.
        if let strand = col("strand"), let focus = col("focus area"), let type = col("type of assessment"),
           let name = col("student name"), let pct = col("assessment percentage") {
            var m = ColumnMap(source: "Essential Assessment")
            m[.name] = name; m[.ref] = col("student id"); m[.date] = col("assessment date")
            m[.subject] = strand; m[.task] = strand; m[.detail] = focus; m[.phase] = type; m[.result] = pct
            m.notes = ["assessment achievement level", "assessment range", "growth"].compactMap(col)
            return m
        }

        var m = ColumnMap()
        var used = Set<Int>()
        let order: [ColumnRole] = [.date, .ref, .first, .surname, .name, .result, .phase, .subject, .task]
        for role in order {
            var best: (col: Int, score: Int)? = nil
            for (i, name) in h.enumerated() where !used.contains(i) && !name.isEmpty {
                if role == .name && ["first", "last", "surname", "given", "family", "preferred"].contains(where: name.contains) { continue }
                if role == .ref && name.contains("name") { continue }
                var score = 0
                for k in role.keywords {
                    if name == k { score = max(score, 3) }
                    else if (" " + name + " ").contains(" " + k + " ") { score = max(score, 2) }
                }
                if score > 0 && score > (best?.score ?? 0) { best = (i, score) }
            }
            if let b = best { m[role] = b.col; used.insert(b.col) }
        }
        if m[.name] != nil && m[.first] != nil && m[.surname] != nil { m[.name] = nil }
        return m
    }
}

// MARK: Names

/// How a person in the file was matched to the roll.
enum NameMatch: Equatable {
    case exact(String)
    /// Picked by the teacher in an earlier import, by the file's student ID.
    case remembered(String)
    /// Close but not certain, such as Alex for Alexander. The teacher should check it.
    case likely(String)
    case none

    var studentID: String? {
        switch self {
        case .exact(let s), .remembered(let s), .likely(let s): return s
        case .none: return nil
        }
    }
}

enum NameMatcher {
    static func fold(_ s: String) -> [String] {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_AU"))
            .lowercased()
        return String(folded.map { $0.isLetter ? $0 : " " }).split(separator: " ").map(String.init)
    }

    /// Splits a single name column into first name and surname. Exports often write the surname
    /// in capitals first ("ADAMS Ava") or with a comma ("Adams, Ava").
    static func split(_ full: String) -> (first: String, surname: String) {
        if let comma = full.firstIndex(of: ",") {
            return (String(full[full.index(after: comma)...]).trimmingCharacters(in: .whitespaces),
                    String(full[..<comma]).trimmingCharacters(in: .whitespaces))
        }
        let words = full.split(separator: " ").map(String.init)
        func shouting(_ w: String) -> Bool {
            let letters = w.filter(\.isLetter)
            return letters.count > 1 && letters == letters.uppercased() && letters != letters.lowercased()
        }
        let caps = words.filter(shouting)
        if !caps.isEmpty && caps.count < words.count {
            return (words.filter { !shouting($0) }.joined(separator: " "), caps.joined(separator: " "))
        }
        guard words.count > 1 else { return (full, "") }
        return (words.dropLast().joined(separator: " "), words.last!)
    }

    /// The roll with each name folded once, so a long file does not fold it again for every person.
    struct Folded {
        var id: String
        var first: [String]
        var surname: [String]
        var whole: [String]
    }

    static func folded(_ roster: [Student]) -> [Folded] {
        roster.map { st in
            let f = fold(st.first), s = fold(st.surname)
            return Folded(id: st.id, first: f, surname: s, whole: (f + s).sorted())
        }
    }

    static func match(first: String, surname: String, ref: String, roster: [Student], remembered: [String: String]) -> NameMatch {
        match(first: first, surname: surname, ref: ref, roll: folded(roster), remembered: remembered)
    }

    static func match(first: String, surname: String, ref: String, roll roster: [Folded], remembered: [String: String]) -> NameMatch {
        if !ref.isEmpty, let sid = remembered[ref], roster.contains(where: { $0.id == sid }) { return .remembered(sid) }
        let f = fold(first), s = fold(surname)
        let whole = (f + s).sorted()
        let exact = roster.filter { $0.whole == whole }
        if exact.count == 1 { return .exact(exact[0].id) }
        if exact.count > 1 { return .none }

        // Same surname and a first name that starts the same way (Alex and Alexander), or the
        // same first name and one surname inside the other (Smith and Smith-Jones).
        func prefix(_ a: [String], _ b: [String]) -> Bool {
            guard let x = a.first, let y = b.first, min(x.count, y.count) >= 3 else { return false }
            return x.hasPrefix(y) || y.hasPrefix(x)
        }
        let likely = roster.filter { st in
            let sf = st.first, ss = st.surname
            if !s.isEmpty && ss == s && prefix(sf, f) { return true }
            if !f.isEmpty && sf == f && !s.isEmpty && !ss.isEmpty && (Set(ss).isSuperset(of: s) || Set(s).isSuperset(of: ss)) { return true }
            return false
        }
        return likely.count == 1 ? .likely(likely[0].id) : .none
    }
}

// MARK: Turning rows into results

/// One person in the file, with how many results they have.
struct ImportPerson: Identifiable {
    var id: String
    var name: String
    var ref: String
    var count: Int
    var match: NameMatch
}

struct ResultsDraft {
    var table: ResultsTable
    var map: ColumnMap

    /// The task text used when no column holds the task.
    var fixedTask = ""
    /// The date used when no column holds the date.
    var fixedDate = todayISO()
    /// The subject used when no column holds the subject.
    var fixedSubject = ""
    /// Each value of the subject column and the Holocron subject it goes to. "" leaves it out.
    var subjectFor: [String: String] = [:]
    /// The student each person in the file is given to, by person id. Missing means left out.
    var assigned: [String: String] = [:]

    init(table: ResultsTable, map: ColumnMap) {
        self.table = table
        self.map = map
    }

    /// Who a row is about: the file's student ID when there is one, else the folded name.
    func personID(_ row: [String]) -> String {
        let ref = table.value(row, map[.ref])
        if !ref.isEmpty { return "ref:" + ref }
        let (f, s) = names(row)
        return "name:" + (NameMatcher.fold(f) + NameMatcher.fold(s)).sorted().joined(separator: " ")
    }

    private func names(_ row: [String]) -> (String, String) {
        if map[.first] != nil || map[.surname] != nil {
            return (table.value(row, map[.first]), table.value(row, map[.surname]))
        }
        return NameMatcher.split(table.value(row, map[.name]))
    }

    func displayName(_ row: [String]) -> String {
        let (f, s) = names(row)
        // "ADAMS" reads as "Adams", but "McDonald" is left as it is.
        let surname = s == s.uppercased() ? s.capitalized(with: Locale(identifier: "en_AU")) : s
        return [f, surname].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Everyone in the file, matched against the roll. People with no name are left out.
    func people(roster: [Student], remembered: [String: String]) -> [ImportPerson] {
        let roll = NameMatcher.folded(roster)
        var out: [String: ImportPerson] = [:]
        var order: [String] = []
        for row in table.rows {
            let (f, s) = names(row)
            guard !(f + s).isEmpty else { continue }
            let id = personID(row)
            if out[id] != nil { out[id]!.count += 1; continue }
            let ref = table.value(row, map[.ref])
            out[id] = ImportPerson(id: id, name: displayName(row), ref: ref, count: 1,
                                   match: NameMatcher.match(first: f, surname: s, ref: ref, roll: roll, remembered: remembered))
            order.append(id)
        }
        return order.compactMap { out[$0] }
    }

    /// The distinct values of the subject column, tidied, in the order they first appear.
    var subjectValues: [String] {
        guard let c = map[.subject] else { return [] }
        let tails = sharedTails
        var seen = Set<String>(), out: [String] = []
        for row in table.rows {
            let v = ResultsDraft.tidy(table.value(row, c), tails[c])
            if !v.isEmpty && seen.insert(v).inserted { out.append(v) }
        }
        return out
    }

    /// Drops a bracketed tail that every value in the column shares, such as "(F-10 New)" in
    /// "Number (F-10 New)". It says nothing about one row and only makes the task longer.
    private static func tidy(_ v: String, _ tail: String?) -> String {
        guard let tail, v.hasSuffix(tail) else { return v }
        return String(v.dropLast(tail.count)).trimmingCharacters(in: .whitespaces)
    }

    private var sharedTails: [Int: String] {
        var out: [Int: String] = [:]
        for c in Set([map[.subject], map[.task], map[.detail]].compactMap { $0 }) {
            var tail: String? = nil, same = true
            for row in table.rows {
                let v = table.value(row, c)
                guard v.hasSuffix(")"), let open = v.lastIndex(of: "("), open > v.startIndex else { same = false; break }
                let t = String(v[open...])
                if tail == nil { tail = t } else if tail != t { same = false; break }
            }
            if same, let t = tail { out[c] = t }
        }
        return out
    }

    struct Outcome {
        var rows: [Row]
        /// Rows in the file left out because their student is not on the roll or was skipped.
        var notOnRoll = 0
        var noDate = 0
        var noResult = 0
        var noSubject = 0
    }

    /// The assessment rows this would add, before they are compared with what is already saved.
    func results() -> Outcome {
        var out = Outcome(rows: [])
        let tails = sharedTails
        func tidied(_ row: [String], _ r: ColumnRole) -> String {
            ResultsDraft.tidy(table.value(row, map[r]), map[r].flatMap { tails[$0] })
        }
        let resultHeader = map[.result].map { ColumnMap.normalised(table.header[$0]) } ?? ""
        let percent = resultHeader.contains("percent")
        // A cell formatted as a percentage in Excel is saved as a fraction, such as 0.63 for 63%.
        let fractions = percent && {
            let nums = table.rows.compactMap { Double(table.value($0, map[.result])) }
            return !nums.isEmpty && nums.allSatisfy { $0 >= 0 && $0 <= 1 } && nums.contains { $0 > 0 && $0 < 1 }
        }()
        var byKey: [String: Int] = [:]

        for row in table.rows {
            guard let sid = assigned[personID(row)] else {
                if !(displayName(row).isEmpty) { out.notOnRoll += 1 }
                continue
            }
            var raw = table.value(row, map[.result])
            if fractions, let f = Double(raw) { raw = String(f * 100) }
            var result = ResultsDraft.number(raw)
            guard !result.isEmpty else { out.noResult += 1; continue }
            if percent && Double(result) != nil { result += "%" }

            let date: String
            if map[.date] != nil {
                guard let d = ResultsDraft.isoDate(table.value(row, map[.date])) else { out.noDate += 1; continue }
                date = d
            } else {
                date = fixedDate
            }

            let subject = map[.subject] != nil ? (subjectFor[tidied(row, .subject)] ?? "") : fixedSubject
            guard !subject.isEmpty else { out.noSubject += 1; continue }

            var task = [tidied(row, .task), tidied(row, .detail)].filter { !$0.isEmpty }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                .joined(separator: ": ")
            if task.isEmpty { task = fixedTask.trimmingCharacters(in: .whitespaces) }
            if task.isEmpty { task = "Imported result" }
            let phase = table.value(row, map[.phase])
            if !phase.isEmpty { task += " (\(phase))" }

            let comment = map.notes.compactMap { c -> String? in
                let v = ResultsDraft.number(table.value(row, c))
                guard !v.isEmpty else { return nil }
                return ResultsDraft.label(table.header[c]) + " " + v
            }.joined(separator: " · ")

            let r: Row = ["student_id": sid, "date": date, "subject": subject, "task": task,
                          "result": result, "comment": comment]
            // A file with the same result twice keeps the last one.
            let k = ResultsDraft.key(r)
            if let i = byKey[k] { out.rows[i] = r } else { byKey[k] = out.rows.count; out.rows.append(r) }
        }
        return out
    }

    static func key(_ r: Row) -> String {
        [r.s("student_id"), r.s("subject"), r.s("task"), r.s("date")].joined(separator: "|")
    }

    /// "Assessment Achievement Level" reads as "Achievement Level".
    static func label(_ header: String) -> String {
        let h = header.trimmingCharacters(in: .whitespaces)
        if h.lowercased().hasPrefix("assessment "), h.count > 11 { return String(h.dropFirst(11)) }
        return h
    }

    /// Whole numbers without ".0", and long decimals from a spreadsheet rounded to two places.
    static func number(_ v: String) -> String {
        guard let d = Double(v), v.contains("."), d.isFinite, abs(d) < 1e12 else { return v }
        if d == d.rounded() { return String(Int(d)) }
        let s = String(format: "%.2f", d)
        return s.hasSuffix("0") ? String(s.dropLast()) : s
    }

    /// Dates as day first (Australian), ISO, or an Excel day number. Returns nil when unsure.
    static func isoDate(_ raw: String) -> String? {
        let v = raw.split(whereSeparator: { $0 == " " || $0 == "T" }).first.map(String.init) ?? raw
        if let n = Double(v), !v.contains("-"), !v.contains("/"), n > 20000, n < 80000 {
            // Excel counts days from 30 December 1899.
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            let base = c.date(from: DateComponents(year: 1899, month: 12, day: 30))!
            guard let d = c.date(byAdding: .day, value: Int(n), to: base) else { return nil }
            let p = c.dateComponents([.year, .month, .day], from: d)
            return Cal.make(p.year!, p.month!, p.day!)
        }
        let parts = v.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "." }).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var (y, m, d) = parts[0] > 31 ? (parts[0], parts[1], parts[2]) : (parts[2], parts[1], parts[0])
        if y < 100 { y += 2000 }
        guard (1...12).contains(m), (1...31).contains(d), (1990...2100).contains(y) else { return nil }
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        guard let date = c.date(from: DateComponents(year: y, month: m, day: d)),
              c.component(.day, from: date) == d else { return nil }
        return Cal.make(y, m, d)
    }

    /// A Holocron subject for a value of the subject column: the same name, else Maths for maths
    /// strands and Literacy or English for English strands. "" when nothing fits.
    static func guessSubject(_ value: String, subjects: [String]) -> String {
        let v = value.lowercased()
        if let same = subjects.first(where: { $0.lowercased() == v }) { return same }
        let maths = ["number", "algebra", "measurement", "space", "statistics", "probability", "geometry", "math", "numeracy"]
        let english = ["literacy", "literature", "language", "reading", "writing", "english", "spelling", "phonics", "grammar"]
        func find(_ words: [String]) -> String? {
            subjects.first { s in words.contains { s.lowercased().contains($0) } }
        }
        if maths.contains(where: v.contains), let s = find(["math", "numeracy"]) { return s }
        if english.contains(where: v.contains), let s = find(["literacy", "english", "reading"]) { return s }
        return ""
    }
}

// MARK: Comparing with what is saved

struct ResultsChanges {
    var added: [Row] = []
    /// Saved results the file has a different result or comment for, by row id.
    var updated: [String: Row] = [:]
    var unchanged = 0

    var isEmpty: Bool { added.isEmpty && updated.isEmpty }

    /// Results already saved for the same student, subject, task and date are updated rather than
    /// added again, so importing a newer export of the same tests is safe.
    init(_ incoming: [Row], existing: [Row]) {
        var saved: [String: Row] = [:]
        for r in existing { saved[ResultsDraft.key(r)] = saved[ResultsDraft.key(r)] ?? r }
        for var r in incoming {
            if let old = saved[ResultsDraft.key(r)] {
                // A saved row with no id (typed into the file by hand) cannot be updated safely,
                // so it is left as it is.
                if old.s("id").isEmpty { unchanged += 1; continue }
                r["comment"] = ResultsChanges.comment(old: old.s("comment"), imported: r.s("comment"))
                if old.s("result") == r.s("result") && old.s("comment") == r.s("comment") { unchanged += 1 }
                else { updated[old.s("id")] = r }
            } else {
                added.append(r)
            }
        }
    }
}

extension ResultsChanges {
    /// Keeps what the teacher typed in a saved comment. The imported part ("Achievement Level 3 ·
    /// Range 3-4") goes after it, and replaces the imported part from an earlier import.
    static func comment(old: String, imported: String) -> String {
        guard !imported.isEmpty else { return old }
        guard !old.isEmpty else { return imported }
        let first = imported.components(separatedBy: " · ")[0]
        let lead = first.lastIndex(of: " ").map { String(first[..<$0]) } ?? first
        if let r = old.range(of: lead) {
            let mine = old[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
            let kept = mine.hasSuffix("·") ? String(mine.dropLast()).trimmingCharacters(in: .whitespaces) : mine
            return kept.isEmpty ? imported : kept + " · " + imported
        }
        return old + " · " + imported
    }
}

extension Database {
    static let importRefPrefix = "import_ref:"

    /// Students picked by hand in earlier imports, by the file's student ID.
    var rememberedImportRefs: [String: String] {
        var out: [String: String] = [:]
        for (k, v) in index(.settings).settings where k.hasPrefix(Database.importRefPrefix) {
            out[String(k.dropFirst(Database.importRefPrefix.count))] = v
        }
        return out
    }

    /// `remember` gives the student picked for each of the file's student IDs. An empty student
    /// forgets an earlier pick.
    func applyResults(_ c: ResultsChanges, remember: [String: String]) {
        for r in c.added {
            var row = r
            row["id"] = uid()
            append(.assessments, row)
        }
        if !c.updated.isEmpty {
            update(.assessments, where: { c.updated[$0.s("id")] != nil }) { row in
                guard let new = c.updated[row.s("id")] else { return }
                row["result"] = new.s("result")
                row["comment"] = new.s("comment")
            }
        }
        touch(.assessments)
        let known = rememberedImportRefs
        var forgot = false
        for (ref, sid) in remember where known[ref] != (sid.isEmpty ? nil : sid) {
            if sid.isEmpty {
                remove(.settings, where: { $0.s("key") == Database.importRefPrefix + ref })
                forgot = true
            } else {
                setSetting(Database.importRefPrefix + ref, sid)
            }
        }
        if forgot { touch(.settings) }
    }
}
