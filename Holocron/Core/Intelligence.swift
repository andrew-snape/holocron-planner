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
    /// Apple Intelligence suggests the columns of an imported spreadsheet.
    case columns

    var id: String { rawValue }

    var title: String {
        switch self {
        case .columns: return "Suggest columns when importing results"
        }
    }

    var blurb: String {
        switch self {
        case .columns: return "Reads the headers of a spreadsheet Holocron does not recognise and suggests which column is which."
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
