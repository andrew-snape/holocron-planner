import SwiftUI
import AppKit

@main
struct HolocronApp: App {
    @State private var model = AppModel()

    init() {
        // Light mode only, by choice.
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .frame(minWidth: 520, minHeight: 480)
        }
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Student…") { model.sheet = .newStudent }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.sheet != nil || !model.isEnabled(.students))
                Button("Log Note…") { model.nav = .quick }
                    .keyboardShortcut("l", modifiers: .command)
                    .disabled(model.sheet != nil || !model.isEnabled(.quick))
            }
            AppCommands(model: model)
            CommandMenu("Go") {
                ForEach(Array(NavItem.allCases.enumerated()), id: \.element) { idx, item in
                    if model.isEnabled(item) {
                        Button(item.title) { model.nav = item }
                            .keyboardShortcut(KeyEquivalent(Character(String((idx + 1) % 10))), modifiers: .command)
                    }
                }
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Day as Rich Text") { model.copyDay(model.cursor) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                    .disabled(model.nav != .today)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print Week…") { PrintWeek.open(model: model) }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(model.nav != .week)
                Button("Save Week as PDF…") { PrintWeek.save(model: model) }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(model.nav != .week)
            }
            CommandGroup(after: .saveItem) {
                Button("Reload from folder") { model.reloadFromFolder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            HelpCommands(model: model)
        }

        WindowGroup("Class screen", id: "classscreen", for: ClassTarget.self) { $target in
            if let t = target {
                ClassScreenView(initial: t)
                    .environment(model)
                    .preferredColorScheme(.light)
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .defaultSize(width: 1180, height: 760)

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(.light)
                .frame(minWidth: 540, idealWidth: 600, minHeight: 460, idealHeight: 620)
        }

        Window("Holocron Help", id: "help") {
            HelpView()
                .environment(model)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 920, height: 680)
    }
}


/// Application menu items. Settings itself lives in the Settings scene, so Cmd+, and the app menu item come for free.
struct AppCommands: Commands {
    var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                UserDefaults.standard.set(SettingsTab.updates.rawValue, forKey: "settingsTab")
                openSettings()
                model.updater.check(userInitiated: true)
            }
        }
    }
}
