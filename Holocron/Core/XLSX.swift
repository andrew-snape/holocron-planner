import Foundation
import Compression

// MARK: - Reading the first sheet of an Excel workbook
//
// An .xlsx file is a zip archive of XML files. Holocron only needs the cell text of the first
// sheet, so this reads the zip directory, inflates the few files it needs with the Compression
// framework and pulls out the values. Formulas give their last saved value. Nothing is written.

enum XLSX {
    enum Failure: Error, Equatable {
        case notAWorkbook
        case unsupported(String)
    }

    /// The first sheet as rows of cell text. Empty cells are "", and short rows are not padded.
    static func firstSheet(_ data: Data) throws -> [[String]] {
        let zip = try Zip(data)
        let shared = try zip.file("xl/sharedStrings.xml").map(sharedStrings) ?? []
        guard let path = firstSheetPath(zip), let sheet = try zip.file(path) else { throw Failure.notAWorkbook }
        return cells(sheet, shared: shared)
    }

    /// The first sheet listed in the workbook, else the first worksheet file in the archive.
    private static func firstSheetPath(_ zip: Zip) -> String? {
        if let wb = try? zip.file("xl/workbook.xml"), let rels = try? zip.file("xl/_rels/workbook.xml.rels") {
            let sheets = XMLScan(wb).elements("sheet")
            let links = XMLScan(rels).elements("Relationship")
            if let rid = sheets.first?["r:id"], let target = links.first(where: { $0["Id"] == rid })?["Target"] {
                let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
                // Resolve "xl/../xl/worksheets/sheet1.xml" and the like.
                var parts: [Substring] = []
                for p in path.split(separator: "/") {
                    if p == ".." { _ = parts.popLast() } else if p != "." { parts.append(p) }
                }
                return parts.joined(separator: "/")
            }
        }
        return zip.names.filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }.first
    }

    private static func sharedStrings(_ xml: Data) -> [String] {
        let d = SharedStringsDelegate()
        let p = XMLParser(data: xml)
        p.delegate = d
        p.parse()
        return d.strings
    }

    private static func cells(_ xml: Data, shared: [String]) -> [[String]] {
        let d = SheetDelegate(shared: shared)
        let p = XMLParser(data: xml)
        p.delegate = d
        p.parse()
        return d.rows
    }

    /// The zero-based column of a cell reference such as "AB12".
    static func column(_ ref: String) -> Int? {
        var n = 0, seen = false
        for ch in ref.uppercased() {
            guard let a = ch.asciiValue, a >= 65, a <= 90 else { break }
            n = n * 26 + Int(a - 64)
            seen = true
            if n > 1_000_000 { return nil }
        }
        return seen ? n - 1 : nil
    }
}

// MARK: Zip

private struct Zip {
    private struct Entry { var method: UInt16; var compressed: Int; var size: Int; var offset: Int }
    private let data: Data
    private var entries: [String: Entry] = [:]
    var names: [String] { Array(entries.keys) }

    /// Larger than any spreadsheet a teacher would export, and small enough to stay safe.
    private static let limit = 200 * 1024 * 1024

    init(_ data: Data) throws {
        self.data = data
        let bytes = [UInt8](data)
        func u16(_ i: Int) -> Int { i + 1 < bytes.count ? Int(bytes[i]) | Int(bytes[i + 1]) << 8 : 0 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }

        // The end of central directory record sits in the last 64 KB.
        var eocd: Int? = nil
        var i = bytes.count - 22
        while i >= max(0, bytes.count - 65_557) {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard let e = eocd else { throw XLSX.Failure.notAWorkbook }
        let count = u16(e + 10)
        var p = u32(e + 16)
        for _ in 0..<count {
            guard p + 46 <= bytes.count, u32(p) == 0x02014b50 else { throw XLSX.Failure.notAWorkbook }
            let nameLen = u16(p + 28), extra = u16(p + 30), comment = u16(p + 32)
            guard p + 46 + nameLen <= bytes.count else { throw XLSX.Failure.notAWorkbook }
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nameLen)], as: UTF8.self)
            let entry = Entry(method: UInt16(u16(p + 10)), compressed: u32(p + 20), size: u32(p + 24), offset: u32(p + 42))
            if entry.compressed == 0xFFFF_FFFF || entry.size == 0xFFFF_FFFF {
                throw XLSX.Failure.unsupported("This workbook is too large to read.")
            }
            entries[name] = entry
            p += 46 + nameLen + extra + comment
        }
    }

    /// The unpacked file, or nil when the archive has no file of that name.
    func file(_ name: String) throws -> Data? {
        guard let e = entries[name] else { return nil }
        let bytes = data
        func u16(_ i: Int) -> Int { Int(bytes[bytes.startIndex + i]) | Int(bytes[bytes.startIndex + i + 1]) << 8 }
        guard e.offset + 30 <= bytes.count else { throw XLSX.Failure.notAWorkbook }
        let start = e.offset + 30 + u16(e.offset + 26) + u16(e.offset + 28)
        guard start + e.compressed <= bytes.count, e.size <= Zip.limit else { throw XLSX.Failure.notAWorkbook }
        let packed = bytes.subdata(in: (bytes.startIndex + start)..<(bytes.startIndex + start + e.compressed))
        switch e.method {
        case 0:
            return packed
        case 8:
            if e.size == 0 { return Data() }
            guard !packed.isEmpty else { throw XLSX.Failure.notAWorkbook }
            var out = Data(count: e.size)
            let n = out.withUnsafeMutableBytes { dst in
                packed.withUnsafeBytes { src in
                    compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, e.size,
                                              src.bindMemory(to: UInt8.self).baseAddress!, packed.count,
                                              nil, COMPRESSION_ZLIB)
                }
            }
            guard n == e.size else { throw XLSX.Failure.notAWorkbook }
            return out
        default:
            throw XLSX.Failure.unsupported("This workbook uses a kind of compression Holocron cannot read.")
        }
    }
}

// MARK: XML

/// The attributes of every element with a given name, for small files such as the workbook list.
private struct XMLScan {
    var data: Data
    init(_ data: Data) { self.data = data }

    func elements(_ name: String) -> [[String: String]] {
        final class D: NSObject, XMLParserDelegate {
            var name = ""
            var found: [[String: String]] = []
            func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                        qualifiedName q: String?, attributes a: [String: String] = [:]) {
                if e == name || q == name { found.append(a) }
            }
        }
        let d = D()
        d.name = name
        let p = XMLParser(data: data)
        p.delegate = d
        p.parse()
        return d.found
    }
}

private final class SharedStringsDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inText = false
    /// Phonetic guides (rPh) repeat the text in another script, so they are left out.
    private var inPhonetic = false

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName q: String?, attributes a: [String: String] = [:]) {
        switch e {
        case "si": current = ""
        case "t": inText = !inPhonetic
        case "rPh": inPhonetic = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inText { current += s }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName q: String?) {
        switch e {
        case "si": strings.append(current)
        case "t": inText = false
        case "rPh": inPhonetic = false
        default: break
        }
    }
}

private final class SheetDelegate: NSObject, XMLParserDelegate {
    /// Excel's own limits. A file claiming more is damaged, and is not padded out to that size.
    static let maxRows = 1_048_576, maxColumns = 16_384
    let shared: [String]
    var rows: [[String]] = []
    private var row: [String] = []
    private var rowIndex = -1
    private var col = 0
    private var type = ""
    private var value = ""
    private var inValue = false

    init(shared: [String]) { self.shared = shared }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName q: String?, attributes a: [String: String] = [:]) {
        switch e {
        case "row":
            row = []
            // Rows can be missing from the file when they are empty, so keep their place.
            let r = (a["r"].flatMap { Int($0) } ?? rowIndex + 2) - 1
            // Rows are kept in file order. A row number that goes backwards or jumps past Excel's
            // limit is placed straight after the last row instead.
            rowIndex = (r > rowIndex && r < SheetDelegate.maxRows) ? r : rowIndex + 1
            while rows.count < rowIndex { rows.append([]) }
        case "c":
            col = a["r"].flatMap(XLSX.column) ?? row.count
            if col >= SheetDelegate.maxColumns { col = -1 }
            type = a["t"] ?? ""
            value = ""
        case "v", "t":
            inValue = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inValue { value += s }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName q: String?) {
        switch e {
        case "v", "t":
            inValue = false
        case "c":
            var text = value
            switch type {
            case "s": text = Int(value).flatMap { $0 >= 0 && $0 < shared.count ? shared[$0] : nil } ?? ""
            case "b": text = value == "1" ? "TRUE" : "FALSE"
            default: break
            }
            guard col >= 0 else { break }
            while row.count < col { row.append("") }
            if row.count == col { row.append(text) } else { row[col] = text }
        case "row":
            if rowIndex < rows.count { rows[rowIndex] = row } else { rows.append(row) }
        default:
            break
        }
    }
}
