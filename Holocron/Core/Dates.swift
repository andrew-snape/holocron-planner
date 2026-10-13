import Foundation

/// Date helpers. Dates are plain "yyyy-MM-dd" strings, exactly like the CSV files,
/// so they sort and compare as text. All maths is integer calendar maths (no time zones).
enum Cal {
    static let weekdayLong = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let weekdayShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let monthLong = ["January", "February", "March", "April", "May", "June", "July",
                            "August", "September", "October", "November", "December"]

    /// Tests set this to pretend it is a particular day.
    static var todayOverride: String? = nil
    static var nowOverride: String? = nil   // "HH:mm"

    /// Days since 1970-01-01 for a civil date.
    static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ z0: Int) -> (Int, Int, Int) {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }

    /// Reads "yyyy-MM-dd" straight from the UTF-8 bytes (the shape every date in the files has).
    /// Anything else falls back to the general parser below.
    static func parts(_ s: String) -> (Int, Int, Int)? {
        if let fast = s.utf8.withContiguousStorageIfAvailable({ b -> (Int, Int, Int)? in
            guard b.count >= 10, b[4] == 45, b[7] == 45 else { return nil }
            @inline(__always) func dig(_ i: Int) -> Int? { let c = Int(b[i]) - 48; return (0...9).contains(c) ? c : nil }
            guard let y0 = dig(0), let y1 = dig(1), let y2 = dig(2), let y3 = dig(3),
                  let m0 = dig(5), let m1 = dig(6), let d0 = dig(8), let d1 = dig(9) else { return nil }
            return (y0 * 1000 + y1 * 100 + y2 * 10 + y3, m0 * 10 + m1, d0 * 10 + d1)
        }), let ok = fast { return ok }
        return slowParts(s)
    }

    private static func slowParts(_ s: String) -> (Int, Int, Int)? {
        let p = s.split(separator: "-", omittingEmptySubsequences: false)
        guard p.count >= 3, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2].prefix(2)) else { return nil }
        return (y, m, d)
    }

    /// "yyyy-MM-dd", built by hand. `String(format:)` goes through Foundation's formatter and was
    /// the slowest part of every loop that steps through days.
    static func make(_ y: Int, _ m: Int, _ d: Int) -> String {
        guard (0...9999).contains(y), (0...99).contains(m), (0...99).contains(d) else {
            return String(format: "%04d-%02d-%02d", y, m, d)
        }
        var b: [UInt8] = [0, 0, 0, 0, 45, 0, 0, 45, 0, 0]
        b[0] = UInt8(48 + y / 1000); b[1] = UInt8(48 + y / 100 % 10)
        b[2] = UInt8(48 + y / 10 % 10); b[3] = UInt8(48 + y % 10)
        b[5] = UInt8(48 + m / 10); b[6] = UInt8(48 + m % 10)
        b[8] = UInt8(48 + d / 10); b[9] = UInt8(48 + d % 10)
        return String(decoding: b, as: UTF8.self)
    }

    /// Monday on or before a date, as a day number (nil when the date cannot be read).
    static func mondayNumber(_ s: String) -> Int? {
        guard let n = dayNumber(s) else { return nil }
        return n - ((n + 3) % 7 + 7) % 7
    }

    static func dayNumber(_ s: String) -> Int? {
        guard let (y, m, d) = parts(s) else { return nil }
        return daysFromCivil(y, m, d)
    }

    static func fromDayNumber(_ n: Int) -> String {
        let (y, m, d) = civilFromDays(n)
        return make(y, m, d)
    }
}

func todayISO() -> String {
    if let t = Cal.todayOverride { return t }
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return Cal.make(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
}

func nowHHMM() -> String {
    if let t = Cal.nowOverride { return t }
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

func nowMinutes() -> Int {
    if let o = Cal.nowOverride { return hm(o) ?? 0 }
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

func addDays(_ s: String, _ n: Int) -> String {
    guard let d = Cal.dayNumber(s) else { return s }
    return Cal.fromDayNumber(d + n)
}

/// Monday = 0 ... Sunday = 6
func dayIdx(_ s: String) -> Int {
    guard let d = Cal.dayNumber(s) else { return 0 }
    return ((d + 3) % 7 + 7) % 7
}

func mondayOf(_ s: String) -> String { addDays(s, -dayIdx(s)) }

func daysBetween(_ a: String, _ b: String) -> Int {
    (Cal.dayNumber(b) ?? 0) - (Cal.dayNumber(a) ?? 0)
}

/// "13 Oct"
func shortDate(_ s: String) -> String {
    guard let (_, m, d) = Cal.parts(s), m >= 1, m <= 12 else { return "" }
    return "\(d) \(Cal.monthShort[m - 1])"
}

/// "Tuesday 13 October"
func longDate(_ s: String) -> String {
    guard let (_, m, d) = Cal.parts(s), m >= 1, m <= 12 else { return s }
    return "\(Cal.weekdayLong[dayIdx(s)]) \(d) \(Cal.monthLong[m - 1])"
}

/// "13 Oct 2026"
func dLong(_ s: String) -> String {
    guard let (y, m, d) = Cal.parts(s), m >= 1, m <= 12 else { return s }
    return "\(d) \(Cal.monthShort[m - 1]) \(y)"
}

func yearOf(_ s: String) -> Int { Cal.parts(s)?.0 ?? 0 }

/// Minutes from "HH:mm" to "HH:mm", never negative.
func mins(_ a: String, _ b: String) -> Int {
    guard let x = hm(a), let y = hm(b) else { return 0 }
    return max(0, y - x)
}

/// "HH:mm" to minutes after midnight.
func hm(_ t: String) -> Int? {
    // Fast path for "H:mm" and "HH:mm".
    if let fast = t.utf8.withContiguousStorageIfAvailable({ b -> Int? in
        guard b.count == 4 || b.count == 5 else { return nil }
        let colon = b.count - 3
        guard b[colon] == 58 else { return nil }
        var h = 0
        for i in 0..<colon { let c = Int(b[i]) - 48; guard (0...9).contains(c) else { return nil }; h = h * 10 + c }
        let m0 = Int(b[colon + 1]) - 48, m1 = Int(b[colon + 2]) - 48
        guard (0...9).contains(m0), (0...9).contains(m1) else { return nil }
        return h * 60 + m0 * 10 + m1
    }), let ok = fast { return ok }
    let p = t.split(separator: ":").compactMap { Int($0) }
    guard p.count >= 2 else { return nil }
    return p[0] * 60 + p[1]
}

/// Hours with one decimal, from minutes (matches the web app's rounding).
func hrs(_ m: Double) -> String {
    String(format: "%.1f", (m / 6).rounded() / 10)
}
func hrs(_ m: Int) -> String { hrs(Double(m)) }

/// "9:30 am"
func fmtTime(_ t: String) -> String {
    guard let v = hm(t) else { return "" }
    let h = v / 60, m = v % 60
    let h12 = (h % 12) == 0 ? 12 : h % 12
    return "\(h12):" + (m < 10 ? "0" : "") + String(m) + " " + (h < 12 ? "am" : "pm")
}

/// Random short id, like the web app's `uid()`.
func uid() -> String {
    let ms = Int(Date().timeIntervalSince1970 * 1000)
    let chars = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    var tail = ""
    for _ in 0..<4 { tail.append(chars[Int.random(in: 0..<36)]) }
    return String(ms, radix: 36) + tail
}
