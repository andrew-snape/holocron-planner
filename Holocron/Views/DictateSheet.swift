import SwiftUI

// MARK: - Dictate notes in Quick log
//
// Speak, check the words, then sort them into notes for each student. Nothing is saved until
// Save is pressed, and every note can be changed or removed first.

struct DictateSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var dictation = Dictation()
    @State private var transcript = ""
    @State private var notes: [SortedNote] = []
    @State private var sorting: Task<Void, Never>? = nil
    @State private var sortError = ""

    var body: some View {
        let db = model.db
        let canSort = Intelligence.can(.dictation, db)
        SheetFrame(title: "Dictate notes", subtitle: longDate(todayISO()), width: 580,
                   dirty: dictation.isBusy || !dictation.text.trimmed.isEmpty || !transcript.trimmed.isEmpty || !notes.isEmpty,
                   discardMessage: "Your dictated notes have not been saved.") {
            if notes.isEmpty {
                listenCard
                HStack {
                    if canSort {
                        Button {
                            sort()
                        } label: { Label("Sort into notes", systemImage: "apple.intelligence") }
                        .buttonStyle(.borderedProminent)
                        .disabled(transcript.trimmed.isEmpty || dictation.isBusy || sorting != nil)
                        if sorting != nil { ProgressView().controlSize(.small).accessibilityLabel("Sorting notes") }
                    }
                    if canSort {
                        Button("Use as one note") { useAsOne() }
                            .disabled(transcript.trimmed.isEmpty || dictation.isBusy || sorting != nil)
                    } else {
                        Button("Use as one note") { useAsOne() }
                            .buttonStyle(.borderedProminent)
                            .disabled(transcript.trimmed.isEmpty || dictation.isBusy)
                    }
                    Spacer()
                }
                if !sortError.isEmpty {
                    Label(sortError, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(canSort
                     ? "Say who each note is about, for example “Ava and Sam, great reasoning in maths.” Holocron sorts it into notes for you to check. Everything stays on this Mac."
                     : "Your words become one note, and you choose the students next. Everything stays on this Mac.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                reviewList
            }
        }
        .onAppear {
            // Load the model while the teacher speaks, so sorting starts sooner.
            if Intelligence.can(.dictation, model.db) { NoteSorter.prewarm(roster: model.db.roster, subjects: model.db.subjectNames) }
        }
        .onChange(of: dictation.state) { _, s in
            // Keep whatever was heard, after Stop and after a failure alike.
            if s == .idle || { if case .failed = s { return true }; return false }() { transcript = dictation.text }
        }
        .onDisappear {
            dictation.cancel()
            sorting?.cancel()
            WarmSessions.discard("sort")
        }
    }

    private func useAsOne() {
        notes = [SortedNote(students: [], kind: .lesson, subject: model.nowSubject(), note: transcript.trimmed)]
    }

    // MARK: Listening

    private var listenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    Task { await toggle() }
                } label: {
                    Label(dictation.isBusy ? "Stop" : "Start dictating", systemImage: dictation.isBusy ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .controlSize(.large)
                .tint(dictation.isBusy ? Color.appRed : Color.appBlue)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("d", modifiers: .command)
                .disabled(dictation.state == .stopping || sorting != nil)
                .help("Start or stop dictating (Cmd+D)")
                switch dictation.state {
                case .preparing: Text("Getting ready…").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                case .stopping: Text("Finishing…").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
                case .listening: Label("Listening", systemImage: "waveform").font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                default: EmptyView()
                }
                Spacer()
            }
            if case .failed(let why) = dictation.state {
                Label(why, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if dictation.isBusy {
                Text(dictation.text.isEmpty ? "Start speaking…" : dictation.text)
                    .font(.system(size: 14))
                    .foregroundStyle(dictation.text.isEmpty ? Color.ink2 : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .textBox()
                    .accessibilityLabel("Dictated so far")
                    .accessibilityValue(dictation.text)
            } else {
                TextEditor(text: $transcript)
                    .writingToolsBehavior(.complete)
                    .font(.system(size: 14))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .textBox()
                    .disabled(sorting != nil)
                    .accessibilityLabel("Dictated words")
                    .accessibilityHint("Edit the words before sorting them into notes")
            }
        }
        .card()
    }

    private func toggle() async {
        if dictation.isBusy {
            await dictation.stop()
        } else {
            await dictation.start(keeping: transcript)
        }
    }

    private func sort() {
        let db = model.db
        let text = transcript.trimmed
        sortError = ""
        sorting = Task {
            do {
                let found = try await NoteSorter.sort(text, roster: db.roster, subjects: db.subjectNames, lessonNow: model.nowSubject())
                if Task.isCancelled { return }
                notes = found.isEmpty ? [SortedNote(students: [], kind: .lesson, subject: model.nowSubject(), note: text)] : found
            } catch {
                if !Task.isCancelled { sortError = Intelligence.message(for: error) + " You can still use your words as one note." }
            }
            sorting = nil
        }
    }

    // MARK: Review

    @ViewBuilder
    private var reviewList: some View {
        let ready = notes.allSatisfy { !$0.students.isEmpty && !$0.note.trimmed.isEmpty }
        Text("Check each note, then save. Notes are saved for today.")
            .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        VStack(spacing: 10) {
            ForEach($notes) { $n in NoteRow(note: $n) { notes.removeAll { $0.id == n.id } } }
        }
        HStack {
            Button("Save \(plural(notes.count, "note"))") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!ready || notes.isEmpty)
                .help("Save (Cmd+Return)")
            Button("Back to the words") { notes = [] }
            Spacer()
        }
        if !ready {
            Text("Every note needs at least one student and some words.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
        }
    }

    private func save() {
        let db = model.db
        var count = 0
        var students = Set<String>()
        for n in notes {
            let text = n.note.trimmed
            guard !n.students.isEmpty, !text.isEmpty else { continue }
            switch n.kind {
            case .lesson:
                db.addLessonNote(students: n.students, subject: n.subject, note: text)
                if !n.subject.isEmpty { model.lastLessonSubject = n.subject }
            case .wellbeing:
                db.addWellbeing(students: n.students, date: todayISO(), periodLost: "", minutes: 0, note: text)
            case .behaviour:
                db.addBehaviour(students: n.students, date: todayISO(), note: text)
            }
            count += 1
            students.formUnion(n.students)
        }
        model.showToast("Saved \(plural(count, "note")) for \(plural(students.count, "student"))")
        dismiss()
    }
}

/// One dictated note being checked: who, what kind, which subject and the words.
private struct NoteRow: View {
    @Environment(AppModel.self) private var model
    @Binding var note: SortedNote
    var remove: () -> Void

    var body: some View {
        let db = model.db
        let firsts = Dictionary(grouping: db.roster) { $0.first.lowercased() }
        let names = note.students.compactMap { db.student($0) }
            .map { (firsts[$0.first.lowercased()]?.count ?? 0) > 1 ? $0.fullName : $0.first }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(db.roster) { s in
                        Toggle(s.fullName, isOn: Binding(get: { note.students.contains(s.id) }, set: { on in
                            note.students.removeAll { $0 == s.id }
                            if on { note.students.append(s.id) }
                        }))
                    }
                } label: {
                    Text(names.isEmpty ? "Choose students" : names.joined(separator: ", ")).lineLimit(1)
                }
                .help(note.students.compactMap { db.student($0)?.fullName }.joined(separator: ", "))
                .accessibilityLabel("Students")
                Spacer(minLength: 0)
                Button { remove() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.appRed)
                    .help("Remove this note")
                    .accessibilityLabel("Remove this note")
            }
            HStack(spacing: 10) {
                Picker("", selection: $note.kind) {
                    ForEach(QuickKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 130)
                .accessibilityLabel("Kind of note")
                if note.kind == .lesson {
                    Picker("", selection: $note.subject) {
                        Text("No subject").tag("")
                        ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().frame(width: 150)
                    .accessibilityLabel("Subject")
                }
                Spacer(minLength: 0)
            }
            if !note.unknown.isEmpty {
                Label {
                    Text("Not matched: \(note.unknown.joined(separator: ", ")). Choose the student above.")
                        .foregroundStyle(Color.ink2)
                } icon: {
                    Image(systemName: "questionmark.circle").foregroundStyle(Color.appAmber)
                }
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            }
            TextField("What happened", text: $note.note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .writingToolsBehavior(.complete)
                .accessibilityLabel("Note")
        }
        .card()
    }
}

extension View {
    /// A white writing area with a hairline edge, as in NoteBox.
    func textBox() -> some View {
        self.padding(8)
            .background(Color.fieldBG)
            .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(Color.fieldStroke, lineWidth: 0.5))
    }
}
