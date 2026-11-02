import Foundation
import FoundationModels

// MARK: - Drafting report comments
//
// Gathers what Holocron knows about one student for a semester and asks the on-device model for a
// comment in the teacher's own voice, learnt from their earlier comments, following the house
// style below and any rules the teacher adds in Settings. It is always a draft: nothing is saved
// until the teacher chooses Use.
//
// Left out on purpose: wellbeing, behaviour, medical notes, adjustments and plan notes (ILP, SSG,
// NCCD), so a draft can never mention a condition or a meeting. A student with an ILP gets the
// teacher's ILP sentence added by Holocron, never written by the model.

enum Pronoun: String, CaseIterable, Identifiable {
    case she, he, they
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var words: String {
        switch self {
        case .she: return "she and her"
        case .he: return "he and his"
        case .they: return "they and their"
        }
    }
}

/// The comments a report holds. English and Maths are dot points under fixed headings.
enum ReportComment: String, CaseIterable, Identifiable {
    case general, english, maths
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General comment"
        case .english: return "English comment"
        case .maths: return "Mathematics comment"
        }
    }

    /// Whether a Holocron subject feeds this comment.
    func covers(_ subject: String) -> Bool {
        let s = subject.lowercased()
        switch self {
        case .general: return true
        case .english: return ["english", "literacy", "reading", "writing", "spelling", "grammar", "phonics"].contains { s.contains($0) }
        case .maths: return ["math", "numeracy", "number"].contains { s.contains($0) }
        }
    }
}

extension Database {
    static let reportRulesKey = "report_rules"
    static let ilpSentenceKey = "ilp_sentence"
    static let defaultILPSentence = "Please also refer to information on [name]'s Individual Learning Plan regarding current learning goals, adjustments and progress."
    /// The longest rules the on-device model can take alongside a student's notes.
    static let reportRulesLimit = 1200

    /// The teacher's own rules for report comments, from Settings.
    var reportRules: String { setting(Database.reportRulesKey) ?? "" }
    func setReportRules(_ t: String) { setSetting(Database.reportRulesKey, String(t.prefix(Database.reportRulesLimit))) }

    /// The sentence added to the end of the general comment for students with an ILP. Empty adds nothing.
    var ilpSentence: String { setting(Database.ilpSentenceKey) ?? Database.defaultILPSentence }
    func setILPSentence(_ t: String) { setSetting(Database.ilpSentenceKey, t) }

    /// The first and last day of a semester such as "2026-S1".
    func semesterRange(_ sem: String) -> (from: String, to: String) {
        let year = Int(sem.prefix(4)) ?? yearOf(todayISO())
        let two = sem.hasSuffix("S2")
        let startMonth = Database.semesterTwoStartMonth
        return two ? (Cal.make(year, startMonth, 1), Cal.make(year, 12, 31))
                   : (Cal.make(year, 1, 1), addDays(Cal.make(year, startMonth, 1), -1))
    }

    func pronoun(_ sid: String) -> Pronoun? { setting("pronoun_" + sid).flatMap(Pronoun.init(rawValue:)) }

    func setPronoun(_ sid: String, _ p: Pronoun) { setSetting("pronoun_" + sid, p.rawValue) }

    /// What the drafter is told about a student, as short lines. `detail` trims it when it is too long.
    func reportFacts(_ sid: String, sem: String, for kind: ReportComment = .general, detail: Int = 3) -> String {
        guard let s = student(sid) else { return "" }
        let r = semesterRange(sem)
        func inRange(_ x: Row) -> Bool { x.s("date") >= r.from && x.s("date") <= r.to && kind.covers(x.s("subject")) }
        func clip(_ t: String, _ n: Int) -> String { t.count > n ? String(t.prefix(n)) + "…" : t }
        var lines: [String] = ["Student: \(s.usualName)"]
        if kind == .general && !s.roles.trimmed.isEmpty { lines.append("Roles: \(s.roles.trimmed)") }

        let context = reportText(sid, sem: sem, "context").trimmed
        if !context.isEmpty { lines.append("The teacher's notes for this report: " + clip(maskingNames(context, keep: sid), 600)) }

        let judged = reportSubjects.filter(kind.covers).compactMap { subj -> String? in
            let j = judgement(sid, sem: sem, subject: subj)
            guard !j.achievement.isEmpty || !j.engagement.isEmpty else { return nil }
            return "\(subj): " + [j.achievement.isEmpty ? "" : "achievement \(j.achievement)", j.engagement.isEmpty ? "" : "engagement \(j.engagement)"]
                .filter { !$0.isEmpty }.joined(separator: ", ")
        }
        if !judged.isEmpty { lines.append("Report judgements (the comment must agree with them): " + judged.joined(separator: "; ")) }

        if kind == .general {
            let units = unitsSorted.filter { u in u.s("start") <= r.to && (u.s("end").isEmpty || u.s("end") >= r.from) }
            for u in units.prefix(2) {
                lines.append("Unit of inquiry: '\(u.s("theme"))'" + (u.s("title").isEmpty ? "" : ", \(u.s("title"))")
                             + (u.s("central_idea").isEmpty ? "" : ". Central idea: \(clip(u.s("central_idea"), 160))"))
            }
        }

        let tests = logRows(.assessments, student: sid).filter(inRange).prefix(detail * 4)
        if !tests.isEmpty {
            lines.append("Assessments: " + tests.map { "\($0.s("subject")) \($0.s("task")) \($0.s("result"))" }.joined(separator: "; "))
        }
        // Notes that mention private matters are left out, and other children's names are masked.
        let notes = logRows(.lessonnotes, student: sid).filter(inRange).filter { !CommentDrafter.mentionsPrivate($0.s("note")) }.prefix(detail * 5)
        func isUnit(_ r: Row) -> Bool { let s = r.s("subject").lowercased(); return s == "tdl" || s.contains("inquiry") || s.contains("unit") }
        func line(_ r: Row) -> String {
            "- " + (r.s("subject").isEmpty ? "" : "\(r.s("subject")): ") + clip(maskingNames(r.s("note"), keep: sid), 160)
        }
        let unitNotes = notes.filter(isUnit), otherNotes = notes.filter { !isUnit($0) }
        if kind == .general && !unitNotes.isEmpty { lines.append("Unit work notes:"); lines += unitNotes.map(line) }
        if !otherNotes.isEmpty { lines.append("Other teacher's notes:"); lines += otherNotes.map(line) }
        return lines.joined(separator: "\n")
    }

    /// Text with every name on the roll, other than `keep`'s, swapped for "a classmate", so
    /// another child's name can never reach a draft. With `replacing`, only that student's names are swapped.
    func maskingNames(_ text: String, keep: String? = nil, replacing one: String? = nil, with word: String = "a classmate") -> String {
        var t = text
        func names(_ s: Student) -> [String] {
            [s.fullName, s.first, s.surname, s.preferred] + (s.first + " " + s.surname + " " + s.preferred).split(separator: " ").map(String.init)
        }
        let parts = roster.filter { one == nil ? $0.id != keep : $0.id == one }.flatMap(names)
        let keepParts = Set(student(keep ?? "").map { names($0).map { $0.lowercased() } } ?? [])
        for p in Set(parts.map { $0.trimmed }).filter({ $0.count > 1 && !keepParts.contains($0.lowercased()) }).sorted(by: { $0.count > $1.count }) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: p) + "\\b"
            t = t.replacingOccurrences(of: pattern, with: word, options: [.regularExpression, .caseInsensitive])
        }
        // "Sam and Ava" becomes "a classmate and a classmate": say it once.
        while t.contains("\(word) and \(word)") { t = t.replacingOccurrences(of: "\(word) and \(word)", with: word == "a classmate" ? "classmates" : word) }
        return t
    }

    /// Up to `n` of the teacher's own comments of a kind to copy their voice from, a different few
    /// each time. The student being written about is left out, and every name is masked.
    func voiceExamples(excluding sid: String, kind: ReportComment = .general, n: Int = 2) -> [String] {
        let pool = rows(.reportcomment)
            .filter { $0.s("student_id") != sid && wordCount($0.s(kind.rawValue)) >= (kind == .general ? 60 : 25) }
            .sorted { $0.s("sem") > $1.s("sem") }
            .prefix(8)
        return pool.shuffled().prefix(n).map { c in
            // Sentences about private matters, such as the ILP sentence, are dropped from examples.
            let raw = c.s(kind.rawValue)
            let kept = kind == .general
                ? CommentDrafter.sentencesOf(raw).filter { !CommentDrafter.mentionsPrivate($0) }.joined(separator: " ")
                : raw.split(separator: "\n", omittingEmptySubsequences: false).filter { !CommentDrafter.mentionsPrivate(String($0)) }.joined(separator: "\n")
            var t = maskingNames(kept, replacing: c.s("student_id"), with: "Name")
            t = maskingNames(t)
            return String(t.prefix(900))
        }
    }

    /// About how long the teacher's general comments usually are, kept within 100 to 150 words.
    var typicalCommentWords: Int {
        let counts = rows(.reportcomment).map { wordCount($0.s("general")) }.filter { $0 >= 60 }
        guard !counts.isEmpty else { return 130 }
        return min(150, max(100, counts.reduce(0, +) / counts.count))
    }
}

enum CommentDrafter {
    static let rules = """
        You write semester report general comments for a primary school teacher in Australia. Parents read them, \
        so write to parents about the student, never to the student. Use plain Australian English, the third person and \
        the present perfect ("has shown", "has worked"). Keep each sentence under 25 words. No contractions, dashes or \
        exclamation marks. Use descriptive words instead of good, well, nice or very good. Be positive, and describe any \
        area of need constructively. Every sentence must come from the teacher's notes and agree with the report \
        judgements. Never invent an achievement, a project, a role or a piece of evidence. Never mention a diagnosis, a \
        learning plan, adjustments, funding or meetings. Never give a score, a percentage or a report label such as \
        Consolidating, Mastering, Appropriate or Comprehensive; describe what it means instead.
        """

    /// A new conversation with the model, primed with the house style, the teacher's rules and voice.
    static func session(base: String, rules teacher: String, examples: [String]) -> LanguageModelSession {
        var instructions = base
        if !teacher.trimmed.isEmpty {
            instructions += "\nThe teacher's own rules. Follow them too, and where they differ from the style above, follow these:\n"
                + teacher.trimmed.prefix(Database.reportRulesLimit)
        }
        if !examples.isEmpty {
            instructions += "\nMatch the tone and sentence length of the teacher's own comments below. They are about other "
                + "students: do not reuse their phrases, details or goals.\n"
                + examples.enumerated().map { "Comment \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    static func prompt(facts: String, name: String, pronoun: Pronoun, words: Int) -> String {
        """
        Write the parts of the general comment for \(name), about \(words) words in all. Call the student \(name), and use \(pronoun.words).
        What the teacher has recorded:
        \(facts)
        """
    }

    /// The comment so far, as the parts arrive.
    static func stream(_ session: LanguageModelSession, _ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            let task = Task {
                do {
                    // A comment never needs more than this, and it stops a model that runs on.
                    let options = GenerationOptions(maximumResponseTokens: 500)
                    for try await part in session.streamResponse(to: prompt, generating: GeneralParts.self, options: options) {
                        let p = part.content
                        c.yield(GeneralParts.join([p.opening, p.work, p.unit, p.goal, p.why, p.closing]))
                    }
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    /// Words that point to private matters a report must never mention.
    static let privateWords = ["ilp", "iep", "ssg", "nccd", "diagnos", "adjustment", "funding", "medical", "medication",
                               "adhd", "autis", "asd", "dyslex", "anxiety", "psycholog", "paediatric", "meeting", "custody"]

    static func mentionsPrivate(_ text: String) -> Bool {
        let t = text.lowercased()
        return privateWords.contains { w in t.range(of: "\\b" + w, options: .regularExpression) != nil }
    }

    /// Runs on the main actor, where Holocron's data lives. Streaming from the model does not block it.
    /// The draft is checked against the house style and revised once if it falls short.
    @MainActor
    static func draft(_ db: Database, sid: String, sem: String, pronoun: Pronoun, words: Int,
                      onWords: @escaping (String) -> Void) async throws -> String {
        guard let st = db.student(sid) else { throw CancellationError() }
        let name = st.usualName
        var last: Error? = nil
        // Detail 3 with examples, then the same without examples if the model copied from them,
        // then less detail if there was too much to fit.
        for (detail, withExamples) in [(3, true), (3, false), (1, false)] {
            let examples = withExamples ? db.voiceExamples(excluding: sid) : []
            let session = session(base: rules, rules: db.reportRules, examples: examples)
            do {
                let text = try await run(session, prompt(facts: db.reportFacts(sid, sem: sem, detail: detail), name: name, pronoun: pronoun, words: words), onWords)
                let done = tidy(text)
                if mentionsPrivate(done) {
                    throw mentionsPrivate(db.reportText(sid, sem: sem, "context") + " " + db.reportRules) ? DraftError.privateInNotes : DraftError.privateTerm
                }
                if copies(done, from: examples) { last = DraftError.copied; continue }
                return finish(done, student: st, ilp: db.ilpSentence)
            } catch {
                guard Intelligence.isTooLong(error) else { throw error }
                last = error
            }
        }
        throw last ?? CancellationError()
    }

    /// One answer from the model, shown as it arrives.
    @MainActor
    private static func run(_ session: LanguageModelSession, _ prompt: String, _ onWords: (String) -> Void) async throws -> String {
        var text = ""
        for try await t in stream(session, prompt) {
            try Task.checkCancellation()
            text = t
            onWords(t)
        }
        // A cancelled stream ends quietly, so check again rather than return half a comment.
        try Task.checkCancellation()
        return text
    }

    enum DraftError: Error { case privateTerm, privateInNotes, copied }

    /// Things in a draft the house style does not allow, for the teacher to see beside it.

    static func styleProblems(_ text: String, name: String) -> [String] {
        var out: [String] = []
        let n = wordCount(text)
        if n < 90 { out.append("It is \(n) words. Make it 100 to 150 words, using only what the teacher recorded.") }
        if n > 170 { out.append("It is \(n) words. Shorten it to 100 to 150 words.") }
        let sentences = sentencesOf(text)
        let openers = sentences.map { $0.split(separator: " ").first.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) } ?? "" }
        for i in 1..<max(1, openers.count) where !openers[i].isEmpty && openers[i] == openers[i - 1] {
            out.append("Sentences \(i) and \(i + 1) both begin with \"\(openers[i].capitalized)\". Begin them differently.")
        }
        for s in sentences where wordCount(s) > 28 { out.append("Split this long sentence: \"\(s.prefix(60))…\"") }
        let lower = text.lowercased()
        for w in ["good", "nice", "very good", "needs to improve"] where lower.range(of: "\\b\(w)\\b", options: .regularExpression) != nil {
            out.append("Replace \"\(w)\" with a more descriptive word.")
        }
        if lower.range(of: "(?<!as )\\bwell\\b(?!-)", options: .regularExpression) != nil {
            out.append("Replace \"well\" with a more descriptive word, such as capably or skilfully.")
        }
        if lower.range(of: "\\b(you|your|keep up)\\b", options: .regularExpression) != nil {
            out.append("Write to parents about \(name), not to \(name).")
        }
        return out
    }

    static func sentencesOf(_ text: String) -> [String] {
        var out: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { s, _, _, _ in
            if let s = s?.trimmed, !s.isEmpty { out.append(s) }
        }
        return out
    }

    /// The formal name first, as "Qixuan (Shirley)", and the teacher's ILP sentence for a student with an ILP.
    static func finish(_ text: String, student s: Student, ilp: String) -> String {
        var t = text
        let usual = s.usualName
        let first = s.first.trimmed
        let both = "\(first) (\(usual))"
        // Only the opening name is changed, and only once, so an ordinary word such as "grace" is left alone.
        if !first.isEmpty, usual.caseInsensitiveCompare(first) != .orderedSame, !t.contains(both), t.hasPrefix(usual),
           t.dropFirst(usual.count).first.map({ !$0.isLetter }) ?? true {
            t = both + t.dropFirst(usual.count)
        }
        if s.hasILP, !ilp.trimmed.isEmpty {
            let possessive = usual.hasSuffix("s") ? usual + "'" : usual + "'s"
            let sentence = ilp.trimmed.replacingOccurrences(of: "[name]'s", with: possessive).replacingOccurrences(of: "[name]", with: usual)
            if !t.contains(sentence) { t += " " + sentence }
        }
        return t
    }

    /// True when the draft repeats six or more words in a row from one of the examples, which are
    /// about other students.
    static func copies(_ draft: String, from examples: [String]) -> Bool {
        func words(_ t: String) -> [String] { t.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) }
        func runs(_ w: [String]) -> Set<String> {
            w.count < 6 ? [] : Set((0...(w.count - 6)).map { w[$0..<($0 + 6)].joined(separator: " ") })
        }
        // The house phrases in the rules are meant to repeat.
        let d = words(draft)
        let mine = runs(d).subtracting(runs(words(rules + DotPointDrafter.rules)))
        guard !mine.isEmpty else { return false }
        return examples.contains { e in
            let w = words(e)
            guard w.count >= 6 else { return false }
            return (0...(w.count - 6)).contains { mine.contains(w[$0..<($0 + 6)].joined(separator: " ")) }
        }
    }

    /// Australian spellings from the house style, unit themes in their usual form, and no dashes or
    /// exclamation marks. With `numbers`, small counts such as "3 books" are written as words.
    static func tidy(_ t: String, numbers: Bool = true) -> String {
        var out = t.replacingOccurrences(of: " — ", with: ", ").replacingOccurrences(of: "—", with: ", ")
            .replacingOccurrences(of: " – ", with: ", ")
            .replacingOccurrences(of: "!?", with: "?").replacingOccurrences(of: "?!", with: "?")
            .replacingOccurrences(of: "!", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let swaps = ["focussed": "focused", "focussing": "focusing", "benefitted": "benefited", "judgment": "judgement",
                     "programme": "program", "organize": "organise", "organized": "organised", "organizing": "organising",
                     "organization": "organisation", "recognize": "recognise", "recognized": "recognised", "realize": "realise",
                     "realized": "realised", "prioritize": "prioritise", "summarize": "summarise", "emphasize": "emphasise",
                     "color": "colour", "behavior": "behaviour", "favorite": "favourite", "center": "centre",
                     "practicing": "practising", "skillfully": "skilfully", "enrollment": "enrolment",
                     "works well with": "works cooperatively with", "worked well with": "worked cooperatively with",
                     "relates well to": "relates positively to", "has done well": "has achieved soundly"]
        for (from, to) in swaps { out = replacingKeepingCase(out, from, to) }
        if numbers { out = smallNumbersAsWords(out) }
        for theme in PYP.themes.map(\.name) {
            out = out.replacingOccurrences(of: theme, with: theme, options: .caseInsensitive)
        }
        return out
    }

    /// Replaces whole words or phrases, keeping a capital at the start: "Focussed" becomes "Focused".
    static func replacingKeepingCase(_ text: String, _ from: String, _ to: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b", options: .caseInsensitive) else { return text }
        var out = text
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let r = Range(m.range, in: out) else { continue }
            let found = out[r]
            let capital = found.first?.isUppercase == true
            out.replaceSubrange(r, with: capital ? to.prefix(1).uppercased() + to.dropFirst() : to)
        }
        return out
    }

    /// "3 books" becomes "three books". Only a number from zero to ten on its own, followed by an
    /// ordinary word, is changed: not "Year 6", "Years 5 and 6", "3 March", "$5", "4 x 5" or "2:30".
    static func smallNumbersAsWords(_ text: String) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        let before = "year|years|term|terms|semester|level|levels|stage|week|weeks|unit|page|room|grade|chapter|lesson|lessons|and|to|or|of|from|between|version"
        let skipAfter: Set<String> = ["january", "february", "march", "april", "may", "june", "july", "august", "september",
                                      "october", "november", "december", "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep",
                                      "sept", "oct", "nov", "dec", "x", "times", "plus", "minus", "divided", "multiplied", "out",
                                      "percent", "per", "am", "pm", "cm", "mm", "m", "km", "g", "kg", "ml", "l", "minutes",
                                      "minute", "seconds", "hours", "o"]
        let pattern = "(?<![$0-9.,:/\\-])(?<!(?i:\\b(?:\(before)) ))\\b(10|[0-9])\\b(?= [a-z])"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        var out = text
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let r = Range(m.range, in: out), let n = Int(out[r]), n < words.count else { continue }
            let next = out[r.upperBound...].dropFirst().prefix { $0.isLetter }.lowercased()
            if skipAfter.contains(next) { continue }
            out.replaceSubrange(r, with: words[n])
        }
        return out
    }
}

/// A general comment in its parts, so the order and openings follow the house style. Holocron joins them.
@Generable
struct GeneralParts {
    @Guide(description: "One sentence: the student's name, then \"has been a\", two or three fitting adjectives, \"student who\" and how they relate to peers and teachers. Mention a leadership role if the notes give one.")
    var opening: String
    @Guide(description: "Two sentences in the present perfect, such as \"She has compared…\", on how the student learns: effort, organisation, independence or taking risks, from the Other teacher's notes. Begin the two sentences with different words, and not with the name.")
    var work: String
    @Guide(description: "One or two sentences on what the student did in the unit of inquiry, using only the Unit work notes, in the form: For our 'Where we are in place and time' unit, Ava created a news report on …, showing … . Empty if there are no Unit work notes.")
    var unit: String
    @Guide(description: "One sentence beginning \"A valuable goal for\" and the name, describing one area of need from the notes as something to grow in.")
    var goal: String
    @Guide(description: "One short sentence on how working on the goal will help the student as a learner. Begin with \"This\" or \"Building\".")
    var why: String
    @Guide(description: "One warm closing sentence for parents about what the student has shown this semester.")
    var closing: String

    static func join(_ parts: [String?]) -> String {
        parts.compactMap { $0?.trimmed }.filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") || $0.hasSuffix("?") ? $0 : $0 + "." }
            .joined(separator: " ")
    }
}

// MARK: - English and Mathematics comments

@Generable
struct DotPoints {
    @Guide(description: "Four to six things the student achieved this semester. Each is a specific statement of 8 to 18 words about one skill, drawn from one note or result. Each completes the sentence \"[name] has:\", so it begins with a past participle such as used, solved, written, explained or compared. Do not repeat the heading.", .count(4...6))
    var achievements: [String]
    @Guide(description: "Three to six specific next steps, each 6 to 15 words, linked to an area the notes show needs work. Each completes the sentence \"Areas for [name] to focus on:\", so it begins with a verb ending in -ing such as checking, explaining or using. Do not repeat the heading.", .count(3...6))
    var goals: [String]
}

enum DotPointDrafter {
    static let rules = """
        You write the English or Mathematics comment in a semester report for a primary school teacher in Australia. \
        Parents read it. Write in plain Australian English. Each point is one short, specific statement drawn from the \
        teacher's notes, results and judgements, and must agree with the report judgements. Never invent evidence. Never \
        give a score, a percentage or a report label. Never mention a diagnosis, a learning plan, adjustments or meetings. \
        Use their for pronouns if needed.
        """

    static func coverage(_ kind: ReportComment) -> String {
        kind == .english
            ? "Across the points, cover reading, writing, and speaking and listening."
            : "Across the points, cover number and at least one other area, such as measurement, space, statistics or algebra."
    }

    @MainActor
    static func draft(_ db: Database, sid: String, sem: String, kind: ReportComment) async throws -> String {
        guard let st = db.student(sid), kind != .general else { throw CancellationError() }
        let name = st.usualName
        var last: Error? = nil
        for (detail, withExamples) in [(3, true), (1, false)] {
            let examples = withExamples ? db.voiceExamples(excluding: sid, kind: kind) : []
            let session = CommentDrafter.session(base: rules + "\n" + coverage(kind), rules: db.reportRules, examples: examples)
            do {
                let prompt = "Write the \(kind == .english ? "English" : "Mathematics") comment points for \(name).\n"
                    + "What the teacher has recorded:\n" + db.reportFacts(sid, sem: sem, for: kind, detail: detail)
                let p = try await session.respond(to: prompt, generating: DotPoints.self,
                                                  options: GenerationOptions(maximumResponseTokens: 600)).content
                try Task.checkCancellation()
                let text = format(p, name: name, numbers: kind != .maths)
                if CommentDrafter.mentionsPrivate(text) {
                    throw CommentDrafter.mentionsPrivate(db.reportText(sid, sem: sem, "context") + " " + db.reportRules)
                        ? CommentDrafter.DraftError.privateInNotes : CommentDrafter.DraftError.privateTerm
                }
                return text
            } catch {
                guard Intelligence.isTooLong(error) else { throw error }
                last = error
            }
        }
        throw last ?? CancellationError()
    }

    /// "Ava has:" and "Areas for Ava to focus on:", each followed by "- " points that begin in lower
    /// case and end with a full stop.
    static func format(_ p: DotPoints, name: String, numbers: Bool = true) -> String {
        func clean(_ s: String) -> String? {
            var t = CommentDrafter.tidy(s, numbers: numbers).trimmingCharacters(in: CharacterSet(charactersIn: " -•*"))
            // The model sometimes repeats the heading or the stem at the start of a point.
            for lead in ["areas for \(name) to focus on:", "areas for \(name) to", "\(name) has:", "\(name) has ",
                         "\(name) needs to ", "\(name) should ", "\(name) will ", "\(name) can ", "\(name) is to ",
                         "she needs to ", "he needs to ", "they need to ", "needs to ", "should ", "has ", "to "]
            where t.lowercased().hasPrefix(lead.lowercased()) {
                t = String(t.dropFirst(lead.count)).trimmed
            }
            // "explore are sharing ideas" (from "Areas for Ava to explore are …") becomes "sharing ideas".
            if let r = t.range(of: "^[A-Za-z]+ (are|is|include|includes) ", options: .regularExpression) { t = String(t[r.upperBound...]) }
            guard let f = t.first else { return nil }
            // Keep a capital for a name or "I", otherwise begin in lower case.
            if !(t.hasPrefix("I ") || t.hasPrefix("English") || t.hasPrefix("Australian")) { t = f.lowercased() + t.dropFirst() }
            if !t.hasSuffix(".") { t = t.trimmingCharacters(in: CharacterSet(charactersIn: ",;:")) + "." }
            return t
        }
        let a = p.achievements.compactMap(clean).prefix(6)
        let g = p.goals.compactMap(clean).map(ingForm).prefix(6)
        return "\(name) has:\n" + a.map { "- " + $0 }.joined(separator: "\n")
            + "\n\nAreas for \(name) to focus on:\n" + g.map { "- " + $0 }.joined(separator: "\n")
    }

    /// "check her working" becomes "checking her working", so a goal reads on from "Areas for Ava to focus on:".
    static func ingForm(_ point: String) -> String {
        guard let space = point.firstIndex(of: " ") else { return point }
        var verb = String(point[..<space]).lowercased()
        let rest = point[space...]
        if verb.hasSuffix("ing") { return point }
        if verb == "practice" { verb = "practise" }
        let doubled = ["plan", "stop", "set", "get", "put", "run", "skim", "chat", "jot"]
        if doubled.contains(verb) { verb += String(verb.last!) + "ing" }
        else if verb.hasSuffix("ie") { verb = String(verb.dropLast(2)) + "ying" }
        else if verb.hasSuffix("e") && !verb.hasSuffix("ee") { verb = String(verb.dropLast()) + "ing" }
        else { verb += "ing" }
        return verb + rest
    }

    /// The comment as SIMON wants it pasted, with %* starting each point.
    static func forSIMON(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasPrefix("- ") ? "%*" + $0.dropFirst(2) : String($0) }
            .joined(separator: "\n")
    }
}

// MARK: - Drafting a learning intention and success criteria

@Generable
struct DraftedIntent {
    @Guide(description: "The learning intention, beginning \"We are learning to\", short and in words Year 6 students understand")
    var intention: String
    @Guide(description: "Three or four success criteria, each beginning \"I can\", concrete and checkable", .count(3...4))
    var criteria: [String]
}

enum IntentDrafter {
    static func draft(subject: String, summary: String, unit: Row?, teaching: String) async throws -> DraftedIntent {
        let session = LanguageModelSession(instructions: """
            You help a Year 6 teacher in Australia, at an IB PYP school, plan a lesson. Write a learning intention and \
            success criteria in Australian English, matched to the lesson described. Do not add content that is not \
            suggested by the description.
            """)
        var about = "Subject: \(subject)"
        if !summary.trimmed.isEmpty { about += "\nLesson: \(summary.trimmed.prefix(400))" }
        if !teaching.trimmed.isEmpty { about += "\nExplicit teaching: \(teaching.trimmed.prefix(400))" }
        if let u = unit {
            about += "\nUnit of inquiry: '\(u.s("theme"))', \(u.s("title")). Central idea: \(u.s("central_idea").prefix(200))"
        }
        return try await session.respond(to: about, generating: DraftedIntent.self).content
    }
}
