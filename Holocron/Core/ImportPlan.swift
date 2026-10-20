import Foundation

/// Which part of another data folder to bring in.
enum ImportScope: String, CaseIterable, Identifiable {
    case students, planner, everything

    var id: String { rawValue }

    var title: String {
        switch self {
        case .students: return "Students and their records"
        case .planner: return "Planner"
        case .everything: return "Everything"
        }
    }

    var tables: [TableName] {
        switch self {
        case .students: return TableName.studentRecords
        case .planner: return TableName.allCases.filter { $0.isPlanner }
        case .everything: return TableName.allCases
        }
    }

    var includesPhotos: Bool { self != .planner }
}

extension TableName {
    /// The tables that hold students and what is recorded about them.
    static let studentRecords: [TableName] = [.students, .assessments, .plannotes, .wellbeing, .behaviour,
                                              .lessonnotes, .reportjudge, .reportcomment]
}

/// What an import will do. Files that would be replaced are first copied into a dated
/// "Before import" folder in Holocron archive, and if any step fails everything is put back.
struct ImportPlan {
    struct Item: Identifiable {
        var table: TableName
        var from: URL
        var to: URL
        var incomingRows: Int
        /// Rows in the file about to be replaced, or nil when there is no file yet.
        var currentRows: Int?
        var id: TableName { table }
    }

    var source: URL
    var scope: ImportScope
    var items: [Item]
    var photos: [URL]
    var photosDestination: URL
    /// Where replaced files are kept, for example ".../Holocron archive/Before import 2027-01-20 09.15".
    var backup: URL
    /// Planner files that would have replaced a shared planner folder, so were left out.
    var sharedPlannerLeftOut: [TableName]
    /// Reasons the import cannot go ahead. Nothing is imported while there are any.
    var problems: [String]

    var canRun: Bool { problems.isEmpty && (!items.isEmpty || !photos.isEmpty) }
    var replacesSomething: Bool { items.contains { $0.currentRows != nil } }
}

struct ImportSummary {
    var imported: Int
    var photos: Int
    var photosSkipped: Int
    var backup: URL?
}

extension DataFolder {
    /// Works out what importing from `source` would do, without touching anything.
    /// A folder that does not look like a Holocron data folder is rejected as a whole.
    func importPlan(from source: URL, scope: ImportScope, includeSharedPlanner: Bool = false,
                    now: Date = Date(), calendar: Calendar = .current, fm: FileManager = .default) -> ImportPlan {
        var problems: [String] = []
        var items: [ImportPlan.Item] = []
        var leftOut: [TableName] = []
        let backup = StartOverPlan.uniqueFolder(in: archiveRoot, named: "Before import " + StartOverPlan.stamp(now, calendar), fm: fm)

        let here = [url, plannerURL].compactMap { $0?.standardizedFileURL.path }
        if here.contains(source.standardizedFileURL.path) {
            problems.append("That is the folder Holocron is already using. Choose a different folder.")
        }

        for t in scope.tables {
            let name = t.rawValue + ".csv"
            let src = source.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else {
                if fm.fileExists(atPath: source.appendingPathComponent("." + name + ".icloud").path) {
                    try? fm.startDownloadingUbiquitousItem(at: src)
                    problems.append("\(name) is still downloading from iCloud. Try again in a moment.")
                }
                continue
            }
            if plannerURL != nil && t.isPlanner && !privateTables.contains(t) && !includeSharedPlanner {
                leftOut.append(t)
                continue
            }
            guard let data = try? Data(contentsOf: src), let text = String(data: data, encoding: .utf8) else {
                problems.append("\(name) could not be read as text.")
                continue
            }
            let parsed = CSV.parse(text)
            let overlap = Set(parsed.header).intersection(t.header).count
            if overlap < max(1, t.header.count / 2) {
                problems.append("\(name) does not look like a Holocron file, so nothing will be imported.")
                continue
            }
            let dst = fileURL(t)
            var current: Int? = nil
            if fm.fileExists(atPath: dst.path) { current = ArchivePlan.rowCount(dst) }
            items.append(.init(table: t, from: src, to: dst, incomingRows: parsed.rows.count, currentRows: current))
        }

        var photos: [URL] = []
        if scope.includesPhotos {
            let dir = source.appendingPathComponent("photos", isDirectory: true)
            photos = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "jpg" }
        }
        if items.isEmpty && photos.isEmpty && problems.isEmpty {
            problems.append("There is nothing from Holocron in that folder to import.")
        }
        return ImportPlan(source: source, scope: scope, items: items, photos: photos, photosDestination: photosURL,
                          backup: backup, sharedPlannerLeftOut: leftOut, problems: problems)
    }
}

extension ImportPlan {
    enum Failure: Error, Equatable {
        case notReady
        case backupFailed(String)
        /// A file could not be copied in. Everything already swapped in was put back.
        case copyFailed(String)
    }

    func carryOut(fm: FileManager = .default) -> Result<ImportSummary, Failure> {
        guard canRun else { return .failure(.notReady) }

        // 1. Keep a copy of every file that is about to be replaced.
        var madeBackup = false
        func ensureBackup() throws {
            if !madeBackup {
                try fm.createDirectory(at: backup, withIntermediateDirectories: true)
                madeBackup = true
            }
        }
        for it in items where fm.fileExists(atPath: it.to.path) {
            let name = it.to.lastPathComponent
            let b = backup.appendingPathComponent(name)
            do {
                try ensureBackup()
                try fm.copyItem(at: it.to, to: b)
            } catch {
                if madeBackup { try? fm.removeItem(at: backup) }
                return .failure(.backupFailed(name))
            }
            guard ArchivePlan.size(it.to, fm) == ArchivePlan.size(b, fm) else {
                try? fm.removeItem(at: backup)
                return .failure(.backupFailed(name))
            }
        }

        // 2. Swap each file in. Copy beside the old file first, so a failed copy never loses it.
        var done: [Item] = []
        for it in items {
            let name = it.to.lastPathComponent
            let temp = it.to.deletingLastPathComponent().appendingPathComponent(".import-" + name)
            do {
                try? fm.removeItem(at: temp)
                try fm.copyItem(at: it.from, to: temp)
                if fm.fileExists(atPath: it.to.path) {
                    _ = try fm.replaceItemAt(it.to, withItemAt: temp)
                } else {
                    try fm.moveItem(at: temp, to: it.to)
                }
                done.append(it)
            } catch {
                try? fm.removeItem(at: temp)
                rollBack(done, fm)
                return .failure(.copyFailed(name))
            }
        }

        // 3. Photos. A photo that cannot be backed up or copied is skipped, not forced.
        var photoCount = 0, skipped = 0
        if !photos.isEmpty {
            try? fm.createDirectory(at: photosDestination, withIntermediateDirectories: true)
            let photoBackup = backup.appendingPathComponent("photos", isDirectory: true)
            for src in photos {
                let dst = photosDestination.appendingPathComponent(src.lastPathComponent)
                let temp = photosDestination.appendingPathComponent(".import-" + src.lastPathComponent)
                do {
                    if fm.fileExists(atPath: dst.path) {
                        try ensureBackup()
                        try fm.createDirectory(at: photoBackup, withIntermediateDirectories: true)
                        try fm.copyItem(at: dst, to: photoBackup.appendingPathComponent(src.lastPathComponent))
                        try? fm.removeItem(at: temp)
                        try fm.copyItem(at: src, to: temp)
                        _ = try fm.replaceItemAt(dst, withItemAt: temp)
                    } else {
                        try fm.copyItem(at: src, to: dst)
                    }
                    photoCount += 1
                } catch {
                    try? fm.removeItem(at: temp)
                    skipped += 1
                }
            }
        }
        return .success(ImportSummary(imported: done.count, photos: photoCount, photosSkipped: skipped,
                                      backup: madeBackup ? backup : nil))
    }

    /// Puts back the files already swapped in: the old copy from the backup, or no file at all
    /// where there was none before.
    private func rollBack(_ done: [Item], _ fm: FileManager) {
        for it in done.reversed() {
            let b = backup.appendingPathComponent(it.to.lastPathComponent)
            if fm.fileExists(atPath: b.path) {
                let temp = it.to.deletingLastPathComponent().appendingPathComponent(".restore-" + it.to.lastPathComponent)
                try? fm.removeItem(at: temp)
                if (try? fm.copyItem(at: b, to: temp)) != nil {
                    _ = try? fm.replaceItemAt(it.to, withItemAt: temp)
                }
            } else {
                try? fm.removeItem(at: it.to)
            }
        }
    }
}
