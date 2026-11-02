import SwiftUI

// MARK: - Drafts from Apple Intelligence
//
// A draft always appears in its own box, where it can be edited, written again or discarded.
// Nothing reaches the CSV files until Use is pressed.

/// The box a draft is shown in, with Use, Try again and Discard.
struct DraftBox<Extra: View>: View {
    var title: String
    @Binding var text: String
    var working: Bool
    var error: String
    var useLabel = "Use"
    var use: () -> Void
    var again: () -> Void
    var discard: () -> Void
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: "apple.intelligence").font(.system(size: 12.5, weight: .semibold))
                if working { ProgressView().controlSize(.small).accessibilityLabel("Writing a draft") }
                Spacer()
                if !text.isEmpty { Text("\(wordCount(text)) words").font(.system(size: 12)).foregroundStyle(Color.ink2) }
            }
            TextEditor(text: $text)
                .writingToolsBehavior(.complete)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(working)
                .accessibilityLabel(title)
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
                Button("Discard", role: .destructive) { discard() }
            }
            Text("A draft from Apple Intelligence, made on this Mac. Check every sentence before you use it.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
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
    @State private var askReplace = false
    @State private var showClass = false

    var body: some View {
        let db = model.db
        if Intelligence.can(.drafts, db) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button { start() } label: { Label("Draft comment", systemImage: "apple.intelligence") }
                        .disabled(working)
                        .help("Apple Intelligence drafts a comment in your voice from this semester's notes, results and judgements")
                    Picker("", selection: Binding(get: { db.pronoun(sid) ?? .they }, set: { db.setPronoun(sid, $0) })) {
                        ForEach(Pronoun.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                    .accessibilityLabel("Pronoun for this student")
                    .help("The pronoun the draft uses for this student")
                    Spacer()
                    Button("Draft for the class…") { showClass = true }
                }
                if open {
                    DraftBox(title: "Draft comment", text: $text, working: working, error: error,
                             use: { db.generalComment(sid, sem: sem).trimmed.isEmpty ? use(replace: true) : (askReplace = true) },
                             again: start, discard: discard) { EmptyView() }
                }
            }
            .confirmationDialog("Replace the comment you have written?", isPresented: $askReplace) {
                Button("Replace it") { use(replace: true) }
                Button("Add the draft below it") { use(replace: false) }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: sid) { discard() }
            .onChange(of: sem) { discard() }
            .onDisappear { task?.cancel() }
            .sheet(isPresented: $showClass) {
                ClassDraftsSheet(sem: sem).environment(model).preferredColorScheme(.light)
            }
        }
    }

    private func start() {
        let db = model.db
        task?.cancel()
        open = true
        working = true
        error = ""
        text = ""
        let pronoun = db.pronoun(sid) ?? .they
        task = Task {
            do {
                let t = try await CommentDrafter.draft(db, sid: sid, sem: sem, pronoun: pronoun, words: db.typicalCommentWords) { text = $0 }
                text = t
            } catch is CancellationError {
            } catch {
                self.error = Intelligence.message(for: error)
            }
            working = false
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
    @State private var running = false
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        let db = model.db
        let todo = db.roster.filter { db.generalComment($0.id, sem: sem).trimmed.isEmpty || drafts[$0.id] != nil || used.contains($0.id) }
        let waiting = todo.filter { drafts[$0.id] != nil && !used.contains($0.id) && !skipped.contains($0.id) }
        SheetFrame(title: "Draft comments for the class", subtitle: sem.replacingOccurrences(of: "-", with: " "), width: 680,
                   dirty: !waiting.isEmpty, discardMessage: "Drafts you have not used will be lost.") {
            Text("Apple Intelligence drafts a comment for each student without one, in your voice, from this semester's notes, results and judgements. Check each one, edit it, then use it or skip it.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(running ? "Stop" : (drafts.isEmpty ? "Draft \(todo.count) comments" : "Draft the rest")) {
                    running ? stop() : run(todo.map(\.id))
                }
                .buttonStyle(.borderedProminent)
                .disabled(todo.isEmpty)
                if running, let c = current {
                    ProgressView().controlSize(.small)
                    Text("Writing for \(db.student(c)?.first ?? "")…").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                }
                Spacer()
                if !waiting.isEmpty {
                    Button("Use all \(waiting.count)") { for s in waiting { use(s.id) } }
                }
            }
            if todo.isEmpty {
                EmptyNote(title: "Every student has a comment", message: "Drafts are only made for students whose general comment is empty.")
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(todo) { s in row(s) }
                }
            }
            .frame(minHeight: 200, maxHeight: 480)
            HStack { Spacer(); Button("Done") { stop(); dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private func row(_ s: Student) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.fullName).font(.system(size: 13.5, weight: .semibold))
                Spacer()
                if used.contains(s.id) {
                    Label("Used", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color.appGreen)
                } else if skipped.contains(s.id) {
                    Text("Skipped").font(.system(size: 12)).foregroundStyle(Color.ink2)
                } else if drafts[s.id] != nil {
                    Button("Use") { use(s.id) }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Skip") { skipped.insert(s.id) }.controlSize(.small)
                }
            }
            if let why = failed[s.id] {
                Text(why).font(.system(size: 12)).foregroundStyle(Color.appRed)
            } else if let _ = drafts[s.id], !used.contains(s.id), !skipped.contains(s.id) {
                TextEditor(text: Binding(get: { drafts[s.id] ?? "" }, set: { drafts[s.id] = $0 }))
                    .writingToolsBehavior(.complete)
                    .font(.system(size: 13))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        running = true
        task = Task {
            for sid in ids where drafts[sid] == nil && !used.contains(sid) {
                if Task.isCancelled { break }
                current = sid
                failed[sid] = nil
                do {
                    let t = try await CommentDrafter.draft(db, sid: sid, sem: sem, pronoun: db.pronoun(sid) ?? .they,
                                                           words: db.typicalCommentWords) { drafts[sid] = $0 }
                    drafts[sid] = t
                } catch is CancellationError {
                    drafts[sid] = nil
                    break
                } catch {
                    drafts[sid] = nil
                    failed[sid] = Intelligence.message(for: error)
                }
            }
            current = nil
            running = false
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        if let c = current { drafts[c] = nil }
        current = nil
        running = false
    }

    private func use(_ sid: String) {
        guard let t = drafts[sid]?.trimmed, !t.isEmpty else { return }
        let db = model.db
        // Never write over a comment typed while the drafts were being made.
        guard db.generalComment(sid, sem: sem).trimmed.isEmpty else { failed[sid] = "A comment was written for this student meanwhile, so the draft was not used."; return }
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

    var body: some View {
        if Intelligence.can(.drafts, model.db) && !subject.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button { start() } label: { Label("Draft learning intention and success criteria", systemImage: "apple.intelligence") }
                    .disabled(working)
                    .help("Apple Intelligence drafts them from the subject, summary, explicit teaching and the unit")
                if open {
                    DraftBox(title: "Draft learning intention", text: $text, working: working, error: error,
                             useLabel: content.li.trimmed.isEmpty && content.sc.trimmed.isEmpty ? "Use" : "Replace mine",
                             use: use, again: start, discard: discard) { EmptyView() }
                }
            }
        }
    }

    private func start() {
        open = true
        working = true
        error = ""
        let unit = subject == "TDL" ? model.db.unitOn(date) : nil
        let c = content
        Task {
            do {
                let d = try await IntentDrafter.draft(subject: subject, summary: c.summary, unit: unit, teaching: c.teaching)
                text = d.intention + "\n\n" + d.criteria.joined(separator: "\n")
            } catch {
                self.error = Intelligence.message(for: error)
            }
            working = false
        }
    }

    /// The first paragraph is the intention, and each line after it a criterion.
    private func use() {
        let parts = text.components(separatedBy: "\n\n")
        content.li = parts.first?.trimmed ?? ""
        content.sc = linesOf(parts.dropFirst().joined(separator: "\n")).joined(separator: "\n")
        discard()
    }

    private func discard() {
        open = false
        working = false
        text = ""
        error = ""
    }
}
