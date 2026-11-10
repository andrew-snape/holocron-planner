import Foundation

/// The class markbook: one subject's results as a grid, students down and tasks across.
/// Foundation only, so it can be tested on its own (see scripts/test-core.sh).
enum Markbook {
    /// How a result reads, for colour. Results are plain text, so this is worked out from the words or the score.
    enum Band: Int, CaseIterable {
        case top, strong, middle, developing, low, modified

        /// The colour the cell is drawn from (through `Tone`).
        var hex: String {
            switch self {
            case .top: return "#34C759"
            case .strong: return "#30B0C7"
            case .middle: return "#007AFF"
            case .developing: return "#FF9500"
            case .low: return "#FF3B30"
            case .modified: return "#8E8E93"
            }
        }
    }

    private static let levelPercent: [String: (Double, Band)] = [
        "extending": (100, .top), "mastering": (80, .strong), "consolidating": (60, .middle),
        "developing": (40, .developing), "emerging": (20, .low),
        "working beyond": (100, .top), "at standard": (67, .middle), "working towards": (33, .developing)
    ]

    /// A result as a number from 0 to 100, or nil when it has no number ("Modified", a word, a blank).
    /// Achievement levels count as 20 to 100, and a score such as 18/20 or 85% as its percentage.
    static func percent(_ result: String) -> Double? {
        let t = result.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return nil }
        if let l = levelPercent[t] { return l.0 }
        if t.hasSuffix("%"), let v = Double(t.dropLast().trimmingCharacters(in: .whitespaces)) { return min(max(v, 0), 100) }
        let parts = t.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2,
           let a = Double(parts[0].trimmingCharacters(in: .whitespaces)),
           let b = Double(parts[1].trimmingCharacters(in: .whitespaces)), b > 0 {
            return min(max(a / b * 100, 0), 100)
        }
        return nil
    }

    /// The band for a result's colour, or nil when there is nothing to colour.
    static func band(_ result: String) -> Band? {
        let t = result.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return nil }
        if t == "modified" { return .modified }
        if let l = levelPercent[t] { return l.1 }
        guard let p = percent(result) else { return nil }
        switch p {
        case 85...: return .top
        case 70...: return .strong
        case 55...: return .middle
        case 40...: return .developing
        default: return .low
        }
    }

    struct TaskColumn: Hashable, Identifiable {
        var subject: String
        var task: String
        var date: String
        var id: String { date + "|" + task }
    }

    /// A pre-test and post-test of the same thing, found from the words "pre" and "post" in the task names.
    struct Pair: Hashable, Identifiable {
        var base: String
        var pre: TaskColumn
        var post: TaskColumn
        var id: String { base + "|" + pre.id + "|" + post.id }
    }

    struct Line: Identifiable {
        var id: String          // student id
        var results: [String: String]   // task column id to result
    }

    struct Grid {
        var subject: String
        var tasks: [TaskColumn]
        var lines: [Line]
        var pairs: [Pair]
    }

    /// Results for one subject. Students come in the order given. A task is one name on one date.
    static func build(assessments: [Row], students: [String], subject: String) -> Grid {
        var tasks: [TaskColumn] = []
        var seen = Set<String>()
        var byStudent: [String: [String: String]] = [:]
        for a in assessments where a.s("subject") == subject && !a.s("task").isEmpty {
            let col = TaskColumn(subject: subject, task: a.s("task"), date: a.s("date"))
            if seen.insert(col.id).inserted { tasks.append(col) }
            let r = a.s("result").trimmingCharacters(in: .whitespaces)
            if !r.isEmpty { byStudent[a.s("student_id"), default: [:]][col.id] = r }
        }
        tasks.sort { ($0.date, $0.task) < ($1.date, $1.task) }
        let lines = students.map { Line(id: $0, results: byStudent[$0] ?? [:]) }
        return Grid(subject: subject, tasks: tasks, lines: lines, pairs: pairs(in: tasks))
    }

    /// The tokens of a task name that say what it is about, without the pre or post words.
    private static func core(_ task: String) -> (base: String, isPre: Bool, isPost: Bool) {
        let words = task.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        var pre = false, post = false
        var rest: [String] = []
        for w in words {
            switch w {
            case "pre", "pretest", "preassessment": pre = true
            case "post", "posttest", "postassessment": post = true
            case "test", "assessment", "check", "task": break
            default: rest.append(w)
            }
        }
        return (rest.joined(separator: " "), pre && !post, post && !pre)
    }

    static func pairs(in tasks: [TaskColumn]) -> [Pair] {
        var pres: [String: TaskColumn] = [:]
        var out: [Pair] = []
        for t in tasks {
            let c = core(t.task)
            if c.isPre { pres[c.base] = t }
            else if c.isPost, let p = pres[c.base] {
                out.append(Pair(base: c.base, pre: p, post: t))
                pres[c.base] = nil
            }
        }
        return out
    }

    /// Growth from the pre-test to the post-test, in percentage points, or nil when either has no number.
    static func growth(_ pair: Pair, _ line: Line) -> Double? {
        guard let a = percent(line.results[pair.pre.id] ?? ""), let b = percent(line.results[pair.post.id] ?? "") else { return nil }
        return b - a
    }

    /// The average of a student's numbered results, or nil when there are none.
    static func average(_ line: Line, tasks: [TaskColumn]) -> Double? {
        let v = tasks.compactMap { percent(line.results[$0.id] ?? "") }
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    /// "+22 points" or "-5 points".
    static func growthText(_ g: Double) -> String {
        let n = Int(g.rounded())
        return (n > 0 ? "+" : "") + "\(n) points"
    }

    /// The grid as CSV: a Student column, a column for each task, and a growth column for each pair.
    /// `names` gives each student id's name for the first column.
    static func csv(_ grid: Grid, names: [String: String]) -> Data {
        func title(_ t: TaskColumn) -> String { t.date.isEmpty ? t.task : "\(t.task) (\(t.date))" }
        var header = ["Student"] + grid.tasks.map(title)
        header += grid.pairs.map { "Growth: " + $0.base }
        var rows: [Row] = []
        for l in grid.lines {
            var r: Row = ["Student": names[l.id] ?? ""]
            for t in grid.tasks { r[title(t)] = l.results[t.id] ?? "" }
            for p in grid.pairs { r["Growth: " + p.base] = growth(p, l).map(growthText) ?? "" }
            rows.append(r)
        }
        return CSV.writeData(header: header, rows: rows)
    }

    /// Names of students with no result for a task.
    static func missing(_ grid: Grid, task: TaskColumn) -> [String] {
        grid.lines.filter { ($0.results[task.id] ?? "").isEmpty }.map(\.id)
    }

    /// One point on a student's growth chart.
    struct Point: Identifiable {
        var id: String
        var date: String
        var subject: String
        var task: String
        var percent: Double
    }

    /// A student's numbered results in date order, for the chart on their Assessment tab.
    static func points(assessments: [Row], student: String) -> [Point] {
        assessments.filter { $0.s("student_id") == student && !$0.s("subject").isEmpty }
            .compactMap { a -> Point? in
                guard let p = percent(a.s("result")) else { return nil }
                return Point(id: a.s("id").isEmpty ? a.s("date") + a.s("task") : a.s("id"), date: a.s("date"),
                             subject: a.s("subject"), task: a.s("task"), percent: p)
            }
            .sorted { ($0.date, $0.task) < ($1.date, $1.task) }
    }
}
