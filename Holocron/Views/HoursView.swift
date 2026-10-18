import SwiftUI

// MARK: - Hours

struct TermHours: Identifiable {
    var term: Term
    var full: Database.Minutes
    var sofar: Database.Minutes
    var id: String { term.id }
}

struct HoursView: View {
    @Environment(AppModel.self) private var model

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
                DottlForm()

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

/// The form for logging DOTTL time. It keeps its own typing, so the hours tables above are not worked
/// out again on every keystroke.
private struct DottlForm: View {
    @Environment(AppModel.self) private var model
    @State private var date = todayISO()
    @State private var type = Lists.dottlTypes[0]
    @State private var minutes = "60"
    @State private var note = ""

    var body: some View {
        let db = model.db
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
            }
            .buttonStyle(.borderedProminent)
        }
        .card()
    }
}
