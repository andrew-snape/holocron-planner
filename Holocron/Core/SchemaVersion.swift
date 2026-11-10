import Foundation

/// The version of the file layout, kept in settings.csv as `schema_version`.
///
/// A folder without the row was made by an older Holocron and counts as version 0. Whenever a release
/// changes what is stored in the files (a new column or table is only read, so it does not count, but
/// one that moves or rewrites existing values does), add a `Step` and raise `current`. Before any step
/// runs, the files it touches are copied into `Holocron archive`.
enum SchemaVersion {
    static let current = 1
    static let key = "schema_version"

    enum Check: Equatable {
        case upToDate
        case needsMigration(from: Int)
        /// The files were saved by a newer Holocron. They are read as they are and not stamped.
        case newerThanApp(Int)
    }

    static func check(stored: String?, current: Int = SchemaVersion.current) -> Check {
        let v = stored.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
        if v > current { return .newerThanApp(v) }
        return v == current ? .upToDate : .needsMigration(from: v)
    }

    /// One change to the files. `tables` are the files it rewrites, so they are copied first.
    struct Step {
        var to: Int
        var name: String
        var tables: [TableName]
        var transform: (TableName, [Row]) -> [Row]
    }

    /// Version 1 only adds the version row. Nothing in the files changes.
    static let steps: [Step] = [
        Step(to: 1, name: "Add the schema version", tables: [], transform: { _, rows in rows })
    ]

    /// The steps that take a folder from `from` to `current`.
    static func pending(from: Int, steps: [Step] = SchemaVersion.steps) -> [Step] {
        steps.filter { $0.to > from }.sorted { $0.to < $1.to }
    }
}

extension DataFolder {
    /// Where files copied before a merge are kept: "Holocron archive/Before merge".
    var beforeMergeURL: URL { archiveRoot.appendingPathComponent("Before merge", isDirectory: true) }

    /// Copies files into a folder and checks each copy is the same size. A file that is already there is
    /// kept as it is and counts as done. Returns false, having changed nothing else, if any copy fails.
    @discardableResult
    static func safetyCopy(_ files: [URL], into folder: URL, prefix: String = "", fm: FileManager = .default) -> Bool {
        do { try fm.createDirectory(at: folder, withIntermediateDirectories: true) } catch { return false }
        for f in files {
            let dst = folder.appendingPathComponent(prefix + f.lastPathComponent)
            if fm.fileExists(atPath: dst.path) { continue }
            do {
                try fm.copyItem(at: f, to: dst)
                let a = (try? fm.attributesOfItem(atPath: f.path)[.size] as? Int) ?? -1
                let b = (try? fm.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? -2
                if a != b { try? fm.removeItem(at: dst); return false }
            } catch {
                return false
            }
        }
        return true
    }

    /// Copies a table's file as it is on disk into "Before merge", before every merge.
    func copyBeforeMerge(_ t: TableName, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let fm = FileManager.default
        let f = fileURL(t)
        guard fm.fileExists(atPath: f.path) else { return true }
        // Every merge gets its own copy, even two in the same minute, so no version on disk is lost.
        do { try fm.createDirectory(at: beforeMergeURL, withIntermediateDirectories: true) } catch { return false }
        let stamp = StartOverPlan.stamp(now, calendar)
        var dst = beforeMergeURL.appendingPathComponent("\(stamp) \(f.lastPathComponent)")
        var n = 2
        while fm.fileExists(atPath: dst.path) {
            dst = beforeMergeURL.appendingPathComponent("\(stamp) \(t.rawValue) \(n).csv")
            n += 1
        }
        do {
            try fm.copyItem(at: f, to: dst)
            let a = (try? fm.attributesOfItem(atPath: f.path)[.size] as? Int) ?? -1
            let b = (try? fm.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? -2
            if a != b { try? fm.removeItem(at: dst); return false }
            return true
        } catch {
            return false
        }
    }

    /// Copies every table file into a dated "Before opening in an older Holocron" folder, once. Returns false if that fails.
    func copyAllBeforeOlderApp(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let fm = FileManager.default
        let files = TableName.allCases.map { fileURL($0) }.filter { fm.fileExists(atPath: $0.path) }
        guard !files.isEmpty else { return true }
        let dir = StartOverPlan.uniqueFolder(in: archiveRoot, named: "Before opening in an older Holocron " + StartOverPlan.stamp(now, calendar), fm: fm)
        return DataFolder.safetyCopy(files, into: dir)
    }

    enum MigrationResult: Equatable {
        case done(version: Int, archive: URL?)
        case failed(String)
    }

    /// Runs the steps after `from`. Every file they touch (and settings.csv, which holds the version) is
    /// copied into a dated "Before migration" folder first. If that copy fails, nothing is changed.
    /// The version row itself is written by the caller.
    func migrate(from: Int, steps: [SchemaVersion.Step] = SchemaVersion.steps, now: Date = Date(), calendar: Calendar = .current) -> MigrationResult {
        let todo = SchemaVersion.pending(from: from, steps: steps)
        guard let last = todo.last else { return .done(version: from, archive: nil) }
        let fm = FileManager.default
        var tables: [TableName] = [.settings]
        for s in todo { for t in s.tables where !tables.contains(t) { tables.append(t) } }
        let files = tables.map { fileURL($0) }.filter { fm.fileExists(atPath: $0.path) }
        var archive: URL? = nil
        if !files.isEmpty {
            let dir = StartOverPlan.uniqueFolder(in: archiveRoot, named: "Before migration to \(last.to) " + StartOverPlan.stamp(now, calendar), fm: fm)
            guard DataFolder.safetyCopy(files, into: dir) else {
                return .failed("A safety copy could not be made in Holocron archive, so the files were not changed.")
            }
            archive = dir
        }
        for s in todo {
            for t in s.tables {
                switch read(t) {
                case .ok(let header, let rows):
                    do { try write(t, header: header, rows: s.transform(t, rows)) }
                    catch { return .failed("\(t.rawValue).csv could not be saved. Your copy is in Holocron archive.") }
                case .missing: break
                case .failed(let m): return .failed(m)
                }
            }
        }
        return .done(version: last.to, archive: archive)
    }
}
