import Foundation

/// The "What's new" sheet shown on the first launch after an update. The notes come from the
/// CHANGELOG.md bundled with the app, so they work offline and always match the running version.
enum WhatsNew {
    struct Notice: Identifiable {
        let version: String
        let items: [String]
        var id: String { version }
    }

    static let seenKey = "whatsNewSeenVersion"

    /// Returns the notes to show when this launch runs a different version from the last one seen.
    /// Records the version as seen, so the sheet appears once per update. A version with no changelog
    /// section shows nothing.
    static func pending(defaults: UserDefaults = .standard) -> Notice? {
        let now = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard defaults.string(forKey: seenKey) != now else { return nil }
        defaults.set(now, forKey: seenKey)
        let items = bullets(for: now)
        return items.isEmpty ? nil : Notice(version: now, items: items)
    }

    /// The bullet lines under "## <version>" in the bundled CHANGELOG.md, with markdown marks removed.
    static func bullets(for version: String) -> [String] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var inSection = false
        var items: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                if inSection { break }
                inSection = line.dropFirst(3).trimmingCharacters(in: .whitespaces) == version
            } else if inSection, line.hasPrefix("- ") {
                let plain = line.dropFirst(2).replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "`", with: "")
                items.append(plain)
            }
        }
        return items
    }
}
