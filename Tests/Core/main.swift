import Foundation

// Core tests. Foundation only, run against temporary folders, never the real data folder.
// Run with scripts/test-core.sh.

// WorkFiles.swift uses this helper, which lives in Database.swift in the app.
extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

var failures = 0
var checks = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    checks += 1
    if !ok { failures += 1; print("FAIL (line \(line)): \(what)") }
}

func r(_ pairs: KeyValuePairs<String, String>) -> Row {
    var o: Row = [:]
    for (k, v) in pairs { o[k] = v }
    return o
}

let lessonKey = RowMerge.keyColumns(for: .lessons)
func lesson(_ date: String, _ per: String, _ subject: String, _ summary: String, _ li: String = "") -> Row {
    r(["date": date, "period": per, "subject": subject, "summary": summary, "li": li])
}

// MARK: CSV

do {
    let text = "a,b\n1,\"x, y\"\n2,\"say \"\"hi\"\"\"\n"
    let p = CSV.parse(text)
    check(p.rows.count == 2 && p.rows[0]["b"] == "x, y" && p.rows[1]["b"] == "say \"hi\"", "CSV parse quotes")
    let back = CSV.parse(String(decoding: CSV.writeData(header: p.header, rows: p.rows), as: UTF8.self))
    check(back.rows == p.rows, "CSV round trip")
    check(p.rows[0].s("missing") == "", "missing column reads as empty")
}

// MARK: Row merge rules

do {
    let a = lesson("2026-11-10", "3", "Maths", "Fractions")
    let b = lesson("2026-11-11", "2", "English", "Poetry")
    let c = lesson("2026-11-12", "4", "Science", "Forces")
    let base = [a, b]

    // Only they added.
    var m = RowMerge.merge(base: base, mine: base, theirs: base + [c], key: lessonKey)
    check(m.rows.count == 3 && m.conflicts.isEmpty && m.changedFromMine, "they added a row")
    // Only I added.
    m = RowMerge.merge(base: base, mine: base + [c], theirs: base, key: lessonKey)
    check(m.rows.count == 3 && !m.changedFromMine, "I added a row")
    // Only they removed.
    m = RowMerge.merge(base: base, mine: base, theirs: [a], key: lessonKey)
    check(m.rows.count == 1 && m.rows[0]["summary"] == "Fractions", "they removed a row")
    // Only I removed.
    m = RowMerge.merge(base: base, mine: [a], theirs: base, key: lessonKey)
    check(m.rows.count == 1, "I removed a row")
    // Same change on both sides.
    var edited = a; edited["summary"] = "Decimals"
    m = RowMerge.merge(base: base, mine: [edited, b], theirs: [edited, b], key: lessonKey)
    check(m.rows.count == 2 && m.rows[0]["summary"] == "Decimals" && m.conflicts.isEmpty, "same change twice")
    // Different columns of one row.
    var mineEdit = a; mineEdit["summary"] = "Decimals"
    var theirEdit = a; theirEdit["li"] = "I can add decimals"
    m = RowMerge.merge(base: base, mine: [mineEdit, b], theirs: [theirEdit, b], key: lessonKey)
    check(m.conflicts.isEmpty && m.rows[0]["summary"] == "Decimals" && m.rows[0]["li"] == "I can add decimals", "different columns keep both")
    // Same column.
    var theirSame = a; theirSame["summary"] = "Percentages"
    m = RowMerge.merge(base: base, mine: [mineEdit, b], theirs: [theirSame, b], key: lessonKey)
    check(m.conflicts.count == 1 && m.conflicts[0].columns == ["summary"], "same column is a conflict")
    check(m.rows[0]["summary"] == "Percentages", "file keeps their version until answered")
    check(RowMerge.keepingMine(m.rows, conflicts: m.conflicts, key: lessonKey)[0]["summary"] == "Decimals", "memory keeps mine")
    // Conflict in one column, change in another: only the conflicting column goes back to mine.
    var theirBoth = a; theirBoth["summary"] = "Percentages"; theirBoth["li"] = "Their intention"
    m = RowMerge.merge(base: base, mine: [mineEdit, b], theirs: [theirBoth, b], key: lessonKey)
    let kept = RowMerge.keepingMine(m.rows, conflicts: m.conflicts, key: lessonKey)[0]
    check(kept["summary"] == "Decimals" && kept["li"] == "Their intention", "keeping mine leaves other columns merged")
    // One removed, other edited.
    m = RowMerge.merge(base: base, mine: [b], theirs: [theirEdit, b], key: lessonKey)
    check(m.rows.count == 2 && m.rows.contains { $0["li"] == "I can add decimals" }, "I removed, they edited: edited row kept")
    m = RowMerge.merge(base: base, mine: [mineEdit, b], theirs: [b], key: lessonKey)
    check(m.rows.count == 2 && m.rows.contains { $0["summary"] == "Decimals" }, "they removed, I edited: edited row kept")
    // Both removed.
    m = RowMerge.merge(base: base, mine: [b], theirs: [b], key: lessonKey)
    check(m.rows.count == 1, "both removed")
    // Both added the same key differently.
    let x1 = lesson("2026-11-13", "1", "Art", "Clay"), x2 = lesson("2026-11-13", "1", "Art", "Paint")
    m = RowMerge.merge(base: [], mine: [x1], theirs: [x2], key: lessonKey)
    check(m.conflicts.count == 1, "both added the same slot")
    // Both added a different slot.
    m = RowMerge.merge(base: [], mine: [x1], theirs: [c], key: lessonKey)
    check(m.rows.count == 2 && m.conflicts.isEmpty, "different slots both stay")
    // Duplicate keys survive.
    m = RowMerge.merge(base: [a, a], mine: [a, a], theirs: [a, a, c], key: lessonKey)
    check(m.rows.count == 3, "duplicate keys are kept")
    // Missing column counts as empty.
    var short = a; short.removeValue(forKey: "li")
    check(RowMerge.same(short, a), "missing column equals empty")
    // Keys.
    check(RowMerge.keyColumns(for: .timetable) == ["week", "day", "period"], "timetable key")
    check(RowMerge.keyColumns(for: .assessments) == ["id"], "student tables use id")
    check(RowMerge.keyColumns(for: .settings) == ["key"], "settings key")
    for t in TableName.allCases {
        let k = RowMerge.keyColumns(for: t)
        check(k.allSatisfy { t.header.contains($0) }, "key columns exist in \(t.rawValue)")
    }
}

// MARK: Schema version

do {
    check(SchemaVersion.check(stored: nil) == .needsMigration(from: 0), "no row is version 0")
    check(SchemaVersion.check(stored: "1", current: 1) == .upToDate, "up to date")
    check(SchemaVersion.check(stored: "7", current: 1) == .newerThanApp(7), "newer than the app")
    check(SchemaVersion.check(stored: "junk", current: 1) == .needsMigration(from: 0), "junk reads as 0")
}

// MARK: Folder tests

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("holocron-core-tests-" + UUID().uuidString, isDirectory: true)
let fm = FileManager.default
let studentURL = tmp.appendingPathComponent("data", isDirectory: true)
try! fm.createDirectory(at: studentURL, withIntermediateDirectories: true)
let folder = DataFolder(url: studentURL)
defer { try? fm.removeItem(at: tmp) }

do {
    // Older files load: missing columns read as empty.
    try! "date,period,subject,summary\n2026-11-10,3,Maths,Fractions\n".write(to: folder.fileURL(.lessons), atomically: true, encoding: .utf8)
    if case .ok(_, let rows) = folder.read(.lessons) {
        check(rows.count == 1 && rows[0].s("support") == "" && rows[0].s("li") == "", "older file loads")
    } else { check(false, "older file read") }

    // A file with the wrong columns is refused.
    try! "foo,bar\n1,2\n".write(to: folder.fileURL(.terms), atomically: true, encoding: .utf8)
    if case .failed = folder.read(.terms) { check(true, "wrong columns refused") } else { check(false, "wrong columns refused") }

    // UTF-16 is refused.
    try! Data([0xFF, 0xFE, 0x61, 0x00]).write(to: folder.fileURL(.quotes))
    if case .failed = folder.read(.quotes) { check(true, "UTF-16 refused") } else { check(false, "UTF-16 refused") }
}

do {
    // Save with no outside change: plain write.
    let header = TableName.lessons.header
    let base = [lesson("2026-11-10", "3", "Maths", "Fractions")]
    try! folder.write(.lessons, header: header, rows: base)
    let sig = folder.signature(.lessons)
    var mine = base; mine[0]["summary"] = "Decimals"
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    var o = folder.saveMerging(.lessons, header: header, mine: mine, base: base, expected: sig, now: t0)
    check(o.kind == .written, "plain save is written")
    check(!fm.fileExists(atPath: folder.beforeMergeURL.path), "no copy when nothing changed outside")

    // An outside edit between read and save is merged, and copied first.
    let sig2 = folder.signature(.lessons)
    let theirs = [mine[0], lesson("2026-11-11", "2", "English", "Poetry")]
    Thread.sleep(forTimeInterval: 1.1)
    try! folder.write(.lessons, header: header, rows: theirs)
    var mine2 = mine; mine2[0]["li"] = "I can order decimals"
    o = folder.saveMerging(.lessons, header: header, mine: mine2, base: mine, expected: sig2, now: t0)
    check(o.kind == .merged && o.conflicts.isEmpty, "outside change is merged")
    if case .ok(_, let disk) = folder.read(.lessons) {
        check(disk.count == 2 && disk.contains { $0["li"] == "I can order decimals" } && disk.contains { $0["subject"] == "English" }, "both sides on disk")
    }
    let copies = (try? fm.contentsOfDirectory(atPath: folder.beforeMergeURL.path)) ?? []
    check(copies.count == 1 && copies[0].hasSuffix("lessons.csv"), "file copied to Before merge")

    // A later merge is copied too, so no earlier version is lost.
    let sig3 = folder.signature(.lessons)
    Thread.sleep(forTimeInterval: 1.1)
    try! folder.write(.lessons, header: header, rows: theirs + [lesson("2026-11-12", "1", "Art", "Clay")])
    _ = folder.saveMerging(.lessons, header: header, mine: o.rows, base: o.rows, expected: sig3, now: t0.addingTimeInterval(300))
    check(((try? fm.contentsOfDirectory(atPath: folder.beforeMergeURL.path)) ?? []).count == 2, "a later merge is copied too")

    // A conflict writes theirs, keeps mine in a copy.
    let b = [lesson("2026-11-20", "1", "Maths", "Base")]
    try! folder.write(.lessons, header: header, rows: b)
    let sig4 = folder.signature(.lessons)
    Thread.sleep(forTimeInterval: 1.1)
    try! folder.write(.lessons, header: header, rows: [lesson("2026-11-20", "1", "Maths", "Theirs")])
    o = folder.saveMerging(.lessons, header: header, mine: [lesson("2026-11-20", "1", "Maths", "Mine")], base: b, expected: sig4, now: t0.addingTimeInterval(900))
    check(o.kind == .merged && o.conflicts.count == 1, "conflict reported")
    if case .ok(_, let disk) = folder.read(.lessons) { check(disk[0]["summary"] == "Theirs", "file keeps their version") }
    let all = (try? fm.contentsOfDirectory(atPath: folder.beforeMergeURL.path)) ?? []
    check(all.contains { $0.contains("(mine)") }, "my side kept in a copy")

    // A file that cannot be read is not written.
    let sig5 = folder.signature(.lessons)
    Thread.sleep(forTimeInterval: 1.1)
    try! Data([0xFF, 0xFE, 0x61, 0x00]).write(to: folder.fileURL(.lessons))
    let before = try! Data(contentsOf: folder.fileURL(.lessons))
    o = folder.saveMerging(.lessons, header: header, mine: [lesson("2026-11-20", "1", "Maths", "Mine")], base: b, expected: sig5)
    if case .blocked = o.kind { check(true, "unreadable file blocks save") } else { check(false, "unreadable file blocks save") }
    check((try! Data(contentsOf: folder.fileURL(.lessons))) == before, "unreadable file untouched")
}

do {
    // Conflict copies made by iCloud are found, and the planner file itself is not one.
    try! "date,label\n".write(to: studentURL.appendingPathComponent("nonteaching 2.csv"), atomically: true, encoding: .utf8)
    try! "date,label\n".write(to: studentURL.appendingPathComponent("nonteaching.csv"), atomically: true, encoding: .utf8)
    try! "x\n".write(to: studentURL.appendingPathComponent("nonteaching notes.csv"), atomically: true, encoding: .utf8)
    let found = folder.conflictCopies(of: .nonteaching)
    check(found.count == 1 && found[0].lastPathComponent == "nonteaching 2.csv", "iCloud conflict copy found")
}

do {
    // Migration copies settings first, and a run with nothing to do changes nothing.
    try! "key,value\nclass_name,Test\n".write(to: folder.fileURL(.settings), atomically: true, encoding: .utf8)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    if case .done(let v, let archive) = folder.migrate(from: 0, now: now) {
        check(v == 1, "migrates to 1")
        let files = (try? fm.contentsOfDirectory(atPath: archive?.path ?? "")) ?? []
        check(files == ["settings.csv"], "settings copied before migration")
    } else { check(false, "migration ran") }
    if case .done(let v, let archive) = folder.migrate(from: 1, now: now) { check(v == 1 && archive == nil, "nothing to do at current version") }

    // A step that rewrites a table is copied first and applied.
    let step = SchemaVersion.Step(to: 2, name: "Test", tables: [.nonteaching], transform: { _, rows in rows.map { var x = $0; x["label"] = "changed"; return x } })
    try! "date,label\n2026-01-01,Holiday\n".write(to: folder.fileURL(.nonteaching), atomically: true, encoding: .utf8)
    if case .done(let v, let archive) = folder.migrate(from: 1, steps: [step], now: now) {
        check(v == 2, "custom step version")
        let kept = try? String(contentsOf: archive!.appendingPathComponent("nonteaching.csv"), encoding: .utf8)
        check(kept?.contains("Holiday") == true, "original kept before migration")
        if case .ok(_, let rows) = folder.read(.nonteaching) { check(rows[0]["label"] == "changed", "step applied") }
    } else { check(false, "custom migration ran") }
}

// MARK: Markbook and report board

do {
    check(Markbook.percent("18/20") == 90, "score as percent")
    check(Markbook.percent("85%") == 85, "percent sign")
    check(Markbook.percent("Mastering") == 80, "level as percent")
    check(Markbook.percent("Modified") == nil && Markbook.percent("") == nil && Markbook.percent("well done") == nil, "no number")
    check(Markbook.band("Extending") == .top && Markbook.band("Modified") == .modified, "level bands")
    check(Markbook.band("9/20") == .developing && Markbook.band("19/20") == .top && Markbook.band("2/10") == .low, "score bands")
    check(Markbook.band("") == nil, "blank has no band")

    func a(_ sid: String, _ date: String, _ task: String, _ res: String, subject: String = "Maths") -> Row {
        r(["id": sid + date + task, "student_id": sid, "date": date, "subject": subject, "task": task, "result": res])
    }
    let rows = [
        a("s1", "2026-02-10", "Fractions pre-test", "8/20"), a("s2", "2026-02-10", "Fractions pre-test", "10/20"),
        a("s1", "2026-03-20", "Fractions post-test", "16/20"),
        a("s1", "2026-03-01", "Measurement", "Mastering"),
        a("s1", "2026-03-01", "Reading", "Extending", subject: "English"),
    ]
    let grid = Markbook.build(assessments: rows, students: ["s1", "s2", "s3"], subject: "Maths")
    check(grid.tasks.map(\.task) == ["Fractions pre-test", "Measurement", "Fractions post-test"], "tasks in date order, subject only")
    check(grid.lines.count == 3 && grid.lines[2].results.isEmpty, "every student has a line")
    check(grid.pairs.count == 1 && grid.pairs[0].base == "fractions", "pre and post paired")
    check(Markbook.growth(grid.pairs[0], grid.lines[0]) == 40, "growth in points")
    check(Markbook.growth(grid.pairs[0], grid.lines[1]) == nil, "no growth without a post result")
    check(Markbook.missing(grid, task: grid.tasks[2]) == ["s2", "s3"], "missing results listed")
    check(Markbook.average(grid.lines[0], tasks: grid.tasks) == (40 + 80 + 80) / 3, "average")
    check(Markbook.growthText(40) == "+40 points" && Markbook.growthText(-5) == "-5 points", "growth text")
    let csvText = String(decoding: Markbook.csv(grid, names: ["s1": "Student One", "s2": "Student Two", "s3": "Student Three"]), as: UTF8.self)
    let parsed = CSV.parse(csvText)
    check(parsed.rows.count == 3 && parsed.header.first == "Student" && parsed.header.last == "Growth: fractions", "csv shape")
    check(Markbook.points(assessments: rows, student: "s1").count == 4, "chart points skip other words")

    check(ReportBoard.generalStatus("") == .none, "empty comment")
    check(ReportBoard.generalStatus(String(repeating: "word ", count: 120)) == .ready, "120 words ready")
    check(ReportBoard.generalStatus(String(repeating: "word ", count: 80)) == .draft, "80 words draft")
    check(ReportBoard.generalStatus(String(repeating: "word ", count: 151)) == .draft, "151 words draft")
    let pts = (1...8).map { "- point \($0)" }.joined(separator: "\n")
    check(ReportBoard.pointCount(pts) == 8 && ReportBoard.pointsStatus(pts) == .ready, "points ready")
    check(ReportBoard.pointsStatus("- one\n- two") == .draft, "few points draft")
    check(ReportBoard.judged(["a", "b", "c"], achievement: { $0 == "b" ? "Mastering" : "" }) == 1, "judged count")
}

// MARK: Subject colours

do {
    check(SubjectColours.palette.count == 12, "twelve subject colours")
    for c in SubjectColours.palette {
        let t = ToneMaths.tone(hex: c.hex)
        let tint = ToneMaths.mix(RGB(255, 255, 255), t.bar, 0.16)
        check(ToneMaths.contrast(t.ink, tint) >= 5, "\(c.name) text reaches 5:1 on its tint")
        // The name must still look like the colour, not black.
        check(ToneMaths.contrast(t.ink, RGB(0, 0, 0)) >= 1.3 || c.name == "Grey", "\(c.name) text keeps some colour")
    }
    for (i, a) in SubjectColours.palette.enumerated() {
        for b in SubjectColours.palette[(i + 1)...] {
            let x = RGB(hex: a.hex), y = RGB(hex: b.hex)
            let d = abs(x.r - y.r) + abs(x.g - y.g) + abs(x.b - y.b)
            check(d >= 70, "\(a.name) and \(b.name) are apart")
        }
    }
    // Every colour the starter subjects use is readable too.
    for (_, hex) in [("x", "#A2845E"), ("y", "#64D2FF")] { check(ToneMaths.contrast(ToneMaths.tone(hex: hex).ink, ToneMaths.mix(RGB(255, 255, 255), RGB(hex: hex), 0.16)) >= 5, "starter colour \(hex) readable") }
}

// MARK: Groups

do {
    let students = (1...9).map { "s\($0)" }
    var g = Grouping.random(students, groups: 3, seed: 7)
    check(g.count == 3 && g.allSatisfy { $0.count == 3 }, "random groups are even")
    check(Set(g.flatMap { $0 }) == Set(students), "random groups hold everyone once")
    let scores: [String: Double] = ["s1": 95, "s2": 90, "s3": 85, "s4": 60, "s5": 55, "s6": 50, "s7": 20, "s8": 15, "s9": 10]
    g = Grouping.mixed(students, groups: 3, score: { scores[$0] })
    check(g.allSatisfy { grp in Set(grp).intersection(["s1", "s2", "s3"]).count == 1 }, "mixed groups hold one high result each")
    check(Set(g.flatMap { $0 }) == Set(students), "mixed groups hold everyone once")
    g = Grouping.mixed(students, groups: 2, score: { _ in nil })
    check(g.count == 2 && g.flatMap { $0 }.count == 9, "mixed with no results still places everyone")
    check(Grouping.ids("a;b; c;;") == ["a", "b", "c"] && Grouping.join(["a", "b"]) == "a;b", "group id list")
    check(Grouping.sizes(total: 10, groups: 3) == [4, 3, 3], "uneven sizes")
}

print(failures == 0 ? "All \(checks) checks passed." : "\(failures) of \(checks) checks failed.")
exit(failures == 0 ? 0 : 1)
