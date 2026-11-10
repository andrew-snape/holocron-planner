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
    @State private var sort = [MarkSort(key: "name")]

    var body: some View {
        let db = model.db
        let subjects = subjectsWithResults(db)
        let current = subjects.contains(subject) ? subject : (subjects.first ?? "")
        let grid = Markbook.build(assessments: db.rows(.assessments), students: db.roster.map(\.id), subject: current)
        let rows = markRows(grid, db).sorted(using: sort)
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
                Table(rows, sortOrder: $sort) {
                    TableColumn("Student", sortUsing: MarkSort(key: "name")) { row in
                        Text(row.name).font(.body1Medium)
                    }
                    .width(min: 130, ideal: 170)
                    TableColumnForEach(grid.tasks) { t in
                        TableColumn(title(t), sortUsing: MarkSort(key: t.id)) { row in
                            cell(row.line.results[t.id] ?? "", db)
                        }
                        .width(min: 90, ideal: 110)
                    }
                    TableColumn("Average", sortUsing: MarkSort(key: "avg")) { row in
                        Text(row.values["avg"].map { "\(Int($0.rounded()))%" } ?? "")
                            .font(.body1).foregroundStyle(Color.ink2)
                    }
                    .width(min: 70, ideal: 80)
                    TableColumnForEach(grid.pairs) { p in
                        TableColumn("Growth: " + p.base, sortUsing: MarkSort(key: p.id)) { row in
                            growthCell(row.values[p.id])
                        }
                        .width(min: 100, ideal: 120)
                    }
                }
                .frame(minHeight: 260)
                missingList(grid, db)
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

    @ViewBuilder
    private func cell(_ result: String, _ db: Database) -> some View {
        if result.isEmpty {
            Text("Missing")
                .font(.label).foregroundStyle(Color.ink2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.appAmber.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
                .accessibilityLabel("Missing result")
        } else if let band = Markbook.band(result) {
            let tone = db.tone(forHex: band.hex)
            Text(result)
                .font(.caption1Medium)
                .foregroundStyle(tone.inkColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(tone.tintColor, in: RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
        } else {
            Text(result).font(.caption1)
        }
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

    @ViewBuilder
    private func missingList(_ grid: Markbook.Grid, _ db: Database) -> some View {
        let gaps = grid.tasks.map { ($0, Markbook.missing(grid, task: $0)) }.filter { !$0.1.isEmpty }
        if !gaps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Missing results").font(.hSection)
                ForEach(gaps, id: \.0.id) { t, ids in
                    (Text(title(t) + ": ").font(.caption1Semibold)
                     + Text(ids.map { db.studentName($0) }.joined(separator: ", ")).font(.caption1))
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
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
