import SwiftUI
import AppKit

// MARK: - Mark the whole class against one task

/// A box in the class list that Return moves down, one student at a time.
private enum MarkField: Hashable {
    case result(String)
    case comment(String)
}

/// Mark class has two views: marking one task, and the whole class's results in one grid.
struct MarkClassView: View {
    @Environment(AppModel.self) private var model
    @State private var book = false

    var body: some View {
        Group {
            if book { MarkbookView() } else { MarkClassForm() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $book) {
                    Text("Mark a task").tag(false)
                    Text("Markbook").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .accessibilityLabel("Mark class view")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { model.sheet = .groups } label: { Label("Groups…", systemImage: "person.3") }
                    .help("Make or change groups of students")
            }
        }
    }
}

private struct MarkClassForm: View {
    @Environment(AppModel.self) private var model
    @State private var groupID = ""
    @FocusState private var focus: MarkField?
    @State private var subject = ""
    @State private var task = ""
    @State private var date = todayISO()
    @State private var rubric = ""
    @State private var results: [String: String] = [:]
    @State private var comments: [String: String] = [:]
    @State private var done: Set<String> = []
    @State private var reopen = ""
    @AppStorage("resultMode") private var mode = ResultMode.score

    var body: some View {
        let db = model.db
        let roster = shownRoster(db)
        let subjects = db.subjects.filter { $0.kind == "teach" }.map { $0.subject }
        let rubs = rubricNames(db)
        let rubOn = !rubric.isEmpty && rubs.contains(rubric)
        let elements = rubOn ? rubricElements(db, rubric) : []
        let started = startedTasks(db)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                        if !db.studentGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel(text: "Group")
                                Picker("", selection: $groupID) {
                                    Text("Whole class").tag("")
                                    ForEach(db.studentGroups) { Text($0.name).tag($0.id) }
                                }
                                .labelsHidden()
                                .frame(width: 170)
                            }
                        }
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
                                    Text("\(t.subject): \(t.task) · \(shortDate(t.date)) · \(t.n) \(t.n == 1 ? "student" : "students")").tag(t.key)
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
                    EmptyNote(title: "No students on the roll", message: "Add them under Students first.",
                              actionTitle: model.isEnabled(.students) ? "Add student" : nil) { model.sheet = .newStudent }
                } else {
                    VStack(spacing: 0) {
                        ForEach(roster) { s in
                            HStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    Avatar(student: s, size: 30)
                                    Text(s.fullName).font(.bodyLarge)
                                }
                                .frame(width: 210, alignment: .leading)
                                Toggle("Done", isOn: bindDone(s.id))
                                    .toggleStyle(.checkbox)
                                    .frame(width: 70, alignment: .leading)
                                    .accessibilityLabel("Done, \(s.fullName)")
                                    .help("Tick when \(s.fullName) has finished the task")
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
                                        .focused($focus, equals: .result(s.id))
                                        .onSubmit { focus = nextID(after: s.id, in: roster).map { MarkField.result($0) } }
                                }
                                TextField("Comment", text: bindComment(s.id))
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focus, equals: .comment(s.id))
                                    .onSubmit { focus = nextID(after: s.id, in: roster).map { MarkField.comment($0) } }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            Divider()
                        }
                    }
                    .background(Color.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
                    .hairlineEdge(Radius.panel)
                    HStack(spacing: 12) {
                        Button("Save the whole class") { save() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut("s", modifiers: .command)
                        Text("Return moves to the next student. Blank rows are skipped. With a group chosen, only its students are saved. Clearing a row that was saved before removes it. Ticks for Done are saved too.")
                            .font(.caption1).foregroundStyle(Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Mark class")
        .navigationSubtitle("One task, the whole roll, saved in a single pass")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { chooseResultsFile(model) } label: { Label("Import results…", systemImage: "square.and.arrow.down") }
                    .help("Bring in results from a spreadsheet, such as an Essential Assessment export")
            }
        }
        .onChange(of: date) { _, _ in loadExisting() }
        .onChange(of: task) { _, _ in if rubOn { loadExisting() } }
        .onChange(of: subject) { _, _ in loadExisting() }
        .onChange(of: rubric) { _, _ in task = ""; results = [:]; comments = [:]; done = [] }
    }

    // MARK: Bindings and data

    /// The student below this one on the roll, or nil at the end.
    /// The students on show: the whole roll, or one group's students.
    private func shownRoster(_ db: Database) -> [Student] {
        guard !groupID.isEmpty, let g = db.studentGroups.first(where: { $0.id == groupID }) else { return db.roster }
        return db.members(of: g)
    }

    private func nextID(after id: String, in roster: [Student]) -> String? {
        guard let i = roster.firstIndex(where: { $0.id == id }), i + 1 < roster.count else { return nil }
        return roster[i + 1].id
    }

    private func bindResult(_ sid: String) -> Binding<String> {
        Binding(get: { results[sid] ?? "" }, set: { results[sid] = $0 })
    }

    private func bindComment(_ sid: String) -> Binding<String> {
        Binding(get: { comments[sid] ?? "" }, set: { comments[sid] = $0 })
    }

    private func bindDone(_ sid: String) -> Binding<Bool> {
        Binding(get: { done.contains(sid) }, set: { on in
            if on { done.insert(sid) } else { done.remove(sid) }
        })
    }

    private func matches(_ a: Row) -> Bool {
        a.s("subject") == subject && a.s("task") == task && a.s("date") == date
    }

    private func loadExisting() {
        results = [:]
        comments = [:]
        done = []
        guard !task.isEmpty else { return }
        for a in model.db.rows(.assessments) where matches(a) {
            results[a.s("student_id")] = a.s("result")
            comments[a.s("student_id")] = a.s("comment")
        }
        for d in model.db.rows(.taskdone) where matches(d) {
            done.insert(d.s("student_id"))
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
        // Count each student once per task, even when they have both a result and a Done tick.
        var people: [String: Set<String>] = [:]
        for a in db.rows(.assessments) + db.rows(.taskdone) {
            let k = a.s("subject") + "|" + a.s("task") + "|" + a.s("date")
            people[k, default: []].insert(a.s("student_id"))
            if map[k] == nil {
                map[k] = Started(key: k, subject: a.s("subject"), task: a.s("task"), date: a.s("date"), n: 0)
            }
        }
        return map.values.map { x in
            var x = x
            x.n = people[x.key]?.count ?? 0
            return x
        }
        .sorted { $0.date > $1.date }
        .prefix(15).map { $0 }
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
        // Who already has a result for this task, found in one pass instead of once per student.
        let already = Set(db.rows(.assessments).filter {
            $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
        }.map { $0.s("student_id") })
        // Only the students on show are changed, so a group never clears the rest of the class.
        let shown = shownRoster(db)
        for s in shown {
            let res = (results[s.id] ?? "").trimmingCharacters(in: .whitespaces)
            let com = (comments[s.id] ?? "").trimmingCharacters(in: .whitespaces)
            let isMine: (Row) -> Bool = {
                $0.s("student_id") == s.id && $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
            }
            let exists = already.contains(s.id)
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

        // Done ticks are one row per student, kept apart from results so they never count as a mark.
        let ticked = Set(db.rows(.taskdone).filter {
            $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
        }.map { $0.s("student_id") })
        var ticksChanged = 0
        for s in shown {
            let isMine: (Row) -> Bool = {
                $0.s("student_id") == s.id && $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
            }
            let on = done.contains(s.id)
            if on && !ticked.contains(s.id) {
                db.append(.taskdone, ["id": uid(), "student_id": s.id, "date": date, "subject": sub, "task": tk])
                ticksChanged += 1
            } else if !on && ticked.contains(s.id) {
                db.remove(.taskdone, where: isMine)
                ticksChanged += 1
            }
        }
        if ticksChanged > 0 { db.touch(.taskdone) }

        var parts: [String] = []
        if saved > 0 || removed > 0 || ticksChanged == 0 {
            parts.append(removed > 0 ? "Saved \(saved), removed \(removed)" : "Saved \(saved) result\(saved == 1 ? "" : "s")")
        }
        if ticksChanged > 0 {
            parts.append("updated \(ticksChanged) Done tick\(ticksChanged == 1 ? "" : "s")")
        }
        model.showToast(parts.joined(separator: ", "))
    }
}

/// Each name once, in the order first seen.
private func uniqueInOrder(_ names: [String]) -> [String] {
    var seen = Set<String>()
    return names.filter { seen.insert($0).inserted }
}

func rubricNames(_ db: Database) -> [String] {
    uniqueInOrder(db.rows(.rubrics).map { $0.s("rubric") }.filter { !$0.isEmpty })
}

func rubricElements(_ db: Database, _ name: String) -> [String] {
    let rows = db.rows(.rubrics).filter { $0.s("rubric") == name }.sorted { (Int($0.s("order")) ?? 0) < (Int($1.s("order")) ?? 0) }
    return uniqueInOrder(rows.map { $0.s("element") })
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
                        Text(l).font(.caption1Semibold)
                        Text(rows.first(where: { $0.s("level") == l })?.s("descriptor") ?? "")
                            .font(.label).foregroundStyle(Color.ink2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fillFaint)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.inset, style: .continuous))
                }
            }
        }
    }
}
