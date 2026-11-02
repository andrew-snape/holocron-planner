import Foundation
import FoundationModels

// MARK: - Drafting report comments
//
// Gathers what Holocron knows about one student for a semester and asks the on-device model for a
// general comment in the teacher's own voice, learnt from their earlier comments. It is always a
// draft: nothing is saved until the teacher chooses Use.
//
// Left out on purpose: wellbeing, behaviour, medical notes, adjustments and plan notes (ILP, SSG,
// NCCD), so a draft can never mention a condition or a meeting.

enum Pronoun: String, CaseIterable, Identifiable {
    case she, he, they
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

extension Database {
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
    func reportFacts(_ sid: String, sem: String, detail: Int = 3) -> String {
        guard let s = student(sid) else { return "" }
        let r = semesterRange(sem)
        func inRange(_ x: Row) -> Bool { x.s("date") >= r.from && x.s("date") <= r.to }
        func clip(_ t: String, _ n: Int) -> String { t.count > n ? String(t.prefix(n)) + "…" : t }
        var lines: [String] = ["Student: \(s.first)"]
        if !s.roles.trimmed.isEmpty { lines.append("Roles: \(s.roles.trimmed)") }

        let judged = reportSubjects.compactMap { subj -> String? in
            let j = judgement(sid, sem: sem, subject: subj)
            guard !j.achievement.isEmpty || !j.engagement.isEmpty else { return nil }
            return "\(subj): " + [j.achievement, j.engagement.isEmpty ? "" : "\(j.engagement.lowercased()) engagement"]
                .filter { !$0.isEmpty }.joined(separator: ", ")
        }
        if !judged.isEmpty { lines.append("Report judgements: " + judged.joined(separator: "; ")) }

        let units = unitsSorted.filter { u in u.s("start") <= r.to && (u.s("end").isEmpty || u.s("end") >= r.from) }
        for u in units.prefix(2) {
            lines.append("Unit of inquiry: '\(u.s("theme"))'" + (u.s("title").isEmpty ? "" : ", \(u.s("title"))")
                         + (u.s("central_idea").isEmpty ? "" : ". Central idea: \(clip(u.s("central_idea"), 160))"))
        }

        let tests = logRows(.assessments, student: sid).filter(inRange).prefix(detail * 4)
        if !tests.isEmpty {
            lines.append("Assessments: " + tests.map { "\($0.s("subject")) \($0.s("task")) \($0.s("result"))" }.joined(separator: "; "))
        }
        let notes = logRows(.lessonnotes, student: sid).filter(inRange).prefix(detail * 5)
        if !notes.isEmpty {
            lines.append("Teacher's notes:")
            // Notes that mention private matters are left out, and other children's names are masked.
            lines += notes.filter { !CommentDrafter.mentionsPrivate($0.s("note")) }
                .map { "- " + ($0.s("subject").isEmpty ? "" : "\($0.s("subject")): ") + clip(maskingNames($0.s("note"), keep: sid), 160) }
        }
        return lines.joined(separator: "\n")
    }

    /// Text with every name on the roll, other than `keep`'s, swapped for "a classmate", so
    /// another child's name can never reach a draft. With `replacing`, only that student's names are swapped.
    func maskingNames(_ text: String, keep: String? = nil, replacing one: String? = nil, with word: String = "a classmate") -> String {
        var t = text
        let parts = roster.filter { one == nil ? $0.id != keep : $0.id == one }
            .flatMap { [$0.fullName, $0.first, $0.surname] + $0.first.split(separator: " ").map(String.init) + $0.surname.split(separator: " ").map(String.init) }
        let keepParts = Set(student(keep ?? "").map { ($0.first + " " + $0.surname).lowercased().split(separator: " ").map(String.init) } ?? [])
        for p in Set(parts.map { $0.trimmed }).filter({ $0.count > 1 && !keepParts.contains($0.lowercased()) }).sorted(by: { $0.count > $1.count }) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: p) + "\\b"
            t = t.replacingOccurrences(of: pattern, with: word, options: [.regularExpression, .caseInsensitive])
        }
        // "Sam and Ava" becomes "a classmate and a classmate": say it once.
        while t.contains("\(word) and \(word)") { t = t.replacingOccurrences(of: "\(word) and \(word)", with: word == "a classmate" ? "classmates" : word) }
        return t
    }

    /// Up to `n` of the teacher's own general comments to copy their voice from, a different few
    /// each time. The student being written about is left out, and every name is masked.
    func voiceExamples(excluding sid: String, n: Int = 2) -> [String] {
        let pool = rows(.reportcomment)
            .filter { $0.s("student_id") != sid && wordCount($0.s("general")) >= 60 }
            .sorted { $0.s("sem") > $1.s("sem") }
            .prefix(8)
        return pool.shuffled().prefix(n).map { c in
            var t = maskingNames(c.s("general"), replacing: c.s("student_id"), with: "Name")
            t = maskingNames(t)
            return String(t.prefix(1100))
        }
    }

    /// About how long the teacher's comments usually are, for the target length.
    var typicalCommentWords: Int {
        let counts = rows(.reportcomment).map { wordCount($0.s("general")) }.filter { $0 >= 60 }
        guard !counts.isEmpty else { return 140 }
        return min(200, max(80, counts.reduce(0, +) / counts.count))
    }
}

enum CommentDrafter {
    static let rules = """
        You write semester report general comments for a primary school teacher in Australia. The comments go to parents.
        Write one paragraph in Australian English, in the third person and the present perfect ("has been", "has shown"). \
        No contractions. No dashes. Formal but warm. Say each idea once. Every sentence must be supported by the teacher's \
        notes. Never invent an achievement, a project, a role or a piece of evidence. Never mention a diagnosis, a learning \
        plan, adjustments, funding or meetings. Never give a score, a percentage or a report label such as Consolidating, \
        Mastering or "appropriate engagement"; describe what they mean in plain words instead.
        Use these five parts, in order:
        1. "[Name] has been a [two or three fitting adjectives] student who [how they relate to peers and teachers]." Mention a leadership role here if there is one.
        2. One or two sentences on how they work: effort, organisation, independence or taking risks, drawn from the notes.
        3. If the notes describe their unit work: "For our '[unit theme]' unit, [Name] [what they made and what it showed]."
        4. "A valuable goal for [Name] is to [one forward-looking goal from the notes]." Then one short line on why it will help.
        5. A warm closing line, such as "[Name] should be proud of the effort [pronoun] has shown this semester."
        """

    /// A new conversation with the model, primed with the teacher's voice.
    static func session(examples: [String]) -> LanguageModelSession {
        var instructions = rules
        if !examples.isEmpty {
            instructions += "\nMatch the tone and sentence length of the teacher's own comments below. They are about other "
                + "students: do not reuse their phrases, details or goals.\n"
                + examples.enumerated().map { "Comment \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    static func prompt(facts: String, name: String, pronoun: Pronoun, words: Int) -> String {
        let p: String
        switch pronoun {
        case .she: p = "she and her"
        case .he: p = "he and his"
        case .they: p = "they and their"
        }
        return """
            Write the general comment for \(name), about \(words) words. Use \(name)'s name and \(p).
            What the teacher has recorded:
            \(facts)
            """
    }

    /// Words, as they arrive.
    static func stream(_ session: LanguageModelSession, _ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            let task = Task {
                do {
                    for try await part in session.streamResponse(to: prompt) { c.yield(part.content) }
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    /// Writes a whole comment, trying again with less detail if there was too much for the model.
    /// Words that point to private matters a report must never mention.
    static let privateWords = ["ilp", "iep", "ssg", "nccd", "diagnos", "adjustment", "funding", "medical", "medication",
                               "adhd", "autis", "asd", "dyslex", "anxiety", "psycholog", "paediatric", "meeting", "custody"]

    static func mentionsPrivate(_ text: String) -> Bool {
        let t = text.lowercased()
        return privateWords.contains { w in t.range(of: "\\b" + w, options: .regularExpression) != nil }
    }

    /// Runs on the main actor, where Holocron's data lives. Streaming from the model does not block it.
    @MainActor
    static func draft(_ db: Database, sid: String, sem: String, pronoun: Pronoun, words: Int,
                      onWords: @escaping (String) -> Void) async throws -> String {
        let name = db.student(sid)?.first ?? "The student"
        var last: Error? = nil
        // Detail 3 with examples, then the same without examples if the model copied from them,
        // then less detail if there was too much to fit.
        for (detail, withExamples) in [(3, true), (3, false), (1, false)] {
            let examples = withExamples ? db.voiceExamples(excluding: sid) : []
            let session = session(examples: examples)
            var text = ""
            do {
                for try await t in stream(session, prompt(facts: db.reportFacts(sid, sem: sem, detail: detail), name: name, pronoun: pronoun, words: words)) {
                    try Task.checkCancellation()
                    text = t
                    onWords(t)
                }
                // A cancelled stream ends quietly, so check again rather than return half a comment.
                try Task.checkCancellation()
                let done = tidy(text)
                if mentionsPrivate(done) { throw DraftError.privateTerm }
                if copies(done, from: examples) { last = DraftError.copied; continue }
                return done
            } catch {
                guard case LanguageModelSession.GenerationError.exceededContextWindowSize = error else { throw error }
                last = error
            }
        }
        throw last ?? CancellationError()
    }

    enum DraftError: Error { case privateTerm, copied }

    /// True when the draft repeats six or more words in a row from one of the examples, which are
    /// about other students.
    static func copies(_ draft: String, from examples: [String]) -> Bool {
        func words(_ t: String) -> [String] { t.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) }
        func runs(_ w: [String]) -> Set<String> {
            w.count < 6 ? [] : Set((0...(w.count - 6)).map { w[$0..<($0 + 6)].joined(separator: " ") })
        }
        // The house phrases in the rules ("should be proud of the effort") are meant to repeat.
        let d = words(draft)
        let mine = runs(d).subtracting(runs(words(rules)))
        guard !mine.isEmpty else { return false }
        return examples.contains { e in
            let w = words(e)
            guard w.count >= 6 else { return false }
            return (0...(w.count - 6)).contains { mine.contains(w[$0..<($0 + 6)].joined(separator: " ")) }
        }
    }

    /// Removes dashes and stray whitespace the house style does not use.
    static func tidy(_ t: String) -> String {
        var out = t.replacingOccurrences(of: " — ", with: ", ").replacingOccurrences(of: "—", with: ", ")
            .replacingOccurrences(of: " – ", with: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Unit themes keep their capital, as in 'Where we are in place and time'.
        for theme in PYP.themes.map(\.name) {
            out = out.replacingOccurrences(of: theme, with: theme, options: .caseInsensitive)
        }
        return out
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
