import Foundation
import CryptoKit

// MARK: - Photos of students' work
//
// The file side of work photos: which files may be imported, their SHA256, where they are kept, how
// they are copied, and how the list is filtered. Only Foundation and CryptoKit are used, so this file
// can be checked on its own with swiftc.
//
// Images are never resized, re-encoded, rotated or stripped of metadata. The file is copied byte for
// byte and the copy is checked against the original. The original file is never moved or changed.

enum WorkFiles {
    /// The kinds of file that can be imported.
    enum Kind: String, Equatable {
        case jpeg, png, heic, tiff, pdf
    }

    enum Failure: Error, Equatable {
        /// The extension is not one of the allowed types, or the bytes do not match it.
        case unsupportedType
        /// The file could not be opened or read.
        case unreadable
        /// The copy could not be made.
        case copyFailed
        /// The copy does not match the original (size or SHA256).
        case verifyFailed
        /// A file with that name is already in the work folder.
        case alreadyExists
    }

    /// The kind a file extension (lower case, no dot) should hold.
    static func kind(forExtension ext: String) -> Kind? {
        switch ext.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic": return .heic
        case "tif", "tiff": return .tiff
        case "pdf": return .pdf
        default: return nil
        }
    }

    /// The kind the first bytes of a file show, or nil when they match no allowed type.
    static func sniff(_ head: Data) -> Kind? {
        let b = [UInt8](head.prefix(16))
        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return .jpeg }
        if b.count >= 8, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return .png }
        if b.count >= 4, b[0] == 0x25, b[1] == 0x50, b[2] == 0x44, b[3] == 0x46 { return .pdf }
        if b.count >= 4, (b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00)
            || (b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A) { return .tiff }
        if b.count >= 12, b[4] == 0x66, b[5] == 0x74, b[6] == 0x79, b[7] == 0x70 {
            // An ISO base media file. HEIC photos name their brand as heic, heix, mif1 or similar.
            let brand = String(bytes: b[8..<12], encoding: .ascii) ?? ""
            if ["heic", "heix", "heim", "heis", "mif1", "msf1"].contains(brand) { return .heic }
        }
        return nil
    }

    /// Checks a file before it is copied: the extension must be allowed and the bytes must match it.
    /// Only the first bytes are read.
    static func check(_ url: URL) throws -> Kind {
        guard let fromName = kind(forExtension: url.pathExtension) else { throw Failure.unsupportedType }
        guard let h = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        defer { try? h.close() }
        guard let head = try? h.read(upToCount: 16) else { throw Failure.unreadable }
        guard sniff(head) == fromName else { throw Failure.unsupportedType }
        return fromName
    }

    /// The SHA256 of a file, as lower case hex, read in pieces so large scans do not fill memory.
    static func sha256(of url: URL) throws -> String {
        guard let h = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data
            do { chunk = try h.read(upToCount: 1 << 20) ?? Data() } catch { throw Failure.unreadable }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Paths

    /// The year folder a work file goes in: the year of the `added` date, or "undated".
    static func yearFolder(added: String) -> String {
        let y = added.prefix(4)
        return y.count == 4 && y.allSatisfy({ $0.isASCII && $0.isNumber }) ? String(y) : "undated"
    }

    /// A file name that is safe to join onto a folder: no slashes, not hidden, not empty.
    /// Values from the CSV are checked with this before they are used in a path.
    static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains(":") && name != ".."
    }

    /// The file name for a row's image: the row id and the original extension, lower case.
    static func fileName(id: String, source: URL) -> String {
        id + "." + source.pathExtension.lowercased()
    }

    // MARK: Copying

    /// Copies the source into work/<year>/<name> without changing it, and checks the copy by size and SHA256.
    /// The copy is made beside its final place under a hidden name first, then moved into place, so a
    /// failed copy never leaves a half file with a real name. Returns the file name for the row.
    static func stage(_ source: URL, into workDir: URL, id: String, added: String, sha: String,
                      fm: FileManager = .default) throws -> String {
        _ = try check(source)
        let name = fileName(id: id, source: source)
        let dir = workDir.appendingPathComponent(yearFolder(added: added), isDirectory: true)
        let dest = dir.appendingPathComponent(name)
        guard !fm.fileExists(atPath: dest.path) else { throw Failure.alreadyExists }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw Failure.copyFailed
        }
        let temp = dir.appendingPathComponent(".import-" + name)
        try? fm.removeItem(at: temp)
        do {
            try fm.copyItem(at: source, to: temp)
        } catch {
            try? fm.removeItem(at: temp)
            throw Failure.copyFailed
        }
        guard size(source, fm) != nil, size(source, fm) == size(temp, fm),
              (try? sha256(of: temp)) == sha else {
            try? fm.removeItem(at: temp)
            throw Failure.verifyFailed
        }
        do {
            try fm.moveItem(at: temp, to: dest)
        } catch {
            try? fm.removeItem(at: temp)
            throw Failure.copyFailed
        }
        return name
    }

    /// Adds rows, then saves them. If the save fails the rows are taken back out. The image is never
    /// touched here, so it stays where it was staged.
    static func commit(appendRows: () -> Void, undoRows: () -> Void, save: () -> Bool) -> Bool {
        appendRows()
        if save() { return true }
        undoRows()
        return false
    }

    /// Moves a work file into the removed folder. Returns false when the file is not there (nothing to move).
    @discardableResult
    static func moveToRemoved(_ file: URL, removedDir: URL, fm: FileManager = .default) throws -> Bool {
        guard fm.fileExists(atPath: file.path) else { return false }
        try fm.createDirectory(at: removedDir, withIntermediateDirectories: true)
        let dest = removedDir.appendingPathComponent(file.lastPathComponent)
        guard !fm.fileExists(atPath: dest.path) else { throw Failure.alreadyExists }
        try fm.moveItem(at: file, to: dest)
        return true
    }

    static func size(_ u: URL, _ fm: FileManager) -> Int? {
        (try? fm.attributesOfItem(atPath: u.path))?[.size] as? Int
    }

    // MARK: Listing

    /// Every file under a folder, recursively, as paths relative to it. Hidden files are left out, except
    /// iCloud placeholders (".name.icloud"), which are returned as the real file URLs so they can be downloaded.
    /// With `forImport`, the work/removed folder and hidden folders are left out too: removed pictures
    /// are not wanted on another Mac, and hidden folders are not part of the work.
    static func files(under dir: URL, fm: FileManager = .default, forImport: Bool = false) -> (files: [String], iCloudStubs: [URL]) {
        guard let e = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                                    options: [.skipsPackageDescendants]) else { return ([], []) }
        let base = dir.standardizedFileURL.path + "/"
        var files: [String] = []
        var stubs: [URL] = []
        for case let u as URL in e {
            let name = u.lastPathComponent
            let rel = String(u.standardizedFileURL.path.dropFirst(base.count))
            if forImport, rel == "removed" || rel.hasPrefix("removed/") {
                e.skipDescendants()
                continue
            }
            if forImport, name.hasPrefix("."), (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                e.skipDescendants()
                continue
            }
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = u.deletingLastPathComponent().appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count)))
                stubs.append(real)
            } else if name.hasPrefix(".") {
                continue
            } else if (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                files.append(rel)
            }
        }
        return (files.sorted(), stubs)
    }

    // MARK: Filtering

    /// The filters on the Work tab and the Class gallery. An empty value means "any".
    struct Filter: Equatable {
        var subject = ""
        /// The chosen term (its id), and that term's first and last day.
        var termID = ""
        var range: ClosedRange<String>? = nil
        var unit = ""
        var student = ""
        var search = ""

        var isEmpty: Bool { subject.isEmpty && termID.isEmpty && range == nil && unit.isEmpty && student.isEmpty && search.trimmed.isEmpty }

        func matches(_ r: Row) -> Bool {
            if !subject.isEmpty && r.s("subject") != subject { return false }
            if let range, !range.contains(r.s("date")) { return false }
            if !unit.isEmpty && r.s("unit_id") != unit { return false }
            if !student.isEmpty && r.s("student_id") != student { return false }
            let q = search.trimmed.lowercased()
            if !q.isEmpty {
                let hay = (r.s("task") + " " + r.s("caption")).lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    /// Whether a student already has a row for a file with this SHA256.
    static func hasCopy(_ rows: [Row], student: String, sha: String) -> Bool {
        rows.contains { $0.s("student_id") == student && !sha.isEmpty && $0.s("sha") == sha }
    }
}

