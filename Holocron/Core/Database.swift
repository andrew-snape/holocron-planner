import Foundation
import Observation

/// One counter per table. Reading it inside a view registers a dependency on that table alone.
@Observable
final class TableStamp {
    var n = 0
}

// MARK: - Small typed views over CSV rows

struct Period: Identifiable, Equatable {
    var period: Int
    var name: String
    var start: String
    var end: String
    var id: Int { period }
    var minutes: Int { mins(start, end) }
}

struct SubjectInfo: Equatable {
    var subject: String
    var kind: String          // "teach", "release" or "dottl"
    var colour: String
    var isRelease: Bool { kind == "release" }
}

struct Term: Identifiable, Equatable {
    var year: String
    var term: String
    var start: String
    var end: String
    var id: String { year + "|" + term }
}

struct Student: Identifiable, Equatable {
    var id: String
    var first: String
    var surname: String
    var birthdate: String
    var parents: String
    var house: String
    var roles: String
    var adjustments: String
    var nccd: String
    var medical: String
    var notes: String
    var fullName: String { surname.isEmpty ? first : first + " " + surname }

    init(row: Row) {
        id = row.s("id"); first = row.s("first"); surname = row.s("surname")
        birthdate = row.s("birthdate"); parents = row.s("parents"); house = row.s("house")
        roles = row.s("roles"); adjustments = row.s("adjustments"); nccd = row.s("nccd")
        medical = row.s("medical"); notes = row.s("notes")
    }

    init(id: String, first: String, surname: String) {
        self.id = id; self.first = first; self.surname = surname
        birthdate = ""; parents = ""; house = ""; roles = ""; adjustments = ""; nccd = ""; medical = ""; notes = ""
    }

    var asRow: Row {
        ["id": id, "first": first, "surname": surname, "birthdate": birthdate, "parents": parents,
         "house": house, "roles": roles, "adjustments": adjustments, "nccd": nccd, "medical": medical, "notes": notes]
    }
}

enum PlanStatus { case plan, summary, empty }

/// Everything a lesson holds: the short summary shown on Today and Week, plus the optional fuller plan.
struct LessonContent: Equatable {
    var summary = ""
    var li = ""
    var sc = ""
    var tuning = ""
    var teaching = ""
    var independent = ""
    var reflection = ""
    var resources = ""
    var codes = ""
    var atl = ""
    var profile = ""

    static let planFields = ["li", "sc", "tuning", "teaching", "independent", "reflection", "resources", "codes", "atl", "profile"]
    static let allFields = ["summary"] + planFields

    init() {}

    init(row: Row?) {
        guard let r = row else { return }
        for f in LessonContent.allFields { self[f] = r.s(f) }
    }

    subscript(_ f: String) -> String {
        get {
            switch f {
            case "summary": return summary
            case "li": return li
            case "sc": return sc
            case "tuning": return tuning
            case "teaching": return teaching
            case "independent": return independent
            case "reflection": return reflection
            case "resources": return resources
            case "codes": return codes
            case "atl": return atl
            case "profile": return profile
            default: return ""
            }
        }
        set {
            switch f {
            case "summary": summary = newValue
            case "li": li = newValue
            case "sc": sc = newValue
            case "tuning": tuning = newValue
            case "teaching": teaching = newValue
            case "independent": independent = newValue
            case "reflection": reflection = newValue
            case "resources": resources = newValue
            case "codes": codes = newValue
            case "atl": atl = newValue
            case "profile": profile = newValue
            default: break
            }
        }
    }

    var isEmpty: Bool {
        LessonContent.allFields.allSatisfy { self[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasPlan: Bool {
        LessonContent.planFields.contains { !self[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var status: PlanStatus {
        if hasPlan { return .plan }
        return summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .summary
    }
}

func linesOf(_ t: String) -> [String] {
    t.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

func listOf(_ t: String) -> [String] {
    t.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

// MARK: - The database

/// All of the planner's data, held as rows exactly as they sit in the CSV files.
/// Every screen reads from here and every change goes through here, so the logic
/// matches the web app: `plannedSubject` is the single source of truth for what is on.
///
/// Screens are told about changes one table at a time. Every read goes through `watch`, which makes
/// SwiftUI remember "this view looked at the lessons table", and every change bumps that table's
/// stamp. So typing in a lesson summary redraws the views that show lessons, and leaves the
/// sidebar calendar, the Students screen and the rest alone.
final class Database {
    private(set) var tables: [String: [Row]] = [:]
    private(set) var headers: [String: [String]] = [:]

    private let stamps: [TableName: TableStamp]

    /// Called whenever something changes, with the files that need saving.
    var persistHandler: ((Set<TableName>) -> Void)?

    init() {
        var s: [TableName: TableStamp] = [:]
        for t in TableName.allCases {
            tables[t.rawValue] = []
            headers[t.rawValue] = t.header
            s[t] = TableStamp()
        }
        stamps = s
    }

    /// Registers a read of a table, so the view doing the reading redraws when the table changes.
    @inline(__always)
    func watch(_ t: TableName) { _ = stamps[t]?.n }

    private func changed(_ t: TableName) {
        cachedIndex = nil
        stamps[t]?.n &+= 1
    }

    func rows(_ t: TableName) -> [Row] {
        watch(t)
        return tables[t.rawValue] ?? []
    }

    func setRows(_ t: TableName, _ rows: [Row]) {
        tables[t.rawValue] = rows
        changed(t)
    }

    func header(_ t: TableName) -> [String] { headers[t.rawValue] ?? t.header }

    /// Replace a table with what was read from disk. The header keeps any extra columns found.
    func load(_ t: TableName, header: [String], rows: [Row]) {
        var h = t.header
        for c in header where !c.isEmpty && !h.contains(c) { h.append(c) }
        headers[t.rawValue] = h
        tables[t.rawValue] = rows
        changed(t)
    }

    func touch(_ names: TableName...) { persistHandler?(Set(names)) }
    func touch(_ names: Set<TableName>) { persistHandler?(names) }

    func append(_ t: TableName, _ row: Row) {
        tables[t.rawValue, default: []].append(row)
        changed(t)
    }

    /// Changes matching rows. The array is taken out of the dictionary while it is edited, so it is
    /// uniquely held and Swift edits it where it sits instead of copying the whole table first.
    func update(_ t: TableName, where match: (Row) -> Bool, _ change: (inout Row) -> Void) {
        let key = t.rawValue
        guard var list = tables.removeValue(forKey: key) else { return }
        for i in list.indices where match(list[i]) { change(&list[i]) }
        tables[key] = list
        changed(t)
    }

    func remove(_ t: TableName, where match: (Row) -> Bool) {
        tables[t.rawValue]?.removeAll(where: match)
        changed(t)
    }

    // MARK: Lookup index
    //
    // Screens ask the same questions again and again (what is on in period 3 on this date, which
    // colour is Maths, who is this student). Answering each from a scan of the raw rows made the
    // Week, Term and Hours screens do thousands of string comparisons per redraw. The index holds
    // dictionaries and sorted lists built once, on first use after a change, and thrown away
    // whenever a table changes. It always keeps the first matching row, as the scans did.

    private var cachedIndex: Index?

    /// The lookup index, after registering a read of `t`. Always name the table the answer comes from.
    func index(_ t: TableName) -> Index {
        watch(t)
        if let i = cachedIndex { return i }
        let i = Index(tables: tables)
        cachedIndex = i
        return i
    }

    struct SlotKey: Hashable { var date: String; var per: Int }
    struct TimetableKey: Hashable { var week: String; var day: Int; var per: Int }

    final class Index {
        private let tables: [String: [Row]]
        init(tables: [String: [Row]]) { self.tables = tables }

        private func rows(_ t: TableName) -> [Row] { tables[t.rawValue] ?? [] }

        lazy var periods: [Period] = rows(.periods).compactMap { r in
            guard let n = Int(r.s("period")) else { return nil }
            return Period(period: n, name: r.s("name"), start: r.s("start"), end: r.s("end"))
        }.sorted { $0.period < $1.period }

        lazy var periodByNumber: [Int: Period] =
            Dictionary(periods.map { ($0.period, $0) }, uniquingKeysWith: { first, _ in first })

        lazy var subjects: [SubjectInfo] = rows(.subjects).map {
            SubjectInfo(subject: $0.s("subject"), kind: $0.s("kind"), colour: $0.s("colour"))
        }

        lazy var subjectByName: [String: SubjectInfo] =
            Dictionary(subjects.map { ($0.subject, $0) }, uniquingKeysWith: { first, _ in first })

        /// Colour maths (contrast search) done once per subject until the subjects change.
        private var toneCache: [String: Tone] = [:]
        func tone(forSubject name: String, colour: String) -> Tone {
            if let t = toneCache[name] { return t }
            let t = ToneMaths.tone(hex: colour)
            toneCache[name] = t
            return t
        }

        lazy var terms: [Term] = rows(.terms).map {
            Term(year: $0.s("year"), term: $0.s("term"), start: $0.s("start"), end: $0.s("end"))
        }

        lazy var termsSorted: [Term] = terms.sorted { $0.start < $1.start }

        lazy var nonTeachingLabels: [String: String] =
            Dictionary(rows(.nonteaching).map { ($0.s("date"), $0.s("label")) }, uniquingKeysWith: { first, _ in first })

        lazy var overrides: [String: Row] =
            Dictionary(rows(.dayoverrides).map { ($0.s("date"), $0) }, uniquingKeysWith: { first, _ in first })

        lazy var dayPlan: [SlotKey: String] = {
            var d: [SlotKey: String] = [:]
            for r in rows(.dayplan) {
                guard let p = Int(r.s("period")) else { continue }
                let k = SlotKey(date: r.s("date"), per: p)
                if d[k] == nil { d[k] = r.s("subject") }
            }
            return d
        }()

        lazy var timetable: [TimetableKey: String] = {
            var d: [TimetableKey: String] = [:]
            for r in rows(.timetable) {
                guard let day = Int(r.s("day")), let p = Int(r.s("period")) else { continue }
                let k = TimetableKey(week: r.s("week"), day: day, per: p)
                if d[k] == nil { d[k] = r.s("subject") }
            }
            return d
        }()

        lazy var lessons: [SlotKey: Row] = {
            var d: [SlotKey: Row] = [:]
            for r in rows(.lessons) {
                guard let p = Int(r.s("period")) else { continue }
                let k = SlotKey(date: r.s("date"), per: p)
                if d[k] == nil { d[k] = r }
            }
            return d
        }()

        lazy var students: [Student] = rows(.students).map { Student(row: $0) }

        lazy var roster: [Student] = students.sorted {
            $0.first.localizedCaseInsensitiveCompare($1.first) == .orderedAscending
        }

        lazy var studentByID: [String: Student] =
            Dictionary(students.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Lookups

    var periods: [Period] { index(.periods).periods }

    func period(_ n: Int) -> Period? { index(.periods).periodByNumber[n] }

    var subjects: [SubjectInfo] { index(.subjects).subjects }

    func subjectInfo(_ name: String) -> SubjectInfo {
        index(.subjects).subjectByName[name] ?? SubjectInfo(subject: name, kind: "teach", colour: "#8A8F94")
    }

    func tone(forSubject name: String) -> Tone {
        let ix = index(.subjects)
        let colour = ix.subjectByName[name]?.colour ?? "#8A8F94"
        return ix.tone(forSubject: name, colour: colour)
    }

    var terms: [Term] { index(.terms).terms }

    var termsSorted: [Term] { index(.terms).termsSorted }

    // MARK: Students

    var students: [Student] { index(.students).students }

    var roster: [Student] { index(.students).roster }

    func student(_ id: String) -> Student? { index(.students).studentByID[id] }

    func studentName(_ id: String) -> String {
        student(id)?.fullName ?? "Unknown"
    }
}
