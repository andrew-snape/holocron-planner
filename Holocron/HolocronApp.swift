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
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    model.nav = .settings
                    model.updater.check(userInitiated: true)
                }
            }
            CommandMenu("Go") {
                ForEach(Array(NavItem.allCases.enumerated()), id: \.element) { idx, item in
                    if model.isEnabled(item) {
                        Button(item.title) { model.nav = item }
                            .keyboardShortcut(item == .settings ? KeyEquivalent(",") : KeyEquivalent(Character(String((idx + 1) % 10))), modifiers: .command)
                    }
                }
            }
            CommandGroup(after: .saveItem) {
                Button("Reload from folder") {
                    model.flushNow(wait: true)
                    model.loadAll()
                    model.showToast("Reloaded from folder")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
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
    }
}
