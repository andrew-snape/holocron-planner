import Foundation

// MARK: - Face to face, release and DOTTL

extension Database {
    struct Minutes {
        var teach = 0
        var release = 0
        var days = 0
    }

    /// Minutes taught on one date, by kind.
    func dayMinutes(_ date: String) -> Minutes {
        var out = Minutes()
        guard isSchoolDay(date) else { return out }
        if let ov = overrideOf(date), ov.s("type") != "Normal" { return out }
        for p in periods {
            let s = plannedSubject(date, p.period)
            if s.isEmpty { continue }
            let k = subjectInfo(s).kind
            if k == "release" { out.release += p.minutes }
            else if k == "teach" { out.teach += p.minutes }
        }
        return out
    }

    func rangeMinutes(_ from: String, _ to: String) -> Minutes {
        var o = Minutes()
        guard !from.isEmpty, !to.isEmpty, from <= to else { return o }
        for d in Cal.dates(from: from, through: to) {
            let m = dayMinutes(d)
            if m.teach + m.release > 0 {
                o.teach += m.teach
                o.release += m.release
                o.days += 1
            }
        }
        return o
    }

    /// One full A + B cycle straight from the timetable.
    func fortnightMinutes() -> (teach: Int, release: Int) {
        var teach = 0, rel = 0
        for wk in ["A", "B"] {
            for d in 0..<5 {
                for p in periods {
                    let s = slotSubject(week: wk, day: d, per: p.period)
                    if s.isEmpty { continue }
                    let k = subjectInfo(s).kind
                    if k == "release" { rel += p.minutes }
                    else if k == "teach" { teach += p.minutes }
                }
            }
        }
        return (teach, rel)
    }

    /// DOTTL minutes by type between two dates. Wellbeing entries on students count too.
    func dottlMinutes(_ from: String, _ to: String) -> [String: Int] {
        var by: [String: Int] = [:]
        for r in rows(.dottl) where r.s("date") >= from && r.s("date") <= to {
            by[r.s("type"), default: 0] += Int(r.s("minutes")) ?? 0
        }
        for r in rows(.wellbeing) where r.s("date") >= from && r.s("date") <= to {
            by["Wellbeing", default: 0] += Int(r.s("minutes")) ?? 0
        }
        return by
    }

    func addDottl(date: String, type: String, minutes: Int, note: String) {
        append(.dottl, ["id": uid(), "date": date, "type": type, "minutes": String(minutes), "note": note])
        touch(.dottl)
    }
}
