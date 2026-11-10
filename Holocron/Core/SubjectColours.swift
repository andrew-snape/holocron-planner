import Foundation

/// The colours a subject can have. Twelve that sit apart from each other, and each one stays readable:
/// the subject name is drawn in a darkened copy of the colour on a pale tint of it (see `Tone`), and
/// `scripts/test-core.sh` checks every one reaches 5:1 contrast and none is close to another.
enum SubjectColours {
    static let palette: [(name: String, hex: String)] = [
        ("Green", "#34C759"), ("Orange", "#FF8000"), ("Yellow", "#FFCC00"), ("Teal", "#00C7BE"),
        ("Sky", "#32ADE6"), ("Blue", "#007AFF"), ("Indigo", "#5856D6"), ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"), ("Red", "#D70015"), ("Brown", "#A2845E"), ("Grey", "#8E8E93")
    ]

    static func name(forHex hex: String) -> String? {
        palette.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name
    }

    static func contains(_ hex: String) -> Bool { name(forHex: hex) != nil }
}
