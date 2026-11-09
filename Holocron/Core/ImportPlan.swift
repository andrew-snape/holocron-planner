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

    /// Photos, interview recordings and work photos come with the students.
    var includesPhotos: Bool { self != .planner }
}

extension TableName {
    /// The tables that hold students and what is recorded about them.
    static let studentRecords: [TableName] = [.students, .assessments, .plannotes, .wellbeing, .behaviour, .strandcomments,
                                              .lessonnotes, .reportjudge, .reportcomment, .interviews, .work, .taskdone]
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
    /// Work photo files, as paths relative to the work folder, and where they come from and go.
    var workFiles: [String] = []
    var workSource: URL? = nil
    var workDestination: URL? = nil
    /// Interview recording files (names only), and where they come from and go.
    var recordingFiles: [String] = []
    var recordingSource: URL? = nil
    var recordingDestination: URL? = nil
    /// Photos, work photos and recordings that would overwrite a copy already on this Mac.
    var mediaReplaced: Int = 0

    var canRun: Bool { problems.isEmpty && (!items.isEmpty || !photos.isEmpty || !workFiles.isEmpty || !recordingFiles.isEmpty) }
    var replacesSomething: Bool { items.contains { $0.currentRows != nil } || mediaReplaced > 0 }
}

struct ImportSummary {
    var imported: Int
    var photos: Int
    var photosSkipped: Int
    var backup: URL?
    /// Work photo files copied in, and those that could not be copied.
    var work: Int = 0
    var workSkipped: Int = 0
    /// Interview recordings copied in, and those that could not be copied.
    var recordings: Int = 0
    var recordingsSkipped: Int = 0
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
            if fm.fileExists(atPath: dst.path) {
                current = ArchivePlan.rowCount(dst)
            } else if fm.fileExists(atPath: dst.deletingLastPathComponent().appendingPathComponent("." + name + ".icloud").path) {
                // The file you would replace is in iCloud but not on this Mac yet. Replacing it now
                // could lose it, so wait for the download.
                try? fm.startDownloadingUbiquitousItem(at: dst)
                problems.append("\(name) in your own folder is still downloading from iCloud. Try again in a moment.")
                continue
            }
            items.append(.init(table: t, from: src, to: dst, incomingRows: parsed.rows.count, currentRows: current))
        }

        var photos: [URL] = []
        var workFiles: [String] = []
        var workSource: URL? = nil
        var workDestination: URL? = nil
        var recordingFiles: [String] = []
        var recordingSource: URL? = nil
        var recordingDestination: URL? = nil
        if scope.includesPhotos {
            let dir = source.appendingPathComponent("photos", isDirectory: true)
            photos = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "jpg" }
            let stubs = DataFolder.photoStubs(in: dir, fm: fm)
            if !stubs.isEmpty {
                for u in stubs { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(stubs.count) photo\(stubs.count == 1 ? " is" : "s are") still downloading from iCloud in that folder. Try again in a moment.")
            }
            let mine = DataFolder.photoStubs(in: photosURL, fm: fm)
            if !mine.isEmpty {
                for u in mine { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(mine.count) photo\(mine.count == 1 ? " is" : "s are") still downloading from iCloud in your own photos folder. Try again in a moment.")
            }
            // Work photos sit in year folders, so the whole tree is checked. It is walked once.
            let sourceWork = source.appendingPathComponent("work", isDirectory: true)
            let theirWork = WorkFiles.files(under: sourceWork, fm: fm, forImport: true)
            if DataFolder.isDirectory(sourceWork) {
                workFiles = theirWork.files
                workSource = sourceWork
                workDestination = workURL
            }
            let theirStubs = theirWork.iCloudStubs
            if !theirStubs.isEmpty {
                for u in theirStubs { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(theirStubs.count) work photo\(theirStubs.count == 1 ? " is" : "s are") still downloading from iCloud in that folder. Try again in a moment.")
            }
            let myStubs = WorkFiles.files(under: workURL, fm: fm).iCloudStubs
            if !myStubs.isEmpty {
                for u in myStubs { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(myStubs.count) work photo\(myStubs.count == 1 ? " is" : "s are") still downloading from iCloud in your own work folder. Try again in a moment.")
            }
            // Interview recordings sit flat in recordings/. Hidden iCloud stubs are waited for, and
            // the removed folder is skipped because it is not a file.
            let sourceRecs = source.appendingPathComponent("recordings", isDirectory: true)
            let theirRecs = (try? fm.contentsOfDirectory(at: sourceRecs, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            let theirRecStubs = theirRecs.filter { $0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent.hasSuffix(".icloud") }
            if !theirRecStubs.isEmpty {
                for u in theirRecStubs { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(theirRecStubs.count) recording\(theirRecStubs.count == 1 ? " is" : "s are") still downloading from iCloud in that folder. Try again in a moment.")
            }
            let myRecs = (try? fm.contentsOfDirectory(at: recordingsURL, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            let myRecStubs = myRecs.filter { $0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent.hasSuffix(".icloud") }
            if !myRecStubs.isEmpty {
                for u in myRecStubs { try? fm.startDownloadingUbiquitousItem(at: u) }
                problems.append("\(myRecStubs.count) recording\(myRecStubs.count == 1 ? " is" : "s are") still downloading from iCloud in your own recordings folder. Try again in a moment.")
            }
            if DataFolder.isDirectory(sourceRecs) {
                recordingFiles = theirRecs
                    .filter { !$0.lastPathComponent.hasPrefix(".") && !DataFolder.isDirectory($0) }
                    .map { $0.lastPathComponent }
            }
            if !recordingFiles.isEmpty {
                recordingSource = sourceRecs
                recordingDestination = recordingsURL
            }
        }
        if items.isEmpty && photos.isEmpty && workFiles.isEmpty && recordingFiles.isEmpty && problems.isEmpty {
            problems.append(leftOut.isEmpty
                ? "There is nothing from Holocron in that folder to import."
                : "Your planner folder is shared, so its files were left out. Tick Also replace the shared planner files to bring them in.")
        }
        // Media files that would overwrite a copy already here. Each is backed up before it is replaced.
        let mediaReplaced = photos.filter { fm.fileExists(atPath: photosURL.appendingPathComponent($0.lastPathComponent).path) }.count
            + workFiles.filter { fm.fileExists(atPath: workURL.appendingPathComponent($0).path) }.count
            + recordingFiles.filter { fm.fileExists(atPath: recordingsURL.appendingPathComponent($0).path) }.count
        return ImportPlan(source: source, scope: scope, items: items, photos: photos, photosDestination: photosURL,
                          backup: backup, sharedPlannerLeftOut: leftOut, problems: problems,
                          workFiles: workFiles, workSource: workSource, workDestination: workDestination,
                          recordingFiles: recordingFiles, recordingSource: recordingSource,
                          recordingDestination: recordingDestination, mediaReplaced: mediaReplaced)
    }
}

extension ImportPlan {
    enum Failure: Error, Equatable {
        case notReady
        case backupFailed(String)
        /// The data folder (or one inside it) could not be created.
        case destinationNotCreated(String)
        /// A file could not be copied in. Everything already swapped in was put back.
        case copyFailed(String)
        /// A file could not be copied in, and these files could not be put back. The originals
        /// are in the Before import folder.
        case rollbackIncomplete(failed: [String], backup: URL)
    }

    func carryOut(fm: FileManager = .default) -> Result<ImportSummary, Failure> {
        guard canRun else { return .failure(.notReady) }
        for dir in Set(items.map { $0.to.deletingLastPathComponent() }) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { return .failure(.destinationNotCreated(dir.path)) }
        }

        // 1. Keep a copy of every file that is about to be replaced.
        var madeBackup = false
        func ensureBackup() throws {
            if !madeBackup {
                try fm.createDirectory(at: backup, withIntermediateDirectories: true)
                madeBackup = true
            }
        }
        // Copies a photo, work photo or recording over the one already there, keeping the old copy
        // in the Before import folder first. A failed copy leaves no temp file behind.
        func swapMedia(_ src: URL, _ dst: URL, backupTo b: URL) throws {
            let folder = dst.deletingLastPathComponent()
            let temp = folder.appendingPathComponent(".import-" + dst.lastPathComponent)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                try? fm.removeItem(at: temp)
                if fm.fileExists(atPath: dst.path) {
                    try ensureBackup()
                    try fm.createDirectory(at: b.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: dst, to: b)
                    try fm.copyItem(at: src, to: temp)
                    _ = try fm.replaceItemAt(dst, withItemAt: temp)
                } else {
                    try fm.copyItem(at: src, to: temp)
                    try fm.moveItem(at: temp, to: dst)
                }
            } catch {
                try? fm.removeItem(at: temp)
                throw error
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
            guard ArchivePlan.sameSize(it.to, b, fm) else {
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
                let stuck = rollBack(done, fm)
                return .failure(stuck.isEmpty ? .copyFailed(name) : .rollbackIncomplete(failed: stuck, backup: backup))
            }
        }

        // 3. Photos. A photo that cannot be backed up or copied is skipped, not forced.
        var photoCount = 0, skipped = 0
        let photoBackup = backup.appendingPathComponent("photos", isDirectory: true)
        for src in photos {
            do {
                try swapMedia(src, photosDestination.appendingPathComponent(src.lastPathComponent),
                              backupTo: photoBackup.appendingPathComponent(src.lastPathComponent))
                photoCount += 1
            } catch {
                skipped += 1
            }
        }
        // 4. Work photos, copied the same way as photos. A file that cannot be copied is skipped and counted.
        var workCount = 0, workSkipped = 0
        if let wsrc = workSource, let wdst = workDestination {
            let workBackup = backup.appendingPathComponent("work", isDirectory: true)
            for rel in workFiles {
                do {
                    try swapMedia(wsrc.appendingPathComponent(rel), wdst.appendingPathComponent(rel),
                                  backupTo: workBackup.appendingPathComponent(rel))
                    workCount += 1
                } catch {
                    workSkipped += 1
                }
            }
        }
        // 5. Interview recordings, copied the same way as photos. A file that cannot be copied is skipped and counted.
        var recCount = 0, recSkipped = 0
        if let rsrc = recordingSource, let rdst = recordingDestination {
            let recBackup = backup.appendingPathComponent("recordings", isDirectory: true)
            for name in recordingFiles {
                do {
                    try swapMedia(rsrc.appendingPathComponent(name), rdst.appendingPathComponent(name),
                                  backupTo: recBackup.appendingPathComponent(name))
                    recCount += 1
                } catch {
                    recSkipped += 1
                }
            }
        }
        return .success(ImportSummary(imported: done.count, photos: photoCount, photosSkipped: skipped,
                                      backup: madeBackup ? backup : nil, work: workCount, workSkipped: workSkipped,
                                      recordings: recCount, recordingsSkipped: recSkipped))
    }

    /// Puts back the files already swapped in: the old copy from the backup, or no file at all
    /// where there was none before. Returns the names of any files that could not be put back.
    private func rollBack(_ done: [Item], _ fm: FileManager) -> [String] {
        var stuck: [String] = []
        for it in done.reversed() {
            let name = it.to.lastPathComponent
            let b = backup.appendingPathComponent(name)
            if fm.fileExists(atPath: b.path) {
                let temp = it.to.deletingLastPathComponent().appendingPathComponent(".restore-" + name)
                try? fm.removeItem(at: temp)
                do {
                    try fm.copyItem(at: b, to: temp)
                    _ = try fm.replaceItemAt(it.to, withItemAt: temp)
                } catch {
                    try? fm.removeItem(at: temp)
                    stuck.append(name)
                }
            } else {
                do { try fm.removeItem(at: it.to) } catch { stuck.append(name) }
            }
        }
        return stuck
    }
}
