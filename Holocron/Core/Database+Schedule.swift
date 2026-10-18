import Foundation

// MARK: - Terms, weeks, days

extension Database {
    func termOf(_ date: String) -> Term? {
        index(.terms).terms.first { date >= $0.start && date <= $0.end }
    }

    /// Term week number, 1-based. Week 1 is always Week A, so odd weeks are A and even weeks are B.
    func termWeek(_ date: String) -> Int? {
        guard let t = termOf(date) else { return nil }
        let m0 = Cal.mondayNumber(t.start) ?? 0
        let m = Cal.mondayNumber(date) ?? 0
        return Int((Double(m - m0) / 7).rounded()) + 1
    }

    func weekLetter(_ date: String) -> String? {
        guard let w = termWeek(date) else { return nil }
        return w % 2 == 1 ? "A" : "B"
    }

    func isNonTeaching(_ date: String) -> Bool {
        index(.nonteaching).nonTeachingLabels[date] != nil
    }

    func nonTeachingLabel(_ date: String) -> String {
        index(.nonteaching).nonTeachingLabels[date] ?? ""
    }

    func overrideOf(_ date: String) -> Row? {
        index(.dayoverrides).overrides[date]
    }

    func isSchoolDay(_ date: String) -> Bool {
        dayIdx(date) < 5 && termOf(date) != nil && !isNonTeaching(date)
    }

    /// A school day where the timetable runs as normal (no camp, carnival and so on).
    func runsNormally(_ date: String) -> Bool {
        let ov = overrideOf(date)
        return isSchoolDay(date) && (ov == nil || ov?.s("type") == "Normal")
    }

    // MARK: Timetable

    func slotSubject(week: String, day: Int, per: Int) -> String {
        index(.timetable).timetable[TimetableKey(week: week, day: day, per: per)] ?? ""
    }

    func setSlot(week: String, day: Int, per: Int, subject: String) {
        var found = false
        update(.timetable, where: {
            $0.s("week") == week && Int($0.s("day")) == day && Int($0.s("period")) == per
        }) { $0["subject"] = subject; found = true }
        if !found {
            append(.timetable, ["week": week, "day": String(day), "period": String(per), "subject": subject])
        }
        touch(.timetable)
    }

    /// What is actually on for a date and period. A row in dayplan.csv overrides the fortnight template.
    func plannedSubject(_ date: String, _ per: Int, fallbackWeek: String? = nil) -> String {
        if let o = index(.dayplan).dayPlan[SlotKey(date: date, per: per)] { return o }
        guard let wk = weekLetter(date) ?? fallbackWeek, !wk.isEmpty else { return "" }
        return slotSubject(week: wk, day: dayIdx(date), per: per)
    }

    func isMoved(_ date: String, _ per: Int) -> Bool {
        index(.dayplan).dayPlan[SlotKey(date: date, per: per)] != nil
    }

    /// Sets a one-off for a date (without saving). Setting it back to the template deletes the row.
    func setDayPlan(_ date: String, _ per: Int, _ subject: String) {
        let wk = weekLetter(date)
        let base = wk.map { slotSubject(week: $0, day: dayIdx(date), per: per) } ?? ""
        if subject == base {
            clearDayPlanQuiet(date, per)
        } else if isMoved(date, per) {
            update(.dayplan, where: { $0.s("date") == date && Int($0.s("period")) == per }) { $0["subject"] = subject }
        } else {
            append(.dayplan, ["date": date, "period": String(per), "subject": subject])
        }
    }

    func clearDayPlanQuiet(_ date: String, _ per: Int) {
        remove(.dayplan, where: { $0.s("date") == date && Int($0.s("period")) == per })
    }

    func clearDayPlan(_ date: String, _ per: Int) {
        clearDayPlanQuiet(date, per)
        touch(.dayplan)
    }

    /// Change one slot for this date only. The lesson row follows, so its subject matches.
    func changeSubjectOnce(date: String, per: Int, subject: String) {
        setDayPlan(date, per, subject)
        syncLessonSubject(date, per, subject)
        touch(.dayplan)
    }

    /// Change one slot in the standing timetable, every cycle from now on.
    func changeSubjectStanding(date: String, per: Int, subject: String) {
        let wk = weekLetter(date) ?? "A"
        setSlot(week: wk, day: dayIdx(date), per: per, subject: subject)
        clearDayPlanQuiet(date, per)
        syncLessonSubject(date, per, subject)
        touch(.dayplan)
    }

    private func syncLessonSubject(_ date: String, _ per: Int, _ subject: String) {
        if lessonRow(date, per) != nil {
            update(.lessons, where: { $0.s("date") == date && Int($0.s("period")) == per }) { $0["subject"] = subject }
            touch(.lessons)
        }
    }

    /// Swap two sessions on real dates, carrying the lesson plans with them.
    func swapDates(_ d1: String, _ p1: Int, _ d2: String, _ p2: Int) {
        let s1 = plannedSubject(d1, p1), s2 = plannedSubject(d2, p2)
        let c1 = content(d1, p1), c2 = content(d2, p2)
        setDayPlan(d1, p1, s2)
        setDayPlan(d2, p2, s1)
        putContent(d1, p1, s2, c2)
        putContent(d2, p2, s1, c1)
        touch(.dayplan, .lessons)
    }

    /// Swap two slots in the fortnight template, so it sticks every cycle.
    func swapTemplate(_ w1: String, _ day1: Int, _ p1: Int, _ w2: String, _ day2: Int, _ p2: Int) {
        let s1 = slotSubject(week: w1, day: day1, per: p1)
        let s2 = slotSubject(week: w2, day: day2, per: p2)
        setSlot(week: w1, day: day1, per: p1, subject: s2)
        setSlot(week: w2, day: day2, per: p2, subject: s1)
    }

    // MARK: Lessons

    func lessonRow(_ date: String, _ per: Int) -> Row? {
        index(.lessons).lessons[SlotKey(date: date, per: per)]
    }

    func content(_ date: String, _ per: Int) -> LessonContent {
        LessonContent(row: lessonRow(date, per))
    }

    /// Writes a lesson without saving. An all-empty lesson removes its row.
    func putContent(_ date: String, _ per: Int, _ subject: String, _ c: LessonContent) {
        let exists = lessonRow(date, per) != nil
        if c.isEmpty {
            if exists { remove(.lessons, where: { $0.s("date") == date && Int($0.s("period")) == per }) }
            return
        }
        if exists {
            update(.lessons, where: { $0.s("date") == date && Int($0.s("period")) == per }) { row in
                row["subject"] = subject
                for f in LessonContent.allFields { row[f] = c[f] }
            }
        } else {
            var row: Row = ["date": date, "period": String(per), "subject": subject]
            for f in LessonContent.allFields { row[f] = c[f] }
            append(.lessons, row)
        }
    }

    /// Writes many lessons in one pass, for moves that touch a whole run of lessons. Doing them one at a
    /// time rebuilt the lesson lookup after every change. Does not save; the caller touches `.lessons`.
    func putContents(_ items: [(date: String, per: Int, subject: String, content: LessonContent)]) {
        guard !items.isEmpty else { return }
        var list = tables[TableName.lessons.rawValue] ?? []
        var at: [SlotKey: [Int]] = [:]
        for (i, r) in list.enumerated() {
            if let p = Int(r.s("period")) { at[SlotKey(date: r.s("date"), per: p), default: []].append(i) }
        }
        var dropped = Set<Int>()
        for item in items {
            let key = SlotKey(date: item.date, per: item.per)
            if item.content.isEmpty {
                for i in at[key] ?? [] { dropped.insert(i) }
                at[key] = nil
            } else if let spots = at[key] {
                for i in spots {
                    list[i]["subject"] = item.subject
                    for f in LessonContent.allFields { list[i][f] = item.content[f] }
                }
            } else {
                var row: Row = ["date": item.date, "period": String(item.per), "subject": item.subject]
                for f in LessonContent.allFields { row[f] = item.content[f] }
                list.append(row)
                at[key] = [list.count - 1]
            }
        }
        if !dropped.isEmpty {
            list = list.enumerated().filter { !dropped.contains($0.offset) }.map { $0.element }
        }
        setRows(.lessons, list)
    }

    func setContent(_ date: String, _ per: Int, _ subject: String, _ c: LessonContent) {
        putContent(date, per, subject, c)
        touch(.lessons)
    }

    // MARK: Renaming a subject

    /// Renames a subject in every table that refers to it by name. Does not touch the private
    /// subject setting or the lessons held aside for other folders; `AppModel.renameSubject` does those.
    func renameSubject(from old: String, to new: String) {
        guard old != new else { return }
        var changedTables = Set<TableName>()
        for t in [TableName.subjects, .timetable, .dayplan, .lessons, .assessments, .lessonnotes, .reportjudge] {
            var hit = false
            update(t, where: { $0.s("subject") == old }) { $0["subject"] = new; hit = true }
            if hit { changedTables.insert(t) }
        }
        touch(changedTables)
    }

    /// Only the summary changes; any fuller plan on the lesson is kept.
    func setSummary(_ date: String, _ per: Int, _ subject: String, _ text: String) {
        var c = content(date, per)
        c.summary = text
        setContent(date, per, subject, c)
    }

    // MARK: Day types

    func setDayType(_ date: String, type: String, note: String) {
        let ex = overrideOf(date)
        if type == "Normal" && note.isEmpty {
            if ex != nil { remove(.dayoverrides, where: { $0.s("date") == date }) }
        } else if ex != nil {
            update(.dayoverrides, where: { $0.s("date") == date }) { $0["type"] = type; $0["note"] = note }
        } else {
            append(.dayoverrides, ["date": date, "type": type, "note": note])
        }
        touch(.dayoverrides)
    }

    // MARK: Units

    func unitOn(_ date: String) -> Row? {
        rows(.units).first { !$0.s("start").isEmpty && !$0.s("end").isEmpty && date >= $0.s("start") && date <= $0.s("end") }
    }

    var unitsSorted: [Row] {
        rows(.units).sorted { $0.s("start") < $1.s("start") }
    }

    struct UnitStats {
        var atl: [String: Int] = [:]
        var lp: [String: Int] = [:]
        var tdl = 0
        var planned = 0
    }

    func unitStats(_ u: Row) -> UnitStats {
        var s = UnitStats()
        let start = u.s("start"), end = u.s("end")
        for l in rows(.lessons) where l.s("date") >= start && l.s("date") <= end {
            for x in listOf(l.s("atl")) { s.atl[x, default: 0] += 1 }
            for x in listOf(l.s("profile")) { s.lp[x, default: 0] += 1 }
        }
        guard !start.isEmpty, !end.isEmpty, start <= end else { return s }
        let ps = periods
        for d in Cal.dates(from: start, through: end) where runsNormally(d) {
            for p in ps where plannedSubject(d, p.period) == "TDL" {
                s.tdl += 1
                if !content(d, p.period).isEmpty { s.planned += 1 }
            }
        }
        return s
    }
}
