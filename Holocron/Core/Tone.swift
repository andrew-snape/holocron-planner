import Foundation

struct RGB: Equatable {
    var r: Int
    var g: Int
    var b: Int

    init(_ r: Int, _ g: Int, _ b: Int) { self.r = r; self.g = g; self.b = b }

    /// Parses "#RRGGBB" or "#RGB". Falls back to a neutral grey.
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        if h.count == 6, let n = Int(h, radix: 16) {
            self.init((n >> 16) & 255, (n >> 8) & 255, n & 255)
        } else {
            self.init(142, 142, 147)
        }
    }

    var hex: String { String(format: "#%02x%02x%02x", r, g, b) }
}

/// Apple Calendar style colours from one subject colour: the bar (the colour itself),
/// a pale tint for the block background (16% on white) and an ink for the subject name,
/// darkened until it reaches 5:1 contrast on the tint.
struct Tone: Equatable {
    var bar: RGB
    var tint: RGB
    var ink: RGB

    /// Neutral grey, for a slot with no subject.
    static let unset = Tone(bar: RGB(199, 199, 204), tint: RGB(242, 242, 247), ink: RGB(85, 85, 90))
}

enum ToneMaths {
    static func relLum(_ c: RGB) -> Double {
        func f(_ v: Int) -> Double {
            let x = Double(v) / 255
            return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let x = relLum(a), y = relLum(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        func m(_ x: Int, _ y: Int) -> Int { Int((Double(x) * (1 - t) + Double(y) * t).rounded()) }
        return RGB(m(a.r, b.r), m(a.g, b.g), m(a.b, b.b))
    }

    static func tone(hex: String) -> Tone {
        let c = RGB(hex: hex)
        let tint = mix(RGB(255, 255, 255), c, 0.16)
        var t = 0.0
        var ink = c
        while contrast(ink, tint) < 5 && t < 1 {
            t += 0.02
            ink = mix(c, RGB(0, 0, 0), t)
        }
        return Tone(bar: c, tint: tint, ink: ink)
    }
}
