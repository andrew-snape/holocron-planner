import Foundation
import AVFoundation
import Speech

// MARK: - Dictation
//
// Turns speech into text on this Mac with the Speech framework. Nothing is recorded or kept:
// the microphone is only open between Start and Stop, and only the words are passed on.

@MainActor
@Observable
final class Dictation {
    enum State: Equatable {
        case idle
        case preparing
        case listening
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Words the recogniser has settled on.
    private(set) var settled = ""
    /// Words still being worked out, shown greyed while speaking.
    private(set) var pending = ""

    var text: String { [settled, pending].filter { !$0.isEmpty }.joined(separator: " ") }

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var feed: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var reading: Task<Void, Never>?

    /// Starts listening. `keeping` is text already typed, which new words are added after.
    func start(keeping existing: String = "") async {
        guard state == .idle || isFailed else { return }
        settled = existing.trimmed
        pending = ""
        state = .preparing

        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            state = .failed("Holocron needs the microphone. Allow it in System Settings, then Privacy & Security, then Microphone.")
            return
        }
        var found = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_AU"))
        if found == nil { found = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_GB")) }
        guard let locale = found else {
            state = .failed("Dictation in English is not available on this Mac.")
            return
        }
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        do {
            if let download = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await download.downloadAndInstall()
            }
        } catch {
            state = .failed("The dictation language could not be downloaded. Check your internet connection and try again.")
            return
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            state = .failed("Dictation could not start on this Mac.")
            return
        }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        reading = Task { [weak self] in
            do {
                for try await r in transcriber.results {
                    self?.heard(String(r.text.characters), final: r.isFinal)
                }
            } catch {
                self?.fail("Dictation stopped unexpectedly. Try again.")
            }
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        guard micFormat.sampleRate > 0, let converter = AVAudioConverter(from: micFormat, to: format) else {
            reading?.cancel()
            state = .failed("No microphone was found. Connect one, then try again.")
            return
        }
        Dictation.tap(input, micFormat: micFormat, converter: converter, to: format, into: continuation)
        do {
            try await analyzer.start(inputSequence: stream)
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            reading?.cancel()
            state = .failed("The microphone could not be started. Close other apps using it, then try again.")
            return
        }
        self.engine = engine
        self.analyzer = analyzer
        self.feed = continuation
        state = .listening
    }

    /// Stops listening and waits for the last words to be settled.
    func stop() async {
        guard state == .listening || state == .preparing else { return }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        feed?.finish()
        feed = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        await reading?.value
        reading = nil
        if !pending.isEmpty { append(pending); pending = "" }
        if !isFailed { state = .idle }
    }

    /// Stops at once, for when the sheet closes.
    func cancel() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        feed?.finish()
        feed = nil
        reading?.cancel()
        reading = nil
        if let a = analyzer { Task { await a.cancelAndFinishNow() } }
        analyzer = nil
        state = .idle
    }

    private var isFailed: Bool { if case .failed = state { return true }; return false }

    private func heard(_ words: String, final: Bool) {
        if final { append(words); pending = "" } else { pending = words.trimmed }
    }

    private func append(_ words: String) {
        let w = words.trimmed
        guard !w.isEmpty else { return }
        settled = settled.isEmpty ? w : settled + " " + w
    }

    private func fail(_ message: String) {
        if state == .listening { state = .failed(message) }
    }

    /// Sends the microphone's audio to the recogniser. The block runs on an audio thread, so it is
    /// made here, outside the main actor.
    nonisolated private static func tap(_ input: AVAudioInputNode, micFormat: AVAudioFormat, converter: AVAudioConverter,
                                        to format: AVAudioFormat, into feed: AsyncStream<AnalyzerInput>.Continuation) {
        input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
            if let out = convert(buffer, with: converter, to: format) {
                feed.yield(AnalyzerInput(buffer: out))
            }
        }
    }

    /// The microphone's audio in the format the recogniser wants.
    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                            to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var given = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if given { status.pointee = .noDataNow; return nil }
            given = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}
