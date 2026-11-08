import Foundation
import FoundationModels

// MARK: - Drafting the steps of a lesson
//
// From a lesson's summary (and the subject, the unit of inquiry and anything already written) the
// on-device model drafts tuning in, explicit teaching, independent work and reflection. Lessons can
// live in a shared planner folder, so no student information is ever used: every name on the roll is
// swapped out of the text before it is read, and the prompt holds only planner text.

@Generable
struct DraftedLesson {
    @Guide(description: "Tuning in: a short hook that opens the lesson and gets students thinking, one to three sentences")
    var tuning: String
    @Guide(description: "Explicit teaching: what the teacher models or explains, as three to five short steps, one step on each line, with no numbers or bullets")
    var teaching: String
    @Guide(description: "Independent work: what students do on their own or in pairs, one to three short lines")
    var independent: String
    @Guide(description: "Reflection: one or two questions or prompts that bring the lesson to a close")
    var reflection: String
}

enum LessonDrafter {
    /// The four fields this drafts, in lesson order. They are the keys of `LessonContent`.
    static let keys = PlanSeq.all.map(\.key)

    @MainActor
    static func draft(_ db: Database, subject: String, content c: LessonContent, unit: Row?) async throws -> [String: String] {
        var last: Error? = nil
        // Too much for the model at once: try again with less.
        for detail in [0, 1] {
            let session = LanguageModelSession(instructions: """
                You help a Year 6 teacher in Australia, at an IB PYP school, plan a lesson. Draft the parts of the lesson \
                in Australian English, in short, plain sentences, matched to the lesson described. Write what the teacher \
                and students do. Do not add content, links, resources or names that are not suggested by the description.
                """)
            do {
                let r = try await session.respond(to: prompt(db, subject: subject, c: c, unit: unit, detail: detail),
                                                  generating: DraftedLesson.self,
                                                  options: GenerationOptions(maximumResponseTokens: 700)).content
                try Task.checkCancellation()
                return ["tuning": clean(r.tuning), "teaching": clean(r.teaching),
                        "independent": clean(r.independent), "reflection": clean(r.reflection)]
            } catch {
                guard Intelligence.isTooLong(error) else { throw error }
                last = error
            }
        }
        throw last ?? CancellationError()
    }

    /// Only planner text. Every name on the roll becomes "a student" before it goes in.
    @MainActor
    static func prompt(_ db: Database, subject: String, c: LessonContent, unit: Row?, detail: Int) -> String {
        let limit = detail == 0 ? 400 : 150
        func part(_ label: String, _ text: String) -> String? {
            let t = db.maskingNames(text.trimmed, word: "a student")
            return t.isEmpty ? nil : "\(label): " + String(t.prefix(limit))
        }
        var lines = ["Subject: \(subject)"]
        lines += [part("Lesson", c.summary), part("Learning intention", c.li), part("Success criteria", c.sc.replacingOccurrences(of: "\n", with: " ")),
                  part("Tuning in already written", c.tuning), part("Explicit teaching already written", c.teaching),
                  part("Independent work already written", c.independent), part("Reflection already written", c.reflection)].compactMap { $0 }
        if detail == 0, let u = unit {
            lines.append(db.maskingNames("Unit of inquiry: '\(u.s("theme"))', \(u.s("title")). Central idea: \(u.s("central_idea").prefix(160))", word: "a student"))
        }
        return lines.joined(separator: "\n")
    }

    /// One step to a line, with any numbers or bullets the model added taken off.
    static func clean(_ text: String) -> String {
        linesOf(text).map { line in
            line.replacingOccurrences(of: #"^\s*(?:[-•*–]|\d{1,2}[.)])\s+"#, with: "", options: .regularExpression)
        }.joined(separator: "\n")
    }
}
