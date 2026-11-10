import Foundation

/// Three-way merge of a table, row by row. Foundation only, so it can be tested on its own.
///
/// `base` is the rows as Holocron last read or wrote them, `mine` is what is in memory now, and
/// `theirs` is what is in the file on disk now (a colleague, a hand edit or an AI assistant changed it).
/// Rows are matched by a key, which `RowMerge.keyColumns(for:)` gives for each table.
enum RowMerge {
    /// A row both sides changed in the same column. The merged rows carry their value for these columns.
    struct Conflict: Equatable {
        var key: String
        var columns: [String]
        var base: Row?
        var mine: Row?
        var theirs: Row?
    }

    struct Result {
        /// The rows to write. Where there is a conflict the file keeps their version until it is answered.
        var rows: [Row]
        var conflicts: [Conflict]
        /// True when the merged rows differ from `mine`, so what is on screen needs updating.
        var changedFromMine: Bool
    }

    /// The columns that identify a row in each table.
    static func keyColumns(for t: TableName) -> [String] {
        switch t {
        case .lessons, .lessonsprivate: return ["date", "period", "subject"]
        case .timetable: return ["week", "day", "period"]
        case .dayplan: return ["date", "period"]
        case .subjects: return ["subject"]
        case .periods: return ["period"]
        case .terms: return ["year", "term"]
        case .nonteaching, .dayoverrides, .devotion, .quotes: return ["date"]
        case .rubrics: return ["rubric", "element", "level"]
        case .classsteps: return ["date", "period"]
        case .settings: return ["key"]
        default: return ["id"]
        }
    }

    /// Two rows are the same when every column matches. A column a row does not have counts as empty.
    static func same(_ a: Row, _ b: Row) -> Bool {
        if a.count == b.count, a == b { return true }
        for k in Set(a.keys).union(b.keys) where a.s(k) != b.s(k) { return false }
        return true
    }

    /// Rows by key. A key used twice gets a number after it ("k", "k#1"), so repeated rows are kept.
    private static func keyed(_ rows: [Row], key: [String]) -> (order: [String], byKey: [String: Row]) {
        var order: [String] = []
        var by: [String: Row] = [:]
        var seen: [String: Int] = [:]
        for r in rows {
            let base = key.map { r.s($0) }.joined(separator: "\u{1F}")
            let n = seen[base, default: 0]
            seen[base] = n + 1
            let k = n == 0 ? base : base + "#\(n)"
            order.append(k)
            by[k] = r
        }
        return (order, by)
    }

    static func merge(base: [Row], mine: [Row], theirs: [Row], key: [String]) -> Result {
        let b = keyed(base, key: key)
        let m = keyed(mine, key: key)
        let t = keyed(theirs, key: key)
        var out: [Row] = []
        var conflicts: [Conflict] = []

        // Mine first in my order, then the rows only they have, in their order.
        var keys = m.order
        let mineSet = Set(m.order)
        keys += t.order.filter { !mineSet.contains($0) }
        keys += b.order.filter { !mineSet.contains($0) && t.byKey[$0] == nil }   // removed by both, dropped below

        for k in keys {
            let bv = b.byKey[k], mv = m.byKey[k], tv = t.byKey[k]
            switch (bv, mv, tv) {
            case (nil, nil, nil):
                break
            case (nil, nil, let t?):
                out.append(t)
            case (nil, let m?, nil):
                out.append(m)
            case (nil, let m?, let t?):
                out.append(columns(base: [:], mine: m, theirs: t, key: k, original: (nil, m, t), conflicts: &conflicts))
            case (let b?, nil, nil):
                _ = b
            case (let b?, nil, let t?):
                // I removed it. If they left it alone it stays removed, and if they edited it, it stays.
                if !same(b, t) { out.append(t) }
            case (let b?, let m?, nil):
                if !same(b, m) { out.append(m) }
            case (let b?, let m?, let t?):
                if same(m, t) { out.append(m) }
                else if same(m, b) { out.append(t) }
                else if same(t, b) { out.append(m) }
                else { out.append(columns(base: b, mine: m, theirs: t, key: k, original: (b, m, t), conflicts: &conflicts)) }
            }
        }
        let changed = out.count != mine.count || zip(out, mine).contains { !same($0, $1) }
        return Result(rows: out, conflicts: conflicts, changedFromMine: changed)
    }

    /// Both changed a row. Columns changed by one side keep that change, and a column both changed to
    /// different values is a conflict, where the file keeps their value.
    private static func columns(base: Row, mine: Row, theirs: Row, key: String,
                                original: (Row?, Row?, Row?), conflicts: inout [Conflict]) -> Row {
        var merged = theirs
        var bad: [String] = []
        let cols = Set(base.keys).union(mine.keys).union(theirs.keys)
        for c in cols.sorted() {
            let bv = base.s(c), mv = mine.s(c), tv = theirs.s(c)
            if mv == tv { merged[c] = mv }
            else if mv == bv { merged[c] = tv }
            else if tv == bv { merged[c] = mv }
            else { bad.append(c); merged[c] = tv }
        }
        if !bad.isEmpty {
            conflicts.append(Conflict(key: key, columns: bad, base: original.0, mine: original.1, theirs: original.2))
        }
        return merged
    }
}
