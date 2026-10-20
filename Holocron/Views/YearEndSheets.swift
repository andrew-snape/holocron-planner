import SwiftUI
import AppKit

private func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
    "\(n) " + (n == 1 ? one : (many ?? one + "s"))
}

// MARK: - Archive this year

/// Makes a complete copy of the data folder in Holocron archive. It only copies: the planner,
/// students and settings carry on exactly as they are.
struct ArchiveYearSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var includeShared = false
    @State private var plan: ArchivePlan? = nil
    @State private var working = false
    @State private var result: Result<ArchiveSummary, ArchivePlan.Failure>? = nil

    private var shared: Bool { model.folder.plannerURL != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result {
                finished(result)
            } else {
                form
            }
        }
        .padding(24)
        .frame(width: 500)
        .interactiveDismissDisabled(working)
        .onAppear {
            if label.isEmpty { label = model.archiveYearGuess }
            refresh()
        }
    }

    private func refresh() { plan = model.archivePlan(label: label, includeSharedPlanner: includeShared) }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Archive this year").font(.system(size: 22, weight: .bold))
            Text("Makes a complete copy of your Holocron data. It only copies, so nothing is changed or cleared and you carry on as you are.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Year").font(.system(size: 13, weight: .semibold))
                TextField("Year", text: $label)
                    .textFieldStyle(.roundedBorder).frame(width: 140)
                    .onSubmit { refresh() }
                Text("Saved as \(ArchivePlan.cleanLabel(label)) year end")
                    .font(.system(size: 12)).foregroundStyle(Color.ink3)
            }

            if shared {
                Toggle("Also copy the shared planner folder", isOn: $includeShared)
                    .toggleStyle(.checkbox)
                    .onChange(of: includeShared) { refresh() }
                Text("It is shared with colleagues, so it is left out unless you tick this. Your private lessons and Devotion files are always included.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let plan {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This will copy \(plural(plan.copies.count, "file")) and the student photos into")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    Text(plan.archive.deletingLastPathComponent().path)
                        .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                }
                .card()
                if !plan.waitingOnICloud.isEmpty {
                    Label("Still downloading from iCloud: \(plan.waitingOnICloud.joined(separator: ", ")). Try again in a moment.",
                          systemImage: "icloud.and.arrow.down")
                        .font(.system(size: 12.5)).foregroundStyle(Color.appAmber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("The copy holds real student information. Please keep it only where your school's policy allows.")
                .font(.system(size: 12)).foregroundStyle(Color.ink3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if working {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(plan.map { "Copying \(plural($0.copies.count, "file")) and the student photos" } ?? "Copying files")
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(working)
                Button("Make archive") { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || (plan?.canRun != true))
            }
        }
    }

    private func run() {
        // Plan again with the final name, so the folder name is free and the files on disk are current.
        let p = model.archivePlan(label: label, includeSharedPlanner: includeShared)
        working = true
        Task.detached {
            let r = p.carryOut(version: AppModel.appVersion)
            await MainActor.run {
                working = false
                result = r
            }
        }
    }

    @ViewBuilder
    private func finished(_ r: Result<ArchiveSummary, ArchivePlan.Failure>) -> some View {
        switch r {
        case .success(let s):
            Text("Archive made").font(.system(size: 22, weight: .bold))
            Text("Your data is unchanged. A copy is in")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
            VStack(alignment: .leading, spacing: 6) {
                Text(s.archive.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                Text("\(plural(s.tables.count, "file")) and \(plural(s.photos, "photo")). A README.txt inside lists what is in it.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([s.archive]) }
            }
            .card()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        case .failure(let f):
            Text("No archive was made").font(.system(size: 22, weight: .bold))
            Text(message(f)).font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your data was not changed.").font(.system(size: 12.5)).foregroundStyle(Color.ink3)
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
    }

    private func message(_ f: ArchivePlan.Failure) -> String {
        switch f {
        case .nothingToCopy: return "There are no files to copy yet."
        case .waitingOnICloud(let names): return "Still downloading from iCloud: \(names.joined(separator: ", ")). Try again in a moment."
        case .archiveNotCreated: return "The archive folder could not be created next to your data folder."
        case .copyFailed(let n): return "\(n) could not be copied. Close any other app that has it open, then try again."
        case .checkFailed(let n): return "The copy of \(n) did not match the original, so the archive was removed."
        }
    }
}

// MARK: - Import from folder

/// Shows what an import will replace before anything happens. Replaced files are kept in a
/// "Before import" folder in Holocron archive.
struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var source: URL
    /// Set on first run, when the data folder has not been created yet. It is created only when
    /// Import is pressed.
    var target: DataFolder? = nil
    @State private var scope: ImportScope = .everything
    @State private var working = false
    @State private var includeShared = false
    @State private var plan: ImportPlan? = nil
    @State private var outcome: AppModel.ImportOutcome? = nil

    private var shared: Bool { model.folder.plannerURL != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let outcome { finished(outcome) } else { form }
        }
        .padding(24)
        .frame(width: 520)
        .interactiveDismissDisabled(working)
        .onAppear { refresh() }
    }

    private func refresh() {
        plan = model.importPlan(from: source, scope: scope, includeSharedPlanner: includeShared, into: target)
    }

    private func run(_ p: ImportPlan) {
        model.prepareImport()
        working = true
        Task.detached {
            let r = p.carryOut()
            await MainActor.run {
                working = false
                outcome = model.finishImport(r, into: target)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import from folder").font(.system(size: 22, weight: .bold))
            Text(source.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                .lineLimit(2).truncationMode(.middle)

            Picker("What to import", selection: $scope) {
                ForEach(ImportScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .onChange(of: scope) { refresh() }

            if shared && scope != .students {
                Toggle("Also replace the shared planner files", isOn: $includeShared)
                    .toggleStyle(.checkbox)
                    .onChange(of: includeShared) { refresh() }
                if let plan, !plan.sharedPlannerLeftOut.isEmpty {
                    Text("Your planner folder is shared with colleagues, so its files are left alone unless you tick this.")
                        .font(.system(size: 12)).foregroundStyle(Color.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let plan {
                if plan.problems.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(plan.items) { it in
                            HStack {
                                Text(it.table.rawValue + ".csv").font(.system(size: 12, design: .monospaced))
                                Spacer()
                                Text(line(it)).font(.system(size: 12)).foregroundStyle(Color.ink2)
                            }
                        }
                        if !plan.photos.isEmpty {
                            HStack {
                                Text("photos").font(.system(size: 12, design: .monospaced))
                                Spacer()
                                Text(plural(plan.photos.count, "photo")).font(.system(size: 12)).foregroundStyle(Color.ink2)
                            }
                        }
                    }
                    .card()
                    if plan.replacesSomething {
                        Text("Files this replaces are first copied into a Before import folder in Holocron archive, next to your data folder.")
                            .font(.system(size: 12)).foregroundStyle(Color.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(plan.problems, id: \.self) { p in
                        Label(p, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12.5)).foregroundStyle(Color.appAmber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                if working {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(plan.map { "Importing \(plural($0.items.count, "file")) and \(plural($0.photos.count, "photo"))" } ?? "Importing files")
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(working)
                Button("Import") { if let plan { run(plan) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || plan?.canRun != true)
            }
        }
    }

    private func line(_ it: ImportPlan.Item) -> String {
        if let cur = it.currentRows { return "replaces \(plural(cur, "row")) with \(plural(it.incomingRows, "row"))" }
        return "adds \(plural(it.incomingRows, "row"))"
    }

    @ViewBuilder
    private func finished(_ o: AppModel.ImportOutcome) -> some View {
        switch o {
        case .done(let s):
            Text("Imported").font(.system(size: 22, weight: .bold))
            Text("\(plural(s.imported, "file")) and \(plural(s.photos, "photo")) were brought in.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
            if s.photosSkipped > 0 {
                Text("\(plural(s.photosSkipped, "photo")) could not be copied and were skipped.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.appAmber)
            }
            if let b = s.backup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The files it replaced are in").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    Text(b.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([b]) }
                }
                .card()
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        case .failed(let message):
            Text("Nothing was changed").font(.system(size: 22, weight: .bold))
            Text(message).font(.system(size: 13)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
    }
}
