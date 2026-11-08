import Foundation
import FoundationModels

// MARK: - Suggesting a subject and kind for a typed note
//
// The teacher types a note and chooses Suggest. The on-device model reads the note and picks the
// kind (lesson, behaviour or wellbeing, as in dictated notes) and one of the teacher's own subjects.
// The answer is limited to those choices, so nothing can be invented. It is only ever shown as a
// suggestion for the teacher to accept. The note is student information: it is read on this Mac only
// and is never logged or stored by this code.

struct NoteSuggestion: Equatable {
    var kind: QuickKind
    /// One of the teacher's subjects, or empty.
    var subject: String
}

enum NoteTagger {
    private static let kinds = ["lesson", "behaviour", "wellbeing"]
    private static let noSubject = "none"

    static func suggest(_ note: String, subjects: [String]) async throws -> NoteSuggestion {
        var names: [String] = []
        for s in subjects.map(\.trimmed) where !s.isEmpty && s.lowercased() != noSubject && !names.contains(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) {
            names.append(s)
        }
        // The answer can only be one of these words.
        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(name: "NoteTags", properties: [
                .init(name: "kind", description: "lesson for learning, understanding and effort in a subject; behaviour for conduct such as calling out, disrupting, being kind, helping or following rules; wellbeing for feelings, health, friendships, worries or family",
                      schema: DynamicGenerationSchema(name: "Kind", anyOf: kinds)),
                .init(name: "subject", description: "The subject the note is about, or none when no subject is clear or the note is not about learning",
                      schema: DynamicGenerationSchema(name: "Subject", anyOf: names + [noSubject])),
            ]),
            dependencies: [])
        let session = LanguageModelSession(instructions: """
            A primary school teacher in Australia typed a note about a student. Choose the kind of note and the subject \
            it is about. Only pick a subject when the note clearly refers to it.
            """)
        let out = try await session.respond(to: "Note: " + String(note.trimmed.prefix(600)), schema: schema,
                                            options: GenerationOptions(samplingMode: .greedy)).content
        try Task.checkCancellation()
        let kindWord = try out.value(String.self, forProperty: "kind")
        let subjectWord = try out.value(String.self, forProperty: "subject")
        let kind: QuickKind = kindWord == "behaviour" ? .behaviour : kindWord == "wellbeing" ? .wellbeing : .lesson
        let subject = kind == .lesson ? (names.first { $0.caseInsensitiveCompare(subjectWord) == .orderedSame } ?? "") : ""
        return NoteSuggestion(kind: kind, subject: subject)
    }
}
