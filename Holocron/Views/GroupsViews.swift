import SwiftUI

/// Look after groups of students and make new ones. Groups are kept in groups.csv in the student folder.
struct GroupsSheet: View {
    @Environment(AppModel.self) private var model
    @State private var mode = Mode.random
    @State private var count = 4
    @State private var subject = ""
    @State private var label = "Group"
    @State private var made: [[String]] = []
    @State private var names: [String] = []
    @State private var deleting: StudentGroup? = nil

    enum Mode: String, CaseIterable, Identifiable {
        case random = "Random"
        case mixed = "Mixed results"
        var id: String { rawValue }
    }

    var body: some View {
        let db = model.db
        SheetFrame(title: "Groups", subtitle: "Reading groups, maths groups, inquiry teams", width: 560, cancelTitle: "Close") {
            if db.studentGroups.isEmpty {
                Text("No groups yet. Make some below.")
                    .font(.caption1).foregroundStyle(Color.ink2)
            }
            ForEach(db.studentGroups) { g in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Name", text: Binding(get: { g.name }, set: { db.renameGroup(g.id, to: $0) }))
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                        if !g.subject.isEmpty { Text(g.subject).font(.label).foregroundStyle(Color.ink2) }
                        Spacer()
                        Button("Delete", role: .destructive) { deleting = g }
                            .accessibilityLabel("Delete \(g.name)")
                    }
                    Text(db.members(of: g).map(\.first).joined(separator: ", "))
                        .font(.caption1).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }

            Text("Make groups").font(.hSection).padding(.top, 6)
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 260)
            HStack(spacing: 14) {
                Stepper("Groups: \(count)", value: $count, in: 2...8).fixedSize()
                if mode == .mixed {
                    Picker("Results from", selection: $subject) {
                        Text("Any subject").tag("")
                        ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 260)
                }
            }
            Text(mode == .random ? "Everyone is shared out by chance." : "Each group gets a spread of results. The latest scored result for each student decides, so no group has all the top results. Students with no result are shared out last.")
                .font(.caption1).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("Name", text: $label).textFieldStyle(.roundedBorder).frame(width: 160)
                Button(made.isEmpty ? "Make groups" : "Make them again") { make() }
                    .disabled(db.roster.count < count)
            }
            if !made.isEmpty {
                ForEach(Array(made.enumerated()), id: \.offset) { i, ids in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: Binding(get: { i < names.count ? names[i] : "" }, set: { if i < names.count { names[i] = $0 } }))
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                        Text(ids.map { db.student($0)?.first ?? "" }.joined(separator: ", "))
                            .font(.caption1).foregroundStyle(Color.ink2)
                    }
                    .card()
                }
                Button("Save these groups") { save() }.buttonStyle(.borderedProminent)
            }
        }
        .confirmationDialog("Delete this group?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete group", role: .destructive) { if let g = deleting { db.deleteGroup(g.id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The students stay on the roll. You can undo this from the Edit menu.")
        }
    }

    private func make() {
        let db = model.db
        let ids = db.roster.map(\.id)
        made = mode == .random
            ? Grouping.random(ids, groups: count)
            : Grouping.mixed(ids, groups: count) { db.latestPercent($0, subject: subject) }
        let base = label.trimmed.isEmpty ? "Group" : label.trimmed
        names = (1...made.count).map { "\(base) \($0)" }
    }

    private func save() {
        let db = model.db
        for (i, ids) in made.enumerated() {
            db.addGroup(name: names[i].trimmed.isEmpty ? "Group \(i + 1)" : names[i].trimmed,
                        subject: mode == .mixed ? subject : "", studentIDs: ids)
        }
        model.showToast("Saved \(made.count) groups")
        made = []
    }
}

/// A menu that picks a group, for choosing its students.
struct GroupMenu: View {
    @Environment(AppModel.self) private var model
    var choose: (StudentGroup) -> Void

    var body: some View {
        let groups = model.db.studentGroups
        Menu {
            ForEach(groups) { g in
                Button(g.name) { choose(g) }
            }
            if !groups.isEmpty { Divider() }
            Button("Manage groups…") { model.sheet = .groups }
        } label: {
            Label("Groups", systemImage: "person.3")
        }
        .help("Choose a group's students, or make groups")
    }
}

/// Groups on the Class screen. Only shown when switched on in Settings, because students' names would be
/// on the projector. Hide names with one click.
struct ClassGroupsCard: View {
    @Environment(AppModel.self) private var model
    var subject: String
    // Starts hidden, so names never appear on the projector until you choose to show them.
    @State private var hidden = true

    var body: some View {
        let db = model.db
        let all = db.studentGroups
        let groups = all.filter { $0.subject.isEmpty || $0.subject == subject }
        if db.classGroupsOn, !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Groups").font(.hSection)
                    Spacer()
                    Button(hidden ? "Show names" : "Hide names") { hidden.toggle() }
                        .buttonStyle(.bordered).controlSize(.small)
                        .help("Show or hide students' names on the projector")
                        .accessibilityHint("Shows or hides students' names on the projector")
                }
                if hidden {
                    Text("Names are hidden.").font(.body2).foregroundStyle(Color.ink2)
                } else {
                    ForEach(groups) { g in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name).font(.system(size: 15, weight: .semibold))
                            Text(db.members(of: g).map(\.first).joined(separator: ", "))
                                .font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .card()
        }
    }
}
