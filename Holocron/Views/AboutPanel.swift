import SwiftUI
import AppKit

/// The About Holocron panel. It is the standard macOS panel, with a description, the frameworks
/// the app is built on and a link to the repository added as credits.
enum AboutPanel {
    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    static var credits: NSAttributedString {
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        centred.paragraphSpacing = 8

        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centred,
        ]
        let heading: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centred,
        ]

        let out = NSMutableAttributedString()
        func add(_ text: String, _ attributes: [NSAttributedString.Key: Any], link: URL? = nil) {
            var a = attributes
            if let link { a[.link] = link }
            out.append(NSAttributedString(string: text + "\n", attributes: a))
        }

        add("A classroom planner for primary school teachers in Victoria, Australia. It keeps the fortnightly A and B timetable, lesson plans, student notes, results, report drafts and teaching hours as plain CSV files that the teacher owns. Everything runs on the Mac. The only network request is the update check to GitHub Releases.", body)
        add("", body)
        add("Dependencies", heading)
        add("No third-party libraries or packages. Holocron uses only Apple's system frameworks:", body)
        add("SwiftUI and AppKit: the interface", body)
        add("Foundation, Observation and os: data, files, state and logging", body)
        add("FoundationModels: on-device Apple Intelligence drafts", body)
        add("Speech and AVFoundation: dictation and interview recording", body)
        add("Vision, PDFKit, ImageIO and QuickLookUI: reading text, PDFs, images and previews", body)
        add("AppIntents: Siri and Shortcuts", body)
        add("Charts: the Hours chart", body)
        add("CryptoKit and Compression: checksums and reading spreadsheet files", body)
        add("UniformTypeIdentifiers: file types", body)
        add("", body)
        add("Source code", heading)
        add(HelpActions.repoURL.absoluteString, body, link: HelpActions.repoURL)
        add("Licensed under the MIT Licence.", body)

        return out
    }
}
