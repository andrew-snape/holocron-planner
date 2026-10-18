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
        // Who already has a result for this task, found in one pass instead of once per student.
        let already = Set(db.rows(.assessments).filter {
            $0.s("subject") == sub && $0.s("task") == tk && $0.s("date") == date
        }.map { $0.s("student_id") })
        for s in db.roster {
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
        model.showToast(removed > 0 ? "Saved \(saved), removed \(removed)" : "Saved \(saved) result\(saved == 1 ? "" : "s")")
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
