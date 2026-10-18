import SwiftUI
import AppKit

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let date = model.cursor
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(date)
                dayBar(date)
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
    }

    // MARK: Header

    private func header(_ date: String) -> some View {
        let db = model.db
        let t = db.termOf(date)
        let wk = db.weekLetter(date)
        let di = dayIdx(date)
        var sub = longDate(date)
        if let wk = wk { sub += " · Week \(wk)" }
        if let t = t { sub += " · Term \(t.term), week \(db.termWeek(date) ?? 0)" }
        let title = date == todayISO() ? "Today" : (di < 5 ? Cal.weekdayLong[di] : "Weekend")
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.5)
                Text(sub).font(.system(size: 13)).foregroundStyle(Color.ink2)
            }
            Spacer(minLength: 0)
            if let q = model.quote() { QuoteCard(row: q).frame(maxWidth: 340) }
        }
    }

    private func dayBar(_ date: String) -> some View {
        HStack(spacing: 8) {
            Button("Yesterday") { model.cursor = addDays(date, -1) }
            Button("Today") { model.cursor = todayISO() }
            Button("Tomorrow") { model.cursor = addDays(date, 1) }
            DatePicker("", selection: isoBinding({ model.cursor }, { model.cursor = $0 }), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
            Spacer()
            Button("Copy lessons") { model.copyDay(date) }
                .help("Copy every lesson and time for this day as rich text, ready to paste into the school LMS")
            Button("Class screen") {
                if let t = ClassTarget.pick(model, date: date) { openWindow(id: "classscreen", value: t) }
                else { model.showToast("No lessons on this day") }
            }
            Button("Set day type") { model.sheet = .dayType(date: date) }
        }
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
                VStack(spacing: 8) {
                    ForEach(Array(ps.enumerated()), id: \.element.id) { idx, p in
                        BlockRow(date: date, period: p)
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
            Text(label).font(.system(size: 12.5))
            Spacer()
        }
        .foregroundStyle(Color.ink3)
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }
}

struct BlockRow: View {
    @Environment(AppModel.self) private var model
    var date: String
    var period: Period
    /// Minutes since midnight when the date is today, otherwise nil.
    var minutesNow: Int?

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
                Text(period.name).font(.system(size: 11)).foregroundStyle(Color.ink2)
            }
            .frame(width: 112, alignment: .leading)
            .padding(.leading, 12)
            .padding(.vertical, 11)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subj.isEmpty ? "Not set" : subj)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(tone.inkColor)
                    if c.hasPlan { TagLabel(text: "Plan", fg: tone.inkColor, bg: Color.white.opacity(0.7)) }
                    if moved { Circle().fill(Color.appAmber).frame(width: 6, height: 6).help("Moved for today") }
                }
                Text("\(info.isRelease ? "Release" : "Face to face") · \(period.minutes) min" + (moved ? " · changed for today" : ""))
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
                if !c.summary.isEmpty {
                    Text(linkified(c.summary)).font(.system(size: 13.5)).textSelection(.enabled).padding(.top, 2)
                }
                if !c.li.isEmpty {
                    Text("\(Text("LI ").fontWeight(.bold))\(c.li)").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                }
                if let u = unit {
                    Text("\(Text("Unit ").fontWeight(.bold))\(u.s("title"))").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appBlue, lineWidth: isNow ? 2 : 0)
        )
    }
}

struct QuoteCard: View {
    var row: Row
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(row.s("quote"))\u{201D}").font(.system(size: 12.5)).italic()
            let who = row.s("artist") + (row.s("band").isEmpty || row.s("band") == row.s("artist") ? "" : ", " + row.s("band"))
            Text(who).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.ink2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                Text("Face to face today").font(.system(size: 12)).foregroundStyle(Color.ink2)
                Divider().padding(.vertical, 4)
                HStack {
                    Text("Release").font(.system(size: 13))
                    Spacer()
                    Text("\(hrs(dm.release)) hrs").font(.system(size: 13, design: .rounded))
                }
            }
            .card()

            TodoPanel()

            if !bd.isEmpty {
                Text("Birthdays").font(.system(size: 13, weight: .semibold)).padding(.top, 4)
                ForEach(bd) { b in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.system(size: 13.5, weight: .semibold))
                        Text(b.days == 0 ? "Today" : (b.days == 1 ? "Tomorrow" : "\(shortDate(b.date)), in \(b.days) days"))
                            .font(.system(size: 12)).foregroundStyle(Color.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 10)
                }
            }

            Text("Recent notes").font(.system(size: 13, weight: .semibold)).padding(.top, 4)
            if recent.isEmpty {
                Text("Notes you add against students show here.").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            } else {
                ForEach(recent) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Divider()
                        Text(db.studentName(a.who)).font(.system(size: 12.5, weight: .semibold))
                        Text("\(a.kind) · \(shortDate(a.date))").font(.system(size: 11.5)).foregroundStyle(Color.ink2)
                        Text(String(a.text.prefix(70)) + (a.text.count > 70 ? "…" : ""))
                            .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                }
            }
        }
    }
}

struct TodoPanel: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var hasDue = false
    @State private var due = Date()

    var body: some View {
        let db = model.db
        let open = db.openTodos()
        let done = db.doneTodayTodos()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("To do").font(.system(size: 13, weight: .semibold))
                if !open.isEmpty { Text("\(open.count)").font(.system(size: 12)).foregroundStyle(Color.ink2) }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(open, id: \Row.["id"]) { x in row(x, done: false) }
                ForEach(done, id: \Row.["id"]) { x in row(x, done: true) }
                HStack(spacing: 6) {
                    TextField("Add a to-do", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add).controlSize(.small)
                }
                HStack(spacing: 6) {
                    Toggle("Due", isOn: $hasDue).toggleStyle(.checkbox).font(.system(size: 12))
                    if hasDue {
                        DatePicker("", selection: $due, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                    }
                }
            }
            .card(padding: 10)
        }
    }

    private func add() {
        let t = text.trimmed
        guard !t.isEmpty else { return }
        var dueISO = ""
        if hasDue {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: due)
            dueISO = Cal.make(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
        }
        model.db.addTodo(text: t, due: dueISO)
        text = ""
        hasDue = false
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark not done" : "Mark done")
            Text(x.s("text"))
                .font(.system(size: 13.5))
                .strikethrough(done)
                .foregroundStyle(done ? Color.ink3 : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !done, !x.s("due").isEmpty { dueLabel(x.s("due")) }
            Button {
                model.db.deleteRow(.todo, id: id)
            } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ink3)
                .accessibilityLabel("Delete to-do")
        }
    }

    @ViewBuilder
    private func dueLabel(_ due: String) -> some View {
        let t = todayISO()
        if due < t {
            Text(shortDate(due)).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appRed)
        } else if due == t {
            Text("Today").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appAmber)
        } else if due == addDays(t, 1) {
            Text("Tomorrow").font(.system(size: 11)).foregroundStyle(Color.ink2)
        } else {
            Text("\(Cal.weekdayShort[dayIdx(due)]) \(shortDate(due))").font(.system(size: 11)).foregroundStyle(Color.ink2)
        }
    }
}
