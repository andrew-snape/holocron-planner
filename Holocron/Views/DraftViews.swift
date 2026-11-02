import SwiftUI

// MARK: - Drafts from Apple Intelligence
//
// A draft always appears in its own box, where it can be edited, written again or discarded.
// Nothing reaches the CSV files until Use is pressed.

/// The box a draft is shown in, with Use, Try again and Discard.
struct DraftBox<Extra: View>: View {
    @Binding var text: String
    var working: Bool
    var error: String
    var hint = ""
    /// Things to check, such as two sentences that begin the same way.
    var notes: [String] = []
    var useLabel = "Use"
    var use: () -> Void
    var again: () -> Void
    var discard: () -> Void
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Draft", systemImage: "apple.intelligence").font(.system(size: 12.5, weight: .semibold))
                if working { ProgressView().controlSize(.small).accessibilityLabel("Writing a draft") }
                Spacer()
                if !text.isEmpty { Text("\(wordCount(text)) words").font(.system(size: 11.5)).foregroundStyle(Color.ink2) }
            }
            TextEditor(text: $text)
                .writingToolsBehavior(.complete)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .textBox()
                .disabled(working)
                .accessibilityLabel("Draft")
            if !hint.isEmpty {
                Text(hint).font(.system(size: 12)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !notes.isEmpty && !working {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check before you use it").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                    ForEach(notes, id: \.self) { n in
                        Label(n, systemImage: "pencil.circle").font(.system(size: 12)).foregroundStyle(Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(useLabel) { use() }.buttonStyle(.borderedProminent).disabled(working || text.trimmed.isEmpty)
                Button("Try again") { again() }.disabled(working)
                extra
                Spacer()
                Button("Discard", role: .destructive) { discard() }.foregroundStyle(Color.appRed)
            }
            Text("A draft from Apple Intelligence, made on this Mac. Check every sentence before you use it.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.appBlue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.appBlue.opacity(0.25)))
    }
}

// MARK: Report general comment

/// The Draft button and box under a student's general comment.
struct CommentDraftArea: View {
    @Environment(AppModel.self) private var model
    var sid: String
    var sem: String
    @State private var text = ""
    @State private var open = false
    @State private var working = false
    @State private var error = ""
    @State private var task: Task<Void, Never>? = nil
    /// Which draft is wanted, so a late answer from one that was discarded is ignored.
    @State private var run = UUID()
    @State private var askReplace = false
    @State private var showClass = false

    var body: some View {
        let db = model.db
        if Intelligence.can(.drafts, db) {
            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 10) {
                    Button { start() } label: { Label("Draft comment", systemImage: "apple.intelligence") }
                        .fixedSize()
                        .disabled(working)
                        .help("Apple Intelligence drafts a comment in your voice from this semester's notes, results and judgements")
                    HStack(spacing: 6) {
                        Text("Pronoun").font(.system(size: 12)).foregroundStyle(Color.ink2)
                        Picker("", selection: Binding(get: { db.pronoun(sid) ?? .they }, set: { db.setPronoun(sid, $0) })) {
                            ForEach(Pronoun.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                        .accessibilityLabel("Pronoun for this student")
                    }
                    Button("Draft for the class…") { showClass = true }.fixedSize()
                }
                if open {
                    DraftBox(text: $text, working: working, error: error,
                             notes: text.isEmpty ? [] : CommentDrafter.styleProblems(text, name: db.student(sid)?.usualName ?? ""),
                             use: { db.generalComment(sid, sem: sem).trimmed.isEmpty ? use(replace: true) : (askReplace = true) },
                             again: start, discard: discard) { EmptyView() }
                }
            }
            .confirmationDialog("Replace the comment you have written?", isPresented: $askReplace) {
                Button("Replace it", role: .destructive) { use(replace: true) }
                Button("Add the draft below it") { use(replace: false) }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: sid) { discard() }
            .onChange(of: sem) { discard() }
            .onDisappear { discard() }
            .sheet(isPresented: $showClass) {
                ClassDraftsSheet(sem: sem).environment(model).preferredColorScheme(.light)
            }
        }
    }

    private func start() {
        let db = model.db
        task?.cancel()
        let me = UUID()
        run = me
        open = true
        working = true
        error = ""
        text = ""
        let pronoun = db.pronoun(sid) ?? .they
        task = Task {
            do {
                let t = try await CommentDrafter.draft(db, sid: sid, sem: sem, pronoun: pronoun, words: db.typicalCommentWords) { w in
                    if run == me { text = w }
                }
                if run == me { text = t }
            } catch is CancellationError {
            } catch {
                if run == me { self.error = Intelligence.message(for: error); text = "" }
            }
            if run == me { working = false }
        }
    }

    private func use(replace: Bool) {
        let db = model.db
        let current = db.generalComment(sid, sem: sem).trimmed
        db.setGeneralComment(sid, sem: sem, text: replace || current.isEmpty ? text.trimmed : current + "\n\n" + text.trimmed)
        discard()
    }

    private func discard() {
        task?.cancel()
        task = nil
        run = UUID()
        open = false
        working = false
        text = ""
        error = ""
    }
}

// MARK: English and Mathematics comments

/// A student's English or Mathematics comment: dot points under "[Name] has:" and
/// "Areas for [Name] to focus on:", with a draft and a copy in SIMON's %* format.
struct DotPointCommentBox: View {
    @Environment(AppModel.self) private var model
    var sid: String
    var sem: String
    var kind: ReportComment
    @State private var text = ""
    @State private var open = false
    @State private var working = false
    @State private var error = ""
    @State private var task: Task<Void, Never>? = nil
    @State private var askReplace = false
    @State private var showSource = false

    var body: some View {
        let db = model.db
        let saved = db.reportText(sid, sem: sem, kind.rawValue)
        let imported = db.strandComments(sid, sem: sem, for: kind)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                FieldLabel(text: kind.title, hint: kind == .english
                           ? "4 to 6 achievements and 3 to 6 next steps, covering reading, writing, and speaking and listening"
                           : "4 to 6 achievements and 3 to 6 next steps, covering number and one other area")
                Spacer()
                if !saved.trimmed.isEmpty {
                    Button("Copy for SIMON") { model.copyText(DotPointDrafter.forSIMON(saved), toast: "Copied with %* dot points") }
                        .controlSize(.small)
                        .help("Copies the points with %* at the start of each, ready to paste into SIMON")
                }
            }
            TextEditor(text: Binding(get: { db.reportText(sid, sem: sem, kind.rawValue) },
                                     set: { db.setReportText(sid, sem: sem, kind.rawValue, $0) }))
                .writingToolsBehavior(.complete)
                .font(.system(size: 13))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .textBox()
                .accessibilityLabel(kind.title)
            if !imported.isEmpty {
                DisclosureGroup(isExpanded: $showSource) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(imported, id: \.self) { c in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.s("substrand").isEmpty ? c.s("strand") : "\(c.s("strand")) (\(c.s("substrand")))")
                                    .font(.system(size: 12, weight: .semibold))
                                ForEach([("Success", "success"), ("Growth", "growth"), ("Improvement", "improve")], id: \.1) { label, key in
                                    if !c.s(key).isEmpty {
                                        Text("\(label): ").font(.system(size: 12, weight: .medium)) + Text(c.s(key)).font(.system(size: 12))
                                    }
                                }
                            }
                            .foregroundStyle(Color.ink2)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("From Essential Assessment: " + imported.map { $0.s("strand") }.joined(separator: ", "))
                        .font(.system(size: 12)).foregroundStyle(Color.ink2)
                }
            }
            if Intelligence.can(.drafts, db) {
                Button { start() } label: { Label("Draft \(kind == .english ? "English" : "Mathematics") points", systemImage: "apple.intelligence") }
                    .disabled(working)
                    .help("Apple Intelligence drafts the points from this semester's \(kind == .english ? "English" : "Mathematics") notes, results, judgements and any Essential Assessment report comments")
                if open {
                    DraftBox(text: $text, working: working, error: error,
                             hint: "Each point starts with a lower case letter and ends with a full stop. Lines starting with - become dot points.",
                             use: { saved.trimmed.isEmpty ? use() : (askReplace = true) }, again: start, discard: discard) { EmptyView() }
                }
            }
        }
        .confirmationDialog("Replace the \(kind.title.lowercased()) you have written?", isPresented: $askReplace) {
            Button("Replace it", role: .destructive) { use() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: sid) { discard() }
        .onChange(of: sem) { discard() }
        .onDisappear { discard() }
    }

    private func start() {
        let db = model.db
        task?.cancel()
        open = true
        working = true
        error = ""
        text = ""
        task = Task {
            do {
                let t = try await DotPointDrafter.draft(db, sid: sid, sem: sem, kind: kind)
                if Task.isCancelled { return }
                text = t
            } catch {
                if Task.isCancelled { return }
                self.error = Intelligence.message(for: error)
            }
            working = false
        }
    }

    private func use() {
        model.db.setReportText(sid, sem: sem, kind.rawValue, text.trimmed)
        discard()
    }

    private func discard() {
        task?.cancel()
        task = nil
        open = false
        working = false
        text = ""
        error = ""
    }
}

// MARK: Draft for the whole class

/// Drafts a comment for each student who has none yet, one at a time, for the teacher to go through.
struct ClassDraftsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var sem: String
    @State private var drafts: [String: String] = [:]
    @State private var used: Set<String> = []
    @State private var skipped: Set<String> = []
    @State private var current: String? = nil
    @State private var failed: [String: String] = [:]
    @State private var task: Task<Void, Never>? = nil
    /// The run in progress, so one that was stopped cannot tidy up after a newer one.
    @State private var runID = UUID()

    var body: some View {
        let db = model.db
        let todo = db.roster.filter { db.generalComment($0.id, sem: sem).trimmed.isEmpty || drafts[$0.id] != nil || used.contains($0.id) }
        let waiting = todo.filter { drafts[$0.id] != nil && current != $0.id && !used.contains($0.id) && !skipped.contains($0.id) }
        let left = todo.filter { drafts[$0.id] == nil && !used.contains($0.id) && !skipped.contains($0.id) }
        SheetFrame(title: "Draft comments for the class", subtitle: "Semester " + sem, width: 600,
                   dirty: !waiting.isEmpty || task != nil, discardMessage: "Drafts you have not used will be lost.") {
            Text("Apple Intelligence drafts a comment for each student without one, in your voice, from this semester's notes, results and judgements. Check each one, edit it, then use it or skip it.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if task != nil {
                    Button("Stop") { stop() }
                    ProgressView().controlSize(.small).accessibilityLabel("Writing drafts")
                    if let c = current {
                        Text("Writing for \(db.student(c)?.first ?? "")…").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                    }
                } else {
                    Button(drafts.isEmpty ? "Draft \(plural(left.count, "comment"))" : "Draft the rest (\(left.count))") { run(left.map(\.id)) }
                        .buttonStyle(.borderedProminent)
                        .disabled(left.isEmpty)
                }
                Spacer()
                if !waiting.isEmpty && task == nil {
                    Button("Use all \(waiting.count)") { for s in waiting { use(s.id) } }
                }
            }
            if todo.isEmpty {
                EmptyNote(title: "Every student has a comment", message: "Drafts are only made for students whose general comment is empty.")
            }
            VStack(spacing: 10) {
                ForEach(todo) { s in row(s) }
            }
            HStack { Spacer(); Button("Done") { stop(); dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .onDisappear { stop() }
    }

    @ViewBuilder
    private func row(_ s: Student) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.fullName).font(.system(size: 13, weight: .semibold))
                Spacer()
                if used.contains(s.id) {
                    Label("Used", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color.ink2)
                } else if skipped.contains(s.id) {
                    Text("Skipped").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    Button("Undo") { skipped.remove(s.id) }.controlSize(.small)
                } else if drafts[s.id] != nil && current != s.id {
                    Button("Use") { use(s.id) }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Skip") { skipped.insert(s.id) }.controlSize(.small)
                } else if failed[s.id] != nil && task == nil {
                    Button("Try again") { run([s.id]) }.controlSize(.small)
                }
            }
            if let why = failed[s.id] {
                Label(why, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            } else if drafts[s.id] != nil, !used.contains(s.id), !skipped.contains(s.id) {
                TextEditor(text: Binding(get: { drafts[s.id] ?? "" }, set: { drafts[s.id] = $0 }))
                    .writingToolsBehavior(.complete)
                    .font(.system(size: 13))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .textBox()
                    .disabled(current == s.id)
                    .accessibilityLabel("Draft for \(s.fullName)")
            } else if current != s.id && !used.contains(s.id) && !skipped.contains(s.id) {
                Text("Not drafted yet").font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
        }
        .card()
    }

    private func run(_ ids: [String]) {
        let db = model.db
        let me = UUID()
        runID = me
        task = Task {
            for sid in ids where !used.contains(sid) {
                if Task.isCancelled { break }
                current = sid
                failed[sid] = nil
                do {
                    let t = try await CommentDrafter.draft(db, sid: sid, sem: sem, pronoun: db.pronoun(sid) ?? .they,
                                                           words: db.typicalCommentWords) { w in
                        if !Task.isCancelled { drafts[sid] = w }
                    }
                    if Task.isCancelled { drafts[sid] = nil; break }
                    drafts[sid] = t
                } catch is CancellationError {
                    drafts[sid] = nil
                    break
                } catch {
                    drafts[sid] = nil
                    failed[sid] = Intelligence.message(for: error)
                }
            }
            if runID == me {
                current = nil
                task = nil
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        runID = UUID()
        if let c = current { drafts[c] = nil }
        current = nil
    }

    private func use(_ sid: String) {
        guard let t = drafts[sid]?.trimmed, !t.isEmpty else { return }
        let db = model.db
        // Never write over a comment typed while the drafts were being made.
        guard db.generalComment(sid, sem: sem).trimmed.isEmpty else {
            failed[sid] = "A comment was written for this student meanwhile, so the draft was not used."
            drafts[sid] = nil
            return
        }
        db.setGeneralComment(sid, sem: sem, text: t)
        used.insert(sid)
    }
}

// MARK: Learning intention and success criteria

/// The Draft button and box in a lesson's edit form.
struct IntentDraftArea: View {
    @Environment(AppModel.self) private var model
    var subject: String
    var date: String
    @Binding var content: LessonContent
    @State private var text = ""
    @State private var open = false
    @State private var working = false
    @State private var error = ""
    @State private var task: Task<Void, Never>? = nil
    @State private var askReplace = false

    private var hasOwn: Bool { !content.li.trimmed.isEmpty || !content.sc.trimmed.isEmpty }

    var body: some View {
        if Intelligence.can(.drafts, model.db) && !subject.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button { start() } label: { Label("Draft learning intention and success criteria", systemImage: "apple.intelligence") }
                    .disabled(working)
                    .help("Apple Intelligence drafts them from the subject, summary, explicit teaching and the unit")
                if open {
                    DraftBox(text: $text, working: working, error: error,
                             hint: "The first paragraph is the learning intention. Each line after it is a success criterion.",
                             useLabel: hasOwn ? "Use instead of mine" : "Use",
                             use: { hasOwn ? (askReplace = true) : use() }, again: start, discard: discard) { EmptyView() }
                }
            }
            .confirmationDialog("Replace the learning intention and success criteria you have written?", isPresented: $askReplace) {
                Button("Replace them", role: .destructive) { use() }
                Button("Cancel", role: .cancel) {}
            }
            .onDisappear { discard() }
        }
    }

    private func start() {
        task?.cancel()
        open = true
        working = true
        error = ""
        let unit = subject == "TDL" ? model.db.unitOn(date) : nil
        let c = content
        task = Task {
            do {
                let d = try await IntentDrafter.draft(subject: subject, summary: c.summary, unit: unit, teaching: c.teaching)
                if Task.isCancelled { return }
                text = d.intention + "\n\n" + d.criteria.joined(separator: "\n")
            } catch {
                if Task.isCancelled { return }
                self.error = Intelligence.message(for: error)
            }
            working = false
        }
    }

    /// The first paragraph is the intention, and each line after it a criterion. A part left
    /// empty keeps what was there.
    private func use() {
        let parts = text.trimmed.components(separatedBy: "\n\n")
        let li = parts.first?.trimmed ?? ""
        let sc = linesOf(parts.dropFirst().joined(separator: "\n")).joined(separator: "\n")
        if !li.isEmpty { content.li = li }
        if !sc.isEmpty { content.sc = sc }
        discard()
    }

    private func discard() {
        task?.cancel()
        task = nil
        open = false
        working = false
        text = ""
        error = ""
    }
}
