import Foundation

/// One place Jump (Cmd+K) can go to.
struct JumpResult: Identifiable, Hashable {
    enum Target: Hashable {
        case screen(NavItem)
        case student(String)
        case unit(String)
        case lesson(date: String, per: Int)
    }

    var target: Target
    var title: String
    var detail: String
    var symbol: String

    var id: String {
        switch target {
        case .screen(let n): return "screen-" + n.rawValue
        case .student(let i): return "student-" + i
        case .unit(let i): return "unit-" + i
        case .lesson(let d, let p): return "lesson-\(d)-\(p)"
        }
    }
}

/// Finds students, screens, units and lessons from a few typed letters, worked out in code from rows
/// already in memory. Nothing is indexed or saved. Every typed word has to start a word in the thing
/// it finds, so "mat thu" finds Thursday's Maths.
enum JumpSearch {
    /// Lower case words, split at anything that is not a letter or a number.
    static func words(_ s: String) -> [String] {
        s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// True when every typed word starts one of the words in the text.
    static func matches(_ query: [String], _ text: [String]) -> Bool {
        !query.isEmpty && query.allSatisfy { q in text.contains { $0.hasPrefix(q) } }
    }

    /// `screens` are the screens that are switched on. When `includeStudents` is false (a Class screen could be
    /// showing), only screens are found, because names can turn up in any free text.
    static func results(_ typed: String, db: Database, screens: [NavItem], includeStudents: Bool,
                        today: String, lessonLimit: Int = 6) -> [JumpResult] {
        let q = words(typed)
        func screenResult(_ n: NavItem) -> JumpResult {
            JumpResult(target: .screen(n), title: n.title, detail: n.group.rawValue, symbol: n.symbol)
        }
        if q.isEmpty { return screens.map(screenResult) }

        var out: [JumpResult] = []
        for n in screens where matches(q, words(n.title)) { out.append(screenResult(n)) }

        if includeStudents && screens.contains(.students) {
            for s in db.roster where matches(q, words(s.fullName + " " + s.house)) {
                out.append(JumpResult(target: .student(s.id), title: s.fullName,
                                      detail: s.house.isEmpty ? "Student" : "Student · " + s.house, symbol: "person"))
            }
        }

        // Unit titles and lesson summaries are free text, so they are left out too while names are hidden.
        if includeStudents && screens.contains(.units) {
            for u in db.unitsSorted where matches(q, words(u.s("title") + " " + u.s("theme") + " " + u.s("central_idea"))) {
                out.append(JumpResult(target: .unit(u.s("id")), title: u.s("title"),
                                      detail: u.s("theme").isEmpty ? "Unit of inquiry" : u.s("theme"),
                                      symbol: "globe.asia.australia"))
            }
        }

        if includeStudents && screens.contains(.week) {
            var found: [(gap: Int, result: JumpResult)] = []
            for x in db.rows(.lessons) {
                let date = x.s("date")
                guard Cal.parts(date) != nil, let per = Int(x.s("period")) else { continue }
                let di = dayIdx(date)
                let day = (0..<Cal.weekdayLong.count).contains(di) ? Cal.weekdayLong[di] : ""
                let text = words(x.s("subject") + " " + day + " " + dLong(date) + " " + x.s("summary"))
                guard matches(q, text) else { continue }
                let summary = x.s("summary").trimmed
                let title = x.s("subject") + (summary.isEmpty ? "" : ": " + String(summary.prefix(60)))
                let detail = (day.isEmpty ? "" : day + " ") + shortDate(date) + " · " + (db.period(per)?.name ?? "Period \(per)")
                found.append((abs(daysBetween(today, date)),
                              JumpResult(target: .lesson(date: date, per: per), title: title, detail: detail, symbol: "calendar")))
            }
            // The lessons nearest to today first.
            out += found.sorted { $0.gap < $1.gap }.prefix(lessonLimit).map { $0.result }
        }
        return out
    }
}
