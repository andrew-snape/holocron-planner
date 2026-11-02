import SwiftUI

// MARK: - Importing Essential Assessment report comments
//
// Shown by Import results when the file is a Report Comments export. Students are matched to the
// roll as for results, and their Areas of Success, Growth and Improvement are kept with the
// semester for drafting the Mathematics or English comment.

struct StrandCommentsImport: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var file: StrandCommentsFile
    @State private var sem = ""
    @State private var people: [ImportPerson] = []
    @State private var assigned: [String: String] = [:]
    @State private var showOthers = false
    @State private var done: (added: Int, replaced: Int)? = nil

    private var draft: ResultsDraft {
        var map = ColumnMap()
        map[.name] = file.table.header.map(ColumnMap.normalised).firstIndex(of: "student")
        return ResultsDraft(table: file.table, map: map)
    }

    var body: some View {
        let db = model.db
        VStack(alignment: .leading, spacing: 14) {
            if let done {
                Text("Imported").font(.system(size: 22, weight: .bold))
                Text("\(file.label) comments are saved for \(plural(done.added + done.replaced, "student"))"
                     + (done.replaced > 0 ? ", replacing \(done.replaced) from an earlier import." : ".")
                     + " Draft \(file.kind == .english ? "English" : "Mathematics") points on each student's Report tab to use them.")
                    .font(.system(size: 13)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            } else {
                form(db)
            }
        }
        .onAppear { if people.isEmpty { start() } }
    }

    private func start() {
        let db = model.db
        sem = db.reportSem()
        people = draft.people(roster: db.roster, remembered: db.rememberedImportRefs)
        for p in people { if let s = p.match.studentID { assigned[p.id] = s } }
    }

    @ViewBuilder
    private func form(_ db: Database) -> some View {
        let onRoll = people.filter { assigned[$0.id] != nil }
        let others = people.filter { assigned[$0.id] == nil }
        let existing = Set(db.rows(.strandcomments).filter {
            $0.s("sem") == sem && $0.s("strand") == file.strand && $0.s("substrand") == file.substrand
        }.map { $0.s("student_id") })
        let replacing = onRoll.filter { existing.contains(assigned[$0.id] ?? "") }.count
        let doubled = Dictionary(grouping: assigned.values, by: { $0 }).filter { $0.value.count > 1 }.keys

        VStack(alignment: .leading, spacing: 4) {
            Text("Import report comments").font(.system(size: 22, weight: .bold))
            Text(file.table.name).font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.ink2).lineLimit(1).truncationMode(.middle)
        }
        VStack(alignment: .leading, spacing: 8) {
            Label("Essential Assessment report comments: \(file.label)" + (file.className.isEmpty ? "" : ", \(file.className)"),
                  systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Areas of Success, Growth and Improvement are kept for each student and used when you draft their \(file.kind == .english ? "English" : "Mathematics") points.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Semester").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                Picker("", selection: $sem) {
                    ForEach(semesters, id: \.self) { Text($0.replacingOccurrences(of: "-", with: " ")).tag($0) }
                }
                .labelsHidden().frame(width: 140)
                .accessibilityLabel("Semester")
            }
        }
        .card()

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(onRoll.isEmpty ? "No students matched your roll." : "\(plural(onRoll.count, "student")) in the file \(onRoll.count == 1 ? "is" : "are") on your roll.")
                    .font(.system(size: 13, weight: .semibold))
                ForEach(onRoll) { p in row(p, db) }
                if !others.isEmpty {
                    DisclosureGroup(isExpanded: $showOthers) {
                        ForEach(others) { p in row(p, db) }
                    } label: {
                        Text("Not matched (\(others.count)). Open to match any of them to a student.").font(.system(size: 12.5))
                    }
                }
            }
            .card()
        }
        .frame(minHeight: 160, maxHeight: 420)

        if replacing > 0 {
            Text("\(plural(replacing, "student")) already \(replacing == 1 ? "has" : "have") \(file.label) comments for this semester. They are replaced.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !doubled.isEmpty {
            Label("\(doubled.map { db.studentName($0) }.sorted().joined(separator: ", ")) \(doubled.count == 1 ? "is" : "are") picked for more than one person in the file.",
                  systemImage: "exclamationmark.triangle")
                .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Import for \(plural(onRoll.count, "student"))") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(onRoll.isEmpty || !doubled.isEmpty)
        }
    }

    private func row(_ p: ImportPerson, _ db: Database) -> some View {
        HStack(spacing: 10) {
            Text(p.name).font(.system(size: 13)).lineLimit(1).frame(width: 200, alignment: .leading)
            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Color.ink3).accessibilityHidden(true)
            Picker("", selection: Binding(get: { assigned[p.id] ?? "" }, set: { assigned[p.id] = $0.isEmpty ? nil : $0 })) {
                Text("Leave out").tag("")
                ForEach(db.roster) { Text($0.fullName).tag($0.id) }
            }
            .labelsHidden().frame(width: 200)
            .accessibilityLabel("Student for \(p.name)")
            if case .likely(let sid) = p.match, assigned[p.id] == sid {
                TagLabel(text: "Check", fg: .appAmber, bg: Color.appAmber.opacity(0.14))
                    .help("The name is close but not the same. Check it is the right student.")
            }
            Spacer()
        }
    }

    private var semesters: [String] {
        let y = yearOf(todayISO())
        return [y - 1, y, y + 1].flatMap { ["\($0)-S1", "\($0)-S2"] }
    }

    private func save() {
        let d = draft
        var chosen: [(item: StrandCommentsFile.Item, sid: String)] = []
        // A student listed twice in the file keeps their first row.
        var taken = Set<String>()
        for item in file.items {
            let pid = d.personID(item.row)
            if let sid = assigned[pid], taken.insert(pid).inserted { chosen.append((item, sid)) }
        }
        done = model.db.saveStrandComments(file, sem: sem, students: chosen)
    }
}
