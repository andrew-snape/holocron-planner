import Foundation

/// Making groups of students. Foundation only, so it can be tested on its own.
/// A group's students are kept in groups.csv as ids joined with semicolons.
enum Grouping {
    static func ids(_ text: String) -> [String] {
        text.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func join(_ ids: [String]) -> String { ids.joined(separator: ";") }

    /// How many students go in each group when `total` students are shared as evenly as possible.
    /// The first groups take the extra students.
    static func sizes(total: Int, groups: Int) -> [Int] {
        let g = max(1, groups)
        return (0..<g).map { total / g + ($0 < total % g ? 1 : 0) }
    }

    /// A small seeded generator, so a shuffle can be repeated in a test.
    private struct Mixer: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// Students shuffled and shared out evenly.
    static func random(_ ids: [String], groups: Int, seed: UInt64? = nil) -> [[String]] {
        var mixed = ids
        if let seed {
            var g = Mixer(state: seed)
            mixed.shuffle(using: &g)
        } else {
            mixed.shuffle()
        }
        var out: [[String]] = []
        var i = 0
        for n in sizes(total: mixed.count, groups: groups) {
            out.append(Array(mixed[i..<(i + n)]))
            i += n
        }
        return out
    }

    /// Groups that each hold a spread of results. Students are ranked from highest to lowest and dealt out
    /// in a snake (1, 2, 3, then 3, 2, 1), so no group gets all the top results. Students with no result
    /// are dealt last, in the order given.
    static func mixed(_ ids: [String], groups: Int, score: (String) -> Double?) -> [[String]] {
        let g = max(1, groups)
        let scored = ids.enumerated().compactMap { i, id in score(id).map { (i, id, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }.map(\.1)
        let scoredSet = Set(scored)
        let order = scored + ids.filter { !scoredSet.contains($0) }
        var out = Array(repeating: [String](), count: g)
        for (i, id) in order.enumerated() {
            let round = i / g, pos = i % g
            out[round % 2 == 0 ? pos : g - 1 - pos].append(id)
        }
        return out
    }
}
