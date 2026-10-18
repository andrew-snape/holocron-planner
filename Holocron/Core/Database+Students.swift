import Foundation

struct TimelineItem: Identifiable {
    /// Built from the row's own id, so a row keeps its identity from one redraw to the next.
    var id: String
    var date: String
    var kind: String        // assess, plan, well, beh, les
    var head: String
    var badge: String
    var body: String
    var sub: String
}

struct ActivityItem: Identifiable {
    var id: String
    var date: String
    var who: String
    var kind: String
    var text: String
}

struct BirthdayItem: Identifiable {
    var id: String { name + date }
    var name: String
    var date: String
    var days: Int
}

struct PackRange: Identifiable {
    var id: String
    var label: String
    var from: String
    var to: String
}

struct PackData {
    var plan: [Row]
    var well: [Row]
    var beh: [Row]
    var lessonsBySubject: [(subject: String, notes: [Row])]
    var lessonCount: Int
    var assessments: [Row]
}

extension Database {
    // MARK: Students

    func addStudent(first: String, surname: String) -> String {
        let id = uid()
        append(.students, Student(id: id, first: first, surname: surname).asRow)
        touch(.students)
        return id
    }

    func updateStudent(_ s: Student) {
        update(.students, where: { $0.s("id") == s.id }) { row in
            for (k, v) in s.asRow { row[k] = v }
        }
        touch(.students)
    }

    /// Removes a student and every note attached to them.
    func removeStudent(_ id: String) {
        remove(.students, where: { $0.s("id") == id })
        let logs: [TableName] = [.assessments, .plannotes, .wellbeing, .behaviour, .lessonnotes, .reportjudge, .reportcomment]
        for t in logs { remove(t, where: { $0.s("student_id") == id }) }
        touch(Set([.students] + logs))
    }

    func deleteRow(_ t: TableName, id: String) {
        remove(t, where: { $0.s("id") == id })
        touch(t)
    }

    // MARK: Logs

    func addLessonNote(students ids: [String], subject: String, note: String) {
        let d = todayISO(), t = nowHHMM()
        for sid in ids {
            append(.lessonnotes, ["id": uid(), "student_id": sid, "date": d, "time": t, "subject": subject, "note": note])
        }
        touch(.lessonnotes)
    }

    func addWellbeing(students ids: [String], date: String, periodLost: String, minutes: Int, note: String) {
        for sid in ids {
            append(.wellbeing, ["id": uid(), "student_id": sid, "date": date, "period_lost": periodLost,
                                "minutes": String(minutes), "note": note])
        }
        touch(.wellbeing)
    }

    func addBehaviour(students ids: [String], date: String, note: String) {
        for sid in ids {
            append(.behaviour, ["id": uid(), "student_id": sid, "date": date, "note": note])
        }
        touch(.behaviour)
    }

    func addPlanNote(student sid: String, date: String, type: String, note: String) {
        append(.plannotes, ["id": uid(), "student_id": sid, "date": date, "type": type, "note": note])
        touch(.plannotes)
    }

    func addAssessment(student sid: String, date: String, subject: String, task: String, result: String, comment: String) {
        append(.assessments, ["id": uid(), "student_id": sid, "date": date, "subject": subject,
                              "task": task, "result": result, "comment": comment])
        touch(.assessments)
    }

    /// One student's rows from a log table, newest first.
    func logRows(_ t: TableName, student sid: String) -> [Row] {
        rows(t).filter { $0.s("student_id") == sid }
            .sorted { ($0.s("date") + $0.s("time")) > ($1.s("date") + $1.s("time")) }
    }

    /// How many things have been logged today against each student, for the Quick log badges.
    func todaysEntryCounts() -> [String: Int] {
        let d = todayISO()
        var out: [String: Int] = [:]
        for t in [TableName.lessonnotes, .wellbeing, .behaviour] {
            for x in rows(t) where x.s("date") == d { out[x.s("student_id"), default: 0] += 1 }
        }
        return out
    }

    /// Everything logged against a student today, newest first.
    func todaysEntries(_ sid: String) -> [(time: String, kind: String, note: String)] {
        let d = todayISO()
        var out: [(time: String, kind: String, note: String)] = []
        for x in rows(.lessonnotes) where x.s("student_id") == sid && x.s("date") == d {
            out.append((x.s("time"), (x.s("subject").isEmpty ? "Lesson" : x.s("subject")) + " note", x.s("note")))
        }
        for x in rows(.wellbeing) where x.s("student_id") == sid && x.s("date") == d {
            out.append(("", "Wellbeing", x.s("note")))
        }
        for x in rows(.behaviour) where x.s("student_id") == sid && x.s("date") == d {
            out.append(("", "Behaviour", x.s("note")))
        }
        return out.sorted { $0.time > $1.time }
    }

    func recentActivity(limit: Int = 5) -> [ActivityItem] {
        var all: [ActivityItem] = []
        var n = 0
        func nid(_ k: String, _ x: Row) -> String { n += 1; return "\(k)-\(x.s("id"))-\(n)" }
        for x in rows(.wellbeing) { all.append(ActivityItem(id: nid("well", x), date: x.s("date"), who: x.s("student_id"), kind: "Wellbeing", text: x.s("note"))) }
        for x in rows(.behaviour) { all.append(ActivityItem(id: nid("beh", x), date: x.s("date"), who: x.s("student_id"), kind: "Behaviour", text: x.s("note"))) }
        for x in rows(.lessonnotes) {
            all.append(ActivityItem(id: nid("les", x), date: x.s("date"), who: x.s("student_id"),
                                    kind: (x.s("subject").isEmpty ? "Lesson" : x.s("subject")) + " note", text: x.s("note")))
        }
        for x in rows(.plannotes) {
            all.append(ActivityItem(id: nid("plan", x), date: x.s("date"), who: x.s("student_id"),
                                    kind: x.s("type").isEmpty ? "Plan note" : x.s("type"), text: x.s("note")))
        }
        for x in rows(.assessments) {
            all.append(ActivityItem(id: nid("assess", x), date: x.s("date"), who: x.s("student_id"), kind: "Assessment",
                                    text: x.s("task") + " · " + x.s("result")))
        }
        return Array(all.filter { !$0.date.isEmpty }.sorted { $0.date > $1.date }.prefix(limit))
    }

    /// "20 min · lost Period 2" for a wellbeing row.
    func wellbeingDetail(_ x: Row) -> String {
        var bits: [String] = []
        if let m = Int(x.s("minutes")), m > 0 { bits.append("\(m) min") }
        if let n = Int(x.s("period_lost")), let p = period(n) { bits.append("lost " + p.name) }
        return bits.joined(separator: " · ")
    }

    // MARK: Timeline (one page per student)

    func timeline(_ id: String) -> [TimelineItem] {
        var out: [TimelineItem] = []
        var n = 0
        func nid(_ k: String, _ x: Row) -> String { n += 1; return "\(k)-\(x.s("id"))-\(n)" }
        for x in rows(.assessments) where x.s("student_id") == id {
            out.append(TimelineItem(id: nid("assess", x), date: x.s("date"), kind: "assess",
                                    head: (x.s("subject").isEmpty ? "" : x.s("subject") + ": ") + x.s("task"),
                                    badge: x.s("result"), body: x.s("comment"), sub: ""))
        }
        for x in rows(.plannotes) where x.s("student_id") == id {
            out.append(TimelineItem(id: nid("plan", x), date: x.s("date"), kind: "plan", head: x.s("type").isEmpty ? "Plan note" : x.s("type"),
                                    badge: "", body: x.s("note"), sub: ""))
        }
        for x in rows(.wellbeing) where x.s("student_id") == id {
            out.append(TimelineItem(id: nid("well", x), date: x.s("date"), kind: "well", head: "Wellbeing", badge: "",
                                    body: x.s("note"), sub: wellbeingDetail(x)))
        }
        for x in rows(.behaviour) where x.s("student_id") == id {
            out.append(TimelineItem(id: nid("beh", x), date: x.s("date"), kind: "beh", head: "Behaviour", badge: "", body: x.s("note"), sub: ""))
        }
        for x in rows(.lessonnotes) where x.s("student_id") == id {
            out.append(TimelineItem(id: nid("les", x), date: x.s("date"), kind: "les",
                                    head: (x.s("subject").isEmpty ? "Lesson" : x.s("subject")) + " note",
                                    badge: "", body: x.s("note"), sub: fmtTime(x.s("time"))))
        }
        return out.sorted { $0.date > $1.date }
    }

    func timelineText(_ id: String) -> String {
        guard let s = student(id) else { return "" }
        var L = [s.fullName, className + " · " + s.house]
        if !s.adjustments.isEmpty { L += ["", "Adjustments: " + s.adjustments] }
        if !s.nccd.isEmpty { L.append("NCCD: " + s.nccd) }
        if !s.medical.isEmpty { L.append("Medical: " + s.medical) }
        L.append("")
        for i in timeline(id) {
            L.append(dLong(i.date) + "  " + i.head + (i.badge.isEmpty ? "" : "  [" + i.badge + "]"))
            if !i.body.isEmpty { L.append("    " + i.body) }
            if !i.sub.isEmpty { L.append("    " + i.sub) }
        }
        return L.joined(separator: "\n")
    }

    // MARK: Birthdays

    func upcomingBirthdays(_ days: Int) -> [BirthdayItem] {
        let today = todayISO()
        let y = yearOf(today)
        guard let t0 = Cal.dayNumber(today) else { return [] }
        var out: [BirthdayItem] = []
        for s in students {
            guard let (_, m, d) = Cal.parts(s.birthdate) else { continue }
            for yr in [y, y + 1] {
                let n = Cal.daysFromCivil(yr, m, d)
                let diff = n - t0
                if diff >= 0 && diff <= days {
                    out.append(BirthdayItem(name: s.fullName, date: Cal.fromDayNumber(n), days: diff))
                    break
                }
            }
        }
        return out.sorted { $0.days < $1.days }
    }

    // MARK: To do

    func addTodo(text: String, due: String) {
        append(.todo, ["id": uid(), "text": text, "due": due, "done": "", "created": todayISO()])
        touch(.todo)
    }

    func setTodoDone(_ id: String, done: Bool) {
        update(.todo, where: { $0.s("id") == id }) { $0["done"] = done ? todayISO() : "" }
        touch(.todo)
    }

    func openTodos() -> [Row] {
        let t = todayISO()
        func key(_ x: Row) -> String {
            let due = x.s("due")
            if due.isEmpty { return "1" }
            return due <= t ? "0" + due : "2" + due
        }
        return rows(.todo).filter { $0.s("done").isEmpty }.sorted {
            let a = key($0), b = key($1)
            return a != b ? a < b : $0.s("created") < $1.s("created")
        }
    }

    func doneTodayTodos() -> [Row] {
        let t = todayISO()
        return rows(.todo).filter { $0.s("done") == t }
    }

    // MARK: SSG and report pack

    func packRanges() -> [PackRange] {
        let t = todayISO(), y = String(yearOf(t))
        let ts = terms.filter { $0.year == y }.sorted { $0.start < $1.start }
        let cur = termOf(t) ?? ts.last(where: { $0.start <= t }) ?? ts.first
        var r: [PackRange] = [PackRange(id: "10w", label: "Last 10 weeks", from: addDays(t, -70), to: t)]
        if let c = cur { r.append(PackRange(id: "term", label: "Term " + c.term, from: c.start, to: c.end < t ? c.end : t)) }
        let s1 = ts.filter { (Int($0.term) ?? 0) <= 2 }
        let s2 = ts.filter { (Int($0.term) ?? 0) >= 3 }
        let useS2 = cur.map { (Int($0.term) ?? 0) >= 3 } ?? false
        let sem = useS2 ? s2 : s1
        if let f = sem.first, let l = sem.last {
            r.append(PackRange(id: "sem", label: "Semester " + (useS2 ? "2" : "1"), from: f.start, to: l.end < t ? l.end : t))
        }
        if let f = ts.first { r.append(PackRange(id: "year", label: "This year", from: f.start, to: t)) }
        return r
    }

    func packData(_ sid: String, from: String, to: String) -> PackData {
        func inRange(_ x: Row) -> Bool { x.s("student_id") == sid && x.s("date") >= from && x.s("date") <= to }
        func by(_ a: Row, _ b: Row) -> Bool { (a.s("date") + a.s("time")) < (b.s("date") + b.s("time")) }
        let ln = rows(.lessonnotes).filter(inRange).sorted(by: by)
        var groups: [String: [Row]] = [:]
        for x in ln { groups[x.s("subject").isEmpty ? "Other" : x.s("subject"), default: []].append(x) }
        let grouped = groups.keys.sorted().map { (subject: $0, notes: groups[$0] ?? []) }
        return PackData(plan: rows(.plannotes).filter(inRange).sorted(by: by),
                        well: rows(.wellbeing).filter(inRange).sorted(by: by),
                        beh: rows(.behaviour).filter(inRange).sorted(by: by),
                        lessonsBySubject: grouped, lessonCount: ln.count,
                        assessments: rows(.assessments).filter(inRange).sorted(by: by))
    }

    func packText(_ s: Student, from: String, to: String, data P: PackData, leaveOutMedical: Bool) -> String {
        var L = [s.fullName + ", " + className, dLong(from) + " to " + dLong(to), ""]
        if !s.adjustments.isEmpty { L += ["CURRENT ADJUSTMENTS", s.adjustments, ""] }
        if !s.nccd.isEmpty { L += ["NCCD: " + s.nccd, ""] }
        if !s.medical.isEmpty && !leaveOutMedical { L += ["Medical: " + s.medical, ""] }
        func block(_ title: String, _ rows: [Row], _ f: (Row) -> String) {
            L.append(title.uppercased())
            if rows.isEmpty { L.append("Nothing recorded.") }
            for r in rows { L.append(f(r)) }
            L.append("")
        }
        block("ILP and NCCD notes", P.plan) { dLong($0.s("date")) + "  " + $0.s("type") + ": " + $0.s("note") }
        block("Wellbeing", P.well) {
            dLong($0.s("date")) + "  " + $0.s("note") + ((Int($0.s("minutes")) ?? 0) > 0 ? " (" + $0.s("minutes") + " min)" : "")
        }
        block("Behaviour", P.beh) { dLong($0.s("date")) + "  " + $0.s("note") }
        L.append("LESSON NOTES")
        if P.lessonCount == 0 { L.append("Nothing recorded.") }
        for g in P.lessonsBySubject {
            L.append(g.subject)
            for x in g.notes { L.append("  " + dLong(x.s("date")) + "  " + x.s("note")) }
        }
        L.append("")
        block("Assessments", P.assessments) {
            dLong($0.s("date")) + "  " + $0.s("subject") + ": " + $0.s("task") + "  " + $0.s("result")
                + ($0.s("comment").isEmpty ? "" : "  " + $0.s("comment"))
        }
        return L.joined(separator: "\n").trimmed
    }

    // MARK: Reports

    /// Semester 2 starts in July. Before that the report is for semester 1.
    static let semesterTwoStartMonth = 7

    func reportSem() -> String {
        let t = todayISO()
        let month = Cal.parts(t)?.1 ?? 1
        return String(t.prefix(4)) + (month >= Database.semesterTwoStartMonth ? "-S2" : "-S1")
    }

    var reportSubjects: [String] {
        var seen = Set<String>()
        return subjects.filter { s in
            s.kind == "teach" && !["Devotion", "Incursion/Excursion"].contains(s.subject) && seen.insert(s.subject).inserted
        }.map { $0.subject }
    }

    func judgement(_ sid: String, sem: String, subject: String) -> (achievement: String, engagement: String) {
        let r = rows(.reportjudge).first { $0.s("student_id") == sid && $0.s("sem") == sem && $0.s("subject") == subject }
        return (r?.s("achievement") ?? "", r?.s("engagement") ?? "")
    }

    func setJudgement(_ sid: String, sem: String, subject: String, field: String, value: String) {
        let match: (Row) -> Bool = { $0.s("student_id") == sid && $0.s("sem") == sem && $0.s("subject") == subject }
        if rows(.reportjudge).contains(where: match) {
            update(.reportjudge, where: match) { $0[field] = value }
        } else {
            var r: Row = ["id": uid(), "student_id": sid, "sem": sem, "subject": subject, "achievement": "", "engagement": ""]
            r[field] = value
            append(.reportjudge, r)
        }
        touch(.reportjudge)
    }

    func generalComment(_ sid: String, sem: String) -> String {
        rows(.reportcomment).first(where: { $0.s("student_id") == sid && $0.s("sem") == sem })?.s("general") ?? ""
    }

    func setGeneralComment(_ sid: String, sem: String, text: String) {
        let match: (Row) -> Bool = { $0.s("student_id") == sid && $0.s("sem") == sem }
        if rows(.reportcomment).contains(where: match) {
            update(.reportcomment, where: match) { $0["general"] = text }
        } else {
            append(.reportcomment, ["id": uid(), "student_id": sid, "sem": sem, "general": text])
        }
        touch(.reportcomment)
    }
}

func wordCount(_ t: String) -> Int {
    t.split(whereSeparator: { $0.isWhitespace }).count
}
