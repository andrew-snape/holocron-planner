import AppIntents

// MARK: - Phrases for Siri and Spotlight
//
// Every phrase has to name the app. These need no setting up: they appear in Spotlight and the
// Shortcuts app as soon as Holocron is in the Applications folder.

struct HolocronShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WhatsNextIntent(), phrases: [
            "What's next in \(.applicationName)",
            "What's on now in \(.applicationName)",
            "What's my next lesson in \(.applicationName)",
        ], shortTitle: "What's Next", systemImageName: "clock")
        AppShortcut(intent: TodayIntent(), phrases: [
            "What's on today in \(.applicationName)",
            "Today's lessons in \(.applicationName)",
        ], shortTitle: "Today", systemImageName: "calendar")
        AppShortcut(intent: TomorrowIntent(), phrases: [
            "What's on tomorrow in \(.applicationName)",
        ], shortTitle: "Tomorrow", systemImageName: "calendar.badge.clock")
        AppShortcut(intent: WhenIsSubjectIntent(), phrases: [
            "When is \(\.$subject) in \(.applicationName)",
            "When is \(\.$subject) on in \(.applicationName)",
        ], shortTitle: "When Is a Subject On", systemImageName: "magnifyingglass")
        AppShortcut(intent: BirthdaysIntent(), phrases: [
            "Any birthdays this week in \(.applicationName)",
            "Upcoming birthdays in \(.applicationName)",
        ], shortTitle: "Birthdays", systemImageName: "gift")
        AppShortcut(intent: LogNoteIntent(), phrases: [
            "Log a note in \(.applicationName)",
            "Log a note for \(\.$student) in \(.applicationName)",
        ], shortTitle: "Log a Note", systemImageName: "square.and.pencil")
        AppShortcut(intent: AddTodoIntent(), phrases: [
            "Add a to-do in \(.applicationName)",
            "Add a \(.applicationName) to-do",
        ], shortTitle: "Add a To-Do", systemImageName: "checklist")
        AppShortcut(intent: CopyTodayIntent(), phrases: [
            "Copy today in \(.applicationName)",
            "Copy today's lessons in \(.applicationName)",
        ], shortTitle: "Copy Today", systemImageName: "doc.on.doc")
        AppShortcut(intent: OpenClassScreenIntent(), phrases: [
            "Open the class screen in \(.applicationName)",
        ], shortTitle: "Class Screen", systemImageName: "rectangle.on.rectangle")
        AppShortcut(intent: StartTimerIntent(), phrases: [
            "Start a \(.applicationName) timer",
            "Start the class timer in \(.applicationName)",
        ], shortTitle: "Start Timer", systemImageName: "timer")
    }

    /// Shown in Settings, then Apple Intelligence.
    static let examples = [
        "What's next in Holocron?",
        "What's on tomorrow in Holocron?",
        "When is Maths in Holocron?",
        "Log a note for Ava in Holocron",
        "Start a Holocron timer",
    ]
}
