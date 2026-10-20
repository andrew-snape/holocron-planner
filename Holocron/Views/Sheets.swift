import SwiftUI
import AppKit

// MARK: - Shared sheet frame

struct SheetFrame<Content: View>: View {
    var title: String
    var subtitle: String = ""
    var width: CGFloat = 460
    /// True while there are unsaved edits. Closing then asks before throwing them away.
    var dirty: Bool = false
    var discardMessage: String = "You have changes that are not saved."
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    @State private var askDiscard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .bold))
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Color.ink2) }
                }
                Spacer()
                Button { if dirty { askDiscard = true } else { dismiss() } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color.ink2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .help("Close (Esc)")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: width, idealWidth: width, minHeight: 280, idealHeight: 420)
        .background(Color.appBG)
        .confirmationDialog("Discard your changes?", isPresented: $askDiscard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(discardMessage)
        }
    }
}

private func slotTitle(_ model: AppModel, _ date: String, _ per: Int) -> String {
    let p = model.db.period(per)
    return "\(Cal.weekdayLong[dayIdx(date)]) \(shortDate(date)) · \(p?.name ?? "")"
}

// MARK: - Change subject

struct ChangeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var date: String
    var per: Int
    @State private var subject = ""
    @State private var loaded = false

    var body: some View {
        let db = model.db
        let wk = db.weekLetter(date) ?? "A"
        SheetFrame(title: "Change subject", subtitle: slotTitle(model, date, per) + " · Week \(wk)") {
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: "Subject")
                Picker("", selection: $subject) {
                    Text("Not set").tag("")
                    ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
            }
            Text("\u{201C}This date only\u{201D} leaves the standing timetable alone. \u{201C}Every \(wk) week\u{201D} changes the standing timetable from now on.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            HStack {
                Button("This date only") {
                    db.changeSubjectOnce(date: date, per: per, subject: subject)
                    model.showToast("Changed for this date only")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Button("Every \(wk) week") {
                    db.changeSubjectStanding(date: date, per: per, subject: subject)
                    model.showToast("Standing timetable updated")
                    dismiss()
                }
                if db.isMoved(date, per) {
                    Button("Put back to normal") {
                        db.clearDayPlan(date, per)
                        model.showToast("Put back to normal")
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if !loaded {
                subject = model.db.plannedSubject(date, per, fallbackWeek: model.db.weekLetter(date) ?? "A")
                loaded = true
            }
        }
    }
}

// MARK: - Move (swap two periods on one day)

struct MoveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var date: String
    var per: Int
    @State private var other = -1

    var body: some View {
        let db = model.db
        let others = db.periods.filter { $0.period != per }
        let subj = db.plannedSubject(date, per)
        SheetFrame(title: "Move \(subj.isEmpty ? "this session" : subj)", subtitle: longDate(date)) {
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: "Swap it with")
                Picker("", selection: $other) {
                    ForEach(others) { p in
                        Text("\(p.name) · \(db.plannedSubject(date, p.period).isEmpty ? "Not set" : db.plannedSubject(date, p.period))")
                            .tag(p.period)
                    }
                }
                .labelsHidden()
            }
            Text("This changes today only. The standing timetable stays as it is.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            HStack {
                Button("Swap") {
                    if other >= 0 {
                        db.swapDates(date, per, date, other)
                        model.showToast("Swapped for today")
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                if db.isMoved(date, per) {
                    Button("Put back to normal") {
                        db.clearDayPlan(date, per)
                        model.showToast("Put back to normal")
                        dismiss()
                    }
                }
            }
        }
        .onAppear { if other < 0 { other = others.first?.period ?? -1 } }
    }
}

// MARK: - Day type

struct DayTypeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var date: String
    @State private var type = "Normal"
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        SheetFrame(title: "Day type", subtitle: longDate(date)) {
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: "What kind of day is this?")
                Picker("", selection: $type) {
                    ForEach(Lists.dayTypes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
            }
            LineField(label: "Note", text: $note)
            Button("Save") {
                let db = model.db
                db.setDayType(date, type: type, note: note.trimmingCharacters(in: .whitespaces))
                if type != "Normal" {
                    let plans = db.dayBumpPlans(date)
                    if !db.bumpSummary(plans).isEmpty {
                        model.sheet = .bump(title: "Push this day's lessons forward?", sub: "\(longDate(date)) · \(type)",
                                            intro: "The timetable does not run on this day. Move its planned lessons to the next lesson of each subject?",
                                            plans: plans)
                        return
                    }
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .onAppear {
            if !loaded {
                let ov = model.db.overrideOf(date)
                type = ov?.s("type").isEmpty == false ? (ov?.s("type") ?? "Normal") : "Normal"
                note = ov?.s("note") ?? ""
                loaded = true
            }
        }
    }
}

// MARK: - Swap two sessions

struct SwapSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var a: SlotRef
    var b: SlotRef

    var body: some View {
        let db = model.db
        let s1 = db.plannedSubject(a.date, a.per).isEmpty ? "Not set" : db.plannedSubject(a.date, a.per)
        let s2 = db.plannedSubject(b.date, b.per).isEmpty ? "Not set" : db.plannedSubject(b.date, b.per)
        SheetFrame(title: "Swap two sessions") {
            VStack(alignment: .leading, spacing: 6) {
                Text(s1).font(.system(size: 14, weight: .semibold))
                Text("\(Cal.weekdayLong[a.day]) \(shortDate(a.date)) · \(db.period(a.per)?.name ?? "") · Week \(a.week)")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                Text("swaps with").font(.system(size: 12)).foregroundStyle(Color.ink3).padding(.vertical, 2)
                Text(s2).font(.system(size: 14, weight: .semibold))
                Text("\(Cal.weekdayLong[b.day]) \(shortDate(b.date)) · \(db.period(b.per)?.name ?? "") · Week \(b.week)")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            Text("A one-off leaves your standing timetable alone and only changes these two dates. Lesson notes move with the session either way.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            HStack {
                Button("Just these dates") {
                    db.swapDates(a.date, a.per, b.date, b.per)
                    model.showToast("Swapped for these dates")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Button("Every cycle from now on") {
                    db.swapTemplate(a.week, a.day, a.per, b.week, b.day, b.per)
                    let c1 = db.content(a.date, a.per), c2 = db.content(b.date, b.per)
                    db.putContent(a.date, a.per, db.plannedSubject(a.date, a.per), c2)
                    db.putContent(b.date, b.per, db.plannedSubject(b.date, b.per), c1)
                    db.touch(.lessons)
                    model.showToast("Timetable updated")
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Bump lessons

struct BumpSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var title: String
    var sub: String
    var intro: String
    var plans: [BumpPlan]
    @State private var snapshot: [Row]? = nil

    var body: some View {
        let db = model.db
        let sm = db.bumpSummary(plans)
        SheetFrame(title: snapshot == nil ? title : "Lessons moved", subtitle: sub) {
            if snapshot != nil {
                ForEach(sm, id: \.subject) { x in
                    HStack(spacing: 10) {
                        SubjectChip(name: x.subject)
                        Text("\(x.moved) moved").font(.system(size: 13))
                    }
                }
                HStack {
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    Button("Undo") {
                        if let s = snapshot { db.undoBump(s) }
                        model.showToast("Put back")
                        dismiss()
                    }
                }
            } else if sm.isEmpty {
                Text("Nothing to move.").font(.system(size: 13))
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            } else if sm.contains(where: { $0.lost > 0 }) {
                Text("\(sm.filter { $0.lost > 0 }.map { $0.subject }.joined(separator: ", ")) would run out of lessons before the end of the year, so the last summary would have nowhere to go.")
                    .font(.system(size: 13))
                Text("Nothing has changed. Add the next term's dates in Settings, or clear the last lesson first.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            } else {
                if !intro.isEmpty { Text(intro).font(.system(size: 13)) }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sm, id: \.subject) { x in
                        HStack(alignment: .top, spacing: 10) {
                            SubjectChip(name: x.subject)
                            Text("\(x.moved) lesson\(x.moved == 1 ? "" : "s") move\(x.moved == 1 ? "s" : ""). The last lands on \(Cal.weekdayShort[dayIdx(x.lastDate)]) \(shortDate(x.lastDate)), \(db.period(x.lastPer)?.name ?? "").")
                                .font(.system(size: 13))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                Text("Lesson notes about students stay on the day they were written.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                HStack {
                    Button("Move lessons") { snapshot = db.applyBump(plans) }.buttonStyle(.borderedProminent)
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Lesson plan panel

struct PlanSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    var date: String
    var per: Int
    @State private var editing: Bool
    @State private var draft = LessonContent()
    @State private var loaded = false
    @State private var armedClear = false
    @State private var askCancel = false

    init(date: String, per: Int, startEditing: Bool) {
        self.date = date
        self.per = per
        _editing = State(initialValue: startEditing)
    }

    var body: some View {
        let db = model.db
        let subj = db.plannedSubject(date, per)
        let p = db.period(per)
        let sub = "\(longDate(date)) · \(p?.name ?? "") · \(fmtTime(p?.start ?? "")) to \(fmtTime(p?.end ?? ""))"
        let stored = db.content(date, per)
        SheetFrame(title: subj.isEmpty ? (p?.name ?? "Lesson") : subj, subtitle: sub, width: 640,
                   dirty: editing && draft != stored,
                   discardMessage: "This lesson has edits you have not saved.") {
            if editing {
                form(subj: subj, stored: stored)
            } else {
                readView(subj: subj, c: stored)
            }
            bumpBox(subj: subj, c: editing ? draft : stored)
        }
        .onAppear {
            if !loaded { draft = model.db.content(date, per); loaded = true }
        }
    }

    // MARK: Read view

    @ViewBuilder
    private func readView(subj: String, c: LessonContent) -> some View {
        let db = model.db
        let tone = subj.isEmpty ? Tone.unset : db.tone(forSubject: subj)
        if subj == "TDL", let u = db.unitOn(date) {
            let uTone = db.tone(forHex: PYP.themeHex(u.s("theme")))
            Text(u.s("title") + (u.s("central_idea").isEmpty ? "" : " · " + u.s("central_idea")))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(uTone.inkColor)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(uTone.tintColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        if !c.summary.isEmpty { Text(linkified(c.summary)).font(.system(size: 14)).textSelection(.enabled) }
        if !c.li.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Learning intention", color: tone.inkColor)
                Text(c.li).font(.system(size: 15, weight: .medium)).textSelection(.enabled)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.tintColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        let sc = linesOf(c.sc)
        if !sc.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Success criteria")
                ForEach(sc, id: \.self) { x in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle").foregroundStyle(tone.barColor)
                        Text(x).font(.system(size: 13.5)).textSelection(.enabled)
                    }
                }
            }
        }
        let steps = PlanSeq.all.filter { !c[$0.key].trimmed.isEmpty }
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Lesson sequence")
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(width: 22, height: 22).background(tone.tintColor).clipShape(Circle())
                            .foregroundStyle(tone.inkColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.label).font(.system(size: 13, weight: .semibold))
                            Text(c[s.key]).font(.system(size: 13.5)).textSelection(.enabled)
                        }
                    }
                }
            }
        }
        let res = linesOf(c.resources)
        if !res.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Resources")
                ForEach(res, id: \.self) { line in ResourceRow(line: line) }
            }
        }
        let codes = c.codeList
        if !codes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Curriculum")
                ChipRow(items: codes)
            }
        }
        if !listOf(c.atl).isEmpty || !listOf(c.profile).isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("PYP")
                ChipRow(items: listOf(c.atl) + listOf(c.profile), tinted: true)
            }
        }
        HStack {
            Button("Edit plan") { editing = true; draft = model.db.content(date, per) }.buttonStyle(.borderedProminent)
            Button("Class screen") {
                openWindow(id: "classscreen", value: ClassTarget(date: date, per: per))
                dismiss()
            }
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(.top, 4)
    }

    // MARK: Edit form

    @ViewBuilder
    private func form(subj: String, stored: LessonContent) -> some View {
        NoteBox(label: "Summary", hint: "shows on Today and Week", text: $draft.summary, lines: 2, placeholder: "A sentence or a link")
        NoteBox(label: "Learning intention", text: $draft.li, lines: 2, placeholder: "We are learning to...")
        NoteBox(label: "Success criteria", hint: "one per line", text: $draft.sc, lines: 3, placeholder: "I can...")
        NoteBox(label: "Tuning in", text: $draft.tuning, lines: 3)
        NoteBox(label: "Explicit teaching", text: $draft.teaching, lines: 3)
        NoteBox(label: "Independent work", text: $draft.independent, lines: 3)
        NoteBox(label: "Reflection", text: $draft.reflection, lines: 3)
        NoteBox(label: "Resources and links", hint: "one per line, a label then the link", text: $draft.resources, lines: 3, placeholder: "Slides https://...")
        LineField(label: "Curriculum codes", text: $draft.codes, placeholder: "AC9M6N05, AC9E6LY06")
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "ATL skills")
            ChipToggles(options: PYP.atlSkills, value: $draft.atl)
        }
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "Learner profile")
            ChipToggles(options: PYP.profile, value: $draft.profile)
        }
        HStack {
            Button("Save") {
                var n = draft
                for f in LessonContent.allFields {
                    n[f] = n[f].replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
                }
                model.db.setContent(date, per, subj, n)
                if n.hasPlan { editing = false } else { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
            Button("Cancel") {
                if draft != stored { askCancel = true } else if stored.hasPlan { editing = false } else { dismiss() }
            }
            .confirmationDialog("Discard your changes?", isPresented: $askCancel) {
                Button("Discard changes", role: .destructive) {
                    draft = stored
                    if stored.hasPlan { editing = false } else { dismiss() }
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("This lesson has edits you have not saved.")
            }
            Spacer()
            if !stored.isEmpty {
                Button(armedClear ? "Click again to clear" : "Clear lesson", role: .destructive) {
                    if !armedClear { armedClear = true; return }
                    model.db.setContent(date, per, subj, LessonContent())
                    model.showToast("Lesson cleared")
                    dismiss()
                }
                .foregroundStyle(Color.appRed)
            }
        }
    }

    // MARK: Bump

    @ViewBuilder
    private func bumpBox(subj: String, c: LessonContent) -> some View {
        let db = model.db
        if db.canBump(subj) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bump lessons").font(.system(size: 13, weight: .semibold))
                if !c.isEmpty {
                    Text("Moves this \(subj) lesson, and every \(subj) lesson after it, forward one lesson.")
                        .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    Button("Push forward") {
                        if editing && c != db.content(date, per) { db.setContent(date, per, subj, c) }
                        model.sheet = .bump(title: "Push \(subj) forward", sub: longDate(date), intro: "",
                                            plans: [db.planPush(subj, [(date: date, per: per)])])
                    }
                } else {
                    Text("Pulls the next \(subj) lesson, and every one after it, back one lesson into this slot.")
                        .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    Button("Pull back") {
                        model.sheet = .bump(title: "Pull \(subj) back", sub: longDate(date), intro: "",
                                            plans: [db.planPull(subj, date, per)])
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

enum PlanSeq {
    struct Step { var key: String; var label: String }
    static let all: [Step] = [
        Step(key: "tuning", label: "Tuning in"),
        Step(key: "teaching", label: "Explicit teaching"),
        Step(key: "independent", label: "Independent work"),
        Step(key: "reflection", label: "Reflection")
    ]
}

struct ResourceRow: View {
    var line: String

    var body: some View {
        let parsed = LessonResource.parse(line)
        if let url = parsed.url {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    VStack(alignment: .leading, spacing: 0) {
                        Text(parsed.label.isEmpty ? parsed.host : parsed.label).font(.system(size: 13, weight: .medium))
                        if !parsed.label.isEmpty { Text(parsed.host).font(.system(size: 11)).foregroundStyle(Color.ink2) }
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        } else {
            Text(line).font(.system(size: 13)).textSelection(.enabled)
        }
    }
}
