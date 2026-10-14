import SwiftUI

// MARK: - Entering an assessment result
//
// A result can be typed (a score such as 18/20, or any text) or picked from the achievement levels.
// The choice is remembered and shared by Mark class and each student's Assessment tab. Either way the
// result is saved as plain text in assessments.csv, so existing results and hand edits keep working.

enum ResultMode: String, CaseIterable, Identifiable {
    case score = "Score"
    case level = "Achievement"
    var id: String { rawValue }
}

extension Lists {
    /// The levels offered in the Result dropdown. The descriptions are not shown.
    static let resultLevels = ["Extending", "Mastering", "Consolidating", "Developing", "Emerging", "Modified"]
}

/// Choose between typing a score and picking an achievement level.
struct ResultModePicker: View {
    @Binding var mode: ResultMode

    var body: some View {
        Picker("", selection: $mode) {
            ForEach(ResultMode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 190)
        .help("Type a score, or pick Extending, Mastering, Consolidating, Developing, Emerging or Modified")
    }
}

/// A dropdown of the achievement levels. A value that is not a level (an earlier score, for example)
/// stays in the list so it is never lost or changed by opening the task.
struct LevelPicker: View {
    @Binding var value: String
    var emptyLabel = "Not yet"

    var body: some View {
        Picker("", selection: $value) {
            Text(emptyLabel).tag("")
            ForEach(Lists.resultLevels, id: \.self) { Text($0).tag($0) }
            if !value.isEmpty && !Lists.resultLevels.contains(value) {
                Text(value).tag(value)
            }
        }
        .labelsHidden()
    }
}
