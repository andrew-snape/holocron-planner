import AppKit

extension AppModel {
    /// Puts the day's lessons and times on the clipboard as rich text (HTML and RTF), so they paste
    /// with headings, bold labels, bullets and clickable links. Plain text is kept as a fallback.
    func copyDay(_ date: String) {
        guard db.runsNormally(date) else { showToast("No lessons on this day"); return }
        let md = db.dayMarkdown(date, includeDevotion: isEnabled(.devotion))
        let html = htmlFromMarkdown(md)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(plainFromMarkdown(md), forType: .string)
        pb.setString(html, forType: .html)
        if let attr = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil),
           let rtf = try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pb.setData(rtf, forType: .rtf)
        }
        showToast("Copied the day as rich text")
    }
}
