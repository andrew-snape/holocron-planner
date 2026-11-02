import SwiftUI
import AppKit

// MARK: - Settings, then Apple Intelligence

struct IntelligenceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let db = model.db
        let status = Intelligence.status
        Form {
            Section {
                Label {
                    Text(Intelligence.statusText).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: status == .available ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(status == .available ? Color.appGreen : Color.ink2)
                }
                if status == .turnedOff {
                    Button("Open Apple Intelligence & Siri Settings…") {
                        if let u = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
                            NSWorkspace.shared.open(u)
                        }
                    }
                }
            } footer: {
                Text("Holocron uses the model built into macOS. Your planner and student records stay on this Mac and are never sent to Apple or anyone else.")
            }

            Section {
                ForEach(AIFeature.allCases) { f in
                    Toggle(isOn: Binding(get: { db.aiEnabled(f) }, set: { db.setAI(f, $0) })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.title)
                            Text(f.blurb).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(status != .available)
                }
            } header: {
                Text("Suggestions")
            }

            Section {
                Toggle(isOn: Binding(get: { db.siriMayUseNames }, set: { db.setSiriMayUseNames($0); model.refreshSiriVocabulary() })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Siri can say and suggest student names")
                        Text("For birthdays, notes, and the student list in Shortcuts. Off by default. Names are never said while the Class screen is showing. You can still log a note by saying a student's name either way.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(HolocronShortcuts.examples, id: \.self) { Text("“\($0)”") }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Button("Open Shortcuts") {
                    if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                        NSWorkspace.shared.openApplication(at: u, configuration: .init())
                    }
                }
            } header: {
                Text("Siri, Spotlight and Shortcuts")
            } footer: {
                Text("Ask Siri, or type into Spotlight. Holocron's actions are also in the Shortcuts app, where you can build them into your own shortcuts. Siri works whether or not Apple Intelligence is on.")
            }
        }
        .settingsForm()
    }
}
