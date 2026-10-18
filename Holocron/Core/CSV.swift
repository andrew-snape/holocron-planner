import Foundation

typealias Row = [String: String]

extension Dictionary where Key == String, Value == String {
    /// Value for a column, or "" when the column is missing.
    func s(_ k: String) -> String { self[k] ?? "" }
}

enum CSV {
    /// Parses CSV text. Quoted fields may contain commas, quotes ("") and line breaks.
    /// Returns the header (trimmed) and the rows. Rows where every field is empty are dropped.
    ///
    /// Works on the UTF-8 bytes. Every character the format cares about (comma, quote, line
    /// break) is a single ASCII byte that cannot appear inside another character's encoding, so
    /// the result is the same as reading character by character, only much faster.
    static func parse(_ text: String) -> (header: [String], rows: [Row]) {
        var text = text
        return text.withUTF8 { parseBytes($0) }
    }

    private static func parseBytes(_ b: UnsafeBufferPointer<UInt8>) -> (header: [String], rows: [Row]) {
        var header: [String]? = nil
        var rows: [Row] = []
        var row: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var hasContent = false
        var i = 0
        let n = b.count
        if n >= 3, b[0] == 0xEF, b[1] == 0xBB, b[2] == 0xBF { i = 3 }   // byte order mark

        func endField() {
            row.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }

        func endRecord() {
            if header == nil {
                header = row.map { $0.trimmingCharacters(in: .whitespaces) }
            } else if let h = header, row.contains(where: { !$0.isEmpty }) {
                var o: Row = [:]
                o.reserveCapacity(h.count)
                for (idx, name) in h.enumerated() where !name.isEmpty {
                    o[name] = idx < row.count ? row[idx] : ""
                }
                rows.append(o)
            }
            row.removeAll(keepingCapacity: true)
        }

        while i < n {
            let c = b[i]
            if inQuotes {
                if c == 0x22 {
                    if i + 1 < n && b[i + 1] == 0x22 {
                        field.append(0x22)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == 0x22 {
                inQuotes = true
                hasContent = true
            } else if c == 0x2C {
                endField()
                hasContent = true
            } else if c == 0x0A {
                endField()
                endRecord()
                hasContent = false
            } else if c != 0x0D {
                field.append(c)
                hasContent = true
            }
            i += 1
        }
        if hasContent || !field.isEmpty || !row.isEmpty {
            endField()
            endRecord()
        }
        return (header ?? [], rows)
    }

    /// The file's bytes, built directly so nothing is encoded twice on the way to disk.
    static func writeData(header: [String], rows: [Row]) -> Data {
        var out: [UInt8] = []
        out.reserveCapacity(rows.count * header.count * 12 + 256)

        func put(_ v: String) {
            var v = v
            v.withUTF8 { buf in
                var quote = false
                for byte in buf where byte == 0x2C || byte == 0x22 || byte == 0x0A || byte == 0x0D { quote = true; break }
                if !quote { out.append(contentsOf: buf); return }
                out.append(0x22)
                for byte in buf {
                    if byte == 0x22 { out.append(0x22) }
                    out.append(byte)
                }
                out.append(0x22)
            }
        }

        for (i, h) in header.enumerated() {
            if i > 0 { out.append(0x2C) }
            put(h)
        }
        out.append(0x0A)
        for r in rows {
            for (i, h) in header.enumerated() {
                if i > 0 { out.append(0x2C) }
                put(r[h] ?? "")
            }
            out.append(0x0A)
        }
        return Data(out)
    }
}
