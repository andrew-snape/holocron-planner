import Foundation

/// Reads and writes the CSV files in the data folder.
///
/// Safety rules:
///  - A file that does not exist yet is created blank.
///  - A file that exists but cannot be read is marked unsafe, and nothing will overwrite it.
///  - Writes are atomic (temp file, then replace), so a crash cannot truncate real data.
struct DataFolder {
    /// The student folder: private records, photos and personal settings.
    var url: URL
    /// The planner folder: timetable, lessons, terms, units and devotions. Set this to a shared
    /// folder to sync the planner with other staff. When nil, everything lives in `url`.
    var plannerURL: URL? = nil
    /// Planner tables kept in the student folder instead, because they are marked private
    /// (the Devotion scripts and quotes).
    var privateTables: Set<TableName> = []

    enum ReadResult {
        case ok(header: [String], rows: [Row])
        case missing
        case failed(String)
    }

    /// The folder that holds a table.
    func root(for t: TableName) -> URL {
        t.isPlanner && !privateTables.contains(t) ? (plannerURL ?? url) : url
    }

    func fileURL(_ t: TableName) -> URL {
        root(for: t).appendingPathComponent(t.rawValue + ".csv")
    }

    static func isDirectory(_ u: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir) && isDir.boolValue
    }

    var plannerExists: Bool { plannerURL.map { DataFolder.isDirectory($0) } ?? true }
    var studentExists: Bool { DataFolder.isDirectory(url) }

    var photosURL: URL { url.appendingPathComponent("photos", isDirectory: true) }

    func exists() -> Bool { studentExists && plannerExists }

    func ensureExists() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
    }

    func read(_ t: TableName) -> ReadResult {
        let f = fileURL(t)
        if !FileManager.default.fileExists(atPath: f.path) {
            #if canImport(Darwin)
            // An iCloud file that has not been downloaded yet shows up as ".name.csv.icloud".
            let placeholder = root(for: t).appendingPathComponent("." + t.rawValue + ".csv.icloud")
            if FileManager.default.fileExists(atPath: placeholder.path) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: f)
                return .failed("\(t.rawValue).csv is still downloading from iCloud")
            }
            #endif
            return .missing
        }
        do {
            let data = try Data(contentsOf: f)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return .failed("\(t.rawValue).csv is not text")
            }
            let p = CSV.parse(text)
            return .ok(header: p.header, rows: p.rows)
        } catch {
            return .failed("\(t.rawValue).csv could not be read")
        }
    }

    func write(_ t: TableName, header: [String], rows: [Row]) throws {
        try CSV.writeData(header: header, rows: rows).write(to: fileURL(t), options: .atomic)
    }

    /// Modification time and size of a table's file, or nil when it is not there. The app uses this
    /// to skip re-reading files that have not changed since it last read or wrote them.
    struct Signature: Equatable {
        var modified: Date
        var size: Int
    }

    func signature(_ t: TableName) -> Signature? {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let v = try? fileURL(t).resourceValues(forKeys: keys),
              let d = v.contentModificationDate, let n = v.fileSize else { return nil }
        return Signature(modified: d, size: n)
    }

    func photoURL(_ studentID: String) -> URL {
        photosURL.appendingPathComponent(studentID + ".jpg")
    }

    /// The standard place: iCloud Drive / Holocron / data
    static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Holocron/data", isDirectory: true)
    }
}
