import Foundation

/// One lesson as the Today and Class screens show it. Back-to-back periods of the same subject, with no break
/// between, are joined into one, so a double TDL shows as one lesson from 9:30 to 11:00.
/// The first period holds the plan and the Class screen steps; each period keeps its own rows in the files.
struct LessonRun: Equatable, Identifiable {
    var subject: String
    var periods: [Period]
    var id: Int { lead.period }
    var lead: Period { periods[0] }
    var start: String { periods[0].start }
    var end: String { periods[periods.count - 1].end }
    var isJoined: Bool { periods.count > 1 }
    /// "Period 1", "Period 1 and Period 2" or "Period 1, Period 2 and Period 3". Always in English.
    var name: String {
        let names = periods.map(\.name)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
    var minutes: Int { periods.reduce(0) { $0 + $1.minutes } }
    func contains(_ per: Int) -> Bool { periods.contains { $0.period == per } }
}

extension Database {
    /// Every period of the day, with back-to-back periods of the same subject joined. Unset periods are never joined.
    func dayRuns(_ date: String) -> [LessonRun] {
        var out: [LessonRun] = []
        for p in periods {
            let s = plannedSubject(date, p.period)
            if !s.isEmpty, let last = out.last, last.subject == s, let e = hm(last.end), e == hm(p.start) {
                out[out.count - 1].periods.append(p)
            } else {
                out.append(LessonRun(subject: s, periods: [p]))
            }
        }
        return out
    }

    /// The day's lessons for the Class screen: joined as on Today, without unset periods or DOTTL time.
    func classRuns(_ date: String) -> [LessonRun] {
        dayRuns(date).filter { !$0.subject.isEmpty && subjectInfo($0.subject).kind != "dottl" }
    }

    /// The first period of the joined lesson that holds `per`, or `per` itself.
    func classLead(_ date: String, _ per: Int) -> Int {
        classRuns(date).first { $0.contains(per) }?.lead.period ?? per
    }

    /// The period whose plan a joined lesson shows: the first with anything written, or the first period.
    func planPeriod(_ date: String, _ run: LessonRun) -> Int {
        run.periods.first { !content(date, $0.period).isEmpty }?.period ?? run.lead.period
    }

    /// What a joined lesson shows: the first period's plan, or the next period's when the first is empty.
    func classContent(_ date: String, _ run: LessonRun) -> LessonContent {
        content(date, planPeriod(date, run))
    }
}
