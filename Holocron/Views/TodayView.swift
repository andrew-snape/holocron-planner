import SwiftUI
import AppKit

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let date = model.cursor
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        dayBody(date).frame(maxWidth: .infinity)
                        SidePanel(date: date).frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        dayBody(date)
                        SidePanel(date: date)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(title(date))
        .navigationSubtitle(subtitle(date))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { model.cursor = addDays(date, -1) } label: { Label("Yesterday", systemImage: "chevron.left") }
                    .help("Go to the day before")
                Button("Today") { model.cursor = todayISO() }
                    .help("Go to today")
                Button { model.cursor = addDays(date, 1) } label: { Label("Tomorrow", systemImage: "chevron.right") }
                    .help("Go to the next day")
                DatePicker("Date", selection: isoBinding({ model.cursor }, { model.cursor = $0 }), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .help("Pick a date")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.copyDay(date) } label: { Label("Copy lessons", systemImage: "doc.on.doc") }
                    .help("Copy every lesson and time for this day as rich text, ready to paste into the school LMS")
                Button {
                    if let t = ClassTarget.pick(model, date: date) { openWindow(id: "classscreen", value: t) }
                    else { model.showToast("No lessons on this day") }
                } label: { Label("Class screen", systemImage: "tv") }
                    .help("Show this day's lessons on the class screen")
                Button { model.sheet = .dayType(date: date) } label: { Label("Set day type", systemImage: "calendar.badge.clock") }
                    .help("Set what kind of day this is")
            }
        }
    }

    // MARK: Title

    private func title(_ date: String) -> String {
        let di = dayIdx(date)
        return date == todayISO() ? "Today" : (di < 5 ? Cal.weekdayLong[di] : "Weekend")
    }

    private func subtitle(_ date: String) -> String {
        let db = model.db
        var sub = longDate(date)
        if let wk = db.weekLetter(date) { sub += " · Week \(wk)" }
        if let t = db.termOf(date) { sub += " · Term \(t.term), week \(db.termWeek(date) ?? 0)" }
        return sub
    }

    // MARK: Body of the day

    @ViewBuilder
    private func dayBody(_ date: String) -> some View {
        let db = model.db
        let t = db.termOf(date)
        let di = dayIdx(date)
        let ov = db.overrideOf(date)
        if di > 4 || t == nil || db.isNonTeaching(date) {
            let why = di > 4 ? "It's the weekend."
                : (t == nil ? "This date falls outside term."
                   : (db.nonTeachingLabel(date).isEmpty ? "Non-teaching day." : db.nonTeachingLabel(date)))
            EmptyNote(title: "Nothing on", message: why)
        } else if let ov = ov, ov.s("type") != "Normal" {
            EmptyNote(title: ov.s("type"), message: ov.s("note").isEmpty ? "Timetable does not run today." : ov.s("note"))
        } else {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                let ps = db.periods
                let isToday = date == todayISO()
                let nm: Int? = isToday ? nowMinutes() : nil
                VStack(spacing: 8) {
                    if let nm { NowCard(date: date, minutes: nm) }
                    ForEach(Array(ps.enumerated()), id: \.element.id) { idx, p in
                        BlockRow(date: date, period: p, minutesNow: nm)
                        if idx + 1 < ps.count, mins(p.end, ps[idx + 1].start) > 0 {
                            BreakRow(from: p.end, to: ps[idx + 1].start)
                        }
                    }
                }
            }
        }
    }
}

struct BreakRow: View {
    var from: String
    var to: String
    var body: some View {
        let label = breakLabel(from: from, to: to)
        HStack(spacing: 14) {
            Text("\(from) to \(to)").font(.system(size: 12.5, design: .rounded)).frame(width: 106, alignment: .leading)
            Text(label).font(.caption1)
            Spacer()
        }
        .foregroundStyle(Color.ink3)
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }
}

struct BlockRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    var date: String
    var period: Period
    /// Minutes since midnight when the date is today, otherwise nil.
    var minutesNow: Int?

    /// True when the date is today and the period has finished, so it fades back and the eye lands on now.
    private var isPast: Bool {
        guard let n = minutesNow, let b = hm(period.end) else { return false }
        return n >= b
    }

    var body: some View {
        let db = model.db
        let pn = period.period
        let subj = db.plannedSubject(date, pn)
        let moved = db.isMoved(date, pn)
        let info = db.subjectInfo(subj)
        let tone = subj.isEmpty ? Tone.unset : db.tone(forSubject: subj)
        let c = db.content(date, pn)
        let lesExists = db.lessonRow(date, pn) != nil
        let isNow: Bool = {
            guard let n = minutesNow, let a = hm(period.start), let b = hm(period.end) else { return false }
            return n >= a && n < b
        }()
        let showDevotion = model.isEnabled(.devotion) && (subj == "Circle Time" || c.summary.hasPrefix("Circle Time"))
            && db.rows(.devotion).contains { $0.s("date") == date }
        let unit = subj == "TDL" ? db.unitOn(date) : nil

        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(tone.barColor).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(period.start) to \(period.end)").font(.system(size: 13, weight: .medium, design: .rounded))
                Text(period.name).font(.small).foregroundStyle(Color.ink2)
            }
            .frame(width: 112, alignment: .leading)
            .padding(.leading, 12)
            .padding(.vertical, 11)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subj.isEmpty ? "Not set" : subj)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(tone.inkColor)
                        .accessibilityValue(isNow ? "Happening now" : "")
                    if c.hasPlan { TagLabel(text: "Plan", fg: tone.inkColor, bg: Color.veil.opacity(0.7)) }
                    if moved { Circle().fill(Color.appAmber).frame(width: 6, height: 6).help("Moved for today") }
                }
                Text("\(info.isRelease ? "Release" : "Face to face") · \(period.minutes) min" + (moved ? " · changed for today" : ""))
                    .font(.label).foregroundStyle(Color.ink2)
                if !c.summary.isEmpty {
                    Text(linkified(c.summary)).font(.bodyLarge).textSelection(.enabled).padding(.top, 2)
                }
                if !c.li.isEmpty {
                    Text("\(Text("LI ").fontWeight(.bold))\(c.li)").font(.caption1).foregroundStyle(Color.ink2)
                }
                if let u = unit {
                    Text("\(Text("Unit ").fontWeight(.bold))\(u.s("title"))").font(.caption1).foregroundStyle(Color.ink2)
                }
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if showDevotion {
                    Button("Devotion") { model.devotionDate = date; model.nav = .devotion }
                }
                Button(c.hasPlan ? "Open plan" : (lesExists ? "Edit" : "Add")) {
                    model.sheet = .plan(date: date, per: pn, edit: !c.hasPlan)
                }
                Button("Change") { model.sheet = .change(date: date, per: pn) }
                Button("Move") { model.sheet = .move(date: date, per: pn) }
            }
            .controlSize(.small)
            .padding(10)
        }
        .background(tintedBlock(tone, release: info.isRelease))
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .stroke(Color.appBlue, lineWidth: isNow ? 2 : 0)
        )
        .opacity(isPast ? 0.7 : 1)
        .accessibilityHint(isPast ? "Finished" : "")
        .contextMenu {
            Button(c.hasPlan ? "Open Plan" : (lesExists ? "Edit Plan…" : "Add Plan…")) {
                model.sheet = .plan(date: date, per: pn, edit: !c.hasPlan)
            }
            .disabled(subj.isEmpty || info.isRelease)
            Button("Change Subject…") { model.sheet = .change(date: date, per: pn) }
            Button("Move or Push Lessons…") { model.sheet = .move(date: date, per: pn) }
                .disabled(subj.isEmpty)
            Divider()
            Button("Show on Class Screen") { openWindow(id: "classscreen", value: ClassTarget(date: date, per: pn)) }
                .disabled(subj.isEmpty || info.isRelease)
        }
    }
}

struct QuoteCard: View {
    var row: Row
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(row.s("quote"))\u{201D}").font(.caption1).italic()
            let who = row.s("artist") + (row.s("band").isEmpty || row.s("band") == row.s("artist") ? "" : ", " + row.s("band"))
            Text(who).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.ink2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fillFaint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .help(row.s("source"))
    }
}

// MARK: - Right-hand column

struct SidePanel: View {
    @Environment(AppModel.self) private var model
    var date: String

    var body: some View {
        let db = model.db
        let dm = db.dayMinutes(date)
        let bd = db.upcomingBirthdays(10)
        let recent = db.recentActivity()
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(hrs(dm.teach)) hrs").font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Face to face today").font(.label).foregroundStyle(Color.ink2)
                Divider().padding(.vertical, 4)
                HStack {
                    Text("Release").font(.body1)
                    Spacer()
                    Text("\(hrs(dm.release)) hrs").font(.system(size: 13, design: .rounded))
                }
            }
            .card()

            TodoPanel()

            if !bd.isEmpty {
                Text("Birthdays").font(.body1Semibold).padding(.top, 4)
                ForEach(bd) { b in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.bodyLargeSemibold)
                        Text(b.days == 0 ? "Today" : (b.days == 1 ? "Tomorrow" : "\(shortDate(b.date)), in \(b.days) days"))
                            .font(.label).foregroundStyle(Color.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 10)
                }
            }

            Text("Recent notes").font(.body1Semibold).padding(.top, 4)
            if recent.isEmpty {
                Text("Notes you add against students show here.").font(.caption1).foregroundStyle(Color.ink2)
            } else {
                ForEach(recent) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Divider()
                        Text(db.studentName(a.who)).font(.caption1Semibold)
                        Text("\(a.kind) · \(shortDate(a.date))").font(.footnote).foregroundStyle(Color.ink2)
                        Text(String(a.text.prefix(70)) + (a.text.count > 70 ? "…" : ""))
                            .font(.caption1).foregroundStyle(Color.ink2)
                    }
                }
            }

            // The quote sits at the bottom, out of the way of the day.
            if let q = model.quote() {
                QuoteCard(row: q).padding(.top, 6)
            }
        }
    }
}

/// The lesson on now in its subject colour, a thin line through the period, what comes next, and one button
/// to the Class screen. Shown on today's date only.
struct NowCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    var date: String
    var minutes: Int

    var body: some View {
        let db = model.db
        let lessons = db.periods.filter { p in
            let s = db.plannedSubject(date, p.period)
            return !s.isEmpty && db.subjectInfo(s).kind != "dottl"
        }
        let now = lessons.first { (hm($0.start) ?? 0) <= minutes && minutes < (hm($0.end) ?? 0) }
        let next = lessons.first { (hm($0.start) ?? 0) > minutes }
        if now != nil || next != nil {
            let shown = now ?? next!
            let subj = db.plannedSubject(date, shown.period)
            let tone = db.tone(forSubject: subj)
            let a = hm(shown.start) ?? 0, b = hm(shown.end) ?? 1
            let progress = now == nil ? 0 : min(1, max(0, Double(minutes - a) / Double(max(1, b - a))))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(now != nil ? "NOW" : "NEXT").font(.smallBold).foregroundStyle(tone.inkColor)
                    Text(subj).font(.hSection).foregroundStyle(tone.inkColor)
                    Text("\(shown.start) to \(shown.end)").font(.label).foregroundStyle(tone.inkColor.opacity(0.8))
                    Spacer()
                    Button { openWindow(id: "classscreen", value: ClassTarget(date: date, per: shown.period)) } label: {
                        Label("Class screen", systemImage: "tv")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Show this lesson on the Class screen")
                }
                if now != nil {
                    ProgressView(value: progress)
                        .tint(tone.barColor)
                        .accessibilityLabel("Time through the lesson")
                        .accessibilityValue("\(Int(progress * 100)) percent")
                    Text("\(b - minutes) minutes left").font(.caption1).foregroundStyle(tone.inkColor)
                }
                if now != nil, let n = next {
                    Text("Then \(db.plannedSubject(date, n.period)) at \(n.start)").font(.caption1).foregroundStyle(tone.inkColor).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Space.card)
            .background(tone.tintColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).stroke(tone.barColor.opacity(0.6), lineWidth: 1))
            .accessibilityElement(children: .contain)
        }
    }
}

struct TodoPanel: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var hasDue = false
    @State private var due = Date()
    /// True once the teacher has changed the due date or switched it off, so typing no longer sets it.
    @State private var manual = false
    private var canAdd: Bool { !text.trimmed.isEmpty }

    /// What the typed words say: the to-do and a due date such as "Friday", worked out in code.
    private var parsed: TodoParse.Result { TodoParse.parse(text) }

    /// The due date as yyyy-mm-dd that Add would use, or empty.
    private func dueNow(_ p: TodoParse.Result) -> String {
        if manual {
            guard hasDue else { return "" }
            let c = Calendar.current.dateComponents([.year, .month, .day], from: due)
            return Cal.make(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
        }
        return p.due ?? ""
    }

    var body: some View {
        let db = model.db
        let open = db.openTodos()
        let done = db.doneTodayTodos()
        let p = parsed
        let dueText = dueNow(p)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("To-do").font(.body1Semibold)
                if !open.isEmpty { Text("\(open.count)").font(.label).foregroundStyle(Color.ink2) }
                let dueNow = open.filter { !$0.s("due").isEmpty && $0.s("due") <= todayISO() }.count
                if dueNow > 0 { Text("\(dueNow) due today or overdue").font(.smallSemibold).foregroundStyle(Color.appRed) }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(open, id: \Row.["id"]) { x in row(x, done: false) }
                ForEach(done, id: \Row.["id"]) { x in row(x, done: true) }
                HStack(spacing: 6) {
                    TextField("Add a to-do", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add).controlSize(.small)
                        .disabled(!canAdd)
                }
                HStack(spacing: 6) {
                    Toggle("Due", isOn: Binding(get: { !dueText.isEmpty }, set: { on in
                        manual = true
                        hasDue = on
                        if on, let d = Self.date(p.due ?? todayISO()) { due = d }
                    })).toggleStyle(.checkbox).font(.label)
                    if !dueText.isEmpty {
                        DatePicker("", selection: Binding(get: { Self.date(dueText) ?? due }, set: { d in
                            manual = true
                            hasDue = true
                            due = d
                        }), displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                            .accessibilityLabel("Due date")
                    }
                }
                if canAdd && !manual, let d = p.due {
                    Text((p.text != text.trimmed ? "Will add \u{201C}\(p.text)\u{201D}. " : "") + "Due \(longDate(d)). Change the date or untick Due to keep your words as typed.")
                        .font(.label).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card(padding: 10)
        }
    }

    private static func date(_ iso: String) -> Date? {
        guard let p = Cal.parts(iso) else { return nil }
        return Calendar.current.date(from: DateComponents(year: p.0, month: p.1, day: p.2))
    }

    private func add() {
        guard canAdd else { return }
        let p = parsed
        let dueISO = dueNow(p)
        // The date words come out of the text only when the saved date is the one they said.
        // A date the teacher set by hand, or none, keeps their words as typed.
        let t = (!dueISO.isEmpty && dueISO == p.due && !p.text.isEmpty) ? p.text : p.keepingDate
        guard !t.isEmpty else { return }
        model.db.addTodo(text: t, due: dueISO)
        text = ""
        hasDue = false
        manual = false
    }

    @ViewBuilder
    private func row(_ x: Row, done: Bool) -> some View {
        let id = x.s("id")
        HStack(alignment: .top, spacing: 8) {
            Button {
                model.db.setTodoDone(id, done: !done)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Color.appGreen : Color.ink3)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
                    .padding(-5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark not done" : "Mark done")
            .help(done ? "Reopen this to-do" : "Complete this to-do")
            Text(x.s("text"))
                .font(.bodyLarge)
                .strikethrough(done)
                .foregroundStyle(done ? Color.ink3 : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !done, !x.s("due").isEmpty { dueLabel(x.s("due")) }
            Button {
                model.db.deleteRow(.todo, id: id)
            } label: {
                Image(systemName: "xmark").font(.tiny)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
                    .padding(-5)
            }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ink3)
                .accessibilityLabel("Delete to-do")
                .help("Delete this item")
        }
        .contextMenu {
            Button(done ? "Mark Not Done" : "Mark Done") { model.db.setTodoDone(id, done: !done) }
            Button("Copy") { model.copyText(x.s("text"), toast: "Copied") }
            Divider()
            Button("Delete", role: .destructive) { model.db.deleteRow(.todo, id: id) }
        }
    }

    @ViewBuilder
    private func dueLabel(_ due: String) -> some View {
        let t = todayISO()
        if due < t {
            Text(shortDate(due)).font(.smallSemibold).foregroundStyle(Color.appRed)
        } else if due == t {
            Text("Today").font(.smallSemibold).foregroundStyle(Color.appAmber)
        } else if due == addDays(t, 1) {
            Text("Tomorrow").font(.small).foregroundStyle(Color.ink2)
        } else {
            Text("\(Cal.weekdayShort[dayIdx(due)]) \(shortDate(due))").font(.small).foregroundStyle(Color.ink2)
        }
    }
}
