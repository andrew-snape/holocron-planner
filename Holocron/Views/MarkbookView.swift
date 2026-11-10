import SwiftUI
import AppKit
import Charts

// MARK: - Class markbook
//
// One subject's results for the whole class: students down, tasks across. Cells take their colour from the
// result through Tone. Empty cells say Missing. A pre-test and post-test of the same thing get a growth column.

/// A row in the markbook table, with the numbers each column sorts by.
private struct MarkRow: Identifiable {
    var id: String
    var name: String
    var line: Markbook.Line
    var values: [String: Double]
}

/// Sorts the table by the student's name, the average, a growth column or one task's results.
/// A student with nothing in the column goes last.
private struct MarkSort: SortComparator {
    var key: String
    var order: SortOrder = .forward

    func compare(_ a: MarkRow, _ b: MarkRow) -> ComparisonResult {
        var r: ComparisonResult
        if key == "name" {
            r = a.name.localizedStandardCompare(b.name)
        } else {
            switch (a.values[key], b.values[key]) {
            case (nil, nil): r = .orderedSame
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case (let x?, let y?): r = x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
            }
        }
        if order == .reverse {
            r = r == .orderedAscending ? .orderedDescending : (r == .orderedDescending ? .orderedAscending : .orderedSame)
        }
        return r
    }
}

struct MarkbookView: View {
    @Environment(AppModel.self) private var model
    @State private var subject = ""
    @State private var sortKey = "name"
    @State private var ascending = true

    /// Column widths for the grid. Header and rows share them so they line up.
    private enum W {
        static let name: CGFloat = 170
        static let task: CGFloat = 120
        static let avg: CGFloat = 80
        static let growth: CGFloat = 130
    }

    var body: some View {
        let db = model.db
        let subjects = subjectsWithResults(db)
        let current = subjects.contains(subject) ? subject : (subjects.first ?? "")
        let grid = Markbook.build(assessments: db.rows(.assessments), students: db.roster.map(\.id), subject: current)
        let rows = markRows(grid, db).sorted(using: MarkSort(key: sortKey, order: ascending ? .forward : .reverse))
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Subject")
                    Picker("", selection: Binding(get: { current }, set: { subject = $0 })) {
                        ForEach(subjects, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                Spacer()
                legend
            }
            if subjects.isEmpty || grid.tasks.isEmpty {
                EmptyNote(title: "No results yet", message: "Mark a task in Mark class, or import results, and the whole class shows here.")
            } else {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(rows) { row in
                            HStack(spacing: 0) {
                                Text(row.name).font(.body1Medium)
                                    .frame(width: W.name, alignment: .leading)
                                ForEach(grid.tasks) { t in
                                    GradeCell(result: row.line.results[t.id] ?? "", label: "\(row.name), \(title(t))") { setResult(row.id, t, $0) }
                                        .frame(width: W.task, alignment: .leading)
                                }
                                Text(row.values["avg"].map { "\(Int($0.rounded()))%" } ?? "")
                                    .font(.body1).foregroundStyle(Color.ink2)
                                    .frame(width: W.avg, alignment: .leading)
                                ForEach(grid.pairs) { p in
                                    growthCell(row.values[p.id])
                                        .frame(width: W.growth, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 6)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(rowLabel(row, grid, db))
                            Rectangle().fill(Color.hairline).frame(height: 1)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    headerCell("Student", key: "name", width: W.name)
                                    ForEach(grid.tasks) { t in headerCell(title(t), key: t.id, width: W.task) }
                                    headerCell("Average", key: "avg", width: W.avg)
                                    ForEach(grid.pairs) { p in headerCell("Growth: " + p.base, key: p.id, width: W.growth) }
                                }
                                Rectangle().fill(Color.hairline).frame(height: 1)
                            }
                            .background(Color.cardBG)
                        }
                    }
                }
                .frame(minHeight: 260)
            }
        }
        .padding(24)
        .navigationSubtitle("The whole class for one subject")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { export(grid, db) } label: { Label("Export CSV…", systemImage: "square.and.arrow.up") }
                    .disabled(grid.tasks.isEmpty)
                    .help("Save this grid as a CSV file you can open in a spreadsheet")
            }
        }
    }

    private func subjectsWithResults(_ db: Database) -> [String] {
        let have = Set(db.rows(.assessments).filter { !$0.s("task").isEmpty }.map { $0.s("subject") })
        return db.subjectNames.filter { have.contains($0) }
    }

    /// A column heading that sorts the grid. Click once to sort, again to reverse.
    private func headerCell(_ text: String, key: String, width: CGFloat) -> some View {
        Button {
            if sortKey == key { ascending.toggle() } else { sortKey = key; ascending = true }
        } label: {
            HStack(spacing: 4) {
                Text(text).font(.caption1Semibold).lineLimit(2).multilineTextAlignment(.leading)
                if sortKey == key {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.label)
                }
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ink2)
        .padding(.vertical, 6)
        .accessibilityLabel("Sort by \(text)")
        .accessibilityValue(sortKey == key ? (ascending ? "Sorted ascending" : "Sorted descending") : "Not sorted")
        .accessibilityAddTraits(sortKey == key ? .isSelected : [])
    }

    /// One sentence per row for VoiceOver: the student, then each task, the average and the growth.
    private func rowLabel(_ row: MarkRow, _ grid: Markbook.Grid, _ db: Database) -> String {
        var parts = [row.name]
        for t in grid.tasks {
            let r = row.line.results[t.id] ?? ""
            parts.append("\(title(t)): \(r.isEmpty ? "Missing" : r)")
        }
        if let a = row.values["avg"] { parts.append("Average \(Int(a.rounded())) percent") }
        for p in grid.pairs {
            if let g = row.values[p.id] { parts.append("Growth \(p.base): \(Markbook.growthText(g))") }
        }
        return parts.joined(separator: ", ")
    }

    private func title(_ t: Markbook.TaskColumn) -> String {
        t.date.isEmpty ? t.task : "\(t.task), \(shortDate(t.date))"
    }

    private func markRows(_ grid: Markbook.Grid, _ db: Database) -> [MarkRow] {
        grid.lines.map { l in
            var v: [String: Double] = [:]
            for t in grid.tasks { if let p = Markbook.percent(l.results[t.id] ?? "") { v[t.id] = p } }
            if let a = Markbook.average(l, tasks: grid.tasks) { v["avg"] = a }
            for p in grid.pairs { if let g = Markbook.growth(p, l) { v[p.id] = g } }
            return MarkRow(id: l.id, name: db.studentName(l.id), line: l, values: v)
        }
    }

    /// Saves one result typed in the grid the same way Mark class does: it updates the row, adds one,
    /// or removes it when the box is cleared.
    private func setResult(_ sid: String, _ t: Markbook.TaskColumn, _ res: String) {
        let db = model.db
        guard model.canWrite(.assessments) else {
            model.showToast("Assessments could not be saved. Its file failed to read.")
            return
        }
        let isMine: (Row) -> Bool = {
            $0.s("student_id") == sid && $0.s("subject") == t.subject && $0.s("task") == t.task && $0.s("date") == t.date
        }
        if res.isEmpty {
            // A row with a comment stays, so the comment is not lost. Mark class removes only rows with neither.
            let hasComment = db.rows(.assessments).contains { isMine($0) && !$0.s("comment").isEmpty }
            if hasComment {
                db.update(.assessments, where: isMine) { $0["result"] = "" }
            } else {
                db.remove(.assessments, where: isMine)
            }
        } else if db.rows(.assessments).contains(where: isMine) {
            db.update(.assessments, where: isMine) { $0["result"] = res }
        } else {
            db.append(.assessments, ["id": uid(), "student_id": sid, "date": t.date, "subject": t.subject,
                                     "task": t.task, "result": res, "comment": ""])
        }
        db.touch(.assessments)
    }

    @ViewBuilder
    private func growthCell(_ g: Double?) -> some View {
        if let g {
            Text(Markbook.growthText(g))
                .font(.caption1Semibold)
                .foregroundStyle(g > 0 ? Color.appGreen : (g < 0 ? Color.appRed : Color.ink2))
        } else {
            Text("").accessibilityHidden(true)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach(Markbook.Band.allCases, id: \.rawValue) { b in
                let tone = model.db.tone(forHex: b.hex)
                Text(label(b))
                    .font(.labelMedium)
                    .foregroundStyle(tone.inkColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(tone.tintColor, in: Capsule())
            }
        }
        .accessibilityHidden(true)
    }

    private func label(_ b: Markbook.Band) -> String {
        switch b {
        case .top: return "Extending"
        case .strong: return "Mastering"
        case .middle: return "Consolidating"
        case .developing: return "Developing"
        case .low: return "Emerging"
        case .modified: return "Modified"
        }
    }

    private func export(_ grid: Markbook.Grid, _ db: Database) {
        let names = Dictionary(uniqueKeysWithValues: db.roster.map { ($0.id, db.studentName($0.id)) })
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Markbook \(grid.subject).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.message = "This file has your students' names and results. Keep it somewhere private."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Markbook.csv(grid, names: names).write(to: url, options: .atomic)
            model.showToast("Saved \(url.lastPathComponent)")
        } catch {
            model.showToast("The file could not be saved")
        }
    }
}

// MARK: - A student's results over time

/// A line for each subject on a 0 to 100 scale. Scores count as their percentage and achievement levels as 20 to 100.
struct GrowthChart: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        let db = model.db
        let pts = Markbook.points(assessments: db.rows(.assessments), student: sid)
        let subs = Array(Set(pts.map(\.subject))).sorted()
        if pts.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Growth").font(.hSection)
                Chart(pts) { p in
                    LineMark(x: .value("Date", date(p.date)), y: .value("Result", p.percent), series: .value("Subject", p.subject))
                        .foregroundStyle(by: .value("Subject", p.subject))
                    PointMark(x: .value("Date", date(p.date)), y: .value("Result", p.percent))
                        .foregroundStyle(by: .value("Subject", p.subject))
                        .accessibilityLabel("\(p.subject), \(p.task)")
                        .accessibilityValue("\(Int(p.percent.rounded())) percent")
                }
                .chartForegroundStyleScale(domain: subs, range: subs.map { db.tone(forSubject: $0).barColor })
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 20, 40, 60, 80, 100]) }
                .frame(height: 170)
                Text("Scores show as a percentage. Achievement levels show as Emerging 20 up to Extending 100. Results with no number are left out.")
                    .font(.label).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
        }
    }

    private func date(_ s: String) -> Date {
        guard let (y, m, d) = Cal.parts(s) else { return Date() }
        return Date(timeIntervalSince1970: Double(Cal.daysFromCivil(y, m, d)) * 86400)
    }
}

// MARK: - A result box in the grid

/// A result in the Markbook grid. Click it to type a result. Return, or clicking away, saves it.
/// An empty box says Missing. A box that is cleared is removed, as in Mark class.
private struct GradeCell: View {
    @Environment(AppModel.self) private var model
    var result: String
    var label: String
    var onCommit: (String) -> Void
    @State private var editing = false
    @State private var text = ""
    @State private var cancelled = false
    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            TextField("Result", text: $text)
                .textFieldStyle(.plain)
                .font(.caption1)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .frame(width: 112, alignment: .leading)
                .background(Color.fieldBG, in: RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous).stroke(Color.fieldStroke))
                .focused($focused)
                .onAppear { focused = true }
                .onSubmit { finish() }
                .onChange(of: focused) { _, now in if !now { finish() } }
                .onExitCommand { cancelled = true; finish() }
                .accessibilityLabel(label)
        } else {
            Button {
                text = result
                cancelled = false
                editing = true
            } label: {
                pill
                    .frame(width: 112, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(result.isEmpty ? "Missing" : result)
            .help("Click to type a result")
        }
    }

    @ViewBuilder
    private var pill: some View {
        if result.isEmpty {
            Text("Missing")
                .font(.label).foregroundStyle(Color.ink2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.appAmber.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
        } else if let band = Markbook.band(result) {
            let tone = model.db.tone(forHex: band.hex)
            Text(result)
                .font(.caption1Medium)
                .foregroundStyle(tone.inkColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(tone.tintColor, in: RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
        } else {
            Text(result).font(.caption1)
        }
    }

    private func finish() {
        guard editing else { return }
        editing = false
        if cancelled { return }
        let new = text.trimmingCharacters(in: .whitespaces)
        if new != result { onCommit(new) }
    }
}
