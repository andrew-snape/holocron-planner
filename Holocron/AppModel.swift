import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers
import ImageIO

enum NavItem: String, CaseIterable, Identifiable {
    case today, week, classScreen, term, units, devotion, students, quick, assess, hours, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .classScreen: return "Class screen"
        case .term: return "Term"
        case .units: return "Units"
        case .devotion: return "Devotion"
        case .students: return "Students"
        case .quick: return "Quick log"
        case .assess: return "Mark class"
        case .hours: return "Hours"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "clock"
        case .week: return "calendar"
        case .classScreen: return "tv"
        case .term: return "tablecells"
        case .units: return "magnifyingglass"
        case .devotion: return "plus"
        case .students: return "person.2"
        case .quick: return "square.grid.2x2"
        case .assess: return "checkmark.square"
        case .hours: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// A slot in the Week grid. Dragged onto another slot to swap them.
struct SlotRef: Codable, Hashable, Transferable {
    var week: String
    var day: Int
    var per: Int
    var date: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// A lesson shown on the class screen window.
struct ClassTarget: Codable, Hashable {
    var date: String
    var per: Int
}

enum ActiveSheet: Identifiable {
    case plan(date: String, per: Int, edit: Bool)
    case change(date: String, per: Int)
    case move(date: String, per: Int)
    case dayType(date: String)
    case swap(a: SlotRef, b: SlotRef)
    case bump(title: String, sub: String, intro: String, plans: [BumpPlan])
    case unit(id: String)
    case pack(studentID: String)
    case quick(ids: [String])
    case newStudent

    var id: String {
        switch self {
        case .plan(let d, let p, _): return "plan-\(d)-\(p)"
        case .change(let d, let p): return "change-\(d)-\(p)"
        case .move(let d, let p): return "move-\(d)-\(p)"
        case .dayType(let d): return "daytype-\(d)"
        case .swap(let a, let b): return "swap-\(a.date)-\(a.per)-\(b.date)-\(b.per)"
        case .bump(let t, let s, _, _): return "bump-\(t)-\(s)"
        case .unit(let i): return "unit-\(i)"
        case .pack(let s): return "pack-\(s)"
        case .quick(let ids): return "quick-" + ids.joined(separator: ",")
        case .newStudent: return "newstudent"
        }
    }
}

@Observable
final class AppModel {
    let db = Database()

    // Navigation and view state
    var nav: NavItem = .today
    var cursor: String = todayISO()
    var calMonth: String = String(todayISO().prefix(7)) + "-01"
    var weekMonday: String? = nil
    var weekFilter: String = ""
    var devotionDate: String? = nil
    var selectedStudent: String? = nil
    var termKey: String = ""
    var termSubject: String = ""
    var sheet: ActiveSheet? = nil
    var lastLessonSubject: String = ""
    @ObservationIgnored var quoteKey: String? = nil

    // Data folder
    var folder: DataFolder
    var folderOK = false
    var folderMessage = ""
    var badLoads: Set<String> = []
    var showSetup = false

    // Toast
    var toast: String? = nil

    // Photos change counter, so a replaced photo shows straight away
    var photoVersion = 0

    /// The Class screen timer, shared by the sidebar module and the pop-out window.
    let classTimer = ClassTimer()

    /// Looks for new versions on GitHub Releases and installs them.
    let updater = Updater()

    @ObservationIgnored private var pending: Set<TableName> = []
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    @ObservationIgnored private var toastWork: DispatchWorkItem?
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]
    @ObservationIgnored private var noPhoto: Set<String> = []

    /// What each file looked like when it was last read or written, so a reload can skip the files
    /// nobody has touched.
    @ObservationIgnored private var fileSigs: [TableName: DataFolder.Signature] = [:]
    /// Saves run on this queue, one after another, so a slow disk never freezes the window.
    @ObservationIgnored private let writeQueue = DispatchQueue(label: "au.holocron.save", qos: .utility)
    @ObservationIgnored private var inFlight = 0

    static let folderKey = "dataFolderPath"
    static let plannerKey = "plannerFolderPath"
    static let appVersion = Updater.currentVersion + " (Mac)"

    init() {
        let saved = UserDefaults.standard.string(forKey: AppModel.folderKey)
        let url = saved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? DataFolder.defaultURL()
        let plannerSaved = UserDefaults.standard.string(forKey: AppModel.plannerKey)
        folder = DataFolder(url: url, plannerURL: plannerSaved.map { URL(fileURLWithPath: $0, isDirectory: true) })
        db.persistHandler = { [weak self] names in self?.schedule(names) }
        updater.prepareToQuit = { [weak self] in self?.flushNow(wait: true) }

        if folder.exists() {
            loadAll()
        } else {
            folderOK = false
            folderMessage = missingMessage(folder)
            showSetup = true
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reloadIfIdle()
            self?.updater.checkIfDue()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flushNow(wait: true)
        }
    }

    // MARK: Folder

    private func missingMessage(_ f: DataFolder) -> String {
        if !f.studentExists && !f.plannerExists { return "The student folder and the planner folder were not found." }
        if !f.plannerExists { return "The planner folder was not found. Check that it is still shared and downloaded in iCloud Drive." }
        return "The student folder was not found."
    }

    /// Points the planner tables at a different (often shared) folder, or back at the student folder when nil.
    /// Planner files already in the new folder are kept as they are. Any the new folder does not have yet
    /// are copied across from where they are now, so you can seed a shared folder with your own planner.
    @discardableResult
    func usePlannerFolder(_ url: URL?) -> String {
        if let u = url, !DataFolder.isDirectory(u) { return "That folder could not be opened." }
        flushNow(wait: true)
        var next = folder
        next.plannerURL = url
        let fm = FileManager.default
        var copied = 0, kept = 0
        for t in TableName.allCases where t.isPlanner {
            let dst = next.fileURL(t), src = folder.fileURL(t)
            if dst.path == src.path { continue }
            if fm.fileExists(atPath: dst.path) { kept += 1; continue }
            if fm.fileExists(atPath: src.path), (try? fm.copyItem(at: src, to: dst)) != nil { copied += 1 }
        }
        folder = next
        if let u = url { UserDefaults.standard.set(u.path, forKey: AppModel.plannerKey) }
        else { UserDefaults.standard.removeObject(forKey: AppModel.plannerKey) }
        loadAll()
        if url == nil { return "Planner files are back in the student folder" }
        return "Planner folder connected. \(copied) file\(copied == 1 ? "" : "s") copied in, \(kept) already there were kept."
    }

    func useFolder(_ url: URL, createIfNeeded: Bool) {
        let f = DataFolder(url: url, plannerURL: folder.plannerURL)
        if createIfNeeded { try? f.ensureExists() }
        guard f.exists() else {
            folderMessage = missingMessage(f)
            folderOK = false
            return
        }
        flushNow(wait: true)
        folder = f
        UserDefaults.standard.set(url.path, forKey: AppModel.folderKey)
        imageCache.removeAll()
        noPhoto.removeAll()
        loadAll()
        showSetup = !folderOK
    }

    /// Reads the CSVs. A file that does not exist yet is created blank; one that cannot be read is
    /// left alone and never overwritten. With `force` off, files that have not changed since they
    /// were last read or written are skipped, so switching back to the app costs almost nothing.
    func loadAll(force: Bool = true) {
        let previouslyBad = badLoads
        badLoads.removeAll()
        if force { fileSigs.removeAll() }
        var messages: [String] = []
        var ok = folder.exists()
        for t in TableName.allCases {
            let sig = folder.signature(t)
            if !force, !previouslyBad.contains(t.rawValue), let s = sig, fileSigs[t] == s { continue }
            switch folder.read(t) {
            case .ok(let header, let rows):
                db.load(t, header: header, rows: rows)
                fileSigs[t] = sig
            case .missing:
                let starter = Starter.rows(for: t)
                db.load(t, header: t.header, rows: starter)
                fileSigs[t] = nil
                if ok {
                    try? folder.write(t, header: t.header, rows: starter)
                    fileSigs[t] = folder.signature(t)
                }
            case .failed(let msg):
                badLoads.insert(t.rawValue)
                fileSigs[t] = nil
                messages.append(msg)
            }
        }
        if !folder.exists() { ok = false }
        folderOK = ok && badLoads.isEmpty
        if !folder.exists() { folderMessage = missingMessage(folder) }
        else { folderMessage = messages.isEmpty ? "" : messages.joined(separator: ". ") }
        if db.termsSorted.isEmpty == false && termKey.isEmpty { termKey = termDefault() }

        // A photo that was missing may have arrived from iCloud since.
        if !force, !noPhoto.isEmpty {
            let arrived = noPhoto.filter { FileManager.default.fileExists(atPath: folder.photoURL($0).path) }
            if !arrived.isEmpty { noPhoto.subtract(arrived); photoVersion += 1 }
        }
    }

    func reloadIfIdle() {
        guard pending.isEmpty, inFlight == 0 else { return }
        guard folder.exists() else { folderOK = false; return }
        loadAll(force: false)
    }

    var folderLabel: String {
        folder.url.path.contains("com~apple~CloudDocs") ? "iCloud Drive" : folder.url.lastPathComponent
    }

    // MARK: Saving

    private func schedule(_ names: Set<TableName>) {
        pending.formUnion(names)
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flushNow(showToast: true) }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: w)
    }

    /// Writes whatever is waiting. The files are written on a background queue unless `wait` is set,
    /// which is for moments that cannot carry on until the data is safely on disk (quitting, or
    /// switching folders).
    func flushNow(showToast: Bool = false, wait: Bool = false) {
        if wait { writeQueue.sync { } }   // let any save already under way finish first
        saveWork?.cancel()
        let list = pending
        pending.removeAll()
        guard !list.isEmpty else { return }
        guard folder.exists() else {
            folderOK = false
            if showToast { self.showToast("No data folder. Nothing was saved.") }
            return
        }
        var jobs: [(table: TableName, header: [String], rows: [Row])] = []
        var skippedUnreadable = false
        for t in list {
            if badLoads.contains(t.rawValue) {
                self.showToast("\(t.rawValue).csv could not be read, so it was not overwritten.")
                skippedUnreadable = true
                continue
            }
            jobs.append((t, db.header(t), db.rows(t)))
        }
        guard !jobs.isEmpty else { return }

        let target = folder
        let frozen = jobs
        let work: () -> ([(TableName, DataFolder.Signature?)], [TableName]) = {
            var sigs: [(TableName, DataFolder.Signature?)] = []
            var failed: [TableName] = []
            for j in frozen {
                do {
                    try target.write(j.table, header: j.header, rows: j.rows)
                    sigs.append((j.table, target.signature(j.table)))
                } catch {
                    failed.append(j.table)
                }
            }
            return (sigs, failed)
        }

        inFlight += 1
        if wait {
            let r = writeQueue.sync(execute: work)
            saveFinished(sigs: r.0, failed: r.1, quiet: !showToast || skippedUnreadable)
        } else {
            let quiet = !showToast || skippedUnreadable
            writeQueue.async { [weak self] in
                let r = work()
                DispatchQueue.main.async { [weak self] in self?.saveFinished(sigs: r.0, failed: r.1, quiet: quiet) }
            }
        }
    }

    private func saveFinished(sigs: [(TableName, DataFolder.Signature?)], failed: [TableName], quiet: Bool) {
        inFlight -= 1
        for (t, s) in sigs { fileSigs[t] = s }
        for t in failed { showToast("Could not write \(t.rawValue).csv") }
        if failed.isEmpty && !quiet { showToast("Saved") }
    }

    func showToast(_ text: String) {
        toast = text
        toastWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: w)
    }

    // MARK: Photos

    /// A small version of the photo for the avatars. Reading a 256 pixel thumbnail through ImageIO
    /// keeps memory low and avoids decoding the full picture every time one is drawn. Students
    /// without a photo are remembered too, so the disk is not asked again on every redraw.
    func photo(for id: String) -> NSImage? {
        _ = photoVersion
        if let img = imageCache[id] { return img }
        if noPhoto.contains(id) { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
        ]
        guard let src = CGImageSourceCreateWithURL(folder.photoURL(id) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            noPhoto.insert(id)
            return nil
        }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        imageCache[id] = img
        return img
    }

    func savePhoto(for id: String, from url: URL) {
        guard let img = NSImage(contentsOf: url), let data = AppModel.shrunkJPEG(img, maxSide: 480) else {
            showToast("Could not read that photo")
            return
        }
        do {
            try? FileManager.default.createDirectory(at: folder.photosURL, withIntermediateDirectories: true)
            try data.write(to: folder.photoURL(id), options: .atomic)
            imageCache[id] = nil
            noPhoto.remove(id)
            photoVersion += 1
            showToast("Photo saved")
        } catch {
            showToast("Could not save the photo")
        }
    }

    static func shrunkJPEG(_ img: NSImage, maxSide: CGFloat) -> Data? {
        guard let rep = img.representations.first else { return nil }
        let w = CGFloat(rep.pixelsWide > 0 ? rep.pixelsWide : Int(img.size.width))
        let h = CGFloat(rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(img.size.height))
        guard w > 0, h > 0 else { return nil }
        let k = min(1, maxSide / max(w, h))
        let nw = Int((w * k).rounded()), nh = Int((h * k).rounded())
        guard let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: nw, pixelsHigh: nh, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        bmp.size = NSSize(width: nw, height: nh)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: nw, height: nh).fill()
        img.draw(in: NSRect(x: 0, y: 0, width: nw, height: nh), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.86])
    }

    // MARK: Import from another planner data folder

    /// Copies every CSV (and photos) from another folder, such as the NAS copy, into the current one.
    func importData(from source: URL) -> String {
        let fm = FileManager.default
        var copied = 0
        for t in TableName.allCases {
            let src = source.appendingPathComponent(t.rawValue + ".csv")
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = folder.fileURL(t)
            do {
                if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                try fm.copyItem(at: src, to: dst)
                copied += 1
            } catch {
                return "Could not copy \(t.rawValue).csv"
            }
        }
        let srcPhotos = source.appendingPathComponent("photos", isDirectory: true)
        var photos = 0
        if let files = try? fm.contentsOfDirectory(at: srcPhotos, includingPropertiesForKeys: nil) {
            try? fm.createDirectory(at: folder.photosURL, withIntermediateDirectories: true)
            for f in files where f.pathExtension.lowercased() == "jpg" {
                let dst = folder.photosURL.appendingPathComponent(f.lastPathComponent)
                try? fm.removeItem(at: dst)
                if (try? fm.copyItem(at: f, to: dst)) != nil { photos += 1 }
            }
        }
        imageCache.removeAll()
        noPhoto.removeAll()
        photoVersion += 1
        loadAll()
        return "Imported \(copied) files and \(photos) photos"
    }

    // MARK: Start over

    enum StartOverOutcome {
        case done(archive: URL?, disconnectedShared: Bool)
        case failed(String)
    }

    /// Clears Holocron so it begins again with the starter day and subjects. The current files are
    /// moved into a dated folder in "Holocron archive" beside the data folder, never deleted. A
    /// separate (often shared) planner folder is only disconnected, so colleagues keep their planner.
    func startOver(_ scope: StartOverScope) -> StartOverOutcome {
        flushNow(wait: true)
        guard folder.exists() else {
            return .failed("The data folder could not be found, so nothing was changed.")
        }
        let plan = folder.startOverPlan(scope)
        switch plan.carryOut() {
        case .failure(.archiveNotCreated):
            return .failed("The archive folder could not be created next to your data folder, so nothing was changed.")
        case .failure(.moveFailed(let name)):
            return .failed("\(name) could not be moved, so everything was left as it was. Close any other app that has it open, then try again.")
        case .success:
            break
        }
        if plan.disconnectsSharedPlanner {
            folder.plannerURL = nil
            UserDefaults.standard.removeObject(forKey: AppModel.plannerKey)
        }
        try? folder.ensureExists()
        if scope == .everything {
            UserDefaults.standard.removeObject(forKey: "lastQuote")
            imageCache.removeAll()
            noPhoto.removeAll()
            photoVersion += 1
            selectedStudent = nil
        }
        weekMonday = nil
        weekFilter = ""
        devotionDate = nil
        termKey = ""
        termSubject = ""
        lastLessonSubject = ""
        loadAll()
        return .done(archive: plan.moves.isEmpty ? nil : plan.archive, disconnectedShared: plan.disconnectsSharedPlanner)
    }

    // MARK: Helpers used by several screens

    func termDefault() -> String {
        let ts = db.termsSorted
        let today = todayISO()
        let t = db.termOf(today) ?? ts.first(where: { $0.start > today }) ?? ts.last
        return t?.id ?? ""
    }

    /// The Monday of the week on show in the Week view. Weekends open the coming week.
    var shownMonday: String {
        if let m = weekMonday { return m }
        let t = todayISO()
        return dayIdx(t) >= 5 ? addDays(mondayOf(t), 7) : mondayOf(t)
    }

    func quote() -> Row? {
        let pool = db.rows(.quotes).filter { !$0.s("quote").isEmpty }
        guard !pool.isEmpty else { return nil }
        if let k = quoteKey, let q = pool.first(where: { $0.s("date") == k }) { return q }
        let last = UserDefaults.standard.string(forKey: "lastQuote")
        let opts = pool.count > 1 ? pool.filter { $0.s("date") != last } : pool
        guard let q = opts.randomElement() else { return nil }
        quoteKey = q.s("date")
        UserDefaults.standard.set(q.s("date"), forKey: "lastQuote")
        return q
    }

    /// Whatever lesson is on right now, today.
    func nowSubject() -> String {
        let nm = nowMinutes()
        var cur = ""
        for p in db.periods {
            if let a = hm(p.start), let b = hm(p.end), nm >= a, nm < b {
                cur = db.plannedSubject(todayISO(), p.period)
            }
        }
        return cur
    }
}
