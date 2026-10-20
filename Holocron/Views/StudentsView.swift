import SwiftUI
import AppKit

// MARK: - Students: list on the left, detail on the right

struct StudentsView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var narrow = false

    /// The roster, narrowed by the search field. Matches any part of the full name or the house.
    private var roster: [Student] {
        let all = model.db.roster
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.fullName.localizedCaseInsensitiveContains(q) || $0.house.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        GeometryReader { geo in
            if model.db.roster.isEmpty {
                noStudents
            } else if geo.size.width < 660 {
                compact
            } else {
                wide
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < 660 } action: { narrow = $0 }
        .modifier(StudentSearch(query: $query, active: !model.db.roster.isEmpty && !narrow))
        .onChange(of: query) { _, _ in
            // Keep the detail pane on someone who is in the filtered list.
            if let sel = model.selectedStudent, !roster.contains(where: { $0.id == sel }), let first = roster.first {
                model.selectedStudent = first.id
            }
        }
        .onAppear {
            let db = model.db
            if model.selectedStudent == nil || db.student(model.selectedStudent ?? "") == nil {
                model.selectedStudent = db.roster.first?.id
            }
        }
    }

    private var noStudents: some View {
        VStack(spacing: 14) {
            EmptyNote(title: "No students yet", message: "Add your class to log notes, mark work and build report packs.")
            Button("Add student") { model.sheet = .newStudent }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var wide: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Students").font(.system(size: 17, weight: .bold))
                    Text("\(roster.count)").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    Spacer()
                    Button { model.sheet = .newStudent } label: { Image(systemName: "plus") }
                        .help("Add a student")
                        .accessibilityLabel("Add a student")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(roster) { s in
                            StudentListRow(student: s, selected: model.selectedStudent == s.id)
                                .onTapGesture { model.selectedStudent = s.id }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(model.selectedStudent == s.id ? [.isButton, .isSelected] : .isButton)
                        }
                        if roster.isEmpty {
                            Text("No match for \u{201C}\(query)\u{201D}")
                                .font(.system(size: 13)).foregroundStyle(Color.ink2)
                                .padding(.top, 20)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 236)
            .background(Color.white.opacity(0.6))
            Divider()
            detail
        }
    }

    /// Narrow windows (split screen): a menu of names above the detail instead of the list.
    private var compact: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("", selection: Binding(get: { model.selectedStudent ?? "" },
                                              set: { model.selectedStudent = $0 })) {
                    ForEach(model.db.roster) { s in Text(s.fullName).tag(s.id) }
                }
                .labelsHidden()
                Spacer(minLength: 0)
                Button { model.sheet = .newStudent } label: { Image(systemName: "plus") }
                    .help("Add a student")
                    .accessibilityLabel("Add a student")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        let db = model.db
        Group {
            if let sid = model.selectedStudent, db.student(sid) != nil {
                StudentDetail(sid: sid).id(sid)
            } else {
                VStack {
                    EmptyNote(title: "No student selected", message: "Choose a name on the left.")
                        .padding(40)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The toolbar search field, shown only when the list it filters is on screen.
private struct StudentSearch: ViewModifier {
    @Binding var query: String
    var active: Bool

    func body(content: Content) -> some View {
        if active {
            content.searchable(text: $query, placement: .toolbar, prompt: "Search students")
        } else {
            content
        }
    }
}

struct StudentListRow: View {
    var student: Student
    var selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Avatar(student: student, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(student.fullName).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                if !student.roles.isEmpty {
                    Text(student.roles).font(.system(size: 11)).foregroundStyle(Color.ink2).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(selected ? Color.appBlue.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }
}

enum StudentTab: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case lessons = "Lesson notes"
    case assess = "Assessment"
    case plan = "ILP and NCCD"
    case wellbeing = "Wellbeing"
    case behaviour = "Behaviour"
    case report = "Report"
    case details = "Details"
    var id: String { rawValue }
}

struct StudentDetail: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var tab: StudentTab = .summary

    var body: some View {
        let db = model.db
        if let s = db.student(sid) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(s)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(StudentTab.allCases) { t in
                                Button { tab = t } label: {
                                    Text(t.rawValue)
                                        .font(.system(size: 13, weight: tab == t ? .semibold : .regular))
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 12)
                                        .foregroundStyle(tab == t ? Color.white : Color.primary)
                                        .background(tab == t ? Color.appBlue : Color.black.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    switch tab {
                    case .summary: SummaryTab(sid: sid)
                    case .lessons: LessonNotesTab(sid: sid)
                    case .assess: AssessTab(sid: sid)
                    case .plan: PlanNotesTab(sid: sid)
                    case .wellbeing: WellbeingTab(sid: sid)
                    case .behaviour: BehaviourTab(sid: sid)
                    case .report: ReportTab(sid: sid)
                    case .details: DetailsTab(sid: sid)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private func header(_ s: Student) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                Avatar(student: s, size: 76)
                headerText(s)
                Spacer(minLength: 0)
                headerButtons.layoutPriority(1)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    Avatar(student: s, size: 64)
                    headerText(s)
                }
                headerButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        let flags: [(String, String)] = [("Adjustments", s.adjustments), ("NCCD", s.nccd), ("Medical", s.medical)]
            .filter { !$0.1.isEmpty }
        if !flags.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(flags, id: \.0) { f in
                    HStack(alignment: .top, spacing: 8) {
                        Text(f.0).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2).frame(width: 90, alignment: .leading)
                        Text(f.1).font(.system(size: 13)).textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func headerText(_ s: Student) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.fullName).font(.system(size: 26, weight: .bold)).tracking(-0.4).lineLimit(2)
            FlowLayout(spacing: 6) {
                if !s.house.isEmpty {
                    TagLabel(text: s.house,
                             fg: Color(hex: Lists.houseColours[s.house] ?? "#8E8E93"),
                             bg: Color(hex: Lists.houseColours[s.house] ?? "#8E8E93").opacity(0.14))
                }
                if !s.roles.isEmpty { TagLabel(text: s.roles) }
                if !s.birthdate.isEmpty {
                    Text("Born \(dLong(s.birthdate))").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                }
            }
            if !s.parents.isEmpty {
                Text("Parents: \(s.parents)").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            }
        }
    }

    private var headerButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("SSG or report pack") { model.sheet = .pack(studentID: sid) }
                .buttonStyle(.borderedProminent)
            HStack {
                Button("Change photo") { pickPhoto() }
                Button("Copy as text") { model.copyText(model.db.timelineText(sid)) }
            }
        }
        .fixedSize()
    }

    private func pickPhoto() {
        let p = NSOpenPanel()
        p.title = "Choose a photo"
        p.allowedContentTypes = [.image]
        p.allowsMultipleSelection = false
        if p.runModal() == .OK, let u = p.url {
            model.savePhoto(for: sid, from: u)
        }
    }
}

// MARK: - Shared pieces

struct EntryCard: View {
    var date: String
    var title: String
    var badge: String = ""
    var sub: String = ""
    var text: String
    var tint: Color = .appBlue
    var onDelete: (() -> Void)? = nil
    @State private var armed = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if !badge.isEmpty { TagLabel(text: badge, fg: tint, bg: tint.opacity(0.14)) }
                    Spacer(minLength: 0)
                    Text(dLong(date)).font(.system(size: 11.5)).foregroundStyle(Color.ink2)
                }
                if !text.isEmpty { Text(text).font(.system(size: 13)).textSelection(.enabled) }
                if !sub.isEmpty { Text(sub).font(.system(size: 11.5)).foregroundStyle(Color.ink2) }
            }
            if let del = onDelete {
                Button {
                    if armed { del() } else { armed = true }
                } label: {
                    Image(systemName: armed ? "trash.fill" : "trash")
                        .foregroundStyle(armed ? Color.appRed : Color.ink3)
                }
                .buttonStyle(.plain)
                .help(armed ? "Click again to delete" : "Delete")
                .accessibilityLabel(armed ? "Click again to delete" : "Delete")
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

func timelineTint(_ kind: String) -> Color {
    switch kind {
    case "assess": return .appBlue
    case "plan": return .weekB
    case "well": return .appGreen
    case "beh": return .appAmber
    default: return .ink2
    }
}

struct AddBox<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct DateField: View {
    var label: String = "Date"
    @Binding var iso: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel(text: label)
            DatePicker("", selection: isoBinding({ iso }, { iso = $0 }), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
        }
    }
}

// MARK: - Summary

struct SummaryTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        let items = model.db.timeline(sid)
        if items.isEmpty {
            EmptyNote(title: "Nothing recorded yet", message: "Notes, assessments, wellbeing and behaviour entries appear here, newest first.")
        } else {
            VStack(spacing: 8) {
                ForEach(items) { i in
                    EntryCard(date: i.date, title: i.head, badge: i.badge, sub: i.sub, text: i.body, tint: timelineTint(i.kind))
                }
            }
        }
    }
}

// MARK: - Log lists

/// One student's entries from a log table, newest first, with an empty message when there are none.
/// It sits apart from each tab's form, so typing in a form does not sort the whole table again.
struct LogEntries<Card: View>: View {
    @Environment(AppModel.self) private var model
    var table: TableName
    var sid: String
    var emptyTitle: String
    var emptyMessage: String
    @ViewBuilder var card: (Row) -> Card

    var body: some View {
        let rows = model.db.logRows(table, student: sid)
        ForEach(rows, id: \Row.["id"]) { x in card(x) }
        if rows.isEmpty { EmptyNote(title: emptyTitle, message: emptyMessage) }
    }
}

// MARK: - Lesson notes

struct LessonNotesTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        LessonNoteForm(sid: sid)
        LogEntries(table: .lessonnotes, sid: sid, emptyTitle: "No lesson notes",
                   emptyMessage: "Quick notes you add here or from Quick log appear here.") { x in
            EntryCard(date: x.s("date"), title: (x.s("subject").isEmpty ? "Lesson" : x.s("subject")) + " note",
                      sub: fmtTime(x.s("time")), text: x.s("note"), tint: timelineTint("les")) {
                model.db.deleteRow(.lessonnotes, id: x.s("id"))
            }
        }
    }
}

private struct LessonNoteForm: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var subject = ""
    @State private var note = ""

    var body: some View {
        let db = model.db
        AddBox(title: "Add a lesson note (today)") {
            Picker("Subject", selection: $subject) {
                Text("No subject").tag("")
                ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 260)
            NoteBox(label: "Note", text: $note, lines: 2)
            Button("Add note") {
                let t = note.trimmed
                guard !t.isEmpty else { return }
                db.addLessonNote(students: [sid], subject: subject, note: t)
                note = ""
            }
            .disabled(note.trimmed.isEmpty)
        }
    }
}

// MARK: - Assessment

struct AssessTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        AssessForm(sid: sid)
        LogEntries(table: .assessments, sid: sid, emptyTitle: "No assessments",
                   emptyMessage: "Add a task and a result above.") { x in
            EntryCard(date: x.s("date"),
                      title: (x.s("subject").isEmpty ? "" : x.s("subject") + ": ") + x.s("task"),
                      badge: x.s("result"), text: x.s("comment"), tint: timelineTint("assess")) {
                model.db.deleteRow(.assessments, id: x.s("id"))
            }
        }
    }
}

private struct AssessForm: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var date = todayISO()
    @State private var subject = ""
    @State private var task = ""
    @State private var result = ""
    @State private var comment = ""
    @AppStorage("resultMode") private var mode = ResultMode.score

    var body: some View {
        let db = model.db
        AddBox(title: "Add an assessment") {
            HStack(alignment: .bottom, spacing: 12) {
                DateField(iso: $date)
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Subject")
                    Picker("", selection: $subject) {
                        Text("No subject").tag("")
                        ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
            LineField(label: "Task", text: $task)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    FieldLabel(text: "Result", hint: mode == .score ? "for example 18/20" : "")
                    Spacer()
                    ResultModePicker(mode: $mode)
                }
                if mode == .level {
                    LevelPicker(value: $result, emptyLabel: "Choose a level")
                        .frame(maxWidth: 240, alignment: .leading)
                } else {
                    TextField("", text: $result).textFieldStyle(.roundedBorder)
                }
            }
            NoteBox(label: "Comment", text: $comment, lines: 2)
            Button("Add assessment") {
                db.addAssessment(student: sid, date: date, subject: subject, task: task, result: result, comment: comment)
                task = ""; result = ""; comment = ""
            }
            .disabled(task.trimmingCharacters(in: .whitespaces).isEmpty && result.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - ILP and NCCD

struct PlanNotesTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        PlanNoteForm(sid: sid)
        LogEntries(table: .plannotes, sid: sid, emptyTitle: "No plan notes",
                   emptyMessage: "ILP goals, SSG meetings and NCCD evidence go here.") { x in
            EntryCard(date: x.s("date"), title: x.s("type").isEmpty ? "Plan note" : x.s("type"),
                      text: x.s("note"), tint: timelineTint("plan")) {
                model.db.deleteRow(.plannotes, id: x.s("id"))
            }
        }
    }
}

private struct PlanNoteForm: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var date = todayISO()
    @State private var type = Lists.planNoteTypes[0]
    @State private var note = ""

    var body: some View {
        let db = model.db
        AddBox(title: "Add a plan note") {
            HStack(alignment: .bottom, spacing: 12) {
                DateField(iso: $date)
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Type")
                    Picker("", selection: $type) {
                        ForEach(Lists.planNoteTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
            NoteBox(label: "Note", text: $note, lines: 3)
            Button("Add note") {
                db.addPlanNote(student: sid, date: date, type: type, note: note.trimmed)
                note = ""
            }
            .disabled(note.trimmed.isEmpty)
        }
    }
}

// MARK: - Wellbeing

struct WellbeingTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        WellbeingForm(sid: sid)
        LogEntries(table: .wellbeing, sid: sid, emptyTitle: "No wellbeing entries",
                   emptyMessage: "Log the time and the period lost so it shows in your hours.") { x in
            EntryCard(date: x.s("date"), title: "Wellbeing", sub: model.db.wellbeingDetail(x), text: x.s("note"),
                      tint: timelineTint("well")) {
                model.db.deleteRow(.wellbeing, id: x.s("id"))
            }
        }
    }
}

private struct WellbeingForm: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var date = todayISO()
    @State private var lost = ""
    @State private var minutes = ""
    @State private var note = ""

    var body: some View {
        let db = model.db
        AddBox(title: "Add a wellbeing entry") {
            HStack(alignment: .bottom, spacing: 12) {
                DateField(iso: $date)
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Period lost")
                    Picker("", selection: $lost) {
                        Text("None").tag("")
                        ForEach(db.periods) { p in Text(p.name).tag(String(p.period)) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Minutes")
                    TextField("", text: $minutes).textFieldStyle(.roundedBorder).frame(width: 70)
                }
            }
            NoteBox(label: "Note", text: $note, lines: 3)
            Button("Add entry") {
                db.addWellbeing(students: [sid], date: date, periodLost: lost, minutes: Int(minutes) ?? 0,
                                note: note.trimmed)
                note = ""; minutes = ""; lost = ""
            }
            .disabled(note.trimmed.isEmpty)
        }
    }
}

// MARK: - Behaviour

struct BehaviourTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        BehaviourForm(sid: sid)
        LogEntries(table: .behaviour, sid: sid, emptyTitle: "No behaviour entries",
                   emptyMessage: "Each entry is a date and free text.") { x in
            EntryCard(date: x.s("date"), title: "Behaviour", text: x.s("note"), tint: timelineTint("beh")) {
                model.db.deleteRow(.behaviour, id: x.s("id"))
            }
        }
    }
}

private struct BehaviourForm: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var date = todayISO()
    @State private var note = ""

    var body: some View {
        let db = model.db
        AddBox(title: "Add a behaviour entry") {
            DateField(iso: $date)
            NoteBox(label: "What happened", text: $note, lines: 3)
            Button("Add entry") {
                db.addBehaviour(students: [sid], date: date, note: note.trimmed)
                note = ""
            }
            .disabled(note.trimmed.isEmpty)
        }
    }
}

// MARK: - Report

struct ReportTab: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var sem = ""

    var body: some View {
        let db = model.db
        let current = sem.isEmpty ? db.reportSem() : sem
        let sems = semOptions(current)
        HStack {
            Text("Semester").font(.system(size: 13, weight: .semibold))
            Picker("", selection: Binding(get: { current }, set: { sem = $0 })) {
                ForEach(sems, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            Spacer()
        }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(db.reportSubjects, id: \.self) { subj in
                FlowLayout(spacing: 12) {
                    SubjectChip(name: subj).frame(width: 150, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { db.judgement(sid, sem: current, subject: subj).achievement },
                        set: { db.setJudgement(sid, sem: current, subject: subj, field: "achievement", value: $0) })) {
                        Text("Achievement").tag("")
                        ForEach(Lists.achievement, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                    Picker("", selection: Binding(
                        get: { db.judgement(sid, sem: current, subject: subj).engagement },
                        set: { db.setJudgement(sid, sem: current, subject: subj, field: "engagement", value: $0) })) {
                        Text("Engagement").tag("")
                        ForEach(Lists.engagement, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        let general = db.generalComment(sid, sem: current)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                FieldLabel(text: "General comment")
                Spacer()
                Text("\(wordCount(general)) words").font(.system(size: 11.5)).foregroundStyle(Color.ink2)
            }
            TextEditor(text: Binding(get: { db.generalComment(sid, sem: current) },
                                     set: { db.setGeneralComment(sid, sem: current, text: $0) }))
                .font(.system(size: 13))
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func semOptions(_ current: String) -> [String] {
        let y = yearOf(todayISO())
        var out: [String] = []
        for yr in [y - 1, y, y + 1] {
            out.append("\(yr)-S1")
            out.append("\(yr)-S2")
        }
        if !out.contains(current) { out.append(current) }
        return out
    }
}

// MARK: - Details

struct DetailsTab: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var armDelete = false

    private func bind(_ kp: WritableKeyPath<Student, String>) -> Binding<String> {
        Binding(
            get: { model.db.student(sid)?[keyPath: kp] ?? "" },
            set: { v in
                if var s = model.db.student(sid) {
                    s[keyPath: kp] = v
                    model.db.updateStudent(s)
                }
            }
        )
    }

    var body: some View {
        let s = model.db.student(sid)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LineField(label: "First name", text: bind(\.first))
                LineField(label: "Surname", text: bind(\.surname))
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Birth date")
                    if (s?.birthdate ?? "").isEmpty {
                        Button("Set birth date") { setBirth(todayISO()) }
                    } else {
                        HStack {
                            DatePicker("", selection: isoBinding({ model.db.student(sid)?.birthdate ?? todayISO() }, { setBirth($0) }),
                                       displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                            Button("Clear") { setBirth("") }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "House")
                    Picker("", selection: bind(\.house)) {
                        Text("None").tag("")
                        ForEach(Lists.houseColours.keys.sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }
            LineField(label: "Parents", hint: "names only", text: bind(\.parents))
            LineField(label: "Current responsibilities", hint: "for example SRC or school captain", text: bind(\.roles))
            NoteBox(label: "Adjustments", text: bind(\.adjustments), lines: 2)
            NoteBox(label: "NCCD", text: bind(\.nccd), lines: 2)
            NoteBox(label: "Medical", text: bind(\.medical), lines: 2)
            NoteBox(label: "Notes", text: bind(\.notes), lines: 3)
            Divider()
            Button(armDelete ? "Click again to delete this student and all their notes" : "Delete student", role: .destructive) {
                if !armDelete { armDelete = true; return }
                model.db.removeStudent(sid)
                model.selectedStudent = model.db.roster.first?.id
                model.showToast("Student deleted")
            }
            .foregroundStyle(Color.appRed)
        }
        .card()
    }

    private func setBirth(_ iso: String) {
        if var s = model.db.student(sid) {
            s.birthdate = iso
            model.db.updateStudent(s)
        }
    }
}

// MARK: - New student

struct NewStudentSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var surname = ""

    var body: some View {
        SheetFrame(title: "New student", width: 400) {
            LineField(label: "First name", text: $first)
            LineField(label: "Surname", text: $surname)
            Button("Add student") {
                let f = first.trimmingCharacters(in: .whitespaces)
                guard !f.isEmpty else { return }
                let id = model.db.addStudent(first: f, surname: surname.trimmingCharacters(in: .whitespaces))
                model.selectedStudent = id
                model.nav = .students
                model.showToast("Student added")
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(first.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - SSG or report pack

struct PackSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var studentID: String
    @State private var rangeID = "10w"
    @State private var leaveOutMedical = true

    var body: some View {
        let db = model.db
        let ranges = db.packRanges()
        let range = ranges.first(where: { $0.id == rangeID }) ?? ranges[0]
        SheetFrame(title: "SSG or report pack", subtitle: db.studentName(studentID), width: 640) {
            HStack(spacing: 16) {
                Picker("Period", selection: $rangeID) {
                    ForEach(ranges) { r in Text(r.label).tag(r.id) }
                }
                .frame(width: 260)
                Toggle("Leave out medical details", isOn: $leaveOutMedical)
                Spacer()
            }
            Text("\(dLong(range.from)) to \(dLong(range.to))")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            if let s = db.student(studentID) {
                let data = db.packData(studentID, from: range.from, to: range.to)
                let text = db.packText(s, from: range.from, to: range.to, data: data, leaveOutMedical: leaveOutMedical)
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(minHeight: 260, maxHeight: 360)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack {
                    Button("Copy") { model.copyText(text) }
                    .buttonStyle(.borderedProminent)
                    Button("Save as text file...") { save(text, s) }
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save(_ text: String, _ s: Student) {
        let p = NSSavePanel()
        p.nameFieldStringValue = "\(s.fullName) pack.txt"
        p.allowedContentTypes = [.plainText]
        if p.runModal() == .OK, let u = p.url {
            do {
                try text.write(to: u, atomically: true, encoding: .utf8)
            } catch {
                model.showToast("Could not save the file")
            }
        }
    }
}

// MARK: - Quick log

struct QuickLogView: View {
    @Environment(AppModel.self) private var model
    @State private var selecting = false
    @State private var chosen: Set<String> = []

    var body: some View {
        let db = model.db
        let cols = [GridItem(.adaptive(minimum: 118, maximum: 150), spacing: 12)]
        let counts = db.todaysEntryCounts()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Quick log").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                    Text(selecting ? "Choose several students, then log once" : "Tap a student to add a note")
                        .font(.system(size: 13)).foregroundStyle(Color.ink2)
                    Spacer()
                    Toggle("Select several", isOn: $selecting)
                        .toggleStyle(.switch)
                        .onChange(of: selecting) { _, on in if !on { chosen = [] } }
                    if selecting {
                        Button("Log for \(chosen.count)") { model.sheet = .quick(ids: Array(chosen)) }
                            .buttonStyle(.borderedProminent)
                            .disabled(chosen.isEmpty)
                    }
                }
                if db.roster.isEmpty {
                    EmptyNote(title: "No students yet", message: "Add your class under Students, then log notes from here.")
                } else {
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(db.roster) { s in
                            tile(s, today: counts[s.id] ?? 0)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func tile(_ s: Student, today: Int) -> some View {
        let on = chosen.contains(s.id)
        Button {
            if selecting {
                if on { chosen.remove(s.id) } else { chosen.insert(s.id) }
            } else {
                model.sheet = .quick(ids: [s.id])
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Avatar(student: s, size: 70)
                    if today > 0 {
                        Text("\(today)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.appBlue)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(s.first).font(.system(size: 13, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(on ? Color.appBlue.opacity(0.16) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(on ? Color.appBlue : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(today > 0 ? "\(s.fullName), \(today) logged today" : s.fullName)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

enum QuickKind: String, CaseIterable, Identifiable {
    case lesson = "Lesson note"
    case wellbeing = "Wellbeing"
    case behaviour = "Behaviour"
    var id: String { rawValue }
}

struct QuickLogSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var ids: [String]
    @State private var kind: QuickKind = .lesson
    @State private var subject = ""
    @State private var note = ""
    @State private var lost = ""
    @State private var minutes = ""
    @State private var loaded = false

    var body: some View {
        let db = model.db
        let names = ids.map { db.studentName($0) }.joined(separator: ", ")
        SheetFrame(title: ids.count == 1 ? db.studentName(ids[0]) : "\(ids.count) students",
                   subtitle: ids.count == 1 ? "" : names, width: 480) {
            Picker("", selection: $kind) {
                ForEach(QuickKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if kind == .lesson {
                Picker("Subject", selection: $subject) {
                    Text("No subject").tag("")
                    ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 280)
            }
            if kind == .wellbeing {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        FieldLabel(text: "Period lost")
                        Picker("", selection: $lost) {
                            Text("None").tag("")
                            ForEach(db.periods) { p in Text(p.name).tag(String(p.period)) }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        FieldLabel(text: "Minutes")
                        TextField("", text: $minutes).textFieldStyle(.roundedBorder).frame(width: 70)
                    }
                }
            }
            NoteBox(label: "Note", text: $note, lines: 3)
            HStack {
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(note.trimmed.isEmpty)
                Button("Cancel") { dismiss() }
            }

            if ids.count == 1 {
                let today = db.todaysEntries(ids[0])
                if !today.isEmpty {
                    Divider()
                    Text("Logged today").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    ForEach(Array(today.enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .top, spacing: 8) {
                            Text(e.time.isEmpty ? "" : fmtTime(e.time)).font(.system(size: 11.5)).foregroundStyle(Color.ink2).frame(width: 60, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.kind).font(.system(size: 12, weight: .semibold))
                                Text(e.note).font(.system(size: 12.5))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if !loaded {
                let guess = model.lastLessonSubject.isEmpty ? model.nowSubject() : model.lastLessonSubject
                subject = guess
                loaded = true
            }
        }
    }

    private func save() {
        let t = note.trimmed
        guard !t.isEmpty else { return }
        let db = model.db
        switch kind {
        case .lesson:
            db.addLessonNote(students: ids, subject: subject, note: t)
            if !subject.isEmpty { model.lastLessonSubject = subject }
        case .wellbeing:
            db.addWellbeing(students: ids, date: todayISO(), periodLost: lost, minutes: Int(minutes) ?? 0, note: t)
        case .behaviour:
            db.addBehaviour(students: ids, date: todayISO(), note: t)
        }
        model.showToast(ids.count == 1 ? "Saved" : "Saved for \(ids.count) students")
        dismiss()
    }
}
