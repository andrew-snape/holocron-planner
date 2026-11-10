import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers
import ImageIO

/// The headings in the sidebar.
enum NavGroup: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case teach = "Teach"
    case classroom = "Class"
    var id: String { rawValue }
}

enum NavItem: String, CaseIterable, Identifiable {
    case today, week, term, units, devotion, classScreen, students, work, quick, assess, hours

    var id: String { rawValue }

    /// Which heading this screen sits under in the sidebar.
    var group: NavGroup {
        switch self {
        case .today, .week, .term, .units, .devotion: return .plan
        case .classScreen, .quick, .assess: return .teach
        case .students, .work, .hours: return .classroom
        }
    }

    /// The Cmd+digit key for this screen in the Go menu. Work has none, so the ten original
    /// screens keep the keys they have always had.
    var shortcutDigit: Character? {
        switch self {
        case .today: return "1"
        case .week: return "2"
        case .term: return "3"
        case .units: return "4"
        case .devotion: return "5"
        case .classScreen: return "6"
        case .students: return "7"
        case .quick: return "8"
        case .assess: return "9"
        case .hours: return "0"
        case .work: return nil
        }
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .classScreen: return "Class screen"
        case .term: return "Term"
        case .units: return "Units"
        case .devotion: return "Devotion"
        case .students: return "Students"
        case .work: return "Work"
        case .quick: return "Quick log"
        case .assess: return "Mark class"
        case .hours: return "Hours"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "clock"
        case .week: return "calendar"
        case .classScreen: return "tv"
        case .term: return "tablecells"
        case .units: return "globe.asia.australia"
        case .devotion: return "book.closed"
        case .students: return "person.2"
        case .work: return "photo.on.rectangle"
        case .quick: return "square.grid.2x2"
        case .assess: return "checkmark.square"
        case .hours: return "chart.bar"
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
    case importResults(url: URL)
    case dictate
    case jump
    case interview(sid: String)
    case addWork(studentID: String?)
    case editWork(id: String)
    case merge
    case groups

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
        case .importResults(let u): return "importresults-" + u.path
        case .dictate: return "dictate"
        case .jump: return "jump"
        case .interview(let s): return "interview-" + s
        case .addWork(let s): return "addwork-" + (s ?? "")
        case .editWork(let i): return "editwork-" + i
        case .merge: return "merge"
        case .groups: return "groups"
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
    /// Shown once after an update (see WhatsNew).
    var whatsNew: WhatsNew.Notice? = nil
    var lastLessonSubject: String = ""
    /// The kind of entry last saved from Quick log, so the next one starts there. Lasts until the app closes.
    var lastQuickKind: QuickKind = .lesson
    @ObservationIgnored var quoteKey: String? = nil

    // Data folder
    var folder: DataFolder
    var folderOK = false
    var folderMessage = ""
    var badLoads: Set<String> = []
    var showSetup = false

    // Toast
    var toast: String? = nil
    /// True when the toast has an Undo button, for a change that can be taken back.
    var toastUndo = false

    /// What Edit, Undo and Edit, Redo would do, such as "Delete Note". Nil when there is nothing to go back to.
    var undoName: String? = nil
    var redoName: String? = nil

    /// Set while a save has failed and is waiting to be tried again. Cleared when a save works.
    var saveProblem: String? = nil

    // Photos change counter, so a replaced photo shows straight away
    var photoVersion = 0

    /// The Class screen timer, shared by the sidebar module and the pop-out window.
    let classTimer = ClassTimer()
    /// The Class screen stopwatch. Kept here, so it keeps running when you leave the screen and come back.
    let stopwatch = Stopwatch()
    /// The Class screens on show, in the window, popped out or in the sidebar.
    /// Siri leaves names out while any are.
    var classScreens: Set<UUID> = []
    /// The students and subjects last given to Siri, so they are only sent again when they change.
    @ObservationIgnored private var siriVocabulary = ""

    /// Looks for new versions on GitHub Releases and installs them.
    let updater = Updater()

    @ObservationIgnored private var pending: Set<TableName> = []
    /// Subjects whose lessons are kept in lessonsprivate.csv. See `mergeLessons`.
    @ObservationIgnored private var privateSubjects: Set<String> = []
    @ObservationIgnored private var hiddenShared: [Row] = []
    @ObservationIgnored private var hiddenPrivate: [Row] = []
    @ObservationIgnored private var privacySnapshot = ""
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

    /// Each file's rows as Holocron last read or wrote them, in memory only. A save that finds the file
    /// changed on disk merges with these (see `DataFolder.saveMerging`).
    @ObservationIgnored private var baseRows: [TableName: [Row]] = [:]
    /// The signature and rows of each file as the save queue last wrote them. Saves run one after another,
    /// and the next one must compare with what the last one wrote, even before its result reaches the screen.
    @ObservationIgnored private let memo = SaveMemo()
    /// Names of iCloud copies merged in, noted in settings once the merged rows are safely written.
    @ObservationIgnored private var copyMarks: [TableName: [String: String]] = [:]
    @ObservationIgnored private var migratedFolder: String? = nil
    @ObservationIgnored private var warnedNewer = false
    /// Tables saved while the file had changed, and a conflict is waiting for an answer. Their saves are held.
    @ObservationIgnored private var mergeHeld: Set<TableName> = []
    /// Tables whose file could not be read when a save went to merge. Kept in `pending` and tried again.
    @ObservationIgnored private var mergeBlocked: Set<TableName> = []
    /// Things both you and the shared folder changed, waiting for you to choose.
    var mergeConflicts: [MergeItem] = []
    /// Copies of a file that iCloud made when two Macs saved at once, not yet merged in.
    var conflictCopies: [ConflictCopy] = []

    static let folderKey = "dataFolderPath"
    static let plannerKey = "plannerFolderPath"
    static let appVersion = Updater.currentVersion + " (Mac)"

    init() {
        let saved = UserDefaults.standard.string(forKey: AppModel.folderKey)
        let url = saved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? DataFolder.defaultURL()
        let plannerSaved = UserDefaults.standard.string(forKey: AppModel.plannerKey)
        folder = DataFolder(url: url, plannerURL: plannerSaved.map { URL(fileURLWithPath: $0, isDirectory: true) })
        db.persistHandler = { [weak self] names in self?.schedule(names) }
        db.onUndoChange = { [weak self] done in
            guard let self else { return }
            self.undoName = self.db.undoName
            self.redoName = self.db.redoName
            if let done { self.showToast(done, offerUndo: true) }
        }
        updater.prepareToQuit = { [weak self] in self?.flushNow(wait: true) }

        if folder.exists() {
            loadAll()
        } else {
            folderOK = false
            folderMessage = missingMessage(folder)
            showSetup = true
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flushNow()   // try again any save that failed earlier
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
        guard flushOrStop() else { return "Your changes could not be saved, so the planner folder was not changed." }
        var next = folder
        next.plannerURL = url
        let (copied, kept) = copyMissingFiles(TableName.allCases.filter { $0.isPlanner }, from: folder, to: next)
        folder = next
        if let u = url { UserDefaults.standard.set(u.path, forKey: AppModel.plannerKey) }
        else { UserDefaults.standard.removeObject(forKey: AppModel.plannerKey) }
        loadAll()
        if url == nil { return "Planner files are back in the student folder" }
        return "Planner folder connected. \(copied) file\(copied == 1 ? "" : "s") copied in, \(kept) already there were kept."
    }

    /// Copies each table's file to where `to` keeps it, unless something is already there. Returns how many
    /// files were copied and how many were already in place and so kept.
    private func copyMissingFiles(_ tables: [TableName], from: DataFolder, to: DataFolder) -> (copied: Int, kept: Int) {
        let fm = FileManager.default
        var copied = 0, kept = 0
        for t in tables {
            let src = from.fileURL(t), dst = to.fileURL(t)
            if src.path == dst.path { continue }
            if fm.fileExists(atPath: dst.path) { kept += 1; continue }
            if fm.fileExists(atPath: src.path), (try? fm.copyItem(at: src, to: dst)) != nil { copied += 1 }
        }
        return (copied, kept)
    }

    /// Saves anything waiting, then reads every file again.
    func reloadFromFolder(toast: String? = "Reloaded from folder") {
        guard flushOrStop() else { showToast("Your changes could not be saved, so nothing was reloaded"); return }
        loadAll()
        if let toast { showToast(toast) }
    }

    /// Puts text on the clipboard and says so.
    func copyText(_ text: String, toast: String = "Copied") {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        showToast(toast)
    }

    /// Renames a subject everywhere: the timetable, lessons (including the ones kept aside in the other
    /// file), results, notes and the private subject setting.
    func renameSubject(from old: String, to newName: String) {
        let new = newName.trimmed
        guard !new.isEmpty, new != old, !db.subjects.contains(where: { $0.subject == new }) else { return }
        let wasPrivate = isSubjectPrivate(old)
        for i in hiddenShared.indices where hiddenShared[i].s("subject") == old { hiddenShared[i]["subject"] = new }
        for i in hiddenPrivate.indices where hiddenPrivate[i].s("subject") == old { hiddenPrivate[i]["subject"] = new }
        if wasPrivate {
            privateSubjects.remove(old)
            privateSubjects.insert(new)
            db.setSetting(Database.privateSubjectPrefix + old, "off")
            db.setSetting(Database.privateSubjectPrefix + new, "on")
        }
        db.renameSubject(from: old, to: new)
        pending.insert(.lessons)
    }

    func useFolder(_ url: URL, createIfNeeded: Bool) {
        let f = DataFolder(url: url, plannerURL: folder.plannerURL)
        if createIfNeeded { try? f.ensureExists() }
        guard f.exists() else {
            folderMessage = missingMessage(f)
            folderOK = false
            return
        }
        guard flushOrStop() else {
            showToast("Your changes could not be saved, so the folder was not changed")
            return
        }
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
        memo.clear()
        badLoads.removeAll()
        if force {
            fileSigs.removeAll()
            // A full reload reads every file again, so questions about the old rows no longer apply.
            // Your side of any conflict was kept in Holocron archive, Before merge.
            mergeConflicts.removeAll()
            mergeHeld.removeAll()
            mergeBlocked.removeAll()
        }
        var messages: [String] = []
        let folderThere = folder.exists()
        let privacyProblem = readPrivacy()
        if let problem = privacyProblem {
            // Without the privacy rule, lessons and Devotion could be read or written to the wrong folder,
            // so none of them is written until settings.csv can be read again.
            for name in [TableName.settings, .lessons, .lessonsprivate, .devotion, .quotes] {
                badLoads.insert(name.rawValue)
            }
            messages.append(problem)
        }
        for t in TableName.allCases {
            // Private lessons are read together with the shared ones, below.
            if t == .lessonsprivate { continue }
            let sig = folder.signature(t)
            var unchanged = !force && !previouslyBad.contains(t.rawValue) && sig != nil && fileSigs[t] == sig
            if t == .lessons {
                unchanged = unchanged && !previouslyBad.contains(TableName.lessonsprivate.rawValue)
                    && fileSigs[.lessonsprivate] == folder.signature(.lessonsprivate)
            }
            if unchanged { continue }
            // settings.csv was already reported by readPrivacy, so it is not reported twice.
            if t == .settings, privacyProblem != nil { continue }
            switch folder.read(t) {
            case .ok(let header, let rows):
                db.load(t, header: header, rows: t == .lessons ? mergeLessons(shared: rows, messages: &messages) : rows)
                fileSigs[t] = sig
                baseRows[t] = rows
            case .missing:
                let starter = Starter.rows(for: t)
                db.load(t, header: t.header, rows: t == .lessons ? mergeLessons(shared: starter, messages: &messages) : starter)
                fileSigs[t] = nil
                baseRows[t] = starter
                // Never create a blank file where the folder's rules are unknown or the file is unreadable.
                if folderThere, !badLoads.contains(t.rawValue) {
                    try? folder.write(t, header: t.header, rows: starter)
                    fileSigs[t] = folder.signature(t)
                }
            case .failed(let msg):
                badLoads.insert(t.rawValue)
                fileSigs[t] = nil
                messages.append(msg)
            }
        }
        folderOK = folderThere && badLoads.isEmpty
        if !folderThere { folderMessage = missingMessage(folder) }
        else { folderMessage = messages.isEmpty ? "" : messages.joined(separator: ". ") }
        if !db.termsSorted.isEmpty && termKey.isEmpty { termKey = termDefault() }
        refreshSiriVocabulary()

        if folderThere { writeAIGuides() }
        if folderThere { migrateSchemaIfNeeded() }
        if folderThere { findConflictCopies() }

        // A photo that was missing may have arrived from iCloud since.
        if !force, !noPhoto.isEmpty {
            let arrived = noPhoto.filter { FileManager.default.fileExists(atPath: folder.photoURL($0).path) }
            if !arrived.isEmpty { noPhoto.subtract(arrived); photoVersion += 1 }
        }
    }

    /// Keeps README-for-AI.md up to date in each data folder. It only writes when the content has changed.
    private func writeAIGuides() {
        folder.writeAIGuides(version: Updater.currentVersion, privateSubjects: privateSubjects)
    }

    /// Both guides for the clipboard: the planner guide, then the student guide under its privacy notice.
    func aiGuideText() -> String {
        folder.combinedAIGuide(version: Updater.currentVersion, privateSubjects: privateSubjects)
    }

    /// The planner guide alone, with no student information.
    func plannerGuideText() -> String {
        folder.plannerAIGuide(version: Updater.currentVersion, privateSubjects: privateSubjects)
    }

    func reloadIfIdle() {
        guard pending.isEmpty, inFlight == 0, mergeConflicts.isEmpty else { return }
        guard folder.exists() else { folderOK = false; return }
        loadAll(force: false)
    }

    var folderLabel: String {
        folder.url.path.contains("com~apple~CloudDocs") ? "iCloud Drive" : folder.url.lastPathComponent
    }

    // MARK: Private subjects

    /// Reads which subjects (and whether the Devotion scripts) are private, straight from settings.csv,
    /// before the other files are read. If the answer has changed since the last read, every file is read again.
    /// Returns a message when settings.csv could not be read. The last good answer is then kept.
    private func readPrivacy() -> String? {
        var subjects = Set<String>()
        var devotion = false
        switch folder.read(.settings) {
        case .ok(_, let rows):
            let p = Database.privacy(from: rows)
            subjects = p.subjects
            devotion = p.devotion
        case .missing:
            break
        case .failed(let msg):
            return msg
        }
        privateSubjects = subjects
        let privateTables: Set<TableName> = devotion ? [.devotion, .quotes] : []
        if folder.privateTables != privateTables { folder.privateTables = privateTables }
        let snapshot = subjects.sorted().joined(separator: "|") + (devotion ? "#devotion" : "")
        if snapshot != privacySnapshot {
            privacySnapshot = snapshot
            fileSigs.removeAll()
        }
        return nil
    }

    /// Lessons sit in two files. lessons.csv is the planner folder's copy, shared with colleagues, and
    /// lessonsprivate.csv is yours alone. In memory they are one table: the shared file's lessons for
    /// subjects that are not private, plus the private file's lessons for subjects that are.
    /// Each file keeps, exactly as they were, any rows it holds for subjects that belong to the other
    /// one. Those rows are not shown, and are written back untouched, so switching a subject between
    /// shared and private never moves or loses anything, and a colleague's lessons are never overwritten.
    private func mergeLessons(shared: [Row], messages: inout [String]) -> [Row] {
        hiddenShared = shared.filter { privateSubjects.contains($0.s("subject")) }
        var visible = shared.filter { !privateSubjects.contains($0.s("subject")) }
        var mine: [Row] = []
        switch folder.read(.lessonsprivate) {
        case .ok(_, let rows): mine = rows
        case .missing: break
        case .failed(let msg):
            badLoads.insert(TableName.lessonsprivate.rawValue)
            messages.append(msg)
        }
        hiddenPrivate = mine.filter { !privateSubjects.contains($0.s("subject")) }
        visible += mine.filter { privateSubjects.contains($0.s("subject")) }
        fileSigs[.lessonsprivate] = folder.signature(.lessonsprivate)
        baseRows[.lessonsprivate] = mine
        return visible
    }

    /// How many lessons the shared file holds for a subject.
    func sharedLessonCount(_ subject: String) -> Int {
        guard !isSubjectPrivate(subject) else { return 0 }
        return db.rows(.lessons).count(where: { $0.s("subject") == subject })
    }

    func isSubjectPrivate(_ subject: String) -> Bool { db.isPrivateSubject(subject) }

    /// Marks a subject private or shared. With `copyLessons`, the subject's current lessons are also
    /// copied into the private file the first time it is made private. The shared copies are left alone.
    func setSubjectPrivate(_ subject: String, _ on: Bool, copyLessons: Bool = false) {
        guard flushOrStop() else { showToast("Your changes could not be saved, so the setting was not changed"); return }
        if on && copyLessons {
            let existing = db.rows(.lessons).filter { $0.s("subject") == subject }
            let have = Set(hiddenPrivate.filter { $0.s("subject") == subject }.map { Database.SlotKey(date: $0.s("date"), per: Int($0.s("period")) ?? 0) })
            hiddenPrivate += existing.filter { !have.contains(Database.SlotKey(date: $0.s("date"), per: Int($0.s("period")) ?? 0)) }
        }
        db.setSetting(Database.privateSubjectPrefix + subject, on ? "on" : "off")
        // Save the settings and the private file, then read everything again under the new rule.
        if on && copyLessons { pending.insert(.lessons) }
        guard flushOrStop() else { showToast("Your changes could not be saved, so the setting was not changed"); return }
        loadAll()
    }

    /// Keeps the Devotion scripts and quotes in the student folder (private) or in the planner folder (shared).
    /// Files are copied across when the new place does not have them yet. Anything already there is kept.
    @discardableResult
    func setDevotionPrivate(_ on: Bool) -> String {
        guard flushOrStop() else { return "Your changes could not be saved, so the setting was not changed." }
        db.setSetting(Database.privateDevotionKey, on ? "on" : "off")
        flushNow(wait: true)
        var next = folder
        next.privateTables = on ? [.devotion, .quotes] : []
        let (copied, kept) = copyMissingFiles([.devotion, .quotes], from: folder, to: next)
        folder = next
        loadAll()
        if on { return "Devotion is now private. \(copied) file\(copied == 1 ? "" : "s") copied, \(kept) already there were kept." }
        return "Devotion is shared again. \(copied) file\(copied == 1 ? "" : "s") copied, \(kept) already in the planner folder were kept."
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
            // Keep the changes waiting until the folder is back.
            pending.formUnion(list)
            folderOK = false
            if showToast { self.showToast("No data folder. Nothing was saved.") }
            return
        }
        struct Job {
            var table: TableName
            var header: [String]
            var rows: [Row]
            var base: [Row]?
            var expected: DataFolder.Signature?
        }
        var jobs: [Job] = []
        var skippedUnreadable = false
        for t in list {
            if mergeHeld.contains(t) {
                // A question about this table is waiting. Its changes are saved once it is answered.
                // On quitting, what is on screen is copied into Before merge so nothing typed since is lost.
                if wait {
                    for f in (t == .lessons ? [TableName.lessons, .lessonsprivate] : [t]) {
                        folder.saveMineSnapshot(f, header: db.header(f == .lessonsprivate ? .lessons : f), mine: fileRows(f))
                    }
                }
                pending.insert(t)
                continue
            }
            // A file that could not be read when a save went to merge is looked at again.
            var stillBlocked = false
            for f in (t == .lessons ? [TableName.lessons, .lessonsprivate] : [t]) where mergeBlocked.contains(f) {
                if case .failed = folder.read(f) { stillBlocked = true }
                else { mergeBlocked.remove(f); badLoads.remove(f.rawValue) }
            }
            if stillBlocked {
                pending.insert(t)
                skippedUnreadable = true
                continue
            }
            if badLoads.contains(t.rawValue) {
                self.showToast("\(t.rawValue).csv could not be read, so it was not overwritten.")
                skippedUnreadable = true
                continue
            }
            if t == .lessons {
                // Lessons are saved in two files: the shared one, and the private one for private subjects.
                jobs.append(Job(table: .lessons, header: db.header(.lessons), rows: fileRows(.lessons),
                                base: baseRows[.lessons], expected: fileSigs[.lessons]))
                let privateRows = fileRows(.lessonsprivate)
                let privateFileThere = FileManager.default.fileExists(atPath: folder.fileURL(.lessonsprivate).path)
                if !badLoads.contains(TableName.lessonsprivate.rawValue), !privateRows.isEmpty || privateFileThere {
                    jobs.append(Job(table: .lessonsprivate, header: db.header(.lessons), rows: privateRows,
                                    base: baseRows[.lessonsprivate], expected: fileSigs[.lessonsprivate]))
                }
                continue
            }
            jobs.append(Job(table: t, header: db.header(t), rows: db.rows(t), base: baseRows[t], expected: fileSigs[t]))
        }
        guard !jobs.isEmpty else { return }

        let target = folder
        let frozen = jobs
        let memo = self.memo
        let work: () -> [SaveOutcome] = {
            frozen.map { j in
                let last = memo.get(j.table)
                let o = target.saveMerging(j.table, header: j.header, mine: j.rows,
                                           base: last?.rows ?? j.base, expected: last == nil ? j.expected : last!.signature)
                if case .blocked = o.kind {} else if o.kind != .failed { memo.set(j.table, rows: o.rows, signature: o.signature) }
                return o
            }
        }
        let mineRows = Dictionary(uniqueKeysWithValues: frozen.map { ($0.table, $0.rows) })

        inFlight += 1
        let quiet = !showToast || skippedUnreadable
        if wait {
            let r = writeQueue.sync(execute: work)
            saveFinished(r, mine: mineRows, quiet: quiet)
        } else {
            writeQueue.async { [weak self] in
                let r = work()
                DispatchQueue.main.async { [weak self] in self?.saveFinished(r, mine: mineRows, quiet: quiet) }
            }
        }
    }

    /// The rows of one file, as they are written: lessons are split between the shared and private files.
    private func fileRows(_ t: TableName) -> [Row] {
        switch t {
        case .lessons:
            return db.rows(.lessons).filter { !privateSubjects.contains($0.s("subject")) } + hiddenShared
        case .lessonsprivate:
            return db.rows(.lessons).filter { privateSubjects.contains($0.s("subject")) } + hiddenPrivate
        default:
            return db.rows(t)
        }
    }

    private func saveFinished(_ outcomes: [SaveOutcome], mine: [TableName: [Row]], quiet: Bool) {
        inFlight -= 1
        var failed: [TableName] = []
        var addedFromFolder: [TableName] = []
        var newConflicts = false
        for o in outcomes {
            let pendingName: TableName = o.table == .lessonsprivate ? .lessons : o.table
            switch o.kind {
            case .written:
                fileSigs[o.table] = o.signature
                baseRows[o.table] = o.rows
                markCopies(o.table)
            case .failed:
                failed.append(o.table)
            case .blocked(let why):
                // Nothing was written. The rows stay in memory and the save is tried again.
                badLoads.insert(o.table.rawValue)
                mergeBlocked.insert(o.table)
                pending.insert(pendingName)
                saveProblem = why + " Your changes are still in Holocron."
                showToast(why)
            case .merged where !o.changed && o.conflicts.isEmpty:
                fileSigs[o.table] = o.signature
                baseRows[o.table] = o.rows
                markCopies(o.table)
            case .merged:
                fileSigs[o.table] = o.signature
                baseRows[o.table] = o.rows
                if o.conflicts.isEmpty { markCopies(o.table) }
                let frozenMine = mine[o.table] ?? []
                applyMerged(o, frozenMine: frozenMine)
                addedFromFolder.append(o.table)
                if !o.conflicts.isEmpty {
                    newConflicts = true
                    mergeHeld.insert(pendingName)
                    pending.insert(pendingName)
                    for c in o.conflicts {
                        mergeConflicts.append(MergeItem(table: o.table, conflict: c))
                    }
                }
            }
        }
        if !addedFromFolder.isEmpty, !newConflicts {
            let planner = addedFromFolder.contains { $0.isPlanner && folder.plannerURL != nil }
            showToast(planner ? "Added changes from the shared folder." : "Added changes made outside Holocron.")
        }
        if newConflicts {
            showToast("You and the shared folder changed the same thing. Choose which to keep.")
            if sheet == nil { sheet = .merge }
        }
        guard failed.isEmpty else {
            // Keep the changes waiting. The next change, quitting, or coming back to the app tries again,
            // and reloads stay off until then, so the unsaved rows are not replaced by the old file.
            for t in failed { pending.insert(t == .lessonsprivate ? .lessons : t) }
            let names = failed.map { "\($0.rawValue).csv" }.joined(separator: ", ")
            saveProblem = "Could not save \(names). Your changes are still in Holocron. Keep the app open and check that your data folder is available."
            showToast("Could not save \(names)")
            return
        }
        if pending.isEmpty, mergeBlocked.isEmpty, mergeHeld.isEmpty { saveProblem = nil }
        if !quiet, addedFromFolder.isEmpty { showToast("Saved") }
    }

    private func markCopies(_ t: TableName) {
        guard let marks = copyMarks.removeValue(forKey: t) else { return }
        for (k, v) in marks { db.setSetting(k, v) }
    }

    /// Puts what a merge produced on screen. If something was typed while the save ran, that is carried over.
    private func applyMerged(_ o: SaveOutcome, frozenMine: [Row]) {
        let key = RowMerge.keyColumns(for: o.table)
        // My version stays on screen for anything that is a conflict, until it is answered.
        var target = RowMerge.keepingMine(o.rows, conflicts: o.conflicts, key: key)
        let current = fileRows(o.table)
        let typedMeanwhile = current.count != frozenMine.count || zip(current, frozenMine).contains { !RowMerge.same($0, $1) }
        if typedMeanwhile {
            target = RowMerge.merge(base: frozenMine, mine: current, theirs: target, key: key).rows
            pending.insert(o.table == .lessonsprivate ? .lessons : o.table)
        }
        switch o.table {
        case .lessons:
            hiddenShared = target.filter { privateSubjects.contains($0.s("subject")) }
            let shown = target.filter { !privateSubjects.contains($0.s("subject")) }
                + db.rows(.lessons).filter { privateSubjects.contains($0.s("subject")) }
            db.load(.lessons, header: db.header(.lessons), rows: shown)
        case .lessonsprivate:
            hiddenPrivate = target.filter { !privateSubjects.contains($0.s("subject")) }
            let shown = db.rows(.lessons).filter { !privateSubjects.contains($0.s("subject")) }
                + target.filter { privateSubjects.contains($0.s("subject")) }
            db.load(.lessons, header: db.header(.lessons), rows: shown)
        default:
            db.load(o.table, header: db.header(o.table), rows: target)
        }
    }

    // MARK: Merge questions

    /// Answers one conflict. Keeping theirs puts their row on screen. Keeping mine leaves mine, which is
    /// saved over theirs once every question about the table is answered.
    func resolveMerge(_ item: MergeItem, keepMine: Bool) {
        guard let i = mergeConflicts.firstIndex(where: { $0.id == item.id }) else { return }
        if !keepMine, let theirs = item.conflict.theirs {
            let key = RowMerge.keyColumns(for: item.table)
            func id(_ r: Row) -> String { key.map { r.s($0) }.joined(separator: "\u{1F}") }
            let want = id(theirs)
            // Only the columns both sides changed take their value. Other columns stay as merged.
            let cols = item.conflict.columns
            func take(_ r: inout Row) { for c in cols { r[c] = theirs.s(c) } }
            switch item.table {
            case .lessons, .lessonsprivate:
                if db.rows(.lessons).contains(where: { id($0) == want }) {
                    db.update(.lessons, where: { id($0) == want }) { take(&$0) }
                } else if item.table == .lessons, let h = hiddenShared.firstIndex(where: { id($0) == want }) {
                    take(&hiddenShared[h])
                } else if let h = hiddenPrivate.firstIndex(where: { id($0) == want }) {
                    take(&hiddenPrivate[h])
                }
            default:
                db.update(item.table, where: { id($0) == want }) { take(&$0) }
            }
        }
        mergeConflicts.remove(at: i)
        releaseMergeHolds()
    }

    func resolveAllMerges(keepMine: Bool) {
        for item in mergeConflicts { resolveMerge(item, keepMine: keepMine) }
    }

    private func releaseMergeHolds() {
        for t in mergeHeld {
            let real: TableName = t
            let open = mergeConflicts.contains { ($0.table == .lessonsprivate ? .lessons : $0.table) == real }
            if !open { mergeHeld.remove(t) }
        }
        if mergeHeld.isEmpty, !pending.isEmpty { schedule([]) }
        else if mergeHeld.isEmpty { saveProblem = nil }
    }

    // MARK: Copies made by iCloud

    private func findConflictCopies() {
        var found: [ConflictCopy] = []
        for t in TableName.allCases {
            for u in folder.conflictCopies(of: t) {
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                if db.setting("merged_copy_" + u.lastPathComponent) == String(size) { continue }
                found.append(ConflictCopy(table: t, url: u, size: size))
            }
        }
        conflictCopies = found
    }

    /// Merges a copy iCloud made into the table, matching rows by key. Nothing is ever deleted: the copy
    /// stays where it is. Questions about rows that differ are asked as usual.
    func mergeConflictCopy(_ c: ConflictCopy) {
        guard canWrite(c.table), mergeHeld.isEmpty else { showToast("That file cannot be changed right now."); return }
        guard flushOrStop() else { showToast("Your changes could not be saved, so nothing was merged."); return }
        guard case .ok(_, let copyRows) = folder.readFile(c.url, table: c.table) else {
            showToast("That copy could not be read, so nothing was merged.")
            return
        }
        let key = RowMerge.keyColumns(for: c.table)
        let mineRows = fileRows(c.table)
        let r = RowMerge.merge(base: [], mine: mineRows, theirs: copyRows, key: key)
        // Copy the file first, as for any merge.
        guard folder.copyBeforeMerge(c.table) else { showToast("A safety copy could not be made, so nothing was merged."); return }
        let out = SaveOutcome(table: c.table, kind: .merged, rows: r.rows, conflicts: r.conflicts)
        applyMerged(out, frozenMine: mineRows)
        let pendingName: TableName = c.table == .lessonsprivate ? .lessons : c.table
        pending.insert(pendingName)
        // Base stays as the file on disk, so the added rows are written on the next save.
        for cf in r.conflicts { mergeConflicts.append(MergeItem(table: c.table, conflict: cf)) }
        if !r.conflicts.isEmpty { mergeHeld.insert(pendingName); if sheet == nil { sheet = .merge } }
        copyMarks[c.table, default: [:]]["merged_copy_" + c.url.lastPathComponent] = String(c.size)
        conflictCopies.removeAll { $0.id == c.id }
        schedule([pendingName])
        showToast("Merged \(c.url.lastPathComponent) in. The copy is still in the folder.")
    }

    // MARK: Schema version

    /// Stamps the folder with the file layout version. A folder from an older Holocron is copied into
    /// "Holocron archive" before anything is changed, and a folder from a newer Holocron is left as it is.
    private func migrateSchemaIfNeeded() {
        guard badLoads.isEmpty, mergeHeld.isEmpty, migratedFolder != folder.url.path else { return }
        switch SchemaVersion.check(stored: db.setting(SchemaVersion.key)) {
        case .upToDate:
            return
        case .newerThanApp:
            if !warnedNewer {
                warnedNewer = true
                // Copy everything first, so a file rewritten by this older app can always be got back.
                if folder.copyAllBeforeOlderApp() {
                    showToast("These files were saved by a newer Holocron. A copy is in Holocron archive. Update Holocron before changing them.")
                } else {
                    showToast("These files were saved by a newer Holocron, and a copy could not be made in Holocron archive. Update Holocron before changing them.")
                }
            }
        case .needsMigration(let from):
            guard flushOrStop() else { return }
            migratedFolder = folder.url.path   // once a session, so a step that cannot be saved is never repeated
            switch folder.migrate(from: from) {
            case .done(let v, _):
                let rewrote = SchemaVersion.pending(from: from).contains { !$0.tables.isEmpty }
                db.setSetting(SchemaVersion.key, String(v))
                if rewrote { flushNow(wait: true); loadAll() }   // a step changed files, so read them again
            case .failed(let why):
                showToast(why)
            }
        }
    }

    func showToast(_ text: String, offerUndo: Bool = false) {
        toast = text
        toastUndo = offerUndo
        toastWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.toast = nil; self?.toastUndo = false }
        toastWork = w
        // Longer when there is an Undo button to reach.
        DispatchQueue.main.asyncAfter(deadline: .now() + (offerUndo ? 6 : 1.6), execute: w)
    }

    // MARK: Jump

    /// Goes to what Jump found. A sheet is opened a moment later, once Jump has closed.
    func jump(to target: JumpResult.Target) {
        switch target {
        case .screen(let n):
            nav = n
        case .student(let id):
            selectedStudent = id
            nav = .students
        case .unit(let id):
            nav = .units
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.sheet = .unit(id: id) }
        case .lesson(let d, let p):
            cursor = d
            weekMonday = mondayOf(d)
            nav = .week
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.sheet = .plan(date: d, per: p, edit: false) }
        }
    }

    // MARK: Undo

    /// The Undo button on the toast. It always takes back the last change, even when a note box has focus.
    func undoLastChange() {
        guard let name = db.undo() else { return }
        showToast("Undone: \(name)")
    }

    /// Edit, Undo. A text box being edited keeps its own undo, so typing is never undone by this.
    func undo() {
        if let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.undoManager?.canUndo == true {
            tv.undoManager?.undo()
            return
        }
        guard sheet == nil, let name = db.undo() else { return }
        showToast("Undone: \(name)")
    }

    func redo() {
        if let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.undoManager?.canRedo == true {
            tv.undoManager?.redo()
            return
        }
        guard sheet == nil, let name = db.redo() else { return }
        showToast("Redone: \(name)")
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
            try FileManager.default.createDirectory(at: folder.photosURL, withIntermediateDirectories: true)
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

    enum ImportOutcome {
        case done(ImportSummary)
        case failed(String)
    }

    /// Works out what importing from another data folder would do. Nothing is changed.
    /// `target` is the folder to import into when it is not the one in use yet (first-run setup).
    func importPlan(from source: URL, scope: ImportScope, includeSharedPlanner: Bool, into target: DataFolder? = nil) -> ImportPlan {
        flushNow(wait: true)
        return (target ?? folder).importPlan(from: source, scope: scope, includeSharedPlanner: includeSharedPlanner)
    }

    /// Saves anything waiting now. Returns false, with the changes still waiting, when a save fails, so
    /// that a folder change, reload, import or Start over never replaces rows that have not been saved.
    func flushOrStop() -> Bool {
        flushNow(wait: true)
        return pending.isEmpty
    }

    /// Call on the main thread before running `plan.carryOut()` off it, so pending edits are on disk.
    func prepareImport() { flushNow(wait: true) }

    /// Takes the result of `plan.carryOut()`, reloads from the folder and says what happened.
    /// Every file an import replaces is first copied into a dated "Before import" folder in
    /// Holocron archive, and if anything fails it is all put back.
    func finishImport(_ result: Result<ImportSummary, ImportPlan.Failure>, into target: DataFolder? = nil) -> ImportOutcome {
        switch result {
        case .failure(.notReady):
            return .failed("There is nothing to import from that folder, so nothing was changed.")
        case .failure(.backupFailed(let name)):
            return .failed("A safety copy of \(name) could not be made, so nothing was changed.")
        case .failure(.destinationNotCreated(let path)):
            return .failed("The folder \(path) could not be created, so nothing was changed. Check that iCloud Drive is available.")
        case .failure(.copyFailed(let name)):
            loadAll()
            return .failed("\(name) could not be copied, so everything was put back as it was. Close any other app that has it open, then try again.")
        case .failure(.rollbackIncomplete(let failed, let backup)):
            loadAll()
            return .failed("\(failed.joined(separator: ", ")) could not be put back after a problem. Your original files are safe in \(backup.path). Copy them back into your data folder and press Shift+Cmd+R.")
        case .success(let summary):
            imageCache.removeAll()
            noPhoto.removeAll()
            photoVersion += 1
            if let t = target, t.url != folder.url {
                useFolder(t.url, createIfNeeded: false)
            } else {
                loadAll()
            }
            return .done(summary)
        }
    }

    // MARK: Siri

    /// Lets Siri recognise this class's subjects, and students when names are allowed, in phrases.
    func refreshSiriVocabulary() {
        let names = db.siriMayUseNames ? db.roster.map { $0.id + $0.fullName }.joined(separator: "|") : ""
        let v = names + "#" + db.subjectNames.joined(separator: "|")
        guard v != siriVocabulary else { return }
        siriVocabulary = v
        HolocronShortcuts.updateAppShortcutParameters()
    }

    /// Whether a table can be changed now: the folder is there and the file was read properly.
    func canWrite(_ t: TableName) -> Bool {
        folder.exists() && !badLoads.contains(t.rawValue)
    }

    /// Writes waiting changes and checks the table's file now holds every row. For Siri, which
    /// should only say Saved once the note is on disk.
    func saveNow(_ t: TableName) -> Bool {
        flushNow(wait: true)
        return canWrite(t) && ArchivePlan.rowCount(folder.fileURL(t)) == db.rows(t).count
    }

    // MARK: Import results from a spreadsheet

    enum ResultsOutcome {
        case done(backup: URL?)
        case failed(String)
    }

    /// Saves imported results. assessments.csv is first copied into a dated "Before results import"
    /// folder in Holocron archive, and nothing is changed if that copy cannot be made.
    func importResults(_ changes: ResultsChanges, remember: [String: String], fm: FileManager = .default) -> ResultsOutcome {
        guard flushOrStop() else { return .failed("Your changes could not be saved, so nothing was imported.") }
        guard folder.exists() else { return .failed("The data folder could not be found, so nothing was changed.") }
        guard !badLoads.contains(TableName.assessments.rawValue) else {
            return .failed("assessments.csv could not be read, so it was not changed. Fix or move the file, then press Shift+Cmd+R.")
        }
        let file = folder.fileURL(.assessments)
        var backup: URL? = nil
        if fm.fileExists(atPath: file.path) {
            let dir = StartOverPlan.uniqueFolder(in: folder.archiveRoot, named: "Before results import " + StartOverPlan.stamp(Date(), .current), fm: fm)
            let copy = dir.appendingPathComponent(file.lastPathComponent)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try fm.copyItem(at: file, to: copy)
            } catch {
                try? fm.removeItem(at: dir)
                return .failed("A safety copy of assessments.csv could not be made, so nothing was changed.")
            }
            guard ArchivePlan.sameSize(file, copy, fm) else {
                try? fm.removeItem(at: dir)
                return .failed("A safety copy of assessments.csv could not be made, so nothing was changed.")
            }
            backup = dir
        }
        let expected = db.rows(.assessments).count + changes.added.count
        db.applyResults(changes, remember: remember)
        flushNow(wait: true)
        // flushNow reports a failed write only as a toast, so check the file itself.
        guard ArchivePlan.rowCount(file) == expected else {
            loadAll()
            return .failed("The results could not be saved to assessments.csv, so they were not imported. Check that your data folder is available, then try again."
                           + (backup.map { " A copy from before is in \($0.path)." } ?? ""))
        }
        return .done(backup: backup)
    }

    // MARK: Year end archive

    /// Works out what a year end archive would copy. Nothing is changed.
    func archivePlan(label: String, includeSharedPlanner: Bool) -> ArchivePlan {
        flushNow(wait: true)
        return folder.yearArchivePlan(label: label, includeSharedPlanner: includeSharedPlanner)
    }

    /// The year to suggest for an archive: the year of the latest term, else this year.
    var archiveYearGuess: String {
        db.termsSorted.last?.year ?? String(yearOf(todayISO()))
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
        guard flushOrStop() else { return .failed("Your changes could not be saved, so nothing was changed.") }
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
        lastQuickKind = .lesson
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

    // MARK: Stepping through time (toolbar buttons and the Go menu)

    /// What Previous and Next move by on the screen on show, or nil when the screen has nothing to step through.
    var stepUnit: String? {
        switch nav {
        case .today: return "Day"
        case .week: return "Week"
        case .term: return db.termsSorted.isEmpty ? nil : "Term"
        case .devotion: return db.rows(.devotion).isEmpty ? nil : "Devotion"
        default: return nil
        }
    }

    private var devotionDates: [String] { db.rows(.devotion).map { $0.s("date") }.sorted() }

    /// The devotion date on show, using the same rule as the Devotion screen.
    private func shownDevotion(_ dates: [String]) -> String {
        if let d = devotionDate, dates.contains(d) { return d }
        let today = todayISO()
        return dates.first(where: { $0 >= today }) ?? dates.last ?? today
    }

    private var shownTerm: String {
        let ts = db.termsSorted
        return ts.contains(where: { $0.id == termKey }) ? termKey : termDefault()
    }

    func canStep(_ by: Int) -> Bool {
        switch nav {
        case .today, .week: return true
        case .term:
            let ids = db.termsSorted.map { $0.id }
            guard let i = ids.firstIndex(of: shownTerm) else { return false }
            return ids.indices.contains(i + by)
        case .devotion:
            let dates = devotionDates
            guard let i = dates.firstIndex(of: shownDevotion(dates)) else { return false }
            return dates.indices.contains(i + by)
        default: return false
        }
    }

    /// Moves the screen on show one step back (-1) or forward (+1).
    func step(_ by: Int) {
        guard canStep(by) else { return }
        switch nav {
        case .today: cursor = addDays(cursor, by)
        case .week: weekMonday = addDays(shownMonday, 7 * by)
        case .term:
            let ids = db.termsSorted.map { $0.id }
            if let i = ids.firstIndex(of: shownTerm) { termKey = ids[i + by] }
        case .devotion:
            let dates = devotionDates
            if let i = dates.firstIndex(of: shownDevotion(dates)) { devotionDate = dates[i + by] }
        default: break
        }
    }

    /// Goes to Today with today's date showing.
    func goToday() {
        cursor = todayISO()
        weekMonday = nil
        nav = .today
    }

    /// The Monday of the week on show in the Week view. Weekends open the coming week.
    var shownMonday: String {
        if let m = weekMonday { return m }
        let t = todayISO()
        return dayIdx(t) >= 5 ? addDays(mondayOf(t), 7) : mondayOf(t)
    }

    func quote() -> Row? {
        let all = db.rows(.quotes)
        // Most redraws just want the quote already on show, so look for it before building a list.
        if let k = quoteKey, let q = all.first(where: { $0.s("date") == k && !$0.s("quote").isEmpty }) { return q }
        let pool = all.filter { !$0.s("quote").isEmpty }
        guard !pool.isEmpty else { return nil }
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
