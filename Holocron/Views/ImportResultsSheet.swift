import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Import results from a spreadsheet
//
// Shows which columns and students a spreadsheet's results will go to before anything is saved.
// Students not on the roll are left out. assessments.csv is copied into Holocron archive first.

/// Asks for a spreadsheet, then opens the import sheet for it.
func chooseResultsFile(_ model: AppModel) {
    let p = NSOpenPanel()
    p.title = "Choose a spreadsheet of results"
    p.message = "An Excel (.xlsx) or CSV export, such as one from Essential Assessment."
    p.prompt = "Choose"
    p.allowedContentTypes = [UTType(filenameExtension: "xlsx"), .commaSeparatedText, .tabSeparatedText].compactMap { $0 }
    p.allowsMultipleSelection = false
    if p.runModal() == .OK, let u = p.url { model.sheet = .importResults(url: u) }
}

struct ImportResultsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var url: URL

    @State private var draft: ResultsDraft? = nil
    @State private var people: [ImportPerson] = []
    /// People matched to the roll when the columns were last set. Kept apart from the pickers so a
    /// row stays in its list while the teacher changes it.
    @State private var matchedIDs: Set<String> = []
    /// People whose student the teacher picked by hand.
    @State private var touched: Set<String> = []
    @State private var results = ResultsDraft.Outcome(rows: [])
    @State private var changes = ResultsChanges([], existing: [])
    @State private var loadError = ""
    @State private var showColumns = false
    @State private var showOthers = false
    @State private var showAllOthers = false
    @State private var suggesting = false
    @State private var suggestError = ""
    @State private var outcome: AppModel.ResultsOutcome? = nil
    @State private var added = 0
    @State private var updated = 0

    /// How many unmatched people to list before Show all.
    private let othersShown = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let outcome {
                finished(outcome)
            } else if !loadError.isEmpty {
                Text("Import results").font(.system(size: 22, weight: .bold))
                Label(loadError, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13)).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
            } else if draft != nil {
                form
            } else {
                ProgressView("Reading \(url.lastPathComponent)").controlSize(.small)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 640, maxWidth: 640)
        .task { await load() }
    }

    // MARK: Loading

    private func load() async {
        guard draft == nil else { return }
        let u = url
        let loaded = await Task.detached { () -> Result<ResultsTable, ResultsTable.Failure> in
            do { return .success(try ResultsTable.load(u)) }
            catch let f as ResultsTable.Failure { return .failure(f) }
            catch { return .failure(.empty) }
        }.value
        switch loaded {
        case .failure(.unreadable(let why)):
            loadError = why
        case .failure:
            loadError = "\(url.lastPathComponent) has no rows of results under a header."
        case .success(let table):
            var d = ResultsDraft(table: table, map: ColumnMap.guess(table.header))
            d.fixedSubject = teachSubjects.first ?? ""
            draft = d
            remap()
            showColumns = !d.map.isComplete || d.map.source.isEmpty
            if !d.map.isComplete && ColumnSuggest.isAvailable { suggest() }
        }
    }

    /// Matches students and subjects after the columns change. Choices the teacher already made
    /// are kept for anyone and any subject still in the file.
    private func remap() {
        guard var d = draft else { return }
        let before = d.assigned
        people = d.people(roster: model.db.roster, remembered: model.db.rememberedImportRefs)
        let ids = Set(people.map(\.id))
        touched = touched.intersection(ids)
        d.assigned = [:]
        for p in people {
            if touched.contains(p.id) { d.assigned[p.id] = before[p.id] }
            else if let s = p.match.studentID { d.assigned[p.id] = s }
        }
        matchedIDs = Set(people.filter { d.assigned[$0.id] != nil }.map(\.id))
        let names = teachSubjects
        let oldSubjects = d.subjectFor
        d.subjectFor = Dictionary(uniqueKeysWithValues: d.subjectValues.map {
            ($0, oldSubjects[$0] ?? ResultsDraft.guessSubject($0, subjects: names))
        })
        draft = d
        recount()
    }

    /// Works out the results and what they change. Called after every edit rather than on every redraw.
    private func recount() {
        guard let d = draft else { return }
        results = d.results()
        changes = ResultsChanges(results.rows, existing: model.db.rows(.assessments))
    }

    private func edit(_ change: (inout ResultsDraft) -> Void) {
        guard var d = draft else { return }
        change(&d)
        draft = d
        recount()
    }

    private func suggest() {
        guard let table = draft?.table else { return }
        suggesting = true
        suggestError = ""
        Task {
            do {
                let m = try await ColumnSuggest.suggest(table)
                draft?.map = m
                remap()
                showColumns = true
            } catch {
                suggestError = "Apple Intelligence could not suggest the columns. Choose them below."
            }
            suggesting = false
        }
    }

    private var teachSubjects: [String] {
        model.db.subjects.filter { $0.kind == "teach" }.map { $0.subject }
    }

    /// Students on the roll given to more than one person in the file.
    private var doubled: [String] {
        guard let d = draft else { return [] }
        var n: [String: Int] = [:]
        for sid in d.assigned.values { n[sid, default: 0] += 1 }
        return n.filter { $0.value > 1 }.map { model.db.studentName($0.key) }.sorted()
    }

    // MARK: Form

    @ViewBuilder
    private var form: some View {
        let d = draft!
        let twice = doubled

        VStack(alignment: .leading, spacing: 4) {
            Text("Import results").font(.system(size: 22, weight: .bold))
            Text(url.lastPathComponent).font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.ink2).lineLimit(1).truncationMode(.middle)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                columnsCard(d)
                if d.map.isComplete {
                    if !d.subjectValues.isEmpty { subjectsCard(d) }
                    studentsCard(d)
                }
            }
        }
        .frame(minHeight: 160, maxHeight: 460)

        if d.map.isComplete {
            summary(students: Set(results.rows.map { $0.s("student_id") }).count)
        }
        if !twice.isEmpty {
            Label("\(twice.joined(separator: ", ")) \(twice.count == 1 ? "is" : "are") picked for more than one person in the file. Choose one, or Leave out the others.",
                  systemImage: "exclamationmark.triangle")
                .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                .fixedSize(horizontal: false, vertical: true)
        }

        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button(changes.isEmpty ? "Import" : "Import \(plural(changes.added.count + changes.updated.count, "result"))") {
                run()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!d.map.isComplete || changes.isEmpty || !twice.isEmpty)
        }
    }

    private func columnsCard(_ d: ResultsDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: d.map.isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(d.map.isComplete ? Color.appGreen : Color.appAmber)
                    .accessibilityHidden(true)
                Text(columnsHeadline(d)).font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(showColumns ? "Hide columns" : "Change columns") { showColumns.toggle() }
                if ColumnSuggest.isAvailable {
                    if suggesting {
                        ProgressView().controlSize(.small).accessibilityLabel("Suggesting columns")
                    } else {
                        Button { suggest() } label: { Label("Suggest columns", systemImage: "apple.intelligence") }
                            .help("Apple Intelligence reads the headers on this Mac and suggests which column is which")
                    }
                }
            }
            if !suggestError.isEmpty {
                Label(suggestError, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showColumns {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(ColumnRole.allCases) { role in
                        GridRow {
                            Text(role.title).font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                                .gridColumnAlignment(.trailing)
                            Picker("", selection: columnBinding(role)) {
                                Text("None").tag(-1)
                                ForEach(Array(d.table.header.enumerated()), id: \.offset) { i, h in
                                    Text(h.isEmpty ? "Column \(i + 1)" : h).tag(i)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 260)
                            .accessibilityLabel(role.title)
                        }
                    }
                    GridRow {
                        Text("Add to comment").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                        Menu(notesTitle(d)) {
                            ForEach(Array(d.table.header.enumerated()), id: \.offset) { i, h in
                                Toggle(h.isEmpty ? "Column \(i + 1)" : h, isOn: noteBinding(i))
                            }
                        }
                        .frame(width: 260)
                        .accessibilityLabel("Columns added to the comment")
                    }
                }
            }
            if d.map[.task] == nil && d.map[.detail] == nil {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Task")
                    TextField("Fractions post-test", text: Binding(get: { draft?.fixedTask ?? "" }, set: { v in edit { $0.fixedTask = v } }))
                        .textFieldStyle(.roundedBorder).frame(width: 240)
                        .accessibilityLabel("Task")
                }
            }
            if d.map[.date] == nil {
                DateField(iso: Binding(get: { draft?.fixedDate ?? todayISO() }, set: { v in edit { $0.fixedDate = v } }))
            }
            if d.map[.subject] == nil {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Subject")
                    Picker("", selection: Binding(get: { draft?.fixedSubject ?? "" }, set: { v in edit { $0.fixedSubject = v } })) {
                        Text("Choose").tag("")
                        ForEach(teachSubjects, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().frame(width: 200)
                    .accessibilityLabel("Subject")
                }
            }
        }
        .card()
    }

    private func columnsHeadline(_ d: ResultsDraft) -> String {
        if !d.map.isComplete { return "Choose the student name and result columns" }
        switch d.map.source {
        case "": return "Columns matched from the headers"
        case "Apple Intelligence": return "Columns suggested by Apple Intelligence. Check them before importing."
        default: return "\(d.map.source) export recognised"
        }
    }

    private func notesTitle(_ d: ResultsDraft) -> String {
        switch d.map.notes.count {
        case 0: return "Nothing"
        case 1, 2: return d.map.notes.map { d.table.header[$0] }.joined(separator: ", ")
        default: return "\(d.map.notes.count) columns"
        }
    }

    private func subjectsCard(_ d: ResultsDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subjects").font(.system(size: 13, weight: .semibold))
            FlowLayout(spacing: 10) {
                ForEach(d.subjectValues, id: \.self) { v in
                    HStack(spacing: 6) {
                        Text(v).font(.system(size: 12.5)).lineLimit(2).help(v)
                            .frame(minWidth: 90, maxWidth: 160, alignment: .trailing)
                        Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Color.ink3)
                            .accessibilityHidden(true)
                        Picker("", selection: Binding(get: { draft?.subjectFor[v] ?? "" }, set: { s in edit { $0.subjectFor[v] = s } })) {
                            Text("Leave out").tag("")
                            ForEach(teachSubjects, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                        .accessibilityLabel("Subject for \(v)")
                    }
                }
            }
        }
        .card()
    }

    private func studentsCard(_ d: ResultsDraft) -> some View {
        let roster = model.db.roster
        let onRoll = people.filter { matchedIDs.contains($0.id) }
        let others = people.filter { !matchedIDs.contains($0.id) }
        let found = Set(d.assigned.values)
        let missing = roster.filter { !found.contains($0.id) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Students").font(.system(size: 13, weight: .semibold))
            if onRoll.isEmpty {
                Text("No students matched. Check the student name column, or match people below.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(plural(onRoll.count, "student")) in the file \(onRoll.count == 1 ? "is" : "are") on your roll. Everyone else is left out.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if !missing.isEmpty && missing.count <= 8 {
                    Text("Not found in the file: " + missing.map(\.fullName).joined(separator: ", "))
                        .font(.system(size: 12)).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !missing.isEmpty {
                    Text("\(plural(missing.count, "student")) on your roll \(missing.count == 1 ? "is" : "are") not in the file.")
                        .font(.system(size: 12)).foregroundStyle(Color.ink2)
                }
            }
            VStack(spacing: 0) {
                ForEach(onRoll) { p in personRow(p, roster: roster) }
            }
            if !others.isEmpty {
                DisclosureGroup(isExpanded: $showOthers) {
                    LazyVStack(spacing: 0) {
                        ForEach(showAllOthers ? others : Array(others.prefix(othersShown))) { p in personRow(p, roster: roster) }
                    }
                    if others.count > othersShown && !showAllOthers {
                        Button("Show all \(others.count)") { showAllOthers = true }
                            .padding(.top, 4)
                    }
                } label: {
                    Text("Not on your roll (\(others.count)). Open to match any of them to a student.")
                        .font(.system(size: 12.5))
                }
            }
        }
        .card()
    }

    private func personRow(_ p: ImportPerson, roster: [Student]) -> some View {
        let chosen = draft?.assigned[p.id]
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 13)).lineLimit(2).help(p.name)
                Text(plural(p.count, "result") + (p.ref.isEmpty ? "" : " · ID \(p.ref)"))
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
            .frame(width: 200, alignment: .leading)
            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Color.ink3)
                .accessibilityHidden(true)
            Picker("", selection: Binding(get: { draft?.assigned[p.id] ?? "" }, set: { v in
                touched.insert(p.id)
                edit { $0.assigned[p.id] = v.isEmpty ? nil : v }
            })) {
                Text("Leave out").tag("")
                ForEach(roster) { Text($0.fullName).tag($0.id) }
            }
            .labelsHidden().frame(width: 200)
            .help(chosen.map { model.db.studentName($0) } ?? "Left out")
            .accessibilityLabel("Student for \(p.name)")
            if case .likely(let sid) = p.match, chosen == sid, !touched.contains(p.id) {
                TagLabel(text: "Check", fg: .appAmber, bg: Color.appAmber.opacity(0.14))
                    .help("The name is close but not the same. Check it is the right student.")
            } else if case .remembered(let sid) = p.match, chosen == sid {
                Text("As last time").font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func summary(students: Int) -> some View {
        let r = results, c = changes
        var parts: [String] = []
        if !c.added.isEmpty { parts.append("adds " + plural(c.added.count, "result")) }
        if !c.updated.isEmpty { parts.append("updates " + plural(c.updated.count, "result") + " saved before") }
        if c.unchanged > 0 { parts.append(plural(c.unchanged, "result") + (c.unchanged == 1 ? " is" : " are") + " already saved") }
        var left: [String] = []
        if r.noSubject > 0 { left.append(plural(r.noSubject, "result") + " with no subject") }
        if r.noDate > 0 { left.append(plural(r.noDate, "result") + " with a date Holocron cannot read") }
        if r.noResult > 0 { left.append(plural(r.noResult, "row") + " with no result") }
        let head: String
        if parts.isEmpty {
            head = results.rows.isEmpty ? "Nothing to import yet. Match at least one student and subject." : "Nothing new to import. These results are already saved."
        } else {
            head = "For \(plural(students, "student")), this " + parts.joined(separator: ", ") + "."
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(head).font(.system(size: 12.5, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !left.isEmpty {
                Text("Left out: " + left.joined(separator: ", ") + ".").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("A copy of your saved results is kept in Holocron archive first. Imported results show in Mark class and each student's Assessment tab.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Bindings

    private func columnBinding(_ role: ColumnRole) -> Binding<Int> {
        Binding(get: { draft?.map[role] ?? -1 }, set: { v in
            draft?.map[role] = v < 0 ? nil : v
            draft?.map.notes.removeAll { $0 == v }
            remap()
        })
    }

    private func noteBinding(_ col: Int) -> Binding<Bool> {
        Binding(get: { draft?.map.notes.contains(col) ?? false }, set: { on in
            edit {
                $0.map.notes.removeAll { $0 == col }
                if on { $0.map.notes.append(col) }
            }
        })
    }

    // MARK: Saving

    private func run() {
        guard let d = draft else { return }
        // Remember only students picked by hand, by the file's ID, so the next export matches them
        // straight away. Leaving out someone matched last time forgets that match.
        var remember: [String: String] = [:]
        for p in people where !p.ref.isEmpty && touched.contains(p.id) {
            if let sid = d.assigned[p.id] {
                if case .exact(let s) = p.match, s == sid { continue }
                remember[p.ref] = sid
            } else if case .remembered = p.match {
                remember[p.ref] = ""
            }
        }
        added = changes.added.count
        updated = changes.updated.count
        outcome = model.importResults(changes, remember: remember)
    }

    @ViewBuilder
    private func finished(_ o: AppModel.ResultsOutcome) -> some View {
        switch o {
        case .done(let backup):
            Text("Imported").font(.system(size: 22, weight: .bold))
            Text([added > 0 ? plural(added, "result") + " added" : "", updated > 0 ? plural(updated, "result") + " updated" : ""]
                    .filter { !$0.isEmpty }.joined(separator: " and ") + ".")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
            if let b = backup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("assessments.csv from before the import is in").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    Text(b.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
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
