import Foundation

// MARK: - To-do from plain speech
//
// "Remind me to print excursion forms Friday" becomes the text "Print excursion forms" and a due
// date. Dates are worked out here, in code, relative to today: Australian day-month order, weeks
// that start on Monday, and a bare "Friday" meaning the coming Friday. The language model is not
// used, so this works with Apple Intelligence off and nothing the teacher types leaves the app.

enum TodoParse {
    struct Result: Equatable {
        /// The to-do with the lead-in and the date words taken out, such as "Print excursion forms".
        var text: String
        /// The same wording with only the lead-in taken out, for when the teacher does not want the date.
        var keepingDate: String
        /// The due date as yyyy-mm-dd, when the text named one.
        var due: String?
    }

    /// With `strict`, a date is only taken when it is safe to do so without asking: a day or relative
    /// word must come last or follow by, on, due, before or until, so "Friday sports uniform letter"
    /// is left alone. Without a date, strict keeps the words exactly as typed, lead-in and all.
    static func parse(_ input: String, today: String = todayISO(), strict: Bool = false) -> Result {
        var s = input.trimmed
        let original = tidy(s)
        // Lead-ins such as "remind me to", "don't forget to".
        while let r = s.range(of: lead, options: [.regularExpression, .caseInsensitive]) {
            s = String(s[r.upperBound...])
        }
        let kept = tidy(s)
        guard let hit = lastDate(in: s, today: today, strict: strict) else {
            return Result(text: strict ? original : kept, keepingDate: strict ? original : kept, due: nil)
        }
        var rest = s
        rest.removeSubrange(hit.range)
        // "Print forms by" left behind after taking out "Friday".
        rest = rest.replacingOccurrences(of: #"(?:\s+(?:by|on|before|until|due|for|at|in|the))+\s*[.,;:!]*\s*$"#, with: "",
                                         options: [.regularExpression, .caseInsensitive])
        rest = rest.replacingOccurrences(of: #"^\s*(?:by|on|before|until|due|for)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        rest = rest.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        let text = tidy(rest)
        // If nothing is left, the date was all there was, so keep the words as typed.
        return Result(text: text.isEmpty ? kept : text, keepingDate: kept, due: hit.iso)
    }

    private static let lead = #"^(?:(?:please|can you|could you|todo:?|to do:?)\s+)?(?:remind me (?:to|about)|reminder (?:to|about)?|remember to|don'?t forget to|i (?:need|have|must|should) to|need to|have to|must)\s+"#

    /// A capital letter to start, and no spaces or stray punctuation at the ends.
    static func tidy(_ t: String) -> String {
        var s = t.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,;:-–—"))
        while s.hasSuffix(".") && !s.hasSuffix("..") { s.removeLast() }
        guard let f = s.first else { return "" }
        return f.uppercased() + s.dropFirst()
    }

    // MARK: Dates

    private struct Hit { var range: Range<String.Index>; var iso: String }

    private struct Context { var today: String; var mon: String; var idx: Int }

    /// One kind of date phrase. `absolute` ones name a calendar date and are safe anywhere in the text.
    private struct Rule {
        var re: NSRegularExpression
        var absolute: Bool
        /// Gets the words after the optional by/on/due lead (`prefixed` says if it was there).
        var make: ([String], _ prefixed: Bool, Context) -> String?
    }

    private static let weekdayWords: [(String, Int)] = [
        ("monday", 0), ("mon", 0), ("tuesday", 1), ("tues", 1), ("tue", 1),
        ("wednesday", 2), ("wed", 2), ("thursday", 3), ("thurs", 3), ("thur", 3), ("thu", 3),
        ("friday", 4), ("fri", 4), ("saturday", 5), ("sunday", 6),
    ]
    private static let monthWords: [(String, Int)] = [
        ("january", 1), ("jan", 1), ("february", 2), ("feb", 2), ("march", 3), ("mar", 3), ("april", 4), ("apr", 4),
        ("may", 5), ("june", 6), ("jun", 6), ("july", 7), ("jul", 7), ("august", 8), ("aug", 8),
        ("september", 9), ("sept", 9), ("sep", 9), ("october", 10), ("oct", 10), ("november", 11), ("nov", 11),
        ("december", 12), ("dec", 12),
    ]

    private static func alt(_ words: [(String, Int)]) -> String { words.map(\.0).joined(separator: "|") }
    private static func weekday(_ w: String) -> Int? { weekdayWords.first { $0.0 == w.lowercased() }?.1 }
    private static func month(_ w: String) -> Int? { monthWords.first { $0.0 == w.lowercased() }?.1 }

    /// Group 1 of every rule: "by", "on", "due" and so on, with an optional "the".
    private static let prefix = #"(\b(?:by|on|before|until|due|for)\s+(?:the\s+)?)?"#

    /// "may" is a verb too ("mark 5 may essays"), so it is only the month when written May or after by, on or due.
    private static func monthNumber(_ word: String, prefixed: Bool) -> Int? {
        if word.lowercased() == "may" && word != "May" && !prefixed { return nil }
        return month(word)
    }

    // Compiled once.
    private static let rules: [Rule] = {
        var r: [Rule] = []
        func add(_ pattern: String, absolute: Bool = false, _ make: @escaping ([String], Bool, Context) -> String?) {
            guard let re = try? NSRegularExpression(pattern: prefix + pattern, options: [.caseInsensitive]) else { return }
            r.append(Rule(re: re, absolute: absolute, make: make))
        }
        add(#"\b(?:the\s+)?day after tomorrow\b"#) { _, _, c in addDays(c.today, 2) }
        add(#"\b(?:tomorrow|tmrw|tomorow)\b"#) { _, _, c in addDays(c.today, 1) }
        add(#"\b(?:today|tonight|this (?:morning|afternoon|evening|arvo))\b"#) { _, _, c in c.today }
        add(#"\bend of (?:the |this )?week\b"#) { _, _, c in c.idx <= 4 ? addDays(c.mon, 4) : addDays(c.mon, 11) }
        add(#"\bnext week\b"#) { _, _, c in addDays(c.mon, 7) }
        add(#"\bin (\d{1,3}|a|one|two|three|four|five|six|seven|eight|nine|ten)\s+(day|days|week|weeks)\b"#) { g, _, c in
            let words = ["a": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
            guard let n = Int(g[0]) ?? words[g[0].lowercased()] else { return nil }
            return addDays(c.today, g[1].lowercased().hasPrefix("week") ? n * 7 : n)
        }
        // A day of the week. A bare "Friday" is the coming one, never today. "This Friday" can be today.
        // "Next Friday" is Friday of next week, with weeks starting on Monday.
        add(#"(?:\b(this|next|coming|the coming)\s+)?\b("# + alt(weekdayWords) + #")\b"#) { g, _, c in
            guard let d = weekday(g[1]) else { return nil }
            switch g[0].lowercased() {
            case "next": return addDays(c.mon, 7 + d)
            case "this": return d >= c.idx ? addDays(c.mon, d) : addDays(c.mon, 7 + d)
            default: return addDays(c.today, ((d - c.idx + 6) % 7) + 1)
            }
        }
        // 13/10/2026 or 13/10/26, day first. A year is needed, or by, on, due, before or until in front,
        // so "Year 5/6 camp" and "3/4 fractions" are never dates.
        add(#"\b(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b"#, absolute: true) { g, prefixed, c in
            guard let d = Int(g[0]), let m = Int(g[1]) else { return nil }
            if g[2].isEmpty && !prefixed { return nil }
            return resolve(day: d, month: m, year: Int(g[2]), today: c.today)
        }
        // 13 Oct, 13th of October 2026.
        add(#"\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?("# + alt(monthWords) + #")\b\.?(?:,?\s*(\d{4}))?"#, absolute: true) { g, prefixed, c in
            guard let d = Int(g[0]), let m = monthNumber(g[1], prefixed: prefixed) else { return nil }
            return resolve(day: d, month: m, year: Int(g[2]), today: c.today)
        }
        // Oct 13, October 13th 2026.
        add(#"\b("# + alt(monthWords) + #")\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b(?:,?\s*(\d{4}))?"#, absolute: true) { g, prefixed, c in
            guard let m = monthNumber(g[0], prefixed: prefixed), let d = Int(g[1]) else { return nil }
            return resolve(day: d, month: m, year: Int(g[2]), today: c.today)
        }
        return r
    }()

    /// The date phrase nearest the end of the text, as people usually say the day last.
    private static func lastDate(in s: String, today: String, strict: Bool) -> Hit? {
        let ns = s as NSString
        let ctx = Context(today: today, mon: mondayOf(today), idx: dayIdx(today))
        var hits: [Hit] = []
        for rule in rules {
            for m in rule.re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                guard let r = Range(m.range, in: s) else { continue }
                var groups: [String] = []
                for i in 2..<max(m.numberOfRanges, 2) {
                    groups.append(m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i)))
                }
                let prefixed = m.range(at: 1).location != NSNotFound
                if strict && !rule.absolute && !prefixed {
                    let after = s[r.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " \t.,;:!?"))
                    if !after.isEmpty { continue }
                }
                if let iso = rule.make(groups, prefixed, ctx) { hits.append(Hit(range: r, iso: iso)) }
            }
        }
        // The nearest the end wins. A longer phrase beats one inside it, such as "next Friday" over "Friday".
        return hits.max { a, b in
            let ea = s.distance(from: s.startIndex, to: a.range.upperBound), eb = s.distance(from: s.startIndex, to: b.range.upperBound)
            if ea != eb { return ea < eb }
            return s.distance(from: a.range.lowerBound, to: a.range.upperBound) < s.distance(from: b.range.lowerBound, to: b.range.upperBound)
        }
    }

    /// A date for a day and month. Without a year it is the next time that day comes round, today included.
    private static func resolve(day: Int, month: Int, year: Int?, today: String) -> String? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        func valid(_ y: Int) -> String? {
            let n = Cal.daysFromCivil(y, month, day)
            let (yy, mm, dd) = Cal.civilFromDays(n)
            return (yy, mm, dd) == (y, month, day) ? Cal.make(y, month, day) : nil
        }
        if var y = year {
            if y < 100 { y += 2000 }
            return valid(y)
        }
        let ty = Cal.parts(today)?.0 ?? 1970
        if let a = valid(ty), a >= today { return a }
        return valid(ty + 1)
    }
}
