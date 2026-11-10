import Foundation

/// What happened when one table was saved.
struct SaveOutcome {
    enum Kind: Equatable {
        /// Written as it was. The file had not changed since it was last read or written.
        case written
        /// The file had changed, so it was read again and merged with the rows in memory before writing.
        case merged
        /// The file could not be read or was changing, so nothing was written. The changes stay in memory.
        case blocked(String)
        /// The write itself failed.
        case failed
    }
    var table: TableName
    var kind: Kind
    /// The rows now in the file. For `merged` this is the merge, with their version where there is a conflict.
    var rows: [Row]
    var conflicts: [RowMerge.Conflict] = []
    var signature: DataFolder.Signature?
    /// For `merged`: false when the merge left my rows exactly as they were, so nothing on screen changes.
    var changed = true
}

extension DataFolder {
    /// Saves a table without overwriting changes made to its file since it was last read or written.
    ///
    /// `expected` is the file's signature at that time. If the file on disk still matches, this writes as
    /// always. If not, the file is copied into "Before merge" (once a day), read again and merged three ways
    /// with `base` (the rows as last seen) and `mine`, then written. If the file changes again while merging,
    /// it is merged once more. A file that cannot be read is never written.
    func saveMerging(_ t: TableName, header: [String], mine: [Row], base: [Row]?, expected: Signature?,
                     now: Date = Date(), calendar: Calendar = .current) -> SaveOutcome {
        var tries = 0
        while tries < 3 {
            tries += 1
            let seen = signature(t)
            if seen == nil, expected != nil, case .failed(let msg) = read(t) {
                // The file was there and is not now. It may be an iCloud placeholder that is still downloading.
                return SaveOutcome(table: t, kind: .blocked(msg), rows: mine)
            }
            if seen == nil || seen == expected {
                do {
                    try write(t, header: header, rows: mine)
                    return SaveOutcome(table: t, kind: .written, rows: mine, signature: signature(t))
                } catch {
                    return SaveOutcome(table: t, kind: .failed, rows: mine)
                }
            }
            // The file is not what Holocron last saw.
            guard copyBeforeMerge(t, now: now, calendar: calendar) else {
                return SaveOutcome(table: t, kind: .blocked("A safety copy of \(t.rawValue).csv could not be made in Holocron archive, so it was not saved yet."), rows: mine)
            }
            switch read(t) {
            case .failed(let msg):
                return SaveOutcome(table: t, kind: .blocked(msg), rows: mine)
            case .missing:
                continue
            case .ok(_, let theirs):
                // With no base to compare with, every row counts as added, so differences are asked about.
                let result = RowMerge.merge(base: base ?? [], mine: mine, theirs: theirs, key: RowMerge.keyColumns(for: t))
                guard signature(t) == seen else { continue }   // changed while merging, so merge again
                // With a conflict, my side must be on disk before their version is written over it.
                if !result.conflicts.isEmpty,
                   !saveMineSnapshot(t, header: header, mine: mine, now: now, calendar: calendar) {
                    return SaveOutcome(table: t, kind: .blocked("A copy of your changes to \(t.rawValue).csv could not be made in Holocron archive, so it was not saved yet."), rows: mine)
                }
                do {
                    try write(t, header: header, rows: result.rows)
                    return SaveOutcome(table: t, kind: .merged, rows: result.rows, conflicts: result.conflicts, signature: signature(t), changed: result.changedFromMine)
                } catch {
                    return SaveOutcome(table: t, kind: .failed, rows: mine)
                }
            }
        }
        return SaveOutcome(table: t, kind: .blocked("\(t.rawValue).csv kept changing while it was saved, so it was not saved yet."), rows: mine)
    }

    /// Keeps a copy of my rows beside the other copies when there is a conflict, so my side survives even
    /// if Holocron is closed before the question is answered.
    @discardableResult
    func saveMineSnapshot(_ t: TableName, header: [String], mine: [Row], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let fm = FileManager.default
        do { try fm.createDirectory(at: beforeMergeURL, withIntermediateDirectories: true) } catch { return false }
        let stamp = StartOverPlan.stamp(now, calendar)
        var dst = beforeMergeURL.appendingPathComponent("\(stamp) \(t.rawValue) (mine).csv")
        var n = 2
        while fm.fileExists(atPath: dst.path) {
            dst = beforeMergeURL.appendingPathComponent("\(stamp) \(t.rawValue) (mine) \(n).csv")
            n += 1
        }
        do {
            try CSV.writeData(header: header, rows: mine).write(to: dst, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Other copies of a table's file that iCloud made when two Macs saved at once, such as "lessons 2.csv".
    func conflictCopies(of t: TableName) -> [URL] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: root(for: t).path) else { return [] }
        let prefix = t.rawValue + " "
        return names.filter { n in
            guard n.hasPrefix(prefix), n.hasSuffix(".csv") else { return false }
            let mid = n.dropFirst(prefix.count).dropLast(4)
            return !mid.isEmpty && mid.allSatisfy(\.isNumber)
        }.sorted().map { root(for: t).appendingPathComponent($0) }
    }
}

extension RowMerge {
    /// The merged rows with my version put back where there was a conflict, for the screen to show
    /// until the question is answered.
    static func keepingMine(_ rows: [Row], conflicts: [Conflict], key: [String]) -> [Row] {
        guard !conflicts.isEmpty else { return rows }
        let byKey = Dictionary(conflicts.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var seen: [String: Int] = [:]
        return rows.map { r in
            let base = key.map { r.s($0) }.joined(separator: "\u{1F}")
            let n = seen[base, default: 0]
            seen[base] = n + 1
            guard let c = byKey[n == 0 ? base : base + "#\(n)"], let mine = c.mine else { return r }
            // Only the columns both sides changed go back to mine. Everything else stays merged.
            var row = r
            for col in c.columns { row[col] = mine.s(col) }
            return row
        }
    }
}

/// One thing you and the shared folder both changed, waiting for a choice.
struct MergeItem: Identifiable {
    var table: TableName
    var conflict: RowMerge.Conflict
    var id: String { table.rawValue + "|" + conflict.key }
}

/// A copy of a file that iCloud made when two Macs saved at once, such as "lessons 2.csv".
struct ConflictCopy: Identifiable, Equatable {
    var table: TableName
    var url: URL
    var size: Int
    var id: String { url.path }
}

/// What the save queue last wrote for each table. Read and written only on that queue (and cleared on load).
final class SaveMemo: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [TableName: (rows: [Row], signature: DataFolder.Signature?)] = [:]
    func get(_ t: TableName) -> (rows: [Row], signature: DataFolder.Signature?)? { lock.lock(); defer { lock.unlock() }; return store[t] }
    func set(_ t: TableName, rows: [Row], signature: DataFolder.Signature?) { lock.lock(); store[t] = (rows, signature); lock.unlock() }
    func clear() { lock.lock(); store.removeAll(); lock.unlock() }
}
