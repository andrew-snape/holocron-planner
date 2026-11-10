import SwiftUI
import AppKit

/// A multi-line text box that uses the Mac's spell checker while the teacher types.
/// It starts at `minLines` tall, grows to `maxLines`, then scrolls. Nothing leaves the Mac:
/// the checker is the system one, and the text is only handed back to the binding.
struct SpellCheckField: NSViewRepresentable {
    @Binding var text: String
    var minLines: Int
    var maxLines: Int
    var isEditable: Bool = true
    var accessibilityLabel: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> SpellScrollView {
        let scroll = SpellScrollView()
        let tv = scroll.textView
        tv.delegate = context.coordinator
        tv.string = text
        tv.minLines = minLines
        tv.maxLines = maxLines
        tv.isEditable = isEditable
        tv.setAccessibilityLabel(accessibilityLabel)
        scroll.refreshHeight()
        return scroll
    }

    func updateNSView(_ scroll: SpellScrollView, context: Context) {
        let tv = scroll.textView
        context.coordinator.text = $text
        // Only copy in text that changed from outside (dictation, scan, a reset). Typing already matches.
        if tv.string != text {
            tv.string = text
        }
        tv.minLines = minLines
        tv.maxLines = maxLines
        tv.isEditable = isEditable
        scroll.refreshHeight()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? SpellTextView else { return }
            text.wrappedValue = tv.string
            tv.scrollView?.refreshHeight()
        }
    }
}

/// The scroll view that holds the text. It sizes itself to the text, between the minimum and maximum lines.
final class SpellScrollView: NSScrollView {
    let textView = SpellTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        documentView = textView
        hasVerticalScroller = true
        autohidesScrollers = true
        drawsBackground = false
        borderType = .noBorder
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: frameRect.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
    }

    required init?(coder: NSCoder) { fatalError("SpellScrollView is built in code only") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: textView.fittedHeight)
    }

    /// Asks SwiftUI for a new height after the text or the width changes.
    func refreshHeight() {
        textView.scrollView = self
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        if abs(textView.frame.width - contentView.bounds.width) > 0.5 {
            textView.frame.size.width = contentView.bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

/// The text view itself: spelling on, the rest of the typing helpers (smart quotes, auto-correct) off,
/// so the words typed are the words saved.
final class SpellTextView: NSTextView {
    var minLines = 3
    var maxLines = 9
    weak var scrollView: SpellScrollView?

    private static let inset = NSSize(width: 4, height: 6)

    init() {
        super.init(frame: .zero, textContainer: nil)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = true
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        font = .systemFont(ofSize: 13)
        textColor = .labelColor
        drawsBackground = false
        textContainerInset = Self.inset
        textContainer?.lineFragmentPadding = 4
        writingToolsBehavior = .complete
    }

    required init?(coder: NSCoder) { fatalError("SpellTextView is built in code only") }

    private var lineHeight: CGFloat {
        let f = font ?? .systemFont(ofSize: 13)
        return ceil(f.ascender - f.descender + f.leading)
    }

    /// The height the text needs, kept between the minimum and maximum lines.
    var fittedHeight: CGFloat {
        guard let lm = layoutManager, let tc = textContainer else { return lineHeight * CGFloat(minLines) }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc).height + Self.inset.height * 2
        let lo = lineHeight * CGFloat(minLines) + Self.inset.height * 2
        let hi = lineHeight * CGFloat(maxLines) + Self.inset.height * 2
        return min(max(used, lo), hi)
    }
}
