import SwiftUI
import AppKit

// MARK: - Settings

/// Settings forms sit on Holocron's grey background, with white rows like the rest of the app.
extension View {
    func settingsForm() -> some View {
        self.formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBG)
            .listRowBackground(Color.cardBG)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, timetable, calendar, updates, data
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .timetable: return "Timetable"
        case .calendar: return "Calendar"
        case .updates: return "Updates"
        case .data: return "Data"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .timetable: return "clock"
        case .calendar: return "calendar"
        case .updates: return "arrow.down.circle"
        case .data: return "externaldrive"
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("settingsTab") private var tabRaw = SettingsTab.general.rawValue
    @State private var ntDate = todayISO()
    @State private var ntLabel = ""
    @State private var showStartOver = false
    /// The subject being made private, while we ask whether to copy its current lessons across.
    @State private var privatePrompt: String? = nil

    private var tab: SettingsTab { SettingsTab(rawValue: tabRaw) ?? .general }

    var body: some View {
        TabView(selection: Binding(get: { tab }, set: { tabRaw = $0.rawValue })) {
            ForEach(SettingsTab.allCases) { t in
                content(for: t)
                    .tabItem { Label(t.title, systemImage: t.symbol) }
                    .tag(t)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: generalTab
        case .timetable: timetableTab
        case .calendar: calendarTab
        case .updates: UpdatesSettings()
        case .data: dataTab
        }
    }

    // MARK: Tabs

    @ViewBuilder private var generalTab: some View {
        let db = model.db
        Form {
            Section {
                LabeledContent("Class name") {
                    TextField(Database.defaultClassName, text: Binding(get: { db.classNameSetting }, set: { db.setClassName($0) }))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 200)
                }
            } footer: {
                Text("Shown at the top of the sidebar and on student summaries and report packs.")
            }

            Section {
                ForEach(NavItem.allCases.filter { $0.canDisable }) { item in
                    Toggle(isOn: Binding(get: { model.isEnabled(item) }, set: { model.setEnabled(item, $0) })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Label(item.title, systemImage: item.symbol)
                            Text(item.blurb).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Modules")
            } footer: {
                Text("Switched-off modules disappear from the sidebar and the Go menu. Your data is kept, and Today always stays on.")
            }
        }
        .settingsForm()
    }

    @ViewBuilder private var timetableTab: some View {
        let db = model.db
        let subjectRows = db.rows(.subjects)
        Form {
            Section {
                ForEach(db.periods) { p in
                    HStack(spacing: 8) {
                        TextField("Name", text: periodBinding(p.period, "name"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: 160)
                        Spacer()
                        DatePicker("Start", selection: timeBinding(p.period, "start"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("to").foregroundStyle(.secondary)
                        DatePicker("End", selection: timeBinding(p.period, "end"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("\(p.minutes) min")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            } header: {
                Text("Periods")
            }

            Section {
                ForEach(subjectRows.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        SubjectNameField(name: subjectRows[i].s("subject"))
                            .frame(width: 160)
                        Picker("Type", selection: cellBinding(.subjects, i, "kind")) {
                            Text("Face to face").tag("teach")
                            Text("Release").tag("release")
                            Text("DOTTL").tag("dottl")
                        }
                        .labelsHidden()
                        .frame(width: 130)
                        ColorPicker("Colour", selection: colourBinding(i), supportsOpacity: false)
                            .labelsHidden()
                        Spacer()
                    }
                }
                Button("Add subject") {
                    var name = "New subject", n = 2
                    while db.subjects.contains(where: { $0.subject == name }) { name = "New subject \(n)"; n += 1 }
                    db.append(.subjects, ["subject": name, "kind": "teach", "colour": "#8A8F94"])
                    db.touch(.subjects)
                }
            } header: {
                Text("Subjects")
            } footer: {
                Text("Release subjects are your specialist lessons and count as release time. To keep a subject's lessons to yourself, use Privacy on the Data tab.")
            }
        }
        .settingsForm()
    }

    @ViewBuilder private var calendarTab: some View {
        let db = model.db
        let termRows = db.rows(.terms)
        let nt = db.rows(.nonteaching).sorted { $0.s("date") < $1.s("date") }
        Form {
            Section {
                ForEach(termRows.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("Term").foregroundStyle(.secondary)
                        TextField("Term", text: cellBinding(.terms, i, "term"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .multilineTextAlignment(.center)
                            .frame(width: 36)
                        TextField("Year", text: cellBinding(.terms, i, "year"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                        Spacer()
                        DatePicker("Start", selection: dateCellBinding(.terms, i, "start"), displayedComponents: .date)
                            .labelsHidden()
                        Text("to").foregroundStyle(.secondary)
                        DatePicker("End", selection: dateCellBinding(.terms, i, "end"), displayedComponents: .date)
                            .labelsHidden()
                        Text("\(weeksIn(termRows[i])) weeks")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                Button("Add term") {
                    let last = db.termsSorted.last
                    let y = last?.year ?? String(yearOf(todayISO()))
                    let n = (Int(last?.term ?? "0") ?? 0) + 1
                    let nextYear = n > 4 ? String((Int(y) ?? yearOf(todayISO())) + 1) : y
                    let nextTerm = n > 4 ? "1" : String(n)
                    let start = last.map { addDays($0.end, 14) } ?? todayISO()
                    db.append(.terms, ["year": nextYear, "term": nextTerm, "start": start, "end": addDays(start, 69)])
                    db.touch(.terms)
                }
            } header: {
                Text("Terms")
            } footer: {
                Text("Week 1 of every term is Week A, so Holocron can show whether it is an A or B week.")
            }

            Section {
                ForEach(nt, id: \Row.["date"]) { n in
                    HStack {
                        Text(dLong(n.s("date")))
                        Text(n.s("label")).foregroundStyle(.secondary)
                        Spacer()
                        DeleteButton {
                            db.remove(.nonteaching, where: { $0.s("date") == n.s("date") })
                            db.touch(.nonteaching)
                        }
                    }
                }
                HStack {
                    DatePicker("Date", selection: isoBinding({ ntDate }, { ntDate = $0 }), displayedComponents: .date)
                        .labelsHidden()
                    TextField("Reason", text: $ntLabel, prompt: Text("Public holiday, pupil free day"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                    Button("Add day") {
                        guard !ntLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        db.append(.nonteaching, ["date": ntDate, "label": ntLabel.trimmingCharacters(in: .whitespaces)])
                        db.touch(.nonteaching)
                        ntLabel = ""
                    }
                    .disabled(ntLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Non-teaching days")
            }
        }
        .settingsForm()
    }

    @ViewBuilder private var dataTab: some View {
        let shared = model.folder.plannerURL != nil
        let subjectNames = model.db.rows(.subjects).map { $0.s("subject") }.filter { !$0.isEmpty }
        Form {
            Section {
                LabeledContent("Folder") {
                    Text(model.folder.url.path)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.folder.url]) }
                    Button("Change folder...") { model.showSetup = true }
                }
            } header: {
                Text("Student folder")
            } footer: {
                Text("Students, lesson notes, assessments, wellbeing, behaviour, reports, photos, your hours log, your to-do list and these settings.")
            }

            Section {
                LabeledContent("Folder") {
                    Text((model.folder.plannerURL ?? model.folder.url).path)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Choose planner folder...") {
                        chooseFolder(title: "Choose the planner folder", create: true) { url in
                            model.showToast(model.usePlannerFolder(url))
                        }
                    }
                    if model.folder.plannerURL != nil {
                        Button("Use the student folder for everything") { model.showToast(model.usePlannerFolder(nil)) }
                        Button("Show in Finder") {
                            if let u = model.folder.plannerURL { NSWorkspace.shared.activateFileViewerSelecting([u]) }
                        }
                    }
                }
            } header: {
                Text("Planner folder")
            } footer: {
                Text("Timetable, lessons, terms, non-teaching days, subjects, periods, units, devotions, quotes and rubrics. Point this at a folder shared in iCloud Drive to sync the planner with colleagues. Choosing a folder keeps any planner files already in it and copies across the ones it is missing. To share it, right-click the folder in Finder, choose Share, then Add People. Changes from colleagues appear when you come back to the app or press Reload.")
            }

            Section {
                if !shared {
                    Label("Your planner is not shared, so these make no difference until you choose a separate planner folder above.", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Toggle(isOn: Binding(
                    get: { model.db.devotionIsPrivate },
                    set: { model.showToast(model.setDevotionPrivate($0)) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Devotion scripts and quotes")
                        Text("The scripts and quotes on the Devotion screen.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .disabled(!shared)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject lessons")
                    Text("Tick a subject to keep the lessons you plan for it to yourself. Colleagues still see the slot on the timetable, and their own lessons are never touched.")
                        .font(.callout).foregroundStyle(.secondary)
                    FlowLayout(spacing: 14) {
                        ForEach(subjectNames, id: \.self) { name in
                            Toggle(name, isOn: Binding(
                                get: { model.isSubjectPrivate(name) },
                                set: { on in
                                    if on && model.sharedLessonCount(name) > 0 { privatePrompt = name }
                                    else { model.setSubjectPrivate(name, on) }
                                }))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Private items are saved in your student folder instead of the shared planner folder, so colleagues do not see or change them. Existing files are copied across and the shared copies are left alone.")
            }

            Section {
                Button("Start over...") { showStartOver = true }
                if DataFolder.isDirectory(model.folder.archiveRoot) {
                    Button("Show archive in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.folder.archiveRoot])
                    }
                }
            } header: {
                Text("Start over")
            } footer: {
                Text("Clear Holocron and begin again with a typical school day and a list of subjects. You can clear just the planner or everything. Your current files are moved into a dated folder in Holocron archive, next to your data folder. Nothing is deleted.")
            }

            Section {
                Button("Reload from folders") { model.reloadFromFolder(toast: "Reloaded") }
                LabeledContent("Version") {
                    Text(AppModel.appVersion).foregroundStyle(.secondary)
                }
            }
        }
        .settingsForm()
        .sheet(isPresented: $showStartOver) { StartOverSheet() }
        .confirmationDialog("Make this subject private?", isPresented: Binding(
            get: { privatePrompt != nil }, set: { if !$0 { privatePrompt = nil } }),
            titleVisibility: .visible, presenting: privatePrompt) { name in
            Button("Copy current lessons across") { model.setSubjectPrivate(name, true, copyLessons: true) }
            Button("Start empty") { model.setSubjectPrivate(name, true) }
            Button("Cancel", role: .cancel) { }
        } message: { name in
            Text("\(name) already has \(model.sharedLessonCount(name)) lessons in the planner. Copying puts them in your private file so you can carry on from there. Either way the shared copies are left as they are.")
        }
    }

    // MARK: Binding helpers

    private func weeksIn(_ t: Row) -> Int {
        let a = t.s("start"), b = t.s("end")
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return daysBetween(mondayOf(a), mondayOf(b)) / 7 + 1
    }

    private func edit(_ t: TableName, _ i: Int, _ key: String, _ v: String) {
        model.db.updateRow(t, at: i) { $0[key] = v }
        model.db.touch(t)
    }

    private func cellBinding(_ t: TableName, _ i: Int, _ key: String) -> Binding<String> {
        Binding(
            get: { let r = model.db.rows(t); return i < r.count ? r[i].s(key) : "" },
            set: { edit(t, i, key, $0) }
        )
    }

    private func dateCellBinding(_ t: TableName, _ i: Int, _ key: String) -> Binding<Date> {
        isoBinding({ let r = model.db.rows(t); return i < r.count ? r[i].s(key) : todayISO() },
                   { edit(t, i, key, $0) })
    }

    private func colourBinding(_ i: Int) -> Binding<Color> {
        Binding(
            get: { let r = model.db.rows(.subjects); return Color(hex: i < r.count ? r[i].s("colour") : "#8A8F94") },
            set: { edit(.subjects, i, "colour", $0.hexString) }
        )
    }

    private func periodBinding(_ per: Int, _ key: String) -> Binding<String> {
        Binding(
            get: { model.db.rows(.periods).first(where: { $0.s("period") == String(per) })?.s(key) ?? "" },
            set: { v in
                model.db.update(.periods, where: { $0.s("period") == String(per) }) { $0[key] = v }
                model.db.touch(.periods)
            }
        )
    }

    private func timeBinding(_ per: Int, _ key: String) -> Binding<Date> {
        Binding(
            get: {
                let t = model.db.rows(.periods).first(where: { $0.s("period") == String(per) })?.s(key) ?? "09:00"
                let v = hm(t) ?? 540
                var c = DateComponents()
                c.year = 2000; c.month = 1; c.day = 1; c.hour = v / 60; c.minute = v % 60
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                let s = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
                model.db.update(.periods, where: { $0.s("period") == String(per) }) { $0[key] = s }
                model.db.touch(.periods)
            }
        )
    }
}

/// Edits a subject's name. The new name is applied when return is pressed or the field loses focus, so the
/// timetable, lessons and results follow the rename in one step instead of being cut loose mid-typing.
private struct SubjectNameField: View {
    @Environment(AppModel.self) private var model
    var name: String
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Subject", text: $draft)
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .focused($focused)
            .onAppear { draft = name }
            .onChange(of: name) { _, new in if !focused { draft = new } }
            .onChange(of: focused) { _, now in if !now { commit() } }
            .onSubmit { commit() }
    }

    private func commit() {
        let new = draft.trimmed
        if new.isEmpty || new == name { draft = name; return }
        if model.db.subjects.contains(where: { $0.subject == new }) {
            draft = name
            model.showToast("There is already a subject called \(new)")
            return
        }
        model.renameSubject(from: name, to: new)
    }
}
