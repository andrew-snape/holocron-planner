import Foundation

// MARK: - What Siri and Shortcuts say
//
// Short spoken answers worked out from the planner. They only read data.

extension Database {
    /// The lessons on a day in order, leaving out empty periods. Empty when the day does not run normally.
    func lessonsOn(_ date: String) -> [(period: Period, subject: String)] {
        guard runsNormally(date) else { return [] }
        return periods.compactMap { p in
            let s = plannedSubject(date, p.period)
            return s.isEmpty ? nil : (p, s)
        }
    }

    /// Why a day has no lessons, such as "a pupil free day" or "the weekend". nil on a normal school day.
    func noLessonsReason(_ date: String) -> String? {
        if dayIdx(date) >= 5 { return "it's the weekend" }
        if termsSorted.isEmpty { return "no terms are set up in Holocron yet" }
        if termOf(date) == nil { return "it's the holidays" }
        if isNonTeaching(date) {
            let label = nonTeachingLabel(date).trimmed
            return label.isEmpty ? "it's a non-teaching day" : "it's \(label)"
        }
        if let ov = overrideOf(date), ov.s("type") != "Normal" {
            let note = ov.s("note").trimmed
            var kind = ov.s("type").lowercased()
            if !kind.hasSuffix("day") { kind += " day" }
            let article = "aeiou".contains(kind.prefix(1)) ? "an" : "a"
            return "it's \(article) \(kind)" + (note.isEmpty ? "" : " (\(note))")
        }
        return nil
    }

    /// "Maths now until 10:10 am, then Literacy at 10:10 am."
    func nowAndNext(date: String, minutes now: Int) -> String {
        if let why = noLessonsReason(date) { return "No lessons today, because \(why)." }
        let list = lessonsOn(date)
        guard !list.isEmpty else { return "There are no lessons planned today." }
        let current = list.first { (hm($0.period.start) ?? 0) <= now && now < (hm($0.period.end) ?? 0) }
        let next = list.first { (hm($0.period.start) ?? 0) > now }
        var parts: [String] = []
        if let c = current { parts.append("\(c.subject) now, until \(fmtTime(c.period.end))") }
        if let n = next {
            let lead = current != nil ? "then " : (n.period.period == list.first?.period.period ? "first up, " : "next, ")
            parts.append("\(lead)\(n.subject) at \(fmtTime(n.period.start))")
        }
        if parts.isEmpty { return "That's all for today. The last lesson was \(list.last!.subject)." }
        let s = parts.joined(separator: ", ")
        return s.prefix(1).uppercased() + s.dropFirst() + "."
    }

    /// "Monday, week 3A: Devotion at 8:50 am, Maths at 9:10 am and Literacy at 11:30 am."
    func dayOutline(_ date: String) -> String {
        let head = dayHeading(date)
        if let why = noLessonsReason(date) { return "\(head): no lessons, because \(why)." }
        let list = lessonsOn(date)
        guard !list.isEmpty else { return "\(head): no lessons planned." }
        return "\(head): " + spokenList(list.map { "\($0.subject) at \(fmtTime($0.period.start))" }) + "."
    }

    private func dayHeading(_ date: String) -> String {
        var h = longDate(date)
        if let w = termWeek(date), let l = weekLetter(date) { h += ", week \(w)\(l)" }
        return h
    }

    /// When a subject is on for the rest of the school week, from `date`.
    func whenIs(_ subject: String, from date: String, minutes now: Int) -> String {
        let subject = subjects.first { $0.subject.caseInsensitiveCompare(subject) == .orderedSame }?.subject ?? subject
        let monday = mondayOf(date)
        // This week, else the first of the next two weeks it is on (B week subjects, or a Friday afternoon).
        for week in 0..<3 {
            var times: [String] = []
            for i in 0..<5 {
                let d = addDays(monday, week * 7 + i)
                guard d >= date else { continue }
                let starts = lessonsOn(d).filter { $0.subject == subject && !(d == date && (hm($0.period.end) ?? 0) <= now) }
                    .map { fmtTime($0.period.start) }
                guard !starts.isEmpty else { continue }
                let day = d == date ? "today" : d == addDays(date, 1) ? "tomorrow"
                    : week == 0 ? weekdayName(d) : week == 1 ? "next \(weekdayName(d))" : "\(weekdayName(d)) \(shortDate(d))"
                times.append("\(day) at " + spokenList(starts))
                if week > 0 { break }
            }
            if !times.isEmpty {
                return "\(subject) is on " + spokenList(times) + "."
            }
        }
        return "\(subject) isn't on in the next two weeks."
    }

    /// Birthdays in the next week. Names are left out when `names` is false.
    func birthdaysAnswer(names: Bool) -> String {
        let list = upcomingBirthdays(7)
        guard !list.isEmpty else { return "No birthdays in the next week." }
        guard names else { return "\(list.count) birthday\(list.count == 1 ? "" : "s") in the next week." }
        return spokenList(list.map { b in
            "\(b.name) " + (b.days == 0 ? "today" : b.days == 1 ? "tomorrow" : b.days >= 7 ? "next \(weekdayName(b.date))" : "on \(weekdayName(b.date))")
        }) + "."
    }
}

func weekdayName(_ iso: String) -> String { Cal.weekdayLong[dayIdx(iso)] }

/// "a, b and c"
func spokenList(_ items: [String]) -> String {
    switch items.count {
    case 0: return ""
    case 1: return items[0]
    default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }
}
