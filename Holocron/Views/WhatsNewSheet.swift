import SwiftUI

/// Shown once after an update, listing the changes in the version now running.
struct WhatsNewSheet: View {
    let notice: WhatsNew.Notice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetFrame(title: "What's new in Holocron \(notice.version)", width: 460,
                   confirmTitle: "Done", onConfirm: { dismiss() }, cancelTitle: "Close") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(notice.items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Color.ink2)
                        Text(item)
                            .font(.body1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
