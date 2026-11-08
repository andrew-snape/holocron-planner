import Foundation
import AppKit
import PDFKit
import Vision
import UniformTypeIdentifiers

// MARK: - Scan text from paper
//
// Reads the words in a photo, a scan or a PDF with the text recognition built into macOS (Vision).
// It runs on this Mac, needs no Apple Intelligence and keeps nothing: the picture is read, the
// words come back, and the picture is dropped. Nothing is written to disk and nothing is sent anywhere.

enum TextScan {
    enum ScanError: Error {
        case unreadable
        case noText
    }

    /// The most PDF pages read at once, so a long document cannot hold up the screen.
    static let maxPages = 12

    static let imageTypes: [UTType] = [.image, .pdf]

    static func message(for error: Error) -> String {
        switch error {
        case ScanError.noText: return "No words were found. Try a clearer photo, or one taken straight on in good light."
        case ScanError.unreadable: return "That file could not be read. Choose a photo, a scan or a PDF."
        default: return "The text could not be read. Try again, or type it in."
        }
    }

    /// The words in an image or PDF file.
    static func text(from url: URL) async throws -> String {
        let isPDF = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .pdf) ?? (url.pathExtension.lowercased() == "pdf")
        if isPDF {
            guard let doc = PDFDocument(url: url) else { throw ScanError.unreadable }
            return try await text(from: doc)
        }
        return try await clean(read { try await $0.perform(on: url) })
    }

    /// The words in image data, or in PDF data when `isPDF`.
    static func text(from data: Data, isPDF: Bool) async throws -> String {
        if isPDF {
            guard let doc = PDFDocument(data: data) else { throw ScanError.unreadable }
            return try await text(from: doc)
        }
        return try await clean(read { try await $0.perform(on: data) })
    }

    private static func text(from doc: PDFDocument) async throws -> String {
        var pages: [String] = []
        for i in 0..<min(doc.pageCount, maxPages) {
            try Task.checkCancellation()
            guard let page = doc.page(at: i), let image = render(page) else { continue }
            let t = try await clean(read { try await $0.perform(on: image) }, throwing: false)
            if !t.isEmpty { pages.append(t) }
        }
        guard !pages.isEmpty else { throw ScanError.noText }
        return pages.joined(separator: "\n\n")
    }

    /// A page as a picture about 2,400 points on its long side, which reads small print well.
    private static func render(_ page: PDFPage) -> CGImage? {
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = min(4, 2400 / max(box.width, box.height))
        let size = CGSize(width: box.width * scale, height: box.height * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func read(_ run: (RecognizeTextRequest) async throws -> [RecognizedTextObservation]) async throws -> [RecognizedTextObservation] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Australian, British then American English, when this Mac can read them.
        let wanted = ["en-AU", "en-GB", "en-US"].map { Locale.Language(identifier: $0) }
        let supported = request.supportedRecognitionLanguages
        let english = wanted.filter { supported.contains($0) }
        if !english.isEmpty {
            request.automaticallyDetectsLanguage = false
            request.recognitionLanguages = english
        }
        do {
            return try await run(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ScanError.unreadable
        }
    }

    private static func clean(_ found: [RecognizedTextObservation], throwing: Bool = true) throws -> String {
        let lines = found.map { $0.transcript.trimmed }.filter { !$0.isEmpty }
        if lines.isEmpty {
            if throwing { throw ScanError.noText }
            return ""
        }
        return lines.joined(separator: "\n")
    }

    /// `base` with `scanned` added on a new line at the end.
    static func appending(_ scanned: String, to base: String) -> String {
        let add = scanned.trimmed
        guard !add.isEmpty else { return base }
        let b = base.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        return b.isEmpty ? add : b + "\n" + add
    }
}
