import SwiftUI
import AppKit

// MARK: - Mark the whole class against one task

struct MarkClassView: View {
    @Environment(AppModel.self) private var model
    @State private var subject = ""
    @State private var task = ""
    @State private var date = todayISO()
    @State private var rubric = ""
    @State private var results: [String: String] = [:]
    @State private var comments: [String: String] = [:]
    @State private var reopen = ""
    @AppStorage("resultMode") private var mode = ResultMode.score

    var body: some View {
        let db = model.db
        let roster = db.roster
        let subjects = db.subjects.filter { $0.kind == "teach" }.map { $0.subject }
        let rubs = rubricNames(db)
        let rubOn = !rubric.isEmpty && rubs.contains(rubric)
        let elements = rubOn ? rubricElements(db, rubric) : []
        let started = startedTasks(db)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Mark class").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                    Text("One task, the whole roll, saved in a single pass").font(.system(size: 13)).foregroundStyle(Color.ink2)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel(text: "Subject")
                            Picker("", selection: $subject) {
                                Text("Choose").tag("")
                                ForEach(subjects, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }
                        if !rubs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel(text: "Rubric")
                                Picker("", selection: $rubric) {
                                    Text("None").tag("")
                                    ForEach(rubs, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: 200)
                            }
                        }
                        if rubOn {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel(text: "Element")
                                Picker("", selection: $task) {
                                    Text("Choose an element").tag("")
                                    ForEach(elements, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: 220)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel(text: "Task", hint: "press return to load")
                                TextField("Fractions post-test", text: $task)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 240)
                                    .onSubmit { loadExisting() }
                            }
                        }
                        DateField(iso: $date)
                        if !rubOn {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel(text: "Result")
                                ResultModePicker(mode: $mode)
                            }
                        }
                    }
                    if rubOn, !task.isEmpty { RubricDescriptors(rubric: rubric, element: task) }
                    if !started.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel(text: "Or reopen a task you have already started")
                            Picker("", selection: $reopen) {
                                Text("Choose a task").tag("")
                                ForEach(started, id: \.key) { t in
                                    Text("\(t.subject): \(t.task) · \(shortDate(t.date)) · \(t.n) marked").tag(t.key)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 420)
                            .onChange(of: reopen) { _, k in openStarted(k, started) }
                        }
                    }
                }
                .card()

                if roster.isEmpty {
                    EmptyNote(title: "No students on the roll", message: "Add them under Students first.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(roster) { s in
                            HStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    Avatar(student: s, size: 30)
                                    Text(s.fullName).font(.system(size: 13.5))
                                }
                                .frame(width: 210, alignment: .leading)
                                if rubOn {
                                    Picker("", selection: bindResult(s.id)) {
                                        Text("Not yet").tag("")
                                        ForEach(Lists.rubricLevels, id: \.self) { Text($0).tag($0) }
                                    }
                                    .labelsHidden()
                                    .frame(width: 170)
                                } else if mode == .level {
                                    LevelPicker(value: bindResult(s.id))
                                        .frame(width: 170)
                                } else {
                                    TextField("Result", text: bindResult(s.id))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 170)
                                }
                                TextField("Comment", text: bindComment(s.id))
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            Divider()
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    HStack(spacing: 12) {
                        Button("Save the whole class") { save() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut("s", modifiers: .command)
                        Text("Blank rows are skipped. Clearing a row that was saved before removes it.")
                            .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                }
            }
            .padding(24)
        }
        .onChange(of: date) { _, _ in loadExisting() }
        .onChange(of: task) { _, _ in if rubOn { loadExisting() } }
        .onChange(of: subject) { _, _ in loadExisting() }
        .onChange(of: rubric) { _, _ in task = ""; results = [:]; comments = [:] }
    }

    // MARK: Bindings and data

    private func bindResult(_ sid: String) -> Binding<String> {
        Binding(get: { results[sid] ?? "" }, set: { results[sid] = $0 })
    }

    private func bindComment(_ sid: String) -> Binding<String> {
        Binding(get: { comments[sid] ?? "" }, set: { comments[sid] = $0 })
    }

    private func matches(_ a: Row) -> Bool {
        a.s("subject") == subject && a.s("task") == task && a.s("date") == date
    }

    private func loadExisting() {
        results = [:]
        comments = [:]
        guard !task.isEmpty else { return }
        for a in model.db.rows(.assessments) where matches(a) {
            results[a.s("student_id")] = a.s("result")
            comments[a.s("student_id")] = a.s("comment")
        }
        // Show a task the way it was marked: as levels when every result is a level, otherwise as typed text.
        let vals = results.values.filter { !$0.isEmpty }
        if !vals.isEmpty && !vals.allSatisfy({ Lists.rubricLevels.contains($0) }) {
            mode = vals.allSatisfy({ Lists.resultLevels.contains($0) }) ? .level : .score
        }
    }

    struct Started: Hashable {
        var key: String
        var subject: String
        var task: String
        var date: String
        var n: Int
    }

    private func startedTasks(_ db: Database) -> [Started] {
        var map: [String: Started] = [:]
        for a in db.rows(.assessments) {
            let k = a.s("subject") + "|" + a.s("task") + "|" + a.s("date")
            if var x = map[k] { x.n += 1; map[k] = x }
            else { map[k] = Started(key: k, subject: a.s("subject"), task: a.s("task"), date: a.s("date"), n: 1) }
        }
        return Array(map.values.sorted { $0.date > $1.date }.prefix(15))
    }

    private func openStarted(_ key: String, _ list: [Started]) {
        guard let t = list.first(where: { $0.key == key }) else { return }
        subject = t.subject
        task = t.task
        date = t.date
        loadExisting()
    }

    private func save() {
        let db = model.db
        let sub = subject.trimmingCharacters(in: .whitespaces)
        let tk = task.trimmingCharacters(in: .whitespaces)
        guard !sub.isEmpty, !tk.isEmpty else {
            model.showToast("Choose a subject and a task first")
            return
        }
        var saved = 0, removed = 0
        for s in db.roster {
            let res = (results[s.id] ?? "").trimmingCharacters(in: .whitespaces)
            let com = (comments[s.id] ?? "").trimmingCharacters(in: .whitespaces)
            let isMine: (Row) -> Bool = {
                $0.s("student_id") == s.id && $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
            }
            let exists = db.rows(.assessments).contains(where: isMine)
            if res.isEmpty && com.isEmpty {
                if exists { db.remove(.assessments, where: isMine); removed += 1 }
            } else if exists {
                db.update(.assessments, where: isMine) { $0["result"] = res; $0["comment"] = com }
                saved += 1
            } else {
                db.append(.assessments, ["id": uid(), "student_id": s.id, "date": date, "subject": sub,
                                         "task": tk, "result": res, "comment": com])
                saved += 1
            }
        }
        db.touch(.assessments)
        model.showToast(removed > 0 ? "Saved \(saved), removed \(removed)" : "Saved \(saved) result\(saved == 1 ? "" : "s")")
    }
}

func rubricNames(_ db: Database) -> [String] {
    var seen: [String] = []
    for r in db.rows(.rubrics) where !r.s("rubric").isEmpty && !seen.contains(r.s("rubric")) { seen.append(r.s("rubric")) }
    return seen
}

func rubricElements(_ db: Database, _ name: String) -> [String] {
    var seen: [String] = []
    let rows = db.rows(.rubrics).filter { $0.s("rubric") == name }.sorted { (Int($0.s("order")) ?? 0) < (Int($1.s("order")) ?? 0) }
    for r in rows where !seen.contains(r.s("element")) { seen.append(r.s("element")) }
    return seen
}

struct RubricDescriptors: View {
    @Environment(AppModel.self) private var model
    var rubric: String
    var element: String

    var body: some View {
        let rows = model.db.rows(.rubrics).filter { $0.s("rubric") == rubric && $0.s("element") == element }
        if !rows.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Lists.rubricLevels, id: \.self) { l in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l).font(.system(size: 12.5, weight: .semibold))
                        Text(rows.first(where: { $0.s("level") == l })?.s("descriptor") ?? "")
                            .font(.system(size: 12)).foregroundStyle(Color.ink2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Hours

struct TermHours: Identifiable {
    var term: Term
    var full: Database.Minutes
    var sofar: Database.Minutes
    var id: String { term.id }
}

struct HoursView: View {
    @Environment(AppModel.self) private var model
    @State private var date = todayISO()
    @State private var type = Lists.dottlTypes[0]
    @State private var minutes = "60"
    @State private var note = ""

    var body: some View {
        let db = model.db
        let today = todayISO()
        let ts = db.termsSorted
        let t = db.termOf(today) ?? ts.first(where: { $0.start > today }) ?? ts.last
        let fn = db.fortnightMinutes()
        let year = t?.year ?? String(yearOf(today))
        let yearTerms = ts.filter { $0.year == year }
        let dt = db.dottlMinutes(t?.start ?? today, t?.end ?? today)
        let dtTotal = dt.values.reduce(0, +)
        let dtSorted = dt.sorted { $0.value > $1.value }
        let log = Array(db.rows(.dottl).sorted { $0.s("date") > $1.s("date") }.prefix(14))
        let termStats: [TermHours] = yearTerms.map { x in
            TermHours(term: x,
                      full: db.rangeMinutes(x.start, x.end),
                      sofar: db.rangeMinutes(x.start, today < x.end ? today : x.end))
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Hours").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                    Text("Face to face worked out from the timetable, DOTTL from your log")
                        .font(.system(size: 13)).foregroundStyle(Color.ink2)
                    Spacer()
                }
                HStack(spacing: 12) {
                    stat(hrs(fn.teach), "Face to face per fortnight")
                    stat(hrs(Double(fn.teach) / 2), "Face to face, weekly average")
                    stat(hrs(fn.release), "Release per fortnight")
                    stat(hrs(dtTotal), "Logged DOTTL this term")
                }

                SectionTitle("\(year) by term")
                VStack(spacing: 0) {
                    headerRow(["Term", "Dates", "School days", "F2F so far", "F2F whole term", "Release"])
                    ForEach(termStats) { x in
                        row([("Term " + x.term.term), "\(shortDate(x.term.start)) to \(shortDate(x.term.end))",
                             String(x.full.days), hrs(x.sofar.teach), hrs(x.full.teach), hrs(x.full.release)], bold: false)
                    }
                    row(["Year", "", String(termStats.reduce(0) { $0 + $1.full.days }), "",
                         hrs(termStats.reduce(0) { $0 + $1.full.teach }),
                         hrs(termStats.reduce(0) { $0 + $1.full.release })], bold: true)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SectionTitle("DOTTL log")
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(spacing: 12) {
                        DateField(iso: $date)
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel(text: "Type")
                            Picker("", selection: $type) {
                                ForEach(Lists.dottlTypes, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 210)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel(text: "Minutes")
                            TextField("", text: $minutes).textFieldStyle(.roundedBorder).frame(width: 80)
                        }
                    }
                    LineField(label: "Note", text: $note)
                    Button("Add entry") {
                        db.addDottl(date: date, type: type, minutes: Int(minutes) ?? 0,
                                    note: note.trimmingCharacters(in: .whitespaces))
                        note = ""
                        model.showToast("Saved")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .card()

                if !dtSorted.isEmpty {
                    VStack(spacing: 0) {
                        headerRow(["Type this term", "Total"])
                        ForEach(dtSorted, id: \.key) { kv in
                            row([kv.key, hrs(kv.value) + " hrs"], bold: false)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if log.isEmpty {
                    EmptyNote(title: "Nothing logged yet", message: "Meetings, PD, camps and parent teacher evenings all count here.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(log, id: \Row.["id"]) { r in
                            HStack(spacing: 12) {
                                Text(shortDate(r.s("date"))).frame(width: 70, alignment: .leading)
                                Text(r.s("type")).frame(width: 190, alignment: .leading)
                                Text(hrs(Int(r.s("minutes")) ?? 0) + " hrs").frame(width: 70, alignment: .leading)
                                Text(r.s("note")).foregroundStyle(Color.ink2).lineLimit(1)
                                Spacer()
                                DeleteButton { db.deleteRow(.dottl, id: r.s("id")) }
                            }
                            .font(.system(size: 13))
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            Divider()
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(24)
        }
    }

    private func stat(_ n: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(n).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 12)).foregroundStyle(Color.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func headerRow(_ cols: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, c in
                Text(c).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.03))
    }

    private func row(_ cols: [String], bold: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Array(cols.enumerated()), id: \.offset) { _, c in
                    Text(c).font(.system(size: 13, weight: bold ? .bold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            Divider()
        }
    }
}

struct DeleteButton: View {
    var action: () -> Void
    @State private var armed = false

    var body: some View {
        Button {
            if armed { action() } else { armed = true }
        } label: {
            Text(armed ? "Click again" : "Delete")
                .font(.system(size: 12))
                .foregroundStyle(armed ? Color.appRed : Color.ink2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings

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
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("settingsTab") private var tabRaw = SettingsTab.general.rawValue
    @State private var ntDate = todayISO()
    @State private var ntLabel = ""
    @State private var showStartOver = false

    private var tab: SettingsTab { SettingsTab(rawValue: tabRaw) ?? .general }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.system(size: 28, weight: .bold)).tracking(-0.5)
            Picker("", selection: Binding(get: { tab }, set: { tabRaw = $0.rawValue })) {
                ForEach(SettingsTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 540)
            ScrollView {
                Group {
                    switch tab {
                    case .general: generalTab
                    case .timetable: timetableTab
                    case .calendar: calendarTab
                    case .updates: UpdatesSettings()
                    case .data: dataTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .id(tab)
        }
        .padding([.horizontal, .top], 24)
        .frame(maxWidth: 860, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Tabs

    @ViewBuilder private var generalTab: some View {
        let db = model.db
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Class")
            HStack(spacing: 10) {
                Text("Class name").font(.system(size: 13.5, weight: .medium))
                Spacer()
                TextField(Database.defaultClassName, text: Binding(get: { db.classNameSetting }, set: { db.setClassName($0) }))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("Shown at the top of the sidebar and on student summaries and report packs.")
                .font(.system(size: 12)).foregroundStyle(Color.ink3)

            SectionTitle("Modules")
            VStack(spacing: 0) {
                ForEach(NavItem.allCases.filter { $0.canDisable }) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 22).foregroundStyle(Color.ink2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.system(size: 13.5, weight: .medium))
                            Text(item.blurb).font(.system(size: 12)).foregroundStyle(Color.ink2)
                        }
                        Spacer(minLength: 8)
                        Toggle("", isOn: Binding(get: { model.isEnabled(item) },
                                                 set: { model.setEnabled(item, $0) }))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    Divider()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("Switched-off modules disappear from the sidebar and the Go menu. Your data is kept, and Today and Settings always stay on.")
                .font(.system(size: 12)).foregroundStyle(Color.ink3)

        }
    }

    @ViewBuilder private var timetableTab: some View {
        let db = model.db
        let subjectRows = db.rows(.subjects)
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Periods")
            VStack(spacing: 0) {
                ForEach(db.periods) { p in
                    FlowLayout(spacing: 12) {
                        TextField("", text: periodBinding(p.period, "name")).textFieldStyle(.roundedBorder).frame(width: 190)
                        DatePicker("", selection: timeBinding(p.period, "start"), displayedComponents: .hourAndMinute).labelsHidden()
                        Text("to").foregroundStyle(Color.ink2)
                        DatePicker("", selection: timeBinding(p.period, "end"), displayedComponents: .hourAndMinute).labelsHidden()
                        Text("\(p.minutes) min").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    Divider()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            SectionTitle("Subjects")
            VStack(spacing: 0) {
                ForEach(subjectRows.indices, id: \.self) { i in
                    FlowLayout(spacing: 12) {
                        TextField("", text: cellBinding(.subjects, i, "subject")).textFieldStyle(.roundedBorder).frame(width: 190)
                        Picker("", selection: cellBinding(.subjects, i, "kind")) {
                            Text("Face to face").tag("teach")
                            Text("Release").tag("release")
                            Text("DOTTL").tag("dottl")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        ColorPicker("", selection: colourBinding(i), supportsOpacity: false).labelsHidden()
                        SubjectChip(name: subjectRows[i].s("subject"))
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    Divider()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button("Add subject") {
                db.append(.subjects, ["subject": "New subject", "kind": "teach", "colour": "#8A8F94"])
                db.touch(.subjects)
            }

        }
    }

    @ViewBuilder private var calendarTab: some View {
        let db = model.db
        let termRows = db.rows(.terms)
        let nt = db.rows(.nonteaching).sorted { $0.s("date") < $1.s("date") }
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Terms")
            VStack(spacing: 0) {
                ForEach(termRows.indices, id: \.self) { i in
                    FlowLayout(spacing: 12) {
                        TextField("Year", text: cellBinding(.terms, i, "year")).textFieldStyle(.roundedBorder).frame(width: 70)
                        TextField("Term", text: cellBinding(.terms, i, "term")).textFieldStyle(.roundedBorder).frame(width: 50)
                        DatePicker("", selection: dateCellBinding(.terms, i, "start"), displayedComponents: .date).labelsHidden()
                        Text("to").foregroundStyle(Color.ink2)
                        DatePicker("", selection: dateCellBinding(.terms, i, "end"), displayedComponents: .date).labelsHidden()
                        Text("\(weeksIn(termRows[i])) weeks").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    Divider()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button("Add term") {
                let last = db.termsSorted.last
                let y = last?.year ?? String(yearOf(todayISO()))
                let n = (Int(last?.term ?? "0") ?? 0) + 1
                let nextYear = n > 4 ? String((Int(y) ?? 2026) + 1) : y
                let nextTerm = n > 4 ? "1" : String(n)
                let start = last.map { addDays($0.end, 14) } ?? todayISO()
                db.append(.terms, ["year": nextYear, "term": nextTerm, "start": start, "end": addDays(start, 69)])
                db.touch(.terms)
            }

            SectionTitle("Non-teaching days")
            VStack(alignment: .leading, spacing: 10) {
                FlowLayout(spacing: 12) {
                    DateField(iso: $ntDate)
                    LineField(label: "Reason", text: $ntLabel, placeholder: "Public holiday, pupil free day")
                        .frame(width: 260)
                }
                Button("Add day") {
                    guard !ntLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    db.append(.nonteaching, ["date": ntDate, "label": ntLabel.trimmingCharacters(in: .whitespaces)])
                    db.touch(.nonteaching)
                    ntLabel = ""
                }
            }
            .card()
            VStack(spacing: 0) {
                ForEach(nt, id: \Row.["date"]) { n in
                    HStack(spacing: 12) {
                        Text(dLong(n.s("date"))).frame(width: 120, alignment: .leading)
                        Text(n.s("label")).foregroundStyle(Color.ink2)
                        Spacer()
                        DeleteButton {
                            db.remove(.nonteaching, where: { $0.s("date") == n.s("date") })
                            db.touch(.nonteaching)
                        }
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 7).padding(.horizontal, 12)
                    Divider()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        }
    }

    @ViewBuilder private var dataTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Data")
            Text("Everything is written straight to CSV files. You can edit them in Numbers and reload here. The data is split in two folders so the planner can be shared with other staff while student records stay with you.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").foregroundStyle(Color.ink2)
                    Text("Student folder").font(.system(size: 14, weight: .semibold))
                    TagLabel(text: "Private")
                }
                Text("Students, lesson notes, assessments, wellbeing, behaviour, reports, photos, your hours log, your to-do list and these settings.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                Text(model.folder.url.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.folder.url]) }
                    Button("Change folder...") { model.showSetup = true }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill").foregroundStyle(Color.ink2)
                    Text("Planner folder").font(.system(size: 14, weight: .semibold))
                    TagLabel(text: model.folder.plannerURL == nil ? "Same as student folder" : "Separate",
                             fg: model.folder.plannerURL == nil ? Color.ink2 : Color.appGreen,
                             bg: model.folder.plannerURL == nil ? Color.black.opacity(0.06) : Color.appGreen.opacity(0.14))
                }
                Text("Timetable, lessons, terms, non-teaching days, subjects, periods, units, devotions, quotes and rubrics. Point this at a folder shared in iCloud Drive to sync the planner with colleagues.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                Text((model.folder.plannerURL ?? model.folder.url).path)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
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
                Text("Choosing a folder keeps any planner files already in it and copies across the ones it is missing. To share it, right-click the folder in Finder, choose Share, then Add People. Others choose the same folder here after accepting. Changes from colleagues appear when you come back to the app or press Reload.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink3)
            }
            .card()

            SectionTitle("Start over")
            VStack(alignment: .leading, spacing: 8) {
                Text("Clear Holocron and begin again with a typical school day and a list of subjects. You can clear just the planner or everything. Your current files are moved into a dated folder in Holocron archive, next to your data folder. Nothing is deleted.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Start over...") { showStartOver = true }
                    if DataFolder.isDirectory(model.folder.archiveRoot) {
                        Button("Show archive in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([model.folder.archiveRoot])
                        }
                    }
                }
            }
            .card()
            .sheet(isPresented: $showStartOver) { StartOverSheet() }

            HStack {
                Button("Reload from folders") {
                    model.flushNow(wait: true)
                    model.loadAll()
                    model.showToast("Reloaded")
                }
                Text("Version \(AppModel.appVersion)").font(.system(size: 12)).foregroundStyle(Color.ink3)
            }
        }
    }

    // MARK: Binding helpers

    private func weeksIn(_ t: Row) -> Int {
        let a = t.s("start"), b = t.s("end")
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return daysBetween(mondayOf(a), mondayOf(b)) / 7 + 1
    }

    private func edit(_ t: TableName, _ i: Int, _ key: String, _ v: String) {
        var r = model.db.rows(t)
        guard i < r.count else { return }
        r[i][key] = v
        model.db.setRows(t, r)
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
                c.year = 2026; c.month = 1; c.day = 1; c.hour = v / 60; c.minute = v % 60
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
