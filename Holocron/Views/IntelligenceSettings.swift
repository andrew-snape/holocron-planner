import SwiftUI
import AppKit

// MARK: - Settings, then Apple Intelligence

struct IntelligenceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let db = model.db
        let status = Intelligence.status
        Form {
            SettingsPaneHeader(pane: .intelligence)

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
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: Binding(get: { db.reportRules }, set: { db.setReportRules($0) }))
                        .font(.body)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .textBox()
                        .accessibilityLabel("Report comment rules")
                    Text("\(db.reportRules.count) of \(Database.reportRulesLimit) characters")
                        .font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("ILP sentence") {
                    TextField("", text: Binding(get: { db.ilpSentence }, set: { db.setILPSentence($0) }), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Report comments")
            } footer: {
                Text("Your rules are followed in every draft, on top of Holocron's style: plain Australian English, 100 to 150 words, short sentences, positive framing and no labels or scores. For example: \"Mention our school value of Hope\" or \"Avoid the word excellent\". The ILP sentence is added to the end of the general comment for students with Has an ILP ticked, with [name] replaced by their name. Leave it empty to add nothing.")
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
