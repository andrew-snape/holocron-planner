import SwiftUI
import AppKit

/// Confirms a Start over, carries it out, then shows where the old files went.
struct StartOverSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// The gentler choice is picked by default.
    @State private var scope: StartOverScope = .plannerOnly
    @State private var outcome: AppModel.StartOverOutcome? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let outcome {
                result(outcome)
            } else {
                confirm
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private var shared: Bool { model.folder.plannerURL != nil }

    // MARK: Confirm

    private var confirm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start over").font(.system(size: 22, weight: .bold))
            Text("Choose what to clear. Holocron then begins again with a typical school day and a list of subjects.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Picker("What to clear", selection: $scope) {
                ForEach(StartOverScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(detail(scope))
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)

            if shared {
                Label("Your planner folder is a separate folder that may be shared with colleagues. It will be disconnected, not cleared, so everyone else keeps their planner. You can connect it again in Settings, then Data.",
                      systemImage: "person.2.fill")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your current files will be moved into a dated folder in")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                Text(model.folder.archiveRoot.path)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                Text("Nothing is deleted. To go back, copy the files from there into your data folder and press Shift+Cmd+R.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Start over", role: .destructive) { outcome = model.startOver(scope) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appRed)
            }
        }
    }

    private func detail(_ s: StartOverScope) -> String {
        switch s {
        case .plannerOnly:
            return "Clears the timetable, lessons, terms, non-teaching days, whole-day changes such as camps, subjects, periods, units, devotions, quotes and rubrics. Students and their records, photos, hours, your to-do list and settings are kept."
        case .everything:
            return "Clears everything: students and their records, photos, hours, your to-do list, settings such as the class name and modules, and the whole planner. Holocron opens as it did on the first day."
        }
    }

    // MARK: Result

    @ViewBuilder
    private func result(_ o: AppModel.StartOverOutcome) -> some View {
        switch o {
        case .done(let archive, let disconnected):
            Text("Holocron has started over").font(.system(size: 22, weight: .bold))
            Text("Add your term dates in Settings, then Calendar, and adjust the periods and subjects in Settings, then Timetable.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if let archive {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your old files are in").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    Text(archive.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([archive]) }
                }
                .card()
            }
            if disconnected {
                Text("The separate planner folder was disconnected and left as it was.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        case .failed(let message):
            Text("Nothing was changed").font(.system(size: 22, weight: .bold))
            Text(message)
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
