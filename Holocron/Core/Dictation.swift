import Foundation
import AVFoundation
import Speech

// MARK: - Dictation
//
// Turns speech into text on this Mac with the Speech framework. Nothing is recorded or kept:
// the microphone is only open between Start and Stop, and only the words are passed on. The
// first time, macOS may download the English speech model from Apple. No audio is ever sent.

@MainActor
@Observable
final class Dictation {
    enum State: Equatable {
        case idle
        case preparing
        case listening
        case stopping
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Words the recogniser has settled on.
    private(set) var settled = ""
    /// Words still being worked out, shown while speaking.
    private(set) var pending = ""

    var text: String { [settled, pending].filter { !$0.isEmpty }.joined(separator: " ") }
    var isBusy: Bool { state == .preparing || state == .listening || state == .stopping }

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var feed: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var reading: Task<Void, Never>?
    /// Changes whenever a session starts or ends, so a start that was overtaken by Stop or Cancel
    /// notices after each wait and gives up.
    @ObservationIgnored private var session = 0

    /// Starts listening. `keeping` is text already typed, which new words are added after.
    func start(keeping existing: String = "") async {
        guard !isBusy else { return }
        session += 1
        let me = session
        settled = existing.trimmed
        pending = ""
        state = .preparing
        func current() -> Bool { session == me }

        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            if current() { state = .failed("Holocron needs the microphone. Allow it in System Settings, then Privacy & Security, then Microphone.") }
            return
        }
        var found = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_AU"))
        if found == nil { found = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_GB")) }
        guard current() else { return }
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
            if current() { state = .failed("The English speech model could not be downloaded. Check your internet connection and try again.") }
            return
        }
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard current() else { return }
        guard let format else {
            state = .failed("Dictation could not start on this Mac.")
            return
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        guard micFormat.sampleRate > 0, let converter = AVAudioConverter(from: micFormat, to: format) else {
            state = .failed("No microphone was found. Connect one, then try again.")
            return
        }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.engine = engine
        self.analyzer = analyzer
        self.feed = continuation
        reading = Task { [weak self] in
            do {
                for try await r in transcriber.results {
                    guard let self, self.session == me else { return }
                    self.heard(String(r.text.characters), final: r.isFinal)
                }
            } catch {
                guard let self, self.session == me, self.state == .listening else { return }
                self.tearDown()
                self.state = .failed("Dictation stopped unexpectedly. Your words so far are kept. Try again to carry on.")
            }
        }
        Dictation.tap(input, micFormat: micFormat, converter: converter, to: format, into: continuation)
        do {
            try await analyzer.start(inputSequence: stream)
            guard current() else { return }
            engine.prepare()
            try engine.start()
        } catch {
            guard current() else { return }
            tearDown()
            state = .failed("The microphone could not be started. Close other apps using it, then try again.")
            return
        }
        state = .listening
    }

    /// Stops listening and waits, for a few seconds at most, for the last words to be settled.
    func stop() async {
        guard state == .listening || state == .preparing else { return }
        let wasListening = state == .listening
        state = .stopping
        session += 1
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        feed?.finish()
        feed = nil
        if wasListening, let a = analyzer {
            let finished = await Dictation.within(seconds: 4) { try? await a.finalizeAndFinishThroughEndOfInput() }
            if !finished { await a.cancelAndFinishNow() }
        }
        tearDown()
        if !pending.isEmpty { append(pending); pending = "" }
        state = .idle
    }

    /// Stops at once, for when the sheet closes.
    func cancel() {
        session += 1
        tearDown()
        state = .idle
    }

    /// Closes the microphone and the recogniser, keeping the words heard so far.
    private func tearDown() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        feed?.finish()
        feed = nil
        reading?.cancel()
        reading = nil
        if let a = analyzer { Task { await a.cancelAndFinishNow() } }
        analyzer = nil
    }

    private func heard(_ words: String, final: Bool) {
        if final { append(words); pending = "" } else { pending = words.trimmed }
    }

    private func append(_ words: String) {
        let w = words.trimmed
        guard !w.isEmpty else { return }
        settled = settled.isEmpty ? w : settled + " " + w
    }

    /// Runs `work`, giving up waiting after `seconds`. True when it finished in time.
    private static func within(seconds: Double, _ work: @escaping @Sendable () async -> Void) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await work(); return true }
            group.addTask { try? await Task.sleep(for: .seconds(seconds)); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
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
