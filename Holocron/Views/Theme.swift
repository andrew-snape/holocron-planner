import SwiftUI
import AppKit

// MARK: - Colours

extension RGB {
    var color: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

extension Tone {
    var barColor: Color { bar.color }
    var tintColor: Color { tint.color }
    var inkColor: Color { ink.color }
}

extension Color {
    init(hex: String) { self = RGB(hex: hex).color }

    /// "#rrggbb" for a SwiftUI colour (used by the colour pickers in Settings).
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        return RGB(Int((ns.redComponent * 255).rounded()),
                   Int((ns.greenComponent * 255).rounded()),
                   Int((ns.blueComponent * 255).rounded())).hex
    }

    static let appBG = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let cardBG = Color.white
    static let ink2 = Color(red: 0.43, green: 0.43, blue: 0.45)
    /// The same grey as ink2. The two were once a hair apart, which nobody could see.
    static let ink3 = Color.ink2
    static let hairline = Color.black.opacity(0.08)
    static let appBlue = Color(red: 0.0, green: 0.443, blue: 0.89)
    static let appGreen = Color(red: 0.2, green: 0.62, blue: 0.35)
    static let appAmber = Color(red: 0.76, green: 0.5, blue: 0.25)
    static let appRed = Color(red: 0.8, green: 0.2, blue: 0.19)
    static let weekB = Color(red: 0.48, green: 0.31, blue: 0.66)
    static let weekBBG = Color(red: 0.95, green: 0.925, blue: 0.976)
}

// MARK: - Card style

struct CardStyle: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View { modifier(CardStyle(padding: padding)) }
}

// MARK: - Small shared views

struct SubjectChip: View {
    @Environment(AppModel.self) private var model
    var name: String

    var body: some View {
        let tone = name.isEmpty ? Tone.unset : model.db.tone(forSubject: name)
        Text(name.isEmpty ? "Not set" : name)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(tone.inkColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 9)
            .background(tone.tintColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TagLabel: View {
    var text: String
    var fg: Color = .appBlue
    var bg: Color = Color.appBlue.opacity(0.12)

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(bg)
            .clipShape(Capsule())
    }
}

struct WeekBadge: View {
    var letter: String
    var body: some View {
        Text("Week \(letter)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(letter == "B" ? Color.weekB : Color.appBlue)
            .padding(.vertical, 2)
            .padding(.horizontal, 10)
            .background(letter == "B" ? Color.weekBBG : Color.appBlue.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PageHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var trailing: Trailing

    init(_ title: String, subtitle: String = "", @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 26, weight: .bold)).tracking(-0.4)
            if !subtitle.isEmpty {
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.ink2)
            }
            trailing
            Spacer(minLength: 0)
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String = "") {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct EmptyNote: View {
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(Color.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SectionTitle: View {
    var text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(size: 15, weight: .semibold)).padding(.top, 6)
    }
}

struct FieldLabel: View {
    var text: String
    var hint: String = ""
    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
            if !hint.isEmpty { Text(hint).font(.system(size: 11)).foregroundStyle(Color.ink3) }
        }
    }
}

/// A labelled multi-line text box.
struct NoteBox: View {
    var label: String
    var hint: String = ""
    @Binding var text: String
    var lines: Int = 3
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel(text: label, hint: hint)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(lines...max(lines, lines + 6))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.14), lineWidth: 0.5))
        }
    }
}

struct LineField: View {
    var label: String
    var hint: String = ""
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel(text: label, hint: hint)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// Wrapping row of toggle chips that edits a comma list.
struct ChipToggles: View {
    var options: [String]
    @Binding var value: String

    var body: some View {
        let on = listOf(value)
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { o in
                let isOn = on.contains(o)
                Button {
                    var cur = listOf(value)
                    if let i = cur.firstIndex(of: o) { cur.remove(at: i) } else { cur.append(o) }
                    value = options.filter { cur.contains($0) }.joined(separator: ", ")
                } label: {
                    Text(o)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(isOn ? Color.appBlue : Color.black.opacity(0.06))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Read-only chips.
struct ChipRow: View {
    var items: [String]
    var tinted: Bool = false
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { i in
                Text(i)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(tinted ? Color.appBlue.opacity(0.14) : Color.black.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
    }
}

/// A simple wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, usedW: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW {
                y += rowH + spacing
                x = 0
                rowH = 0
            }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            usedW = max(usedW, x - spacing)
        }
        return CGSize(width: usedW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX {
                y += rowH + spacing
                x = bounds.minX
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - Student photo

struct Avatar: View {
    @Environment(AppModel.self) private var model
    var student: Student
    var size: CGFloat

    var body: some View {
        ZStack {
            if let img = model.photo(for: student.id) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color.black.opacity(0.08))
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink2)
            }
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let a = student.first.first.map { String($0) } ?? "?"
        let b = student.surname.first.map { String($0) } ?? ""
        return (a + b).uppercased()
    }
}

// MARK: - Date binding helpers

/// Binds an ISO date string to a DatePicker.
func isoBinding(_ get: @escaping () -> String, _ set: @escaping (String) -> Void) -> Binding<Date> {
    Binding<Date>(
        get: {
            guard let (y, m, d) = Cal.parts(get()) else { return Date() }
            var c = DateComponents()
            c.year = y; c.month = m; c.day = d; c.hour = 12
            return Calendar.current.date(from: c) ?? Date()
        },
        set: { date in
            let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
            set(Cal.make(c.year ?? 1970, c.month ?? 1, c.day ?? 1))
        }
    )
}

func tintedBlock(_ tone: Tone, release: Bool) -> some View {
    ZStack {
        tone.tintColor
        if release {
            Stripes(color: Color.white.opacity(0.55))
        }
    }
}

/// Diagonal stripes used on release (specialist) blocks.
struct Stripes: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 14
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                ctx.stroke(p, with: .color(color), lineWidth: 5)
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Small helpers

/// Turns a flag on for a moment, then off again. For "Copied" and "Reloaded" labels.
@MainActor
func flash(_ flag: Binding<Bool>, seconds: Double = 1.6) {
    flag.wrappedValue = true
    Task {
        try? await Task.sleep(for: .seconds(seconds))
        flag.wrappedValue = false
    }
}

/// A small capitals heading above a block, such as LEARNING INTENTION.
struct SectionLabel: View {
    var text: String
    var color: Color = .ink2
    init(_ text: String, color: Color = .ink2) { self.text = text; self.color = color }

    var body: some View {
        Text(text.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.6).foregroundStyle(color)
    }
}

/// A delete button that needs a second click, so a stray click does not remove anything.
struct DeleteButton: View {
    var action: () -> Void
    @State private var armed = false

    var body: some View {
        Button {
            if armed { action() } else { armed = true }
        } label: {
            Text(armed ? "Click again" : "Delete")
                .font(.system(size: 12))
                .foregroundStyle(armed ? Color.appRed : Color.ink2)
        }
        .buttonStyle(.plain)
    }
}
