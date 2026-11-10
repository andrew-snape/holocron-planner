import SwiftUI
import AppKit

/// A multi-line text box that uses the Mac's spell checker while the teacher types.
/// It is `minLines` tall, grows to `maxLines`, then scrolls. Nothing leaves the Mac.
/// The height comes from `sizeThatFits`, measured from the text and the width SwiftUI offers,
/// so the view always has a real size and takes clicks.
struct SpellCheckField: NSViewRepresentable {
    @Binding var text: String
    var minLines: Int
    var maxLines: Int
    var isEditable: Bool = true
    var accessibilityLabel: String = ""

    static let font = NSFont.systemFont(ofSize: 13)

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        // The standard scrollable text view, so the container, layout and field editing are wired up by AppKit.
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.font = Self.font
        tv.textColor = .textColor
        tv.drawsBackground = false
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        // Spelling on. Everything that rewrites the text is off, so what is typed is what is saved.
        tv.isContinuousSpellCheckingEnabled = true
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.writingToolsBehavior = .complete
        tv.setAccessibilityLabel(accessibilityLabel)
        tv.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        // Only copy in text that changed from outside (dictation, scan, a reset). Typing already matches.
        if tv.string != text { tv.string = text }
        tv.isEditable = isEditable
        tv.isSelectable = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView, context: Context) -> CGSize? {
        let width = max(proposal.width ?? 300, 40)
        let font = Self.font
        let line = ceil(font.ascender - font.descender + font.leading)
        let measured = (text.isEmpty ? " " : text + (text.hasSuffix("\n") ? " " : ""))
        let rect = (measured as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])
        let lo = line * CGFloat(max(minLines, 1))
        let hi = line * CGFloat(max(maxLines, minLines, 1))
        return CGSize(width: width, height: min(max(ceil(rect.height), lo), hi))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if text.wrappedValue != tv.string { text.wrappedValue = tv.string }
        }
    }
}
