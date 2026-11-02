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
    @State private var sorting = false
    @State private var sortError = ""

    var body: some View {
        let db = model.db
        let canSort = Intelligence.can(.dictation, db)
        SheetFrame(title: "Dictate notes", subtitle: longDate(todayISO()), width: 620,
                   dirty: !transcript.trimmed.isEmpty || !notes.isEmpty,
                   discardMessage: "Your dictated notes have not been saved.") {
            if notes.isEmpty {
                listenCard
                HStack {
                    if canSort {
                        Button {
                            sort()
                        } label: { Label("Sort into notes", systemImage: "apple.intelligence") }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(transcript.trimmed.isEmpty || listening || sorting)
                        if sorting { ProgressView().controlSize(.small).accessibilityLabel("Sorting notes") }
                    } else {
                        Button("Use as one note") { notes = [SortedNote(students: [], kind: .lesson, subject: model.nowSubject(), note: transcript.trimmed)] }
                            .buttonStyle(.borderedProminent)
                            .disabled(transcript.trimmed.isEmpty || listening)
                    }
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                if !sortError.isEmpty {
                    Label(sortError, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(canSort
                     ? "Say who each note is about, for example “Ava and Sam, great reasoning in maths. Leo was upset after lunch.” Holocron sorts it into notes for you to check. Everything stays on this Mac."
                     : "Your words become one note. Choose the students next.")
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                reviewList
            }
        }
        .onDisappear { dictation.cancel() }
    }

    private var listening: Bool { dictation.state == .listening || dictation.state == .preparing }

    // MARK: Listening

    private var listenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    Task { await toggle() }
                } label: {
                    Label(listening ? "Stop" : "Start dictating", systemImage: listening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .controlSize(.large)
                .tint(listening ? Color.appRed : Color.appBlue)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("d", modifiers: .command)
                switch dictation.state {
                case .preparing: Text("Getting ready…").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
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
            if listening {
                Text(dictation.text.isEmpty ? "Start speaking…" : dictation.text)
                    .font(.system(size: 14))
                    .foregroundStyle(dictation.text.isEmpty ? Color.ink2 : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Dictated so far")
                    .accessibilityValue(dictation.text)
            } else {
                TextEditor(text: $transcript)
                    .writingToolsBehavior(.complete)
                    .font(.system(size: 14))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Dictated words")
            }
        }
        .card()
    }

    private func toggle() async {
        if listening {
            await dictation.stop()
            transcript = dictation.text
        } else {
            await dictation.start(keeping: transcript)
        }
    }

    private func sort() {
        let db = model.db
        let text = transcript.trimmed
        sorting = true
        sortError = ""
        Task {
            do {
                let found = try await NoteSorter.sort(text, roster: db.roster, subjects: db.subjectNames, lessonNow: model.nowSubject())
                notes = found.isEmpty ? [SortedNote(students: [], kind: .lesson, subject: model.nowSubject(), note: text)] : found
            } catch {
                sortError = Intelligence.message(for: error) + " You can still use your words as one note."
                notes = []
            }
            sorting = false
        }
    }

    // MARK: Review

    @ViewBuilder
    private var reviewList: some View {
        let ready = notes.allSatisfy { !$0.students.isEmpty && !$0.note.trimmed.isEmpty }
        Text("Check each note, then save. \(notes.count == 1 ? "It is" : "They are") saved for today.")
            .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        ScrollView {
            VStack(spacing: 10) {
                ForEach($notes) { $n in NoteRow(note: $n) { notes.removeAll { $0.id == n.id } } }
            }
        }
        .frame(minHeight: 160, maxHeight: 440)
        HStack {
            Button("Save \(notes.count == 1 ? "note" : "\(notes.count) notes")") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!ready || notes.isEmpty)
            Button("Back to the words") { notes = [] }
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
        }
        if !ready {
            Text("Every note needs at least one student and some words.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
        }
    }

    private func save() {
        let db = model.db
        var saved = 0
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
            saved += n.students.count
        }
        model.showToast(saved == 1 ? "Saved" : "Saved \(saved) notes")
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
                    Text(note.students.isEmpty ? "Choose students" : note.students.map { db.student($0)?.first ?? "?" }.joined(separator: ", "))
                        .lineLimit(1)
                }
                .frame(maxWidth: 230)
                .accessibilityLabel("Students")
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
                    .labelsHidden().frame(width: 140)
                    .accessibilityLabel("Subject")
                }
                Spacer()
                Button(role: .destructive) { remove() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Leave this note out")
                    .accessibilityLabel("Leave this note out")
            }
            if !note.unknown.isEmpty {
                Label("Not on your roll: \(note.unknown.joined(separator: ", ")). Choose the student above.", systemImage: "questionmark.circle")
                    .font(.system(size: 12)).foregroundStyle(Color.appAmber)
            }
            TextField("Note", text: $note.note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .accessibilityLabel("Note")
        }
        .card()
    }
}
