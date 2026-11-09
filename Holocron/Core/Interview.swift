import Foundation
import AVFoundation
import Speech
import FoundationModels

// MARK: - Recording an interview
//
// The teacher records a conversation with a student. The audio is written to a temporary file while
// recording, turned into words on this Mac with the Speech framework, and only moved into the student
// folder when the teacher saves. Nothing is sent anywhere. A summary is only made when the teacher has
// marked the interview as not private, and private words stop it even then.

struct InterviewError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
@Observable
final class InterviewRecorder {
    enum State: Equatable {
        case idle
        case preparing
        case recording
        case transcribing
        case failed(String)
    }

    private(set) var state: State = .idle
    /// The recording while it is kept, until it is saved or discarded. Nil when there is none.
    private(set) var recordingURL: URL? = nil
    /// Whole minutes, at least one, for the length of the last recording.
    private(set) var minutes = 0
    @ObservationIgnored private var recorder: AVAudioRecorder?
    /// Goes up at every start and cancel, so a step that was overtaken (the sheet closed while the
    /// microphone prompt was showing) gives up instead of recording or updating the screen.
    @ObservationIgnored private var session = 0
    /// When the current recording started, for the clock on screen.
    private(set) var startedAt: Date?

    var isBusy: Bool { state == .preparing || state == .recording || state == .transcribing }
    var hasRecording: Bool { recordingURL != nil }

    /// Starts recording into the student folder's recordings folder, as a pending file until Save.
    /// Only one recording is kept at a time. A failed start can be tried again.
    func start(into folder: URL) async {
        guard !isBusy, recordingURL == nil else { return }
        session += 1
        let me = session
        state = .preparing
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            if me == session { state = .failed("Holocron needs the microphone. Allow it in System Settings, then Privacy & Security, then Microphone.") }
            return
        }
        guard me == session else { return }
        let url = folder.appendingPathComponent("interview-pending-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let r = try AVAudioRecorder(url: url, settings: settings)
            guard r.record() else { throw InterviewError(message: "The recording could not be started.") }
            recorder = r
            recordingURL = url
            startedAt = Date()
            state = .recording
        } catch {
            if me == session { state = .failed("The microphone could not be started. Close other apps using it, then try again.") }
        }
    }

    /// Stops recording and turns it into words. Returns the words, or nil when it failed.
    func finish() async -> String? {
        guard state == .recording, let r = recorder else { return nil }
        r.stop()
        recorder = nil
        if let t = startedAt {
            minutes = max(1, Int((Date().timeIntervalSince(t) / 60).rounded()))
        }
        return await transcribe()
    }

    /// Turns the kept recording into words again, after a failure.
    func retry() async -> String? {
        guard hasRecording, !isBusy else { return nil }
        return await transcribe()
    }

    private func transcribe() async -> String? {
        guard let url = recordingURL else { return nil }
        session += 1
        let me = session
        state = .transcribing
        do {
            let words = try await InterviewTranscriber.words(in: url)
            guard me == session else { return nil }
            state = .idle
            return words
        } catch {
            guard me == session else { return nil }
            state = .failed((error as? InterviewError)?.message ?? "The recording could not be turned into words. The recording is kept, so you can try again.")
            return nil
        }
    }

    /// Stops and throws the recording away. The pending file is ours, so it is removed.
    func cancel() {
        session += 1
        recorder?.stop()
        recorder = nil
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        minutes = 0
        startedAt = nil
        state = .idle
    }

    /// Gives up the recording once it has been moved into the student folder.
    func forget() {
        recordingURL = nil
        minutes = 0
        startedAt = nil
        state = .idle
    }
}

enum InterviewTranscriber {
    /// The words said in a recording, on this Mac. Uses English (Australia), or English (UK) if that is not there.
    static func words(in url: URL) async throws -> String {
        var found = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_AU"))
        if found == nil { found = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_GB")) }
        guard let locale = found else {
            throw InterviewError(message: "English speech recognition is not available on this Mac.")
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        do {
            if let download = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await download.downloadAndInstall()
            }
        } catch {
            throw InterviewError(message: "The English speech model could not be downloaded. Check your internet connection and try again.")
        }
        let file = try AVAudioFile(forReading: url)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let reading = Task { () throws -> String in
            var parts: [String] = []
            for try await r in transcriber.results where r.isFinal {
                let t = String(r.text.characters).trimmed
                if !t.isEmpty { parts.append(t) }
            }
            return parts.joined(separator: " ")
        }
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        return try await reading.value
    }
}

enum InterviewSummary {
    /// A short summary of the transcript, drafted on this Mac. Names are swapped for "a student" first,
    /// and a transcript that mentions a private word is refused.
    @MainActor
    static func summarise(_ db: Database, transcript: String) async throws -> String {
        let text = transcript.trimmed
        if CommentDrafter.mentionsPrivate(text) {
            throw InterviewError(message: "This interview mentions a private topic, so Holocron will not summarise it. Write the summary yourself.")
        }
        var last: Error? = nil
        // Too much for the model at once: try again with less of the transcript.
        for limit in [6000, 2500] {
            let session = LanguageModelSession(instructions: """
                You help a Year 6 teacher in Australia write a short summary of an interview with a student, for the \
                teacher's own records. Use short, plain sentences in Australian English. Use only what the transcript \
                says. Do not guess, give advice or name anyone. Write three to six short lines, one point to a line, \
                with no bullets or numbers.
                """)
            do {
                let masked = db.maskingNames(text, word: "a student")
                let r = try await session.respond(to: "Transcript:\n" + String(masked.prefix(limit)),
                                                  options: GenerationOptions(maximumResponseTokens: 400))
                try Task.checkCancellation()
                return r.content.trimmed
            } catch {
                guard Intelligence.isTooLong(error) else { throw error }
                last = error
            }
        }
        throw last ?? CancellationError()
    }
}

enum InterviewNote {
    /// The note Holocron puts above every saved transcript, so the words are never taken as checked.
    static func header(date: String, time: String) -> String {
        let when = time.isEmpty ? longDate(date) : longDate(date) + " at " + fmtTime(time)
        return "Recorded by the teacher on \(when). Turned into words on this Mac from the recording. " +
            "Check the words against the recording before you use them."
    }
}

extension AppModel {
    /// Moves the recording into the student folder and adds the interview's row. Nothing is copied or deleted
    /// along the way, so a failed move leaves the recording where it was.
    func saveInterview(studentID sid: String, minutes: Int, recording: URL, transcript: String, summary: String, notPrivate: Bool) throws {
        let fm = FileManager.default
        // Refuse before anything moves when the interviews file could not be read earlier, so the
        // row would never be saved.
        guard canWrite(.interviews) else {
            throw InterviewError(message: "The interviews file could not be read, so this interview cannot be saved. Your recording is still on this Mac.")
        }
        let id = uid()
        let name = id + ".m4a"
        try fm.createDirectory(at: folder.recordingsURL, withIntermediateDirectories: true)
        let dest = folder.recordingsURL.appendingPathComponent(name)
        try fm.moveItem(at: recording, to: dest)
        db.append(.interviews, ["id": id, "student_id": sid, "date": todayISO(), "time": nowHHMM(),
                                "minutes": String(minutes), "audio": name, "transcript": transcript,
                                "summary": summary, "not_private": notPrivate ? "yes" : ""])
        db.touch(.interviews)
        // Written to disk now, so the row is not lost if the app quits straight after.
        guard saveNow(.interviews) else {
            throw InterviewError(message: "The interview was not written to the interviews file. Your recording is saved in the recordings folder, so check the folder before you try again.")
        }
    }

    /// Removes an interview's row. Its recording is moved to the removed folder, never deleted. The row
    /// goes only if the recording is safely moved, or was never there.
    func removeInterview(_ x: Row) throws {
        let fm = FileManager.default
        let name = x.s("audio")
        let src = folder.recordingsURL.appendingPathComponent(name)
        if !name.isEmpty, fm.fileExists(atPath: "\(folder.recordingsURL.path)/.\(name).icloud") {
            throw InterviewError(message: "This recording is still downloading from iCloud. Try again in a moment.")
        }
        if !name.isEmpty, fm.fileExists(atPath: src.path) {
            try fm.createDirectory(at: folder.removedRecordingsURL, withIntermediateDirectories: true)
            try fm.moveItem(at: src, to: folder.removedRecordingsURL.appendingPathComponent(name))
        }
        db.deleteRow(.interviews, id: x.s("id"))
    }
}
