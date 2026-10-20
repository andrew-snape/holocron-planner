import Foundation

/// A year end archive: a complete copy of the data folder, made while the app keeps working.
/// Unlike Start over, nothing is moved or cleared. The copy is checked file by file, and if
/// anything goes wrong the half-made archive is removed and the data folder is left untouched.
struct ArchivePlan {
    struct Copy: Equatable {
        var table: TableName
        var from: URL
        var to: URL
    }

    /// The new archive folder, for example ".../Holocron archive/2026 year end".
    var archive: URL
    var label: String
    var copies: [Copy]
    /// The student photos folder, when there is one to copy.
    var photosFrom: URL?
    /// True when the planner is a separate (often shared) folder and was left out of the copy.
    var sharedPlannerLeftOut: Bool
    /// Files that are in iCloud but not yet downloaded to this Mac. Copying waits until they are.
    var waitingOnICloud: [String]

    var isEmpty: Bool { copies.isEmpty && photosFrom == nil }
    var canRun: Bool { waitingOnICloud.isEmpty && !isEmpty }
}

struct ArchiveSummary {
    var archive: URL
    var tables: [(name: String, rows: Int)]
    var photos: Int
}

extension DataFolder {
    /// Works out what a year end archive copies, without touching anything.
    /// A shared planner folder belongs to colleagues too, so it is left out unless asked for.
    func yearArchivePlan(label: String, includeSharedPlanner: Bool = false, fm: FileManager = .default) -> ArchivePlan {
        let clean = ArchivePlan.cleanLabel(label)
        let archive = StartOverPlan.uniqueFolder(in: archiveRoot, named: clean + " year end", fm: fm)
        let shared = plannerURL != nil
        var copies: [ArchivePlan.Copy] = []
        var waiting: [String] = []
        var leftOut = false

        for t in TableName.allCases {
            if t.isPlanner && shared && !privateTables.contains(t) && !includeSharedPlanner {
                if fm.fileExists(atPath: fileURL(t).path) { leftOut = true }
                continue
            }
            let name = t.rawValue + ".csv"
            let f = root(for: t).appendingPathComponent(name)
            if fm.fileExists(atPath: f.path) {
                copies.append(.init(table: t, from: f, to: archive.appendingPathComponent(name)))
            } else if fm.fileExists(atPath: root(for: t).appendingPathComponent("." + name + ".icloud").path) {
                try? fm.startDownloadingUbiquitousItem(at: f)
                waiting.append(name)
            }
        }
        let photos = DataFolder.isDirectory(photosURL) ? photosURL : nil
        return ArchivePlan(archive: archive, label: clean, copies: copies, photosFrom: photos,
                           sharedPlannerLeftOut: leftOut, waitingOnICloud: waiting)
    }
}

extension ArchivePlan {
    enum Failure: Error, Equatable {
        case nothingToCopy
        case waitingOnICloud([String])
        case archiveNotCreated(String)
        case copyFailed(String)
        case checkFailed(String)
    }

    /// Copies the files, checks every copy, and writes a README that lists what is inside.
    /// On any failure the new archive folder is removed again.
    func carryOut(version: String, now: Date = Date(), calendar: Calendar = .current,
                  fm: FileManager = .default) -> Result<ArchiveSummary, Failure> {
        guard waitingOnICloud.isEmpty else { return .failure(.waitingOnICloud(waitingOnICloud)) }
        guard !isEmpty else { return .failure(.nothingToCopy) }
        do {
            try fm.createDirectory(at: archive, withIntermediateDirectories: true)
        } catch {
            return .failure(.archiveNotCreated(archive.path))
        }
        func abandon(_ f: Failure) -> Result<ArchiveSummary, Failure> {
            try? fm.removeItem(at: archive)
            return .failure(f)
        }

        var counts: [(name: String, rows: Int)] = []
        for c in copies {
            let name = c.from.lastPathComponent
            do { try fm.copyItem(at: c.from, to: c.to) } catch { return abandon(.copyFailed(name)) }
            guard ArchivePlan.size(c.from, fm) == ArchivePlan.size(c.to, fm) else { return abandon(.checkFailed(name)) }
            counts.append((name, ArchivePlan.rowCount(c.to)))
        }

        var photoCount = 0
        if let src = photosFrom {
            let dst = archive.appendingPathComponent("photos", isDirectory: true)
            do { try fm.copyItem(at: src, to: dst) } catch { return abandon(.copyFailed("photos")) }
            photoCount = ArchivePlan.jpgCount(dst, fm)
            guard photoCount == ArchivePlan.jpgCount(src, fm) else { return abandon(.checkFailed("photos")) }
        }

        let stamp = StartOverPlan.stamp(now, calendar)
        var lines = [
            "Holocron year end archive",
            "Year: \(label)",
            "Made: \(stamp)",
            "Holocron version: \(version)",
            "",
            "This folder is a copy. Nothing was changed or removed in your data folder.",
            "",
            "Files:"
        ]
        lines += counts.map { "  \($0.name): \($0.rows) rows" }
        lines.append("  photos: \(photoCount)")
        if sharedPlannerLeftOut {
            lines += ["", "The shared planner folder was not copied. Its files belong to everyone who uses it."]
        }
        lines += [
            "",
            "To use this copy again, choose Settings, then Data, then Import from folder, and pick this folder.",
            "",
            "It holds real student information. Keep it only where your school's policy allows."
        ]
        do {
            try Data((lines.joined(separator: "\n") + "\n").utf8)
                .write(to: archive.appendingPathComponent("README.txt"), options: .atomic)
        } catch {
            return abandon(.copyFailed("README.txt"))
        }
        return .success(ArchiveSummary(archive: archive, tables: counts, photos: photoCount))
    }

    /// A label that is safe to use as a folder name.
    static func cleanLabel(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let t = s.components(separatedBy: bad).joined().trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Year" : t
    }

    static func size(_ u: URL, _ fm: FileManager) -> Int? {
        (try? fm.attributesOfItem(atPath: u.path))?[.size] as? Int
    }

    static func rowCount(_ u: URL) -> Int {
        guard let d = try? Data(contentsOf: u), let text = String(data: d, encoding: .utf8) else { return 0 }
        return CSV.parse(text).rows.count
    }

    static func jpgCount(_ dir: URL, _ fm: FileManager) -> Int {
        ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.lowercased().hasSuffix(".jpg") }.count
    }
}
