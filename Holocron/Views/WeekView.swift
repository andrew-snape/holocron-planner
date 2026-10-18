import SwiftUI
import AppKit

struct WeekView: View {
    @Environment(AppModel.self) private var model
    @State private var viewport: CGFloat = 900
    @AppStorage(PrintWeek.intentionsKey) private var printIntentions = true

    var body: some View {
        let db = model.db
        let mon = model.shownMonday
        let wk = db.weekLetter(mon) ?? "A"
        let tm = db.termOf(mon)
        let lead = tm.map { "Term \($0.term) Week \(db.termWeek(mon) ?? 0)" } ?? "Outside term"
        let subjects = db.timetableSubjects

        let colWidth = max(150, (viewport - 20 - WeekGrid.labelW - 4 * 5) / 5)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(lead).font(.system(size: 28, weight: .bold)).tracking(-0.5)
                    Text("\(shortDate(mon)) to \(shortDate(addDays(mon, 4)))").font(.system(size: 13)).foregroundStyle(Color.ink2)
                    WeekBadge(letter: wk)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button("Last Week") { model.weekMonday = addDays(mon, -7) }
                    Button("This Week") { model.weekMonday = nil }
                    Button("Next Week") { model.weekMonday = addDays(mon, 7) }
                    Text("Type into a slot, click a subject to change it, drag to swap")
                        .font(.system(size: 12)).foregroundStyle(Color.ink3).lineLimit(1)
                    Spacer()
                    Menu {
                        Button("Print Week...") { PrintWeek.open(model: model) }
                        Button("Save as PDF...") { PrintWeek.save(model: model) }
                        Divider()
                        Toggle("Include learning intentions", isOn: $printIntentions)
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .fixedSize()
                    .help("Print this week on one A4 page, or save it as a PDF")
                    Picker("", selection: Binding(get: { model.weekFilter }, set: { model.weekFilter = $0 })) {
                        Text("All subjects").tag("")
                        ForEach(subjects, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    WeekGrid(mon: mon, wk: wk, colW: colWidth)
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

struct WeekGrid: View {
    @Environment(AppModel.self) private var model
    var mon: String
    var wk: String
    var colW: CGFloat
    static let labelW: CGFloat = 96

    var body: some View {
        let db = model.db
        let ps = db.periods
        Grid(alignment: .topLeading, horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: WeekGrid.labelW, height: 1)
                ForEach(0..<5, id: \.self) { i in
                    let d = addDays(mon, i)
                    let isToday = d == todayISO()
                    HStack(spacing: 5) {
                        Text(Cal.weekdayLong[i]).font(.system(size: 12.5, weight: .semibold))
                        Text(shortDate(d)).font(.system(size: 12))
                    }
                    .foregroundStyle(isToday ? Color.white : Color.primary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(isToday ? Color.appBlue : Color.clear)
                    .clipShape(Capsule())
                    .frame(width: colW, alignment: .leading)
                }
            }
            ForEach(Array(ps.enumerated()), id: \.element.id) { idx, p in
                GridRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.system(size: 12.5, weight: .semibold))
                        Text("\(p.start) to \(p.end)").font(.system(size: 11.5, design: .rounded)).foregroundStyle(Color.ink2)
                    }
                    .frame(width: WeekGrid.labelW, alignment: .leading)
                    .padding(.top, 6)
                    ForEach(0..<5, id: \.self) { di in
                        SlotCell(date: addDays(mon, di), day: di, wk: wk, period: p, colW: colW)
                    }
                }
                if idx + 1 < ps.count, mins(p.end, ps[idx + 1].start) > 0 {
                    let label = breakLabel(from: p.end, to: ps[idx + 1].start)
                    GridRow {
                        Text("\(p.end) to \(ps[idx + 1].start)")
                            .font(.system(size: 10.5, design: .rounded)).foregroundStyle(Color.ink3)
                            .frame(width: WeekGrid.labelW, alignment: .leading)
                        HStack(spacing: 10) {
                            Text(label).font(.system(size: 11)).foregroundStyle(Color.ink3)
                            Rectangle().fill(Color.black.opacity(0.14)).frame(height: 0.5)
                        }
                        .padding(.horizontal, 8)
                        .gridCellColumns(5)
                    }
                }
            }
        }
    }
}

struct SlotCell: View {
    @Environment(AppModel.self) private var model
    var date: String
    var day: Int
    var wk: String
    var period: Period
    var colW: CGFloat
    @FocusState private var focused: Bool

    var body: some View {
        let db = model.db
        let pn = period.period
        let subj = db.plannedSubject(date, pn, fallbackWeek: wk)
        let moved = db.isMoved(date, pn)
        let info = db.subjectInfo(subj)
        let tone = subj.isEmpty ? Tone.unset : db.tone(forSubject: subj)
        let dim = !model.weekFilter.isEmpty && subj != model.weekFilter
        let c = db.content(date, pn)
        let ref = SlotRef(week: wk, day: day, per: pn, date: date)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(tone.barColor).frame(width: 8, height: 8)
                Text(subj.isEmpty ? "Not set" : subj)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tone.inkColor)
                    .lineLimit(1)
                if moved { Circle().fill(Color.appAmber).frame(width: 5, height: 5).help("Changed for this date") }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.sheet = .change(date: date, per: pn) }
            .draggable(ref)
            .help("Click to change, drag onto another slot to swap")

            if info.isRelease {
                Text("Release").font(.system(size: 11.5)).foregroundStyle(tone.inkColor.opacity(0.75))
                Spacer(minLength: 0)
            } else {
                TextField("Summary", text: Binding(
                    get: { db.content(date, pn).summary },
                    set: { db.setSummary(date, pn, subj, $0) }
                ), axis: .vertical)
                    .focused($focused)
                    .lineLimit(2...6)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 7)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.white.opacity(focused ? 1 : (c.summary.isEmpty ? 0.4 : 0.8)))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(focused ? tone.barColor : Color.clear, lineWidth: 1.5))
                    .disabled(subj.isEmpty)
                if !subj.isEmpty {
                    HStack {
                        Spacer()
                        if let link = firstLink(in: c.summary) {
                            Button { NSWorkspace.shared.open(link) } label: {
                                Image(systemName: "link").font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(tone.inkColor)
                            .help("Open \(link.host ?? "link")")
                        }
                        Button {
                            model.sheet = .plan(date: date, per: pn, edit: !c.hasPlan)
                        } label: {
                            HStack(spacing: 4) {
                                if c.hasPlan { Circle().fill(tone.barColor).frame(width: 6, height: 6) }
                                Text("Plan").font(.system(size: 11, weight: c.hasPlan ? .semibold : .medium))
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(c.hasPlan ? 1 : 0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: colW, alignment: .topLeading)
        .frame(minHeight: 92, maxHeight: .infinity, alignment: .topLeading)
        .background(tintedBlock(tone, release: info.isRelease))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(dim ? 0.4 : 1)
        .dropDestination(for: SlotRef.self) { items, _ in
            guard let a = items.first, a != ref else { return false }
            model.sheet = .swap(a: a, b: ref)
            return true
        }
    }
}
