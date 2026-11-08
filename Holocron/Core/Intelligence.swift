import CryptoKit
import Foundation
import FoundationModels

// MARK: - Apple Intelligence
//
// Everything Holocron does with Apple Intelligence runs on this Mac. Nothing is sent anywhere.
// Each feature can be switched off in Settings, then Apple Intelligence, and hides itself when
// the on-device model is not available.

enum Intelligence {
    enum Status: Equatable {
        case available
        /// Apple Intelligence is switched off in System Settings.
        case turnedOff
        /// The model is still downloading.
        case notReady
        /// This Mac cannot run Apple Intelligence.
        case notEligible
        case unknown
    }

    static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
        case .unavailable(.modelNotReady): return .notReady
        case .unavailable(.deviceNotEligible): return .notEligible
        default: return .unknown
        }
    }

    static var isAvailable: Bool { status == .available }

    /// Whether a feature can be offered now: Apple Intelligence is ready and the feature is switched on.
    static func can(_ f: AIFeature, _ db: Database) -> Bool { isAvailable && db.aiEnabled(f) }

    /// Starts loading the model for `session`, so its first words arrive sooner. `prefix` is the
    /// start of the prompt that will follow, when it is known. Does nothing to the answer.
    static func prewarm(_ session: LanguageModelSession, prefix: String? = nil) {
        session.prewarm(promptPrefix: prefix.map { Prompt($0) })
    }

    /// A plain message for an error from the on-device model.
    /// True when there was more to read than the model can take at once. macOS 27 reports it with a
    /// new error type that older SDKs do not have, so that one is recognised by name.
    static func isTooLong(_ error: Error) -> Bool {
        if case LanguageModelSession.GenerationError.exceededContextWindowSize = error { return true }
        return isNewModelError(error, case: "contextSizeExceeded")
    }

    static func isRefusal(_ error: Error) -> Bool {
        if case LanguageModelSession.GenerationError.guardrailViolation = error { return true }
        if case LanguageModelSession.GenerationError.refusal = error { return true }
        return isNewModelError(error, case: "guardrailViolation") || isNewModelError(error, case: "refusal")
    }

    /// Whether `error` is macOS 27's LanguageModelError with the given case.
    private static func isNewModelError(_ error: Error, case name: String) -> Bool {
        String(describing: type(of: error)) == "LanguageModelError" && Mirror(reflecting: error).children.first?.label == name
    }

    static func message(for error: Error) -> String {
        if case CommentDrafter.DraftError.privateInNotes = error {
            return "The draft mentioned something private, which came from your Notes for drafting or your report rules. Take out words such as ILP, meeting or diagnosis there, then try again."
        }
        if case CommentDrafter.DraftError.privateTerm = error {
            return "The draft mentioned something private, such as a plan, a meeting or a diagnosis, so it was not shown. Try again, or write this one yourself."
        }
        if isRefusal(error) {
            return "Apple Intelligence would not write this one. Try again, or write it yourself."
        }
        if isTooLong(error) {
            return "That was too long for Apple Intelligence on this Mac. Try with less text, such as shorter notes or rules."
        }
        return "Apple Intelligence could not finish. Try again in a moment."
    }

    /// A sentence for Settings that says why the features are or are not available.
    static var statusText: String {
        switch status {
        case .available: return "Apple Intelligence is on. Holocron's suggestions are worked out on this Mac only."
        case .turnedOff: return "Apple Intelligence is switched off. Turn it on in System Settings, then Apple Intelligence & Siri."
        case .notReady: return "Apple Intelligence is still getting ready on this Mac. Try again once it has finished downloading."
        case .notEligible: return "This Mac cannot run Apple Intelligence, so these features are hidden."
        case .unknown: return "Apple Intelligence is not available right now."
        }
    }
}

/// Features that can be switched off in Settings. Each is on until it is switched off.
enum AIFeature: String, CaseIterable, Identifiable {
    /// Dictated notes are sorted into students, subjects and kinds of note.
    case dictation
    /// Report comments and learning intentions are drafted for the teacher to edit.
    case drafts
    /// Apple Intelligence suggests the columns of an imported spreadsheet.
    case columns
    /// A lesson's tuning in, explicit teaching, independent work and reflection are drafted from its summary.
    case lessonDraft
    /// A typed note gets a suggested subject and kind of note.
    case noteTags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: return "Sort dictated notes"
        case .drafts: return "Draft comments and learning intentions"
        case .columns: return "Suggest columns when importing results"
        case .lessonDraft: return "Draft lessons"
        case .noteTags: return "Suggest a subject and kind for typed notes"
        }
    }

    var blurb: String {
        switch self {
        case .dictation: return "Splits what you say in Quick log into notes for each student, with the subject and kind of note, for you to check."
        case .drafts: return "Drafts a report comment in your voice, or a lesson's learning intention and success criteria. Nothing is saved until you choose Use."
        case .columns: return "Reads the headers of a spreadsheet Holocron does not recognise and suggests which column is which."
        case .lessonDraft: return "Drafts tuning in, explicit teaching, independent work and reflection from a lesson's summary. Student names are never used. Nothing is saved until you choose Use."
        case .noteTags: return "Reads a note you have typed for a student and suggests the subject and the kind of note, for you to accept with one click."
        }
    }
}

extension Database {
    static let siriNamesKey = "siri_names"

    func aiEnabled(_ f: AIFeature) -> Bool { setting("ai_" + f.rawValue) != "off" }

    func setAI(_ f: AIFeature, _ on: Bool) { setSetting("ai_" + f.rawValue, on ? "on" : "off") }

    /// Whether Siri and Shortcuts may say student names and suggest them, such as for birthdays.
    /// Off until switched on, and never while the Class screen is showing.
    var siriMayUseNames: Bool { setting(Database.siriNamesKey) == "on" }

    func setSiriMayUseNames(_ on: Bool) { setSetting(Database.siriNamesKey, on ? "on" : "off") }
}

/// Sessions made and warmed when a place that drafts opens, so the first request can use one that is
/// already loaded. A warmed session is used once, and only if what it was built from is unchanged.
/// It holds student text (the session's instructions and the payload), so it is kept briefly: expired
/// entries are dropped on every call, and the places that warm discard theirs when they close. Only
/// digests of the instructions and facts are kept for comparing, never the text itself.
enum WarmSessions {
    struct Item {
        let session: LanguageModelSession
        /// Anything else the first request needs to know about how the session was made.
        let payload: [String]
        fileprivate let instructions: Data
        fileprivate let fingerprint: Data
        fileprivate let made: Date
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var items: [String: Item] = [:]
    /// A warmed session older than this is dropped, as the model may have unloaded.
    private static let lifetime: TimeInterval = 180
    private static let capacity = 6

    private static func digest(_ text: String) -> Data { Data(SHA256.hash(data: Data(text.utf8))) }

    /// Call with the lock held.
    private static func purge() {
        let now = Date()
        items = items.filter { now.timeIntervalSince($0.value.made) < lifetime }
    }

    static func put(_ key: String, session: LanguageModelSession, instructions: String, fingerprint: String = "", payload: [String] = []) {
        lock.lock(); defer { lock.unlock() }
        purge()
        if items[key] == nil, items.count >= capacity, let oldest = items.min(by: { $0.value.made < $1.value.made })?.key {
            items[oldest] = nil
        }
        items[key] = Item(session: session, payload: payload, instructions: digest(instructions),
                          fingerprint: digest(fingerprint), made: Date())
    }

    /// Whether a live warmed session for `key` already matches, so it need not be made again.
    static func has(_ key: String, instructions: String, fingerprint: String = "") -> Bool {
        lock.lock(); defer { lock.unlock() }
        purge()
        guard let item = items[key] else { return false }
        return item.instructions == digest(instructions) && item.fingerprint == digest(fingerprint)
    }

    /// The warmed session for `key`, removed so it is used once, when its instructions and
    /// fingerprint still match what the request would build now.
    static func take(_ key: String, instructions: String, fingerprint: String = "") -> Item? {
        lock.lock(); defer { lock.unlock() }
        purge()
        guard let item = items.removeValue(forKey: key), item.instructions == digest(instructions),
              item.fingerprint == digest(fingerprint) else { return nil }
        return item
    }

    static func discard(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        items[key] = nil
    }

    /// Drops every warmed session whose key starts with `prefix`, when a place that warmed closes.
    static func discard(prefix: String) {
        lock.lock(); defer { lock.unlock() }
        items = items.filter { !$0.key.hasPrefix(prefix) }
    }
}
