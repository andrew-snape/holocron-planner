import SwiftUI

// MARK: - Term overview

struct TermLesson: Identifiable {
    var id: String { date + "|" + String(per) }
    var date: String
    var per: Int
    var name: String
    var text: String
    var status: PlanStatus
}

enum TermCell {
    case out
    case note(String)
    case lessons([TermLesson])
}

struct TermDay: Identifiable {
    var date: String
    var cell: TermCell
    var id: String { date }
}

struct TermWeek: Identifiable {
    var id: String { monday }
    var monday: String
    var number: Int
    var letter: String
    var unit: Row?
    var cells: [TermDay]
}

struct TermBuild {
    var weeks: [TermWeek] = []
    var plan = 0
    var summary = 0
    var empty = 0
    var nextGap: String? = nil
}

func buildTerm(_ db: Database, _ t: Term, subject: String) -> TermBuild {
    var out = TermBuild()
    let today = todayISO()
    var m = mondayOf(t.start)
    var guardN = 0
    while m <= t.end && guardN < 60 {
        let ref = m < t.start ? t.start : m
        var cells: [TermDay] = []
        for di in 0..<5 {
            let d = addDays(m, di)
            if d < t.start || d > t.end {
                cells.append(TermDay(date: d, cell: .out))
            } else if db.isNonTeaching(d) {
                let l = db.nonTeachingLabel(d)
                cells.append(TermDay(date: d, cell: .note(l.isEmpty ? "Non-teaching day" : l)))
            } else if let ov = db.overrideOf(d), ov.s("type") != "Normal", !ov.s("type").isEmpty {
                cells.append(TermDay(date: d, cell: .note(ov.s("type"))))
            } else {
                var ls: [TermLesson] = []
                for p in db.periods where db.plannedSubject(d, p.period) == subject {
                    let c = db.content(d, p.period)
                    let st = c.status
                    switch st {
                    case .plan: out.plan += 1
                    case .summary: out.summary += 1
                    case .empty:
                        out.empty += 1
                        if out.nextGap == nil && d >= today { out.nextGap = d }
                    }
                    let txt = !c.summary.isEmpty ? c.summary : (!c.li.isEmpty ? c.li : "Not planned")
                    ls.append(TermLesson(date: d, per: p.period, name: p.name.replacingOccurrences(of: "Period ", with: "P"),
                                         text: txt, status: st))
                }
                cells.append(TermDay(date: d, cell: .lessons(ls)))
            }
        }
        let wu = db.rows(.units).first {
            !$0.s("start").isEmpty && !$0.s("end").isEmpty && $0.s("start") <= addDays(m, 4) && $0.s("end") >= m
        }
        out.weeks.append(TermWeek(monday: m, number: db.termWeek(ref) ?? 0, letter: db.weekLetter(ref) ?? "",
                                  unit: wu, cells: cells))
        m = addDays(m, 7)
        guardN += 1
    }
    return out
}

struct TermView: View {
    @Environment(AppModel.self) private var model
    @State private var viewport: CGFloat = 900

    var body: some View {
        let db = model.db
        let ts = db.termsSorted
        if ts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader("Term")
                EmptyNote(title: "No terms yet", message: "Add term dates in Settings.")
                Spacer()
            }
            .padding(24)
        } else {
            let key = ts.contains(where: { $0.id == model.termKey }) ? model.termKey : model.termDefault()
            let t = ts.first(where: { $0.id == key }) ?? ts[0]
            let ix = ts.firstIndex(where: { $0.id == t.id }) ?? 0
            let subs = Array(Set(db.rows(.timetable).map { $0.s("subject") })).filter { db.canBump($0) }.sorted()
            let subj = subs.contains(model.termSubject) ? model.termSubject : (subs.contains("Maths") ? "Maths" : (subs.first ?? ""))
            let b = buildTerm(db, t, subject: subj)
            let tone = subj.isEmpty ? Tone(bar: RGB(142, 142, 147), tint: RGB(237, 237, 238), ink: RGB(99, 99, 103)) : db.tone(forSubject: subj)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Term \(t.term)").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                        Text("\(t.year) · \(shortDate(t.start)) to \(shortDate(t.end))").font(.system(size: 13)).foregroundStyle(Color.ink2)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Button("Previous term") { model.termKey = ts[ix - 1].id }.disabled(ix <= 0)
                        Button("Next term") { model.termKey = ts[ix + 1].id }.disabled(ix >= ts.count - 1)
                        Spacer()
                        Picker("", selection: Binding(get: { subj }, set: { model.termSubject = $0 })) {
                            ForEach(subs, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    TermStatBar(build: b, tone: tone)
                    ScrollView(.horizontal, showsIndicators: true) {
                        TermGrid(build: b, tone: tone, colW: max(150, (viewport - 20 - TermGrid.labelW - 4 * 5) / 5))
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewport = $0 }
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(24)
            }
        }
    }
}

struct TermStatBar: View {
    var build: TermBuild
    var tone: Tone

    var body: some View {
        let total = max(1, build.plan + build.summary + build.empty)
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(tone.barColor).frame(width: geo.size.width * CGFloat(build.plan) / CGFloat(total))
                    Rectangle().fill(tone.barColor.opacity(0.4)).frame(width: geo.size.width * CGFloat(build.summary) / CGFloat(total))
                    Rectangle().fill(Color.black.opacity(0.06))
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            HStack(spacing: 16) {
                legend(tone.barColor, "\(build.plan) full plan\(build.plan == 1 ? "" : "s")")
                legend(tone.barColor.opacity(0.4), "\(build.summary) summary only")
                legend(Color.black.opacity(0.1), "\(build.empty) not planned")
                Spacer()
                if let g = build.nextGap {
                    Text("Next gap: \(Cal.weekdayShort[dayIdx(g)]) \(shortDate(g))").font(.system(size: 12)).foregroundStyle(Color.ink2)
                }
            }
        }
        .card()
    }

    private func legend(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(text).font(.system(size: 12)).foregroundStyle(Color.ink2)
        }
    }
}

struct TermGrid: View {
    @Environment(AppModel.self) private var model
    var build: TermBuild
    var tone: Tone
    var colW: CGFloat
    static let labelW: CGFloat = 124

    var body: some View {
        let today = todayISO()
        let thisMonday = mondayOf(today)
        Grid(alignment: .topLeading, horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: TermGrid.labelW, height: 1)
                ForEach(0..<5, id: \.self) { i in
                    Text(Cal.weekdayLong[i]).font(.system(size: 12.5, weight: .semibold))
                        .frame(width: colW, alignment: .leading).padding(.horizontal, 4)
                }
            }
            ForEach(build.weeks) { w in
                GridRow {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Week \(w.number == 0 ? "" : String(w.number))").font(.system(size: 12.5, weight: .semibold))
                            if !w.letter.isEmpty {
                                Text(w.letter).font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(w.letter == "B" ? Color.weekB : Color.appBlue)
                                    .frame(width: 20, height: 18)
                                    .background(w.letter == "B" ? Color.weekBBG : Color.appBlue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(shortDate(w.monday)).font(.system(size: 11.5)).foregroundStyle(Color.ink2)
                        if w.monday == thisMonday {
                            Text("This week").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color.appBlue)
                        }
                        if let u = w.unit {
                            let ut = ToneMaths.tone(hex: PYP.themeHex(u.s("theme")))
                            Text(u.s("title")).font(.system(size: 10.5, weight: .semibold)).lineLimit(2)
                                .foregroundStyle(ut.inkColor)
                                .padding(.vertical, 2).padding(.horizontal, 6)
                                .background(ut.tintColor)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .frame(width: TermGrid.labelW, alignment: .leading)
                    .padding(.top, 4)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(w.monday == thisMonday ? Color.appBlue.opacity(0.06) : Color.clear))
                    ForEach(w.cells) { c in
                        cell(c.date, c.cell, today: today, current: w.monday == thisMonday)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ date: String, _ cell: TermCell, today: String, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Cal.weekdayShort[dayIdx(date)]) \(Cal.parts(date)?.2 ?? 0)")
                .font(.system(size: 10.5, weight: .medium)).foregroundStyle(Color.ink3)
            switch cell {
            case .out:
                Color.clear.frame(height: 18)
            case .note(let n):
                Text(n).font(.system(size: 11.5)).foregroundStyle(Color.ink2)
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            case .lessons(let ls):
                ForEach(ls) { l in lessonButton(l) }
            }
        }
        .padding(6)
        .frame(width: colW, alignment: .topLeading)
        .frame(minHeight: 66, maxHeight: .infinity, alignment: .topLeading)
        .background(date == today ? Color.appBlue.opacity(0.08) : (current ? Color.appBlue.opacity(0.045) : Color.black.opacity(0.025)))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func lessonButton(_ l: TermLesson) -> some View {
        Button {
            model.sheet = .plan(date: l.date, per: l.per, edit: l.status == .empty)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(l.name).font(.system(size: 10.5, weight: .bold)).foregroundStyle(tone.inkColor)
                    if l.status == .plan { TagLabel(text: "Plan", fg: tone.inkColor, bg: Color.white.opacity(0.7)) }
                    Spacer(minLength: 0)
                }
                Text(l.text).font(.system(size: 11.5)).lineLimit(3)
                    .foregroundStyle(l.status == .empty ? Color.ink3 : Color.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(l.status == .empty ? Color.white : (l.status == .plan ? tone.tintColor : tone.tintColor.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(l.status == .empty ? Color.black.opacity(0.15) : Color.clear, style: StrokeStyle(lineWidth: 0.8, dash: [3, 2])))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Units of inquiry

func unitDatesText(_ db: Database, _ u: Row) -> String {
    let s = u.s("start"), e = u.s("end")
    guard !s.isEmpty, !e.isEmpty else { return "Dates not set" }
    if let t1 = db.termOf(s), let t2 = db.termOf(e), t1.id == t2.id {
        return "Term \(t1.term), week \(db.termWeek(s) ?? 0) to \(db.termWeek(e) ?? 0)"
    }
    return "\(shortDate(s)) to \(shortDate(e))"
}

struct UnitsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let db = model.db
        let today = todayISO()
        let rank: (Row) -> Int = { u in
            if u.s("start").isEmpty || u.s("end").isEmpty { return 2 }
            if today < u.s("start") { return 1 }
            if today > u.s("end") { return 3 }
            return 0
        }
        let us = db.unitsSorted.sorted { rank($0) < rank($1) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Units of inquiry").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                    Text("\(us.count) unit\(us.count == 1 ? "" : "s")").font(.system(size: 13)).foregroundStyle(Color.ink2)
                    Spacer()
                    Button("New unit") { model.sheet = .unit(id: "__new") }.buttonStyle(.borderedProminent)
                }
                if us.isEmpty {
                    EmptyNote(title: "No units yet",
                              message: "Add your unit of inquiry with its theme, central idea and dates. TDL lessons in those dates will show it, and Term will mark the weeks.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14, alignment: .top)], spacing: 14) {
                        ForEach(us, id: \Row.["id"]) { u in UnitCard(unit: u) }
                    }
                }
                Text("Focus ATLs and attributes are highlighted. Numbers count lessons tagged inside the unit's dates, in any subject.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            }
            .padding(24)
        }
    }
}

struct UnitCard: View {
    @Environment(AppModel.self) private var model
    var unit: Row

    var body: some View {
        let db = model.db
        let today = todayISO()
        let st = today < unit.s("start") ? "Coming up" : (today > unit.s("end") ? "Finished" : "Now")
        let status = unit.s("start").isEmpty || unit.s("end").isEmpty ? "" : st
        let thisMonday = mondayOf(today)
        let inThisWeek = !unit.s("start").isEmpty && !unit.s("end").isEmpty
            && unit.s("start") <= addDays(thisMonday, 4) && unit.s("end") >= thisMonday
        let tone = ToneMaths.tone(hex: PYP.themeHex(unit.s("theme")))
        let stats = db.unitStats(unit)
        let lines = linesOf(unit.s("lines"))
        let key = listOf(unit.s("concepts"))
        let related = listOf(unit.s("related"))
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(unit.s("theme").isEmpty ? "No theme" : unit.s("theme"))
                    .font(.system(size: 11.5, weight: .bold)).foregroundStyle(tone.inkColor)
                if !status.isEmpty { TagLabel(text: status, fg: tone.inkColor, bg: Color.white.opacity(0.7)) }
                if inThisWeek { TagLabel(text: "This week", fg: tone.inkColor, bg: Color.white.opacity(0.7)) }
                Spacer()
                Button("Edit") { model.sheet = .unit(id: unit.s("id")) }
            }
            Text(unit.s("title").isEmpty ? "Untitled unit" : unit.s("title")).font(.system(size: 19, weight: .bold))
            Text(unitDatesText(db, unit) + (stats.tdl > 0 ? " · TDL \(stats.planned) of \(stats.tdl) lessons planned" : ""))
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
            if !unit.s("central_idea").isEmpty {
                Text(unit.s("central_idea")).font(.system(size: 14, weight: .medium))
            }
            if !lines.isEmpty {
                sectionTitle("Lines of inquiry")
                ForEach(lines, id: \.self) { l in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                        Text(l).font(.system(size: 13))
                    }
                }
            }
            if !key.isEmpty || !related.isEmpty {
                sectionTitle("Concepts")
                ChipRow(items: key + related, tinted: true)
            }
            sectionTitle("ATL skills (tagged in lessons)")
            countChips(stats.atl, focus: listOf(unit.s("atl")), tone: tone)
            sectionTitle("Learner profile (tagged in lessons)")
            countChips(stats.lp, focus: listOf(unit.s("profile")), tone: tone)
            if !unit.s("reflection").isEmpty {
                sectionTitle("Reflection")
                Text(unit.s("reflection")).font(.system(size: 13))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(status == "Now" ? tone.barColor : Color.clear, lineWidth: 2))
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.5).foregroundStyle(Color.ink2).padding(.top, 4)
    }

    @ViewBuilder
    private func countChips(_ counts: [String: Int], focus: [String], tone: Tone) -> some View {
        let keys = Array(Set(focus + Array(counts.keys))).sorted()
        if keys.isEmpty {
            Text("None yet").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        } else {
            FlowLayout(spacing: 6) {
                ForEach(keys, id: \.self) { k in
                    let isFocus = focus.contains(k)
                    HStack(spacing: 4) {
                        Text(k)
                        if let n = counts[k], n > 0 { Text("\(n)").fontWeight(.bold) }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 3).padding(.horizontal, 9)
                    .background(Color.white.opacity(isFocus ? 0.9 : 0.5))
                    .overlay(Capsule().stroke(isFocus ? tone.barColor : Color.clear, lineWidth: 1.5))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

struct UnitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var unitID: String
    @State private var u: Row = [:]
    @State private var loaded = false
    @State private var armDelete = false
    @State private var error = ""

    private var isNew: Bool { unitID == "__new" }

    private func b(_ k: String) -> Binding<String> {
        Binding(get: { u[k] ?? "" }, set: { u[k] = $0 })
    }

    var body: some View {
        SheetFrame(title: isNew ? "New unit" : "Edit unit", subtitle: u["title"] ?? "", width: 620) {
            LineField(label: "Unit title", text: b("title"), placeholder: "What's my business?")
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: "Transdisciplinary theme")
                Picker("", selection: b("theme")) {
                    Text("Choose a theme").tag("")
                    ForEach(PYP.themes.map { $0.name }, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
            }
            HStack(alignment: .top, spacing: 16) {
                OptionalDate(label: "Starts", iso: b("start"))
                OptionalDate(label: "Ends", iso: b("end"))
            }
            NoteBox(label: "Central idea", text: b("central_idea"), lines: 2)
            NoteBox(label: "Lines of inquiry", hint: "one per line", text: b("lines"), lines: 3)
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Key concepts")
                ChipToggles(options: PYP.keyConcepts, value: b("concepts"))
            }
            LineField(label: "Related concepts", hint: "comma separated", text: b("related"))
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "ATL skills focus")
                ChipToggles(options: PYP.atlSkills, value: b("atl"))
            }
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Learner profile focus")
                ChipToggles(options: PYP.profile, value: b("profile"))
            }
            NoteBox(label: "Notes", text: b("notes"), lines: 2)
            NoteBox(label: "Reflection", hint: "at the end of the unit", text: b("reflection"), lines: 3)
            if !error.isEmpty { Text(error).font(.system(size: 12.5)).foregroundStyle(Color.appRed) }
            HStack {
                Button("Save") { save() }.buttonStyle(.borderedProminent)
                Button("Cancel") { dismiss() }
                Spacer()
                if !isNew {
                    Button(armDelete ? "Click again to delete" : "Delete unit") {
                        if !armDelete { armDelete = true; return }
                        model.db.deleteRow(.units, id: unitID)
                        model.showToast("Unit deleted")
                        dismiss()
                    }
                    .foregroundStyle(Color.appRed)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if isNew {
                u = ["id": uid()]
            } else if let r = model.db.rows(.units).first(where: { $0.s("id") == unitID }) {
                u = r
            }
        }
    }

    private func save() {
        let title = (u["title"] ?? "").trimmingCharacters(in: .whitespaces)
        if title.isEmpty { error = "Give the unit a title."; return }
        let s = u["start"] ?? "", e = u["end"] ?? ""
        if !s.isEmpty && !e.isEmpty && e < s { error = "The end date is before the start."; return }
        u["title"] = title
        let db = model.db
        if isNew {
            db.append(.units, u)
        } else {
            db.update(.units, where: { $0.s("id") == unitID }) { row in
                for (k, v) in u { row[k] = v }
            }
        }
        db.touch(.units)
        model.showToast("Unit saved")
        dismiss()
    }
}

/// A date that may be empty.
struct OptionalDate: View {
    var label: String
    @Binding var iso: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel(text: label)
            if iso.isEmpty {
                Button("Set date") { iso = todayISO() }
            } else {
                HStack {
                    DatePicker("", selection: isoBinding({ iso }, { iso = $0 }), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                    Button("Clear") { iso = "" }
                }
            }
        }
    }
}

// MARK: - Devotion

struct DevotionView: View {
    @Environment(AppModel.self) private var model

    private func defaultFor(_ day: String, _ dates: [String]) -> String {
        dates.first(where: { $0 >= day }) ?? dates.last ?? day
    }

    var body: some View {
        let db = model.db
        let all = db.rows(.devotion).sorted { $0.s("date") < $1.s("date") }
        if all.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader("Devotion")
                EmptyNote(title: "No devotions loaded", message: "Add the Circle Time lessons to devotion.csv in the data folder.")
                Spacer()
            }
            .padding(24)
        } else {
            let dates = all.map { $0.s("date") }
            let date = (model.devotionDate.map { dates.contains($0) } ?? false) ? (model.devotionDate ?? "") : defaultFor(todayISO(), dates)
            let i = dates.firstIndex(of: date) ?? 0
            let d = all[i]
            let t = db.termOf(date)
            let thisWeek = mondayOf(date) == mondayOf(todayISO())
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Devotion").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                        Text("\(Cal.weekdayLong[dayIdx(date)]) \(shortDate(date))"
                             + (t.map { " · Term \($0.term), week \(db.termWeek(date) ?? 0)" } ?? ""))
                            .font(.system(size: 13)).foregroundStyle(Color.ink2)
                        if thisWeek { TagLabel(text: "This week") }
                        Spacer()
                    }
                    FlowLayout(spacing: 8) {
                        Button("Previous") { model.devotionDate = dates[i - 1] }.disabled(i <= 0)
                        Button("Today") { model.devotionDate = defaultFor(todayISO(), dates) }
                        Button("Next") { model.devotionDate = dates[i + 1] }.disabled(i >= dates.count - 1)
                        Picker("", selection: Binding(get: { date }, set: { model.devotionDate = $0 })) {
                            ForEach(all, id: \Row.["date"]) { x in
                                Text("\(Cal.weekdayShort[dayIdx(x.s("date"))]) \(shortDate(x.s("date"))): \(x.s("theme"))").tag(x.s("date"))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 300)
                    }
                    DevotionCard(d: d)
                }
                .padding(24)
                .frame(maxWidth: 900, alignment: .leading)
            }
        }
    }
}

struct DevotionCard: View {
    var d: Row

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(d.s("theme")).font(.system(size: 24, weight: .bold))
            let chips = [d.s("scripture"), d.s("time"), d.s("domain"),
                         d.s("profile").isEmpty ? "" : "Learner Profile: " + d.s("profile"),
                         d.s("primer_name").isEmpty ? "" : "Berry Street: " + d.s("primer_name")].filter { !$0.isEmpty }
            ChipRow(items: chips, tinted: true)
            if !d.s("focus").isEmpty { Text(d.s("focus")).font(.system(size: 14)).foregroundStyle(Color.ink2) }
            section(1, "Greeting and check-in") { paras(d.s("greeting")) }
            section(2, "Values and expectations") { paras(d.s("values")) }
            section(3, "The devotion") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(d.s("reading")).font(.system(size: 15, design: .serif)).italic().textSelection(.enabled)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(d.s("scripture")).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.ink2)
                    Text("The message").font(.system(size: 13.5, weight: .semibold))
                    paras(d.s("message"))
                    Text("Reflection questions").font(.system(size: 13.5, weight: .semibold)).padding(.top, 4)
                    ForEach(linesOf(d.s("questions")), id: \.self) { q in
                        HStack(alignment: .top, spacing: 6) { Text("\u{2022}"); Text(q).textSelection(.enabled) }.font(.system(size: 14))
                    }
                    Text("Prayer").font(.system(size: 13.5, weight: .semibold)).padding(.top, 4)
                    paras(d.s("prayer"))
                }
            }
            section(4, "Positive primer: " + d.s("primer_name")) {
                VStack(alignment: .leading, spacing: 6) {
                    paras(d.s("primer"))
                    if !d.s("primer_note").isEmpty {
                        Text(d.s("primer_note")).font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                }
            }
            section(5, "What went well and transition") {
                VStack(alignment: .leading, spacing: 6) {
                    paras(d.s("went_well"))
                    if !d.s("transition").isEmpty {
                        Text("Transition: " + d.s("transition")).font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func section<C: View>(_ n: Int, _ title: String, @ViewBuilder _ body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(n). \(title)").font(.system(size: 15, weight: .semibold)).padding(.top, 6)
            body()
        }
    }

    private func paras(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(linesOf(text).enumerated()), id: \.offset) { _, p in
                Text(p).font(.system(size: 14)).textSelection(.enabled)
            }
        }
    }
}
