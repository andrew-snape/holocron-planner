import SwiftUI

/// Asks what to keep when you and the shared folder (or an edit made outside Holocron) changed the same
/// thing. Nothing is dropped without a choice. Also lists copies of files that iCloud made.
struct MergeSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: "Changes to choose between", subtitle: subtitle, width: 560, cancelTitle: "Close") {
            if model.mergeConflicts.isEmpty && model.conflictCopies.isEmpty {
                Text("Everything has been answered. Your choices are saved.")
                    .font(.body1).foregroundStyle(Color.ink2)
            }
            if model.mergeConflicts.count > 1 {
                HStack {
                    Button("Keep all mine") { model.resolveAllMerges(keepMine: true) }
                    Button("Keep all theirs") { model.resolveAllMerges(keepMine: false) }
                    Spacer()
                }
            }
            ForEach(model.mergeConflicts) { item in
                ConflictCard(item: item)
            }
            if !model.conflictCopies.isEmpty {
                Text("Copies made by iCloud").font(.hSection).padding(.top, 4)
                Text("iCloud makes a copy of a file when two Macs save at the same moment. Merge one in to add what is missing. The copy stays in the folder.")
                    .font(.caption1).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(model.conflictCopies) { c in
                    HStack {
                        Text(c.url.lastPathComponent).font(.body1Medium)
                        Spacer()
                        Button("Merge in") { model.mergeConflictCopy(c) }
                            .disabled(!model.mergeConflicts.isEmpty)
                    }
                    .card()
                }
            }
        }
    }

    private var subtitle: String {
        let n = model.mergeConflicts.count
        if n == 0 { return "" }
        return "\(n) changed in both places. Until you choose, the shared file keeps theirs."
    }
}

private struct ConflictCard: View {
    @Environment(AppModel.self) private var model
    let item: MergeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You and the shared folder both changed \(MergeWords.title(item, model.db)).")
                .font(.body1Semibold)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(item.conflict.columns, id: \.self) { col in
                HStack(alignment: .top, spacing: Space.gap) {
                    side("Mine", item.conflict.mine?.s(col) ?? "", col)
                    side("Theirs", item.conflict.theirs?.s(col) ?? "", col)
                }
            }
            HStack {
                Button("Keep mine") { model.resolveMerge(item, keepMine: true) }
                Button("Keep theirs") { model.resolveMerge(item, keepMine: false) }
            }
        }
        .card()
    }

    private func side(_ who: String, _ value: String, _ col: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(text: "\(who), \(MergeWords.column(col))")
            Text(value.isEmpty ? "Empty" : value)
                .font(.caption1)
                .foregroundStyle(value.isEmpty ? Color.ink3 : Color.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.fieldBG, in: RoundedRectangle(cornerRadius: Radius.field))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Plain words for a conflict, with no student names.
enum MergeWords {
    static func column(_ c: String) -> String {
        switch c {
        case "li": return "learning intention"
        case "sc": return "success criteria"
        case "codes": return "curriculum codes"
        case "atl": return "ATL skills"
        case "profile": return "learner profile"
        case "central_idea": return "central idea"
        default: return c.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func title(_ item: MergeItem, _ db: Database) -> String {
        let row = item.conflict.theirs ?? item.conflict.mine ?? [:]
        let date = row.s("date")
        let day = date.isEmpty ? "" : longDate(date)
        func period() -> String {
            let n = Int(row.s("period")) ?? 0
            return db.period(n).map { "period \(n), \($0.name)" } ?? "period \(row.s("period"))"
        }
        switch item.table {
        case .lessons, .lessonsprivate:
            return "\(row.s("subject")), \(day), \(period())"
        case .dayplan:
            return "the plan for \(day), \(period())"
        case .timetable:
            let d = Int(row.s("day")) ?? 0
            let name = (0..<5).contains(d) ? Cal.weekdayLong[d] : "day \(row.s("day"))"
            return "the timetable, Week \(row.s("week")), \(name), period \(row.s("period"))"
        case .subjects: return "the subject \(row.s("subject"))"
        case .periods: return "period \(row.s("period"))"
        case .terms: return "Term \(row.s("term")) \(row.s("year"))"
        case .units: return "the unit \(row.s("title"))"
        case .nonteaching: return "the day off on \(day)"
        case .dayoverrides: return "the day type for \(day)"
        case .devotion: return "Devotion for \(day)"
        case .quotes: return "the quote for \(day)"
        case .settings: return "the setting \(row.s("key"))"
        default:
            return "an entry in \(item.table.rawValue).csv" + (day.isEmpty ? "" : " from \(shortDate(date))")
        }
    }
}

/// Shown while there are choices to make, so they are not forgotten when another sheet is open.
struct MergeBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Space.gap) {
            Image(systemName: "arrow.triangle.merge").foregroundStyle(Color.appAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose which changes to keep").font(.body1Semibold)
                Text("You and the shared folder changed the same thing. Your changes are not saved until you choose.")
                    .font(.label).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Review") { model.sheet = .merge }
                .help("Choose which changes to keep")
        }
        .padding(Space.gap)
        .background(Color.appAmber.opacity(0.12))
        .accessibilityElement(children: .contain)
    }
}
