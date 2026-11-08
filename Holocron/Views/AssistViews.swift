import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Scan text from paper

/// Words read from a picture, waiting for the teacher to check them.
struct ScanFound: Identifiable {
    var id = UUID()
    var text: String
}

/// Reads one picture at a time. The picture is never stored: only the words are kept, in memory,
/// until the teacher inserts or cancels them.
@MainActor @Observable
final class TextScanner {
    var found: ScanFound? = nil
    var working = false
    var error = ""
    private var task: Task<Void, Never>? = nil

    /// Asks for an image or PDF, then reads it.
    func choose() {
        let p = NSOpenPanel()
        p.title = "Choose a photo, a scan or a PDF"
        p.message = "Holocron reads the words on this Mac. The picture is not kept."
        p.prompt = "Read Text"
        p.allowedContentTypes = TextScan.imageTypes
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        run { try await TextScan.text(from: url) }
    }

    func cancel() {
        task?.cancel()
        task = nil
        working = false
        error = ""
    }

    private func run(_ job: @escaping () async throws -> String) {
        task?.cancel()
        working = true
        error = ""
        task = Task {
            do {
                let t = try await job()
                if Task.isCancelled { return }
                found = ScanFound(text: t)
            } catch {
                if Task.isCancelled || error is CancellationError { return }
                self.error = TextScan.message(for: error)
            }
            working = false
        }
    }
}

/// The Scan text button for a field, with its progress and any problem.
struct ScanTextButton: View {
    var scanner: TextScanner

    var body: some View {
        HStack(spacing: 6) {
            if scanner.working {
                ProgressView().controlSize(.small).accessibilityLabel("Reading the text")
                Button("Stop") { scanner.cancel() }.buttonStyle(.bordered).controlSize(.small)
                    .accessibilityLabel("Stop reading")
            } else {
                Button { scanner.choose() } label: {
                    Label("Scan text…", systemImage: "doc.text.viewfinder")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Read the words from a photo, a scan or a PDF. It is read on this Mac and the picture is not kept.")
            }
        }
    }
}

/// Shows the words for checking, and adds them to the end of the field only when the teacher chooses.
/// Each field has its own scanner, and only the one that read a picture opens its sheet. Continuity
/// Camera is not hooked in: macOS cannot say which of several fields on a screen should get the image.
private struct ScanTextSupport: ViewModifier {
    var enabled: Bool
    @Bindable var scanner: TextScanner
    var insert: (String) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.sheet(item: $scanner.found) { f in
                ScanCheckSheet(text: f.text) { insert($0) }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Adds the check sheet for a field's `TextScanner`.
    func scanText(_ enabled: Bool, scanner: TextScanner, insert: @escaping (String) -> Void) -> some View {
        modifier(ScanTextSupport(enabled: enabled, scanner: scanner, insert: insert))
    }
}

struct ScanCheckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var text: String
    var insert: (String) -> Void
    private let original: String

    init(text: String, insert: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.original = text
        self.insert = insert
    }

    var body: some View {
        SheetFrame(title: "Check the scanned text", subtitle: "Fix anything that was misread, then add it to the end of the field.",
                   dirty: text != original, discardMessage: "You have changed the scanned text. Close without adding it?") {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(minHeight: 220)
                .scrollContentBackground(.hidden)
                .textBox()
                .accessibilityLabel("Scanned text")
            Text("Read on this Mac. The picture is not kept.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
            HStack {
                Button("Add to the end") { insert(text); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmed.isEmpty)
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
    }
}

// MARK: - Typed note: suggest a subject and kind

/// A small Suggest button under a typed note. It only runs when the teacher chooses it, so the model
/// never reads a note that is half written, and shows what it found as a suggestion to accept or ignore.
struct NoteSuggestBar: View {
    @Environment(AppModel.self) private var model
    var note: String
    /// The kind chosen now, or nil when the kind is fixed by the screen (such as the Lesson notes tab).
    var kind: QuickKind?
    var subject: String
    var apply: (NoteSuggestion) -> Void
    @State private var suggestion: NoteSuggestion? = nil
    @State private var working = false
    @State private var error = ""
    @State private var task: Task<Void, Never>? = nil

    private var tooShort: Bool { note.trimmed.count < 8 }

    var body: some View {
        if Intelligence.can(.noteTags, model.db) {
            HStack(spacing: 8) {
                if working {
                    ProgressView().controlSize(.small).accessibilityLabel("Reading your note")
                    Text("Reading your note…").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    Button("Stop") { stop() }.buttonStyle(.link).font(.system(size: 12))
                        .accessibilityLabel("Stop suggesting")
                } else if let s = suggestion {
                    result(s)
                } else {
                    Button { start() } label: {
                        Label("Suggest subject and kind", systemImage: "apple.intelligence").font(.system(size: 12))
                    }
                    .buttonStyle(.link)
                    .disabled(tooShort)
                    .accessibilityHint(tooShort ? "Write a little more first." : "")
                    .help("Apple Intelligence reads your note on this Mac and suggests a subject and kind of note. Nothing changes until you accept.")
                    if tooShort {
                        Text("Write a little more first.").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    }
                    if !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(Color.appRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .onChange(of: note) { _, _ in
                // The note has changed, so an old suggestion or problem no longer fits it.
                if working { stop() }
                suggestion = nil
                error = ""
            }
            .onDisappear { stop() }
        }
    }

    @ViewBuilder
    private func result(_ s: NoteSuggestion) -> some View {
        let wrongTab = kind == nil && s.kind != .lesson
        let sameKind = kind == nil || kind == s.kind
        let sameSubject = s.subject.isEmpty || s.subject == subject
        HStack(spacing: 8) {
            Image(systemName: "apple.intelligence").foregroundStyle(Color.appBlue)
            if wrongTab {
                Text("This reads like a \(s.kind == .behaviour ? "behaviour" : "wellbeing") note. Add it on the \(s.kind == .behaviour ? "Behaviour" : "Wellbeing") tab.")
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            } else if sameKind && sameSubject {
                Text("Looks right as it is.").font(.system(size: 12)).foregroundStyle(Color.ink2)
            } else {
                Text(suggestionText(s)).font(.system(size: 12, weight: .medium))
                Button("Use") { apply(s); suggestion = nil }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
            Button { suggestion = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10)).frame(minWidth: 22, minHeight: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ink3)
            .accessibilityLabel("Dismiss the suggestion")
            .help("Dismiss the suggestion")
        }
    }

    /// "Suggested: lesson note in Maths." or "Suggested: wellbeing note."
    private func suggestionText(_ s: NoteSuggestion) -> String {
        let noun = s.kind == .behaviour ? "behaviour note" : s.kind == .wellbeing ? "wellbeing note" : "lesson note"
        if kind == nil { return "Suggested subject: \(s.subject)." }
        return "Suggested: \(noun)" + (s.kind == .lesson && !s.subject.isEmpty ? " in \(s.subject)" : "") + "."
    }

    private func start() {
        task?.cancel()
        working = true
        error = ""
        suggestion = nil
        let text = note, subjects = model.db.subjectNames
        task = Task {
            do {
                let s = try await NoteTagger.suggest(text, subjects: subjects)
                if Task.isCancelled { return }
                suggestion = s
            } catch {
                if Task.isCancelled { return }
                self.error = Intelligence.message(for: error)
            }
            working = false
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        working = false
    }
}

// MARK: - Lesson builder

/// The Draft lesson button and preview in a lesson's edit form.
struct LessonDraftArea: View {
    @Environment(AppModel.self) private var model
    var subject: String
    var date: String
    @Binding var content: LessonContent
    @State private var parts: [String: String] = [:]
    @State private var open = false
    @State private var working = false
    @State private var error = ""
    @State private var replace = false
    @State private var task: Task<Void, Never>? = nil

    private var canDraft: Bool { !content.summary.trimmed.isEmpty }

    /// The steps the draft would fill now: the empty ones, or all of them when replacing.
    private var willFill: [PlanSeq.Step] {
        PlanSeq.all.filter { s in
            !(parts[s.key] ?? "").trimmed.isEmpty && (replace || content[s.key].trimmed.isEmpty)
        }
    }

    var body: some View {
        if Intelligence.can(.lessonDraft, model.db) && !subject.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button { start() } label: { Label("Draft lesson…", systemImage: "apple.intelligence") }
                    .disabled(working || !canDraft)
                    .accessibilityHint(canDraft ? "" : "Write a summary first.")
                    .help(canDraft ? "Apple Intelligence drafts tuning in, explicit teaching, independent work and reflection from the summary. Student names are never used."
                                   : "Write a summary first, then Apple Intelligence can draft the lesson steps from it.")
                if !canDraft && !open {
                    Text("Write a summary first.").font(.system(size: 12)).foregroundStyle(Color.ink2)
                }
                if open { preview }
            }
            .onDisappear { discard() }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Lesson draft", systemImage: "apple.intelligence").font(.system(size: 12.5, weight: .semibold))
                if working {
                    ProgressView().controlSize(.small).accessibilityLabel("Drafting the lesson")
                    Button("Stop") { stop() }.buttonStyle(.link).font(.system(size: 12))
                        .accessibilityLabel("Stop drafting")
                }
                Spacer()
            }
            if !parts.isEmpty {
                ForEach(PlanSeq.all, id: \.key) { s in
                    let mine = !content[s.key].trimmed.isEmpty
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(s.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                            if mine {
                                Text(replace ? "replaces yours" : "yours is kept").font(.system(size: 12)).foregroundStyle(Color.ink2)
                            }
                        }
                        TextEditor(text: Binding(get: { parts[s.key] ?? "" }, set: { parts[s.key] = $0 }))
                            .font(.system(size: 13))
                            .frame(minHeight: 64)
                            .scrollContentBackground(.hidden)
                            .textBox()
                            .disabled(working || (mine && !replace))
                            .accessibilityLabel("Drafted \(s.label)")
                    }
                }
                if PlanSeq.all.contains(where: { !content[$0.key].trimmed.isEmpty }) {
                    Toggle("Replace what I have written", isOn: $replace).toggleStyle(.checkbox).font(.system(size: 12.5))
                }
            }
            if !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5)).foregroundStyle(Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(replace ? "Use instead of mine" : "Use") { use() }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || willFill.isEmpty)
                Button("Write again") { start() }.disabled(working)
                Spacer()
                Button("Discard", role: .destructive) { discard() }.foregroundStyle(Color.appRed)
            }
            if !working && !parts.isEmpty {
                Text(willFill.isEmpty ? "Every step already has your writing. Tick Replace to use the draft."
                                      : "Will fill: " + willFill.map(\.label).joined(separator: ", ") + ".")
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
            Text("A draft from Apple Intelligence, made on this Mac from the lesson text only. No student names are used. Check it before you use it.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
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
                let d = try await LessonDrafter.draft(model.db, subject: subject, content: c, unit: unit)
                if Task.isCancelled { return }
                parts = d
            } catch {
                if Task.isCancelled { return }
                self.error = Intelligence.isTooLong(error)
                    ? "The lesson text is too long to fit in one go. Shorten the summary or the steps you have written, then try again."
                    : Intelligence.message(for: error)
            }
            working = false
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        working = false
        if parts.isEmpty { open = false }
    }

    /// Fills the empty steps, or every step when replacing. Anything else the teacher wrote stays.
    private func use() {
        for s in willFill { content[s.key] = (parts[s.key] ?? "").trimmed }
        discard()
    }

    private func discard() {
        task?.cancel()
        task = nil
        open = false
        working = false
        parts = [:]
        error = ""
        replace = false
    }
}
