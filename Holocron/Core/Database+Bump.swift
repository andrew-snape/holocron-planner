import Foundation

// MARK: - Bump lessons (push forward, pull back)
//
// Push a lesson, and every later lesson for the same subject, forward one lesson. Or pull them
// back into an empty slot. Only lessons.csv changes. Slots are found with `plannedSubject`,
// skipping weekends, non-teaching days and camp-type days.

struct BumpChange {
    var date: String
    var per: Int
    var subject: String
    var from: LessonContent
    var to: LessonContent
}

struct BumpPlan {
    var subject: String
    var changes: [BumpChange]
    var lost: Int
}

struct BumpSummary {
    var subject: String
    var moved: Int
    var lastDate: String
    var lastPer: Int
    var lost: Int
}

extension Database {
    func canBump(_ subject: String) -> Bool {
        !subject.isEmpty && subjectInfo(subject).kind == "teach" && !Lists.noBump.contains(subject)
    }

    /// Every later slot for this subject, after (date, period), up to the end of the last term.
    func slotsAfter(_ subject: String, _ date: String, _ per: Int) -> [(date: String, per: Int)] {
        let last = terms.map { $0.end }.max() ?? date
        let ps = periods
        var out: [(date: String, per: Int)] = []
        for d in Cal.dates(from: date, through: last) where runsNormally(d) {
            for p in ps {
                if d == date && p.period <= per { continue }
                if plannedSubject(d, p.period) == subject { out.append((d, p.period)) }
            }
        }
        return out
    }

    /// `starts` are this subject's slots being emptied, in order. Returns the changes to make.
    func planPush(_ subject: String, _ starts: [(date: String, per: Int)]) -> BumpPlan {
        guard let lastStart = starts.last else { return BumpPlan(subject: subject, changes: [], lost: 0) }
        let fut = slotsAfter(subject, lastStart.date, lastStart.per)
        let seq = starts.map { content($0.date, $0.per) } + fut.map { content($0.date, $0.per) }
        let lost = seq.suffix(from: fut.count).filter { !$0.isEmpty }.count
        var ch: [BumpChange] = []
        for s in starts {
            ch.append(BumpChange(date: s.date, per: s.per, subject: subject, from: content(s.date, s.per), to: LessonContent()))
        }
        for (i, s) in fut.enumerated() {
            ch.append(BumpChange(date: s.date, per: s.per, subject: subject, from: content(s.date, s.per), to: seq[i]))
        }
        return BumpPlan(subject: subject, changes: ch.filter { $0.from != $0.to }, lost: lost)
    }

    func planPull(_ subject: String, _ date: String, _ per: Int) -> BumpPlan {
        let fut = slotsAfter(subject, date, per)
        let all: [(date: String, per: Int)] = [(date, per)] + fut
        let seq = fut.map { content($0.date, $0.per) }
        var ch: [BumpChange] = []
        for (i, s) in all.enumerated() {
            ch.append(BumpChange(date: s.date, per: s.per, subject: subject, from: content(s.date, s.per),
                                 to: i < seq.count ? seq[i] : LessonContent()))
        }
        return BumpPlan(subject: subject, changes: ch.filter { $0.from != $0.to }, lost: 0)
    }

    /// Applies the plans and returns a snapshot of lessons.csv so the move can be undone.
    func applyBump(_ plans: [BumpPlan]) -> [Row] {
        let snap = rows(.lessons)
        putContents(plans.flatMap { $0.changes }.map { (date: $0.date, per: $0.per, subject: $0.subject, content: $0.to) })
        touch(.lessons)
        return snap
    }

    func undoBump(_ snapshot: [Row]) {
        setRows(.lessons, snapshot)
        touch(.lessons)
    }

    func bumpSummary(_ plans: [BumpPlan]) -> [BumpSummary] {
        plans.compactMap { pl in
            let filled = pl.changes.filter { !$0.to.isEmpty }
            let last = filled.last
            let s = BumpSummary(subject: pl.subject, moved: filled.count,
                                lastDate: last?.date ?? "", lastPer: last?.per ?? 0, lost: pl.lost)
            return (s.moved > 0 || s.lost > 0) ? s : nil
        }
    }

    /// A whole day lost (camp, carnival, excursion): push each subject's lessons on it forward.
    func dayBumpPlans(_ date: String) -> [BumpPlan] {
        var bySub: [String: [(date: String, per: Int)]] = [:]
        var order: [String] = []
        for p in periods {
            let s = plannedSubject(date, p.period)
            if canBump(s) && !content(date, p.period).isEmpty {
                if bySub[s] == nil { order.append(s) }
                bySub[s, default: []].append((date, p.period))
            }
        }
        return order.map { planPush($0, bySub[$0] ?? []) }
    }
}
