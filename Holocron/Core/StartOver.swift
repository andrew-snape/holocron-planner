import Foundation

/// How much a Start over clears.
enum StartOverScope: String, CaseIterable, Identifiable {
    /// Every file in the student folder, including photos and settings, plus the planner.
    case everything
    /// Only the planner tables (timetable, lessons, terms, subjects and so on). Students,
    /// hours, reports and settings stay.
    case plannerOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: return "Everything"
        case .plannerOnly: return "Planner only"
        }
    }
}

/// What a Start over will do. Nothing is ever deleted: the current files are moved into a dated
/// archive folder beside the data folder, and the app then begins again with the starter day.
struct StartOverPlan {
    struct Move: Equatable {
        var from: URL
        var to: URL
    }

    /// The new archive folder, for example ".../Holocron/Holocron archive/Start over 2026-10-14 15.32".
    var archive: URL
    var moves: [Move]
    /// True when the planner folder is a separate (often shared) folder. It is disconnected,
    /// never cleared, so colleagues keep their planner.
    var disconnectsSharedPlanner: Bool

    var isEmpty: Bool { moves.isEmpty && !disconnectsSharedPlanner }
}

extension DataFolder {
    /// The folder that holds every Start over archive: "Holocron archive" beside the student folder.
    var archiveRoot: URL {
        url.deletingLastPathComponent().appendingPathComponent("Holocron archive", isDirectory: true)
    }

    /// Works out which files a Start over moves, without touching anything.
    func startOverPlan(_ scope: StartOverScope, now: Date = Date(), calendar: Calendar = .current) -> StartOverPlan {
        let fm = FileManager.default
        let archive = StartOverPlan.uniqueFolder(in: archiveRoot, named: "Start over " + StartOverPlan.stamp(now, calendar), fm: fm)
        let shared = plannerURL != nil
        var moves: [StartOverPlan.Move] = []

        for t in TableName.allCases {
            let clears: Bool
            switch scope {
            case .everything: clears = true
            case .plannerOnly: clears = t.isPlanner
            }
            // A shared planner folder is only ever disconnected, never emptied.
            guard clears, !(t.isPlanner && shared) else { continue }
            let root = root(for: t)
            for name in [t.rawValue + ".csv", "." + t.rawValue + ".csv.icloud"] {
                let f = root.appendingPathComponent(name)
                if fm.fileExists(atPath: f.path) {
                    moves.append(.init(from: f, to: archive.appendingPathComponent(name)))
                }
            }
        }
        if scope == .everything, DataFolder.isDirectory(photosURL) {
            moves.append(.init(from: photosURL, to: archive.appendingPathComponent("photos", isDirectory: true)))
        }
        return StartOverPlan(archive: archive, moves: moves, disconnectsSharedPlanner: shared)
    }
}

extension StartOverPlan {
    enum Failure: Error, Equatable {
        case archiveNotCreated(String)
        /// A file could not be moved. Everything already moved was put back.
        case moveFailed(String)
    }

    /// Moves the files into the archive. If any move fails, the files already moved are put back,
    /// so the data folder is either fully archived or left exactly as it was.
    func carryOut(fm: FileManager = .default) -> Result<Int, Failure> {
        guard !moves.isEmpty else { return .success(0) }
        do {
            try fm.createDirectory(at: archive, withIntermediateDirectories: true)
        } catch {
            return .failure(.archiveNotCreated(archive.path))
        }
        var done: [Move] = []
        for m in moves {
            do {
                try fm.moveItem(at: m.from, to: m.to)
                done.append(m)
            } catch {
                for d in done.reversed() { try? fm.moveItem(at: d.to, to: d.from) }
                // Tidy away the archive folder only when nothing is left in it. If a file could not
                // be put back, it stays safely in the archive.
                if let left = try? fm.contentsOfDirectory(atPath: archive.path), left.isEmpty {
                    try? fm.removeItem(at: archive)
                }
                return .failure(.moveFailed(m.from.lastPathComponent))
            }
        }
        return .success(done.count)
    }

    /// "2026-10-14 15.32", which sorts in date order in Finder. Colons are not used in file names on a Mac.
    static func stamp(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        func two(_ n: Int?) -> String { let v = n ?? 0; return v < 10 ? "0\(v)" : String(v) }
        return "\(c.year ?? 2000)-\(two(c.month))-\(two(c.day)) \(two(c.hour)).\(two(c.minute))"
    }

    /// The folder name, or the name with " 2", " 3" and so on when it is already taken.
    static func uniqueFolder(in parent: URL, named base: String, fm: FileManager) -> URL {
        var candidate = parent.appendingPathComponent(base, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(base) \(n)", isDirectory: true)
            n += 1
        }
        return candidate
    }
}
