import SwiftUI

// MARK: - Record an interview
//
// Record, stop, then check the words that were turned from the recording. Nothing is saved until Save
// is pressed. The audio is kept in the student folder. A summary is only offered when the teacher
// marks the interview as not private.

struct InterviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var studentID: String
    @State private var recorder = InterviewRecorder()
    @State private var words = ""
    @State private var summary = ""
    @State private var notPrivate = false
    @State private var summarising: Task<Void, Never>? = nil
    @State private var summaryError = ""
    @State private var saveError = ""

    var body: some View {
        let db = model.db
        let name = db.studentName(studentID)
        let canSave = !words.trimmed.isEmpty && !recorder.isBusy && recorder.hasRecording
        SheetFrame(title: "Interview with \(name)", subtitle: longDate(todayISO()), width: 580,
                   dirty: recorder.hasRecording || !words.trimmed.isEmpty || !summary.trimmed.isEmpty,
                   discardMessage: "This interview has not been saved. The recording will be thrown away.",
                   confirmTitle: "Save", confirmDisabled: !canSave, onConfirm: { save() }) {
            Text("Tell \(name) the recording is happening before you start. The audio and the words stay on this Mac, in this student's folder.")
                .font(.caption1).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)

            recordCard

            if !words.isEmpty || recorder.state == .transcribing {
                wordsCard
            }
            if !words.trimmed.isEmpty && !recorder.isBusy {
                summaryCard(db)
            }
            if !saveError.isEmpty {
                Label(saveError, systemImage: "exclamationmark.triangle")
                    .font(.caption1).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear {
            summarising?.cancel()
            recorder.cancel()
        }
    }

    // MARK: Recording

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                switch recorder.state {
                case .idle where !recorder.hasRecording:
                    Button { Task { await recorder.start(into: model.folder.recordingsURL) } } label: {
                        Label("Start recording", systemImage: "record.circle")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appBlue)
                    .accessibilityLabel("Start recording")
                case .idle:
                    Label("Recording kept, \(plural(recorder.minutes, "minute"))", systemImage: "checkmark.circle")
                        .font(.caption1).foregroundStyle(Color.ink2)
                    Button("Discard recording", role: .destructive) { discard() }
                        .help("Throw the recording away. It is not saved.")
                case .preparing:
                    ProgressView().controlSize(.small).accessibilityLabel("Getting ready")
                    Text("Getting ready…").font(.caption1).foregroundStyle(Color.ink2)
                case .recording:
                    Button { Task { words = await recorder.finish() ?? words } } label: {
                        Label("Stop", systemImage: "stop.circle.fill").font(.system(size: 15, weight: .semibold))
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appRed)
                    .keyboardShortcut("d", modifiers: .command)
                    .help("Stop recording and turn it into words (Cmd+D)")
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Label("Listening \(clock(recorder.startedAt))", systemImage: "waveform")
                            .font(.caption1Semibold)
                            .foregroundStyle(Color.appRed)
                            .monospacedDigit()
                    }
                    .accessibilityLabel("Recording")
                case .transcribing:
                    ProgressView().controlSize(.small).accessibilityLabel("Turning the recording into words")
                    Text("Turning the recording into words on this Mac…")
                        .font(.caption1).foregroundStyle(Color.ink2)
                case .failed(let why):
                    Label(why, systemImage: "exclamationmark.triangle")
                        .font(.caption1).foregroundStyle(Color.appRed)
                        .fixedSize(horizontal: false, vertical: true)
                    if !recorder.hasRecording {
                        Button("Try again") { Task { await recorder.start(into: model.folder.recordingsURL) } }
                    }
                }
                Spacer(minLength: 0)
            }
            if case .failed = recorder.state, recorder.hasRecording {
                HStack(spacing: 10) {
                    Button("Try again") { Task { words = await recorder.retry() ?? words } }
                    Button("Discard recording", role: .destructive) { discard() }
                }
            }
        }
        .card()
    }

    private func clock(_ since: Date?) -> String {
        guard let since else { return "0:00" }
        let s = max(0, Int(Date().timeIntervalSince(since)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func discard() {
        recorder.cancel()
        summary = ""
        notPrivate = false
    }

    // MARK: Words

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words from the recording")
                .font(.caption1Semibold).foregroundStyle(Color.ink2)
            if recorder.state == .transcribing {
                Text("Working…").font(.body2).foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .textBox()
            } else {
                TextEditor(text: $words)
                    .writingToolsBehavior(.complete)
                    .font(.body2)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .textBox()
                    .accessibilityLabel("Words from the recording")
                    .accessibilityHint("Check them against the recording before you save")
            }
            Text("Holocron adds a note above the words saying they were turned from the recording and need checking. Check them against the recording before you save.")
                .font(.label).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: Summary

    @ViewBuilder
    private func summaryCard(_ db: Database) -> some View {
        let canSummarise = Intelligence.can(.interviewSummary, db)
        VStack(alignment: .leading, spacing: 10) {
            Toggle("This interview is not private, so a summary may be made", isOn: $notPrivate)
                .help("Turn this on only when the talk has no private topics, such as wellbeing, behaviour, medical or plan details.")
                .onChange(of: notPrivate) { _, on in
                    if !on { summary = ""; summaryError = "" }
                }
            if notPrivate {
                if canSummarise {
                    HStack {
                        Button {
                            summarise(db)
                        } label: { Label("Summarise", systemImage: "apple.intelligence") }
                        .buttonStyle(.bordered)
                        .disabled(summarising != nil)
                        if summarising != nil { ProgressView().controlSize(.small).accessibilityLabel("Summarising") }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("Apple Intelligence is off or not available on this Mac, so there is no summary. You can write one below.")
                        .font(.label).foregroundStyle(Color.ink2)
                }
                if !summaryError.isEmpty {
                    Label(summaryError, systemImage: "exclamationmark.triangle")
                        .font(.caption1).foregroundStyle(Color.appRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !summary.isEmpty || canSummarise {
                    Text("Summary").font(.caption1Semibold).foregroundStyle(Color.ink2)
                    TextEditor(text: $summary)
                        .font(.body2)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .textBox()
                        .accessibilityLabel("Summary")
                }
            }
        }
        .card()
    }

    private func summarise(_ db: Database) {
        summaryError = ""
        let text = words
        summarising = Task {
            do {
                let found = try await InterviewSummary.summarise(db, transcript: text)
                if Task.isCancelled { return }
                summary = found
            } catch {
                if !Task.isCancelled {
                    summaryError = error is InterviewError ? error.localizedDescription : Intelligence.message(for: error)
                }
            }
            summarising = nil
        }
    }

    // MARK: Save

    private func save() {
        let text = words.trimmed
        guard !text.isEmpty, let file = recorder.recordingURL else { return }
        let now = (date: todayISO(), time: nowHHMM())
        let transcript = InterviewNote.header(date: now.date, time: now.time) + "\n\n" + text
        do {
            try model.saveInterview(studentID: studentID, minutes: recorder.minutes, recording: file,
                                    transcript: transcript, summary: summary.trimmed,
                                    notPrivate: notPrivate)
            recorder.forget()
            model.showToast("Interview saved")
            dismiss()
        } catch {
            saveError = "The interview could not be saved. The recording is still on this Mac, so you can try again."
        }
    }
}

/// The saved interviews for one student, newest first, with each recording's file name.
struct InterviewsTab: View {
    @Environment(AppModel.self) private var model
    var sid: String

    var body: some View {
        LogEntries(table: .interviews, sid: sid, emptyTitle: "No interviews yet",
                   emptyMessage: "Record an interview from the student's header. Its transcript and any summary appear here.") { x in
            EntryCard(date: x.s("date"), title: "Interview",
                      sub: [fmtTime(x.s("time")), x.s("minutes").isEmpty ? "" : "\(x.s("minutes")) min"].filter { !$0.isEmpty }.joined(separator: ", "),
                      text: [x.s("transcript"), x.s("summary").isEmpty ? "" : "Summary:\n" + x.s("summary")]
                        .filter { !$0.isEmpty }.joined(separator: "\n\n"),
                      tint: timelineTint("int")) {
                do { try model.removeInterview(x) } catch { model.showToast("The interview could not be removed") }
            }
        }
    }
}
