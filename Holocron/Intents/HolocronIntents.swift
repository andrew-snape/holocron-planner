import AppIntents
import Foundation

// MARK: - Siri, Spotlight and Shortcuts
//
// Holocron's App Intents. They run inside the app, which macOS opens in the background when
// needed, and work on the same data as the window. Questions only read. Actions that change
// data ask first or say exactly what they did.

/// The app's model, for intents. Set once when the app starts.
@MainActor
enum IntentHost {
    static weak var model: AppModel?

    /// The model, when its data folder is there. Questions still work if one file could not be read.
    static func require() throws -> AppModel {
        guard let m = model, m.folder.exists() else { throw HolocronIntentError.noData }
        return m
    }

    /// The model, when `table` can be changed safely.
    static func require(writing table: TableName) throws -> AppModel {
        let m = try require()
        guard m.canWrite(table) else { throw HolocronIntentError.unreadable(table.rawValue) }
        return m
    }

    /// Siri says student names only when allowed in Settings, and never while the Class screen
    /// is showing on a projector.
    static var mayUseNames: Bool {
        guard let m = model else { return false }
        return m.db.siriMayUseNames && m.classScreens.isEmpty
    }
}

enum HolocronIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noData
    case unreadable(String)
    case notSaved(String)
    case emptyNote
    case emptyTodo
    case noSuchStudent
    case classScreenOff

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noData: return "Holocron has no data folder connected. Open Holocron to set one up."
        case .unreadable(let t): return "\(t).csv could not be read, so Holocron won't change it. Open Holocron to see what's wrong."
        case .notSaved(let t): return "Holocron could not save to \(t).csv. Open Holocron and check your data folder."
        case .emptyNote: return "The note was empty, so nothing was saved."
        case .emptyTodo: return "The to-do was empty, so nothing was added."
        case .noSuchStudent: return "That student is no longer on your roll in Holocron."
        case .classScreenOff: return "The Class screen is switched off in Holocron's Settings."
        }
    }
}

// MARK: Entities

struct StudentEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Student"
    static let defaultQuery = StudentQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ s: Student) {
        id = s.id
        name = s.fullName
    }
}

struct StudentQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [StudentEntity] {
        let db = try IntentHost.require().db
        return identifiers.compactMap { db.student($0).map(StudentEntity.init) }
    }

    /// First names alone are how teachers say them, so they count, as do surnames and the start of a name.
    @MainActor
    func entities(matching string: String) async throws -> [StudentEntity] {
        let want = NameMatcher.fold(string)
        guard !want.isEmpty else { return [] }
        let roster = try IntentHost.require().db.roster
        return roster.filter { s in
            let have = NameMatcher.fold(s.first) + NameMatcher.fold(s.surname)
            return want.allSatisfy { w in have.contains { $0.hasPrefix(w) } }
        }.map(StudentEntity.init)
    }

    /// The class list is only offered when names are allowed in Settings. A name the teacher says
    /// or types is still matched either way.
    @MainActor
    func suggestedEntities() async throws -> [StudentEntity] {
        let model = try IntentHost.require()
        guard IntentHost.mayUseNames else { return [] }
        return model.db.roster.map(StudentEntity.init)
    }
}

struct SubjectEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Subject"
    static let defaultQuery = SubjectQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct SubjectQuery: EntityStringQuery {
    @MainActor
    private func all() throws -> [SubjectEntity] {
        try IntentHost.require().db.subjects.filter { $0.kind != "dottl" }.map { SubjectEntity(id: $0.subject) }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [SubjectEntity] {
        try all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [SubjectEntity] {
        let s = string.trimmed.lowercased()
        return try all().filter { $0.id.lowercased().hasPrefix(s) || $0.id.lowercased().contains(s) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SubjectEntity] { try all() }
}

// MARK: Questions

struct WhatsNextIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Next"
    static let description = IntentDescription("Says the lesson on now and the one after it.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = try IntentHost.require().db.nowAndNext(date: todayISO(), minutes: nowMinutes())
        return .result(value: answer, dialog: "\(answer)")
    }
}

struct TodayIntent: AppIntent {
    static let title: LocalizedStringResource = "What's On Today"
    static let description = IntentDescription("Lists today's lessons and their times.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = try IntentHost.require().db.dayOutline(todayISO())
        return .result(value: answer, dialog: "\(answer)")
    }
}

struct TomorrowIntent: AppIntent {
    static let title: LocalizedStringResource = "What's On Tomorrow"
    static let description = IntentDescription("Lists the next school day's lessons and their times.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let db = try IntentHost.require().db
        // On a Friday or a weekend, tomorrow means Monday.
        var d = addDays(todayISO(), 1)
        while dayIdx(d) >= 5 { d = addDays(d, 1) }
        let answer = db.dayOutline(d)
        return .result(value: answer, dialog: "\(answer)")
    }
}

struct WhenIsSubjectIntent: AppIntent {
    static let title: LocalizedStringResource = "When Is a Subject On"
    static let description = IntentDescription("Says when a subject is on for the rest of this week.")

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary { Summary("When is \(\.$subject) on") }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = try IntentHost.require().db.whenIs(subject.id, from: todayISO(), minutes: nowMinutes())
        return .result(value: answer, dialog: "\(answer)")
    }
}

struct BirthdaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Upcoming Birthdays"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let description = IntentDescription("Says whose birthday is in the next week.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = try IntentHost.require().db.birthdaysAnswer(names: IntentHost.mayUseNames)
        return .result(value: answer, dialog: "\(answer)")
    }
}

// MARK: Actions

struct LogNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Note"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let description = IntentDescription("Saves a lesson note for a student, as in Quick log.")

    @Parameter(title: "Student")
    var student: StudentEntity

    @Parameter(title: "Note", inputOptions: String.IntentInputOptions(multiline: true))
    var note: String

    @Parameter(title: "Subject", description: "Leave empty to use the lesson on now.")
    var subject: SubjectEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$note) for \(\.$student)") { \.$subject }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentHost.require(writing: .lessonnotes)
        let text = note.trimmed
        guard !text.isEmpty else { throw HolocronIntentError.emptyNote }
        guard model.db.student(student.id) != nil else { throw HolocronIntentError.noSuchStudent }
        let subj = subject?.id ?? (model.db.runsNormally(todayISO()) ? model.nowSubject() : "")
        let what = subj.isEmpty ? "a note" : "a \(subj) note"
        // With the Class screen up, or names switched off, the note itself is not read out either.
        let ask: IntentDialog = IntentHost.mayUseNames ? "Save \(what) for \(student.name): \(text)?" : "Save \(what) for this student?"
        try await requestConfirmation(result: .result(dialog: ask))
        model.db.addLessonNote(students: [student.id], subject: subj, note: text)
        guard model.saveNow(.lessonnotes) else { throw HolocronIntentError.notSaved("lessonnotes") }
        return .result(dialog: "Saved.")
    }
}

struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a To-Do"
    static let description = IntentDescription("Adds an item to Holocron's to-do list on Today.")

    @Parameter(title: "To-do")
    var text: String

    @Parameter(title: "Due")
    var due: Date?

    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$text) to Holocron's to-do list") { \.$due } }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentHost.require(writing: .todo)
        let t = text.trimmed
        guard !t.isEmpty else { throw HolocronIntentError.emptyTodo }
        var dueISO = ""
        if let d = due {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
            dueISO = Cal.make(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
        }
        model.db.addTodo(text: t, due: dueISO)
        guard model.saveNow(.todo) else { throw HolocronIntentError.notSaved("todo") }
        return .result(dialog: dueISO.isEmpty ? "Added to your to-do list." : "Added, due \(longDate(dueISO)).")
    }
}

struct CopyTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Today for a Relief Teacher"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let description = IntentDescription("Copies today's times, lessons and resources as rich text, ready to paste.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentHost.require()
        let d = todayISO()
        guard model.db.runsNormally(d) else { return .result(dialog: "There are no lessons today to copy.") }
        model.copyDay(d)
        return .result(dialog: "Today's lessons are copied. Paste them into your message or the LMS.")
    }
}

struct OpenClassScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the Class Screen"
    static let description = IntentDescription("Shows the Class screen for the lesson on now.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = try IntentHost.require()
        guard model.isEnabled(.classScreen) else { throw HolocronIntentError.classScreenOff }
        model.nav = .classScreen
        return .result()
    }
}

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start the Class Timer"
    static let description = IntentDescription("Starts the Class screen timer.")

    @Parameter(title: "Minutes", default: 10, inclusiveRange: (1, 180))
    var minutes: Int

    static var parameterSummary: some ParameterSummary { Summary("Start a \(\.$minutes) minute timer") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentHost.require()
        model.classTimer.start(minutes: minutes)
        return .result(dialog: "Timer started for \(minutes) minute\(minutes == 1 ? "" : "s").")
    }
}
