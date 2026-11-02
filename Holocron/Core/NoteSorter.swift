import Foundation
import FoundationModels

// MARK: - Sorting dictated notes
//
// "Ava and Sam, great reasoning in maths. Leo was upset after lunch." becomes one Maths lesson
// note for Ava and Sam and a wellbeing note for Leo. The on-device model only splits the words;
// names are matched to the roll here, and the teacher checks every note before it is saved.

@Generable
enum DictatedKind {
    case lesson
    case behaviour
    case wellbeing
}

@Generable
struct DictatedNote {
    @Guide(description: "The students this note is about, as said, one name per item, such as Ava or Sam Lee. Use \"whole class\" when it is about everyone. Empty if no student is named.")
    var students: [String]
    @Guide(description: "lesson for learning, understanding and effort in a subject; behaviour for conduct such as calling out, disrupting, being kind, helping or following rules; wellbeing for feelings, health, friendships or worries")
    var kind: DictatedKind
    @Guide(description: "One of the subjects listed when the note is about one, otherwise empty")
    var subject: String
    @Guide(description: "The note as a full sentence in Australian English, starting with a capital letter and ending with a full stop, keeping the teacher's words and details. Leave out the student's name, for example: Showed great reasoning in maths today.")
    var note: String
}

@Generable
struct DictatedNotes {
    @Guide(description: "One item for each separate observation, in the order said")
    var notes: [DictatedNote]
}

enum QuickKind: String, CaseIterable, Identifiable {
    case lesson = "Lesson note"
    case wellbeing = "Wellbeing"
    case behaviour = "Behaviour"
    var id: String { rawValue }
}

/// A dictated note ready for the teacher to check.
struct SortedNote: Identifiable, Equatable {
    var id = UUID()
    var students: [String]
    /// Names that were said but are not on the roll.
    var unknown: [String] = []
    var kind: QuickKind
    var subject: String
    var note: String
}

enum NoteSorter {
    /// The first name, or the full name when two students share a first name.
    static func spokenNames(_ roster: [Student]) -> [String] {
        let firsts = Dictionary(grouping: roster) { NameMatcher.fold($0.first) }
        return roster.map { s in firsts[NameMatcher.fold(s.first)]!.count > 1 ? s.fullName : s.first }
    }

    static func sort(_ transcript: String, roster: [Student], subjects: [String], lessonNow: String) async throws -> [SortedNote] {
        let session = LanguageModelSession(instructions: """
            You help a primary school teacher in Australia file notes they dictated during the day. \
            Split what they said into separate notes, one for each observation. Students in the class: \
            \(spokenNames(roster).joined(separator: ", ")). Subjects: \(subjects.joined(separator: ", ")). \
            Never invent details, names or subjects that were not said.
            """)
        let out = try await session.respond(to: "Dictated: \(transcript)", generating: DictatedNotes.self,
                                           options: GenerationOptions(sampling: .greedy)).content
        let saidWords = Set(NameMatcher.fold(transcript))
        let firstCounts = Dictionary(grouping: roster) { NameMatcher.fold($0.first) }.mapValues(\.count)
        var seen = Set<String>()
        return out.notes.compactMap { n in
            let text = n.note.trimmed
            // The model sometimes repeats a note.
            guard !text.isEmpty, seen.insert(text.lowercased()).inserted else { return nil }
            var ids: [String] = [], unknown: [String] = []
            for said in n.students {
                if NameMatcher.fold(said) == ["whole", "class"] || NameMatcher.fold(said) == ["everyone"] {
                    if saidWords.contains("class") || saidWords.contains("everyone") || saidWords.contains("everybody") {
                        ids = roster.map(\.id)
                    }
                    continue
                }
                guard let sid = match(said, roster), let st = roster.first(where: { $0.id == sid }) else {
                    if !said.trimmed.isEmpty { unknown.append(said.trimmed) }
                    continue
                }
                // The model can name a student who was never mentioned, so a name must have been said.
                if !(NameMatcher.fold(st.first) + NameMatcher.fold(st.surname)).contains(where: saidWords.contains) {
                    continue
                }
                // Two students with the same first name: the model may have picked one itself,
                // so only accept it when the surname was actually said.
                if (firstCounts[NameMatcher.fold(st.first)] ?? 0) > 1 && !NameMatcher.fold(st.surname).allSatisfy(saidWords.contains) {
                    unknown.append("\(st.first) (which one?)")
                    continue
                }
                if !ids.contains(sid) { ids.append(sid) }
            }
            if ids.isEmpty && unknown.isEmpty {
                // No name came back, but the note may still say who: take any student named in it.
                let words = Set(NameMatcher.fold(text))
                for st in roster {
                    let f = NameMatcher.fold(st.first), sn = NameMatcher.fold(st.surname)
                    let shared = (firstCounts[f] ?? 0) > 1
                    if f.allSatisfy(words.contains) && (!shared || sn.allSatisfy(words.contains)) { ids.append(st.id) }
                }
            }
            let subject = subjects.first { $0.caseInsensitiveCompare(n.subject.trimmed) == .orderedSame }
            let kind: QuickKind = n.kind == .behaviour ? .behaviour : n.kind == .wellbeing ? .wellbeing : .lesson
            return SortedNote(students: ids, unknown: unknown, kind: kind,
                              subject: kind == .lesson ? (subject ?? lessonNow) : "", note: text)
        }
    }

    /// A student for a name as said: the full name, else a first name only one student has,
    /// else a surname only one student has.
    static func match(_ said: String, _ roster: [Student]) -> String? {
        let w = NameMatcher.fold(said)
        guard !w.isEmpty else { return nil }
        let roll = NameMatcher.folded(roster)
        let whole = roll.filter { $0.whole == w.sorted() }
        if whole.count == 1 { return whole[0].id }
        let first = roll.filter { $0.first == w || ($0.first.first == w.first && w.count == 1) }
        if first.count == 1 { return first[0].id }
        let last = roll.filter { $0.surname == w }
        if last.count == 1 { return last[0].id }
        if case .likely(let sid) = NameMatcher.match(first: said, surname: "", ref: "", roll: roll, remembered: [:]) { return sid }
        return nil
    }
}
