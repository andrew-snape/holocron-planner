import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Welcome board
//
// The Class screen's whole-day view: what the class needs, the weather, today's timetable, the timer,
// the day's documents and a question to talk about. It shows timetable and planner text only, never
// student names or records.

/// An SF Symbol name that exists on this Mac, or the fallback. A name macOS does not know draws nothing.
func safeSymbol(_ name: String, _ fallback: String = "circle") -> String {
    NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : fallback
}

// MARK: Wall

/// The navy wall behind the cards, with a few chalk smiley faces.
struct BoardWall: View {
    var body: some View {
        Canvas { ctx, size in
            // Spots as fractions of the wall, so the faces stay put as the window changes size.
            let spots: [(x: CGFloat, y: CGFloat, r: CGFloat, c: Int)] = [
                (0.33, 0.03, 90, 0), (0.66, 0.02, 100, 1), (0.95, 0.20, 110, 2), (0.01, 0.42, 80, 3),
                (0.98, 0.78, 100, 0), (0.08, 1.02, 90, 2), (0.47, 1.03, 80, 3), (0.80, 1.04, 90, 1),
            ]
            for s in spots {
                let c = CGPoint(x: s.x * size.width, y: s.y * size.height)
                let colour = BoardStyle.doodles[s.c % BoardStyle.doodles.count]
                let style = StrokeStyle(lineWidth: 5, lineCap: .round)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - s.r, y: c.y - s.r, width: s.r * 2, height: s.r * 2)), with: .color(colour), style: style)
                var smile = Path()
                smile.addArc(center: c, radius: s.r * 0.55, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
                ctx.stroke(smile, with: .color(colour), style: style)
                for dx in [-0.32, 0.32] {
                    var eye = Path()
                    eye.move(to: CGPoint(x: c.x + s.r * dx, y: c.y - s.r * 0.45))
                    eye.addLine(to: CGPoint(x: c.x + s.r * dx * 1.05, y: c.y - s.r * 0.18))
                    ctx.stroke(eye, with: .color(colour), style: style)
                }
            }
        }
        .background(BoardStyle.wall)
        .accessibilityHidden(true)
    }
}

/// A button that sits on the navy wall.
struct WallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(BoardStyle.wallInk)
            .padding(.horizontal, 14)
            .frame(minWidth: 34, minHeight: 34)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.16)))
            .contentShape(Capsule())
    }
}

/// A small round or capsule button on a card.
struct ChipButtonStyle: ButtonStyle {
    var fill: Color
    var ink: Color
    var font: Font = .system(size: 15, weight: .semibold)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .frame(minWidth: 32, minHeight: 32)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

// MARK: Card

/// The bookmark ribbon in a card's corner.
struct Ribbon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.width * 0.28))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A pastel card with a ribbon in its top corner and an optional title to its right.
struct BoardCard<Accessory: View, Content: View>: View {
    var swatch: BoardSwatch
    var title: String = ""
    var titleFont: Font = .boardTitle
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Spacer().frame(width: 84)
                if !title.isEmpty {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(swatch.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                accessory
            }
            .frame(minHeight: 52)
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Radius.board, style: .continuous).fill(swatch.card))
        .overlay(alignment: .topLeading) {
            Ribbon().fill(swatch.ribbon)
                .frame(width: 64, height: 80)
                .offset(x: 22, y: -22)
                .accessibilityHidden(true)
        }
    }
}

extension BoardCard where Accessory == EmptyView {
    init(swatch: BoardSwatch, title: String = "", titleFont: Font = .boardTitle, @ViewBuilder content: () -> Content) {
        self.swatch = swatch
        self.title = title
        self.titleFont = titleFont
        self.accessory = EmptyView()
        self.content = content()
    }
}

// MARK: Header

struct WelcomeTitle: View {
    @Environment(AppModel.self) private var model
    var date: String
    var size: CGFloat = 80

    var body: some View {
        let db = model.db
        let letters = Array("Welcome")
        let word = letters.indices.reduce(Text("")) { t, i in
            Text("\(t)\(Text(String(letters[i])).foregroundStyle(BoardStyle.letters[i % BoardStyle.letters.count]))")
        }
        var parts = [longDate(date)]
        if let t = db.termOf(date) { parts.append("Term \(t.term)") }
        if let w = db.termWeek(date), let l = db.weekLetter(date) { parts.append("Week \(w)\(l)") }

        return VStack(spacing: 0) {
            word
                .font(.system(size: size, weight: .black, design: .rounded))
                .shadow(color: .white, radius: 0, x: 2, y: 2)
                .shadow(color: .white, radius: 0, x: -2, y: -2)
                .shadow(color: .white, radius: 0, x: 2, y: -2)
                .shadow(color: .white, radius: 0, x: -2, y: 2)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
                .accessibilityLabel("Welcome")
            Text(parts.joined(separator: " · "))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(BoardStyle.wallInk)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

// MARK: The board

struct WelcomeBoard: View {
    var date: String
    var hideDone: Bool
    var openLesson: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if w >= 1150 && h >= 640 {
                HStack(alignment: .top, spacing: 26) {
                    NeedsCard(date: date).frame(width: w * 0.22)
                    ScheduleCard(date: date, hideDone: hideDone, openLesson: openLesson).frame(width: w * 0.32)
                    VStack(spacing: 26) {
                        HStack(alignment: .top, spacing: 26) {
                            BoardTimerCard(swatch: BoardStyle.teal)
                            DocsCard(date: date)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        PromptCard(date: date)
                    }
                }
                .padding(.top, 22)
            } else {
                ScrollView {
                    let two = w >= 860
                    VStack(spacing: 30) {
                        if two {
                            HStack(alignment: .top, spacing: 26) {
                                ScheduleCard(date: date, hideDone: hideDone, openLesson: openLesson).frame(height: 560)
                                BoardTimerCard(swatch: BoardStyle.teal).frame(width: 330)
                            }
                            HStack(alignment: .top, spacing: 26) {
                                NeedsCard(date: date)
                                VStack(spacing: 30) {
                                    PromptCard(date: date).frame(minHeight: 260)
                                    DocsCard(date: date)
                                }
                            }
                        } else {
                            ScheduleCard(date: date, hideDone: hideDone, openLesson: openLesson).frame(height: 520)
                            BoardTimerCard(swatch: BoardStyle.teal)
                            NeedsCard(date: date)
                            PromptCard(date: date).frame(minHeight: 260)
                            DocsCard(date: date)
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.automatic)
            }
        }
    }
}

// MARK: - What's going on today

/// One block of the day: a period (with its subject, if any) or the break after it.
private struct DayBlock: Identifiable {
    var id: String
    var title: String
    var icon: String
    var start: String
    var end: String
    var tone: Tone?
    /// The period number when the block is a lesson the Class screen can open.
    var lesson: Int?
    var subject: String
}

struct ScheduleCard: View {
    @Environment(AppModel.self) private var model
    var date: String
    var hideDone: Bool
    var openLesson: (Int) -> Void
    private let swatch = BoardStyle.purple

    var body: some View {
        BoardCard(swatch: swatch, title: "What's going on today") {
            if let note = dayNote {
                Text(note).font(.boardBodyMedium).foregroundStyle(swatch.ink)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let now = minutesOf(context.date)
                    let isToday = date == todayISO()
                    let shown = blocks.filter { !(hideDone && isToday && (hm($0.end) ?? 0) <= now) }
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(shown) { b in
                                    row(b, now: isToday ? now : -1).id(b.id)
                                }
                                if shown.isEmpty {
                                    Text("That's everything for today.").font(.boardBodyMedium).foregroundStyle(swatch.ink)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(.trailing, 6)
                        }
                        .scrollIndicators(.automatic)
                        .onAppear {
                            if let cur = shown.first(where: { isToday && (hm($0.end) ?? 0) > now }) {
                                proxy.scrollTo(cur.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Why the timetable is not shown, or nil on a normal school day.
    private var dayNote: String? {
        let db = model.db
        if dayIdx(date) > 4 { return "It's the weekend." }
        if db.isNonTeaching(date) { return db.nonTeachingLabel(date).isEmpty ? "No school today." : db.nonTeachingLabel(date) }
        if db.termOf(date) == nil { return "No timetable today." }
        if let ov = db.overrideOf(date), ov.s("type") != "Normal" {
            let t = ov.s("type").isEmpty ? "The timetable does not run today." : ov.s("type")
            return ov.s("note").isEmpty ? t : t + ". " + ov.s("note")
        }
        return nil
    }

    private var blocks: [DayBlock] {
        let db = model.db
        let ps = db.periods
        var out: [DayBlock] = []
        for (i, p) in ps.enumerated() {
            let s = db.plannedSubject(date, p.period)
            let isLesson = !s.isEmpty && db.subjectInfo(s).kind != "dottl"
            let title = isLesson ? s : p.name
            let guessed = BoardIcons.guess(title)
            let icon = isLesson ? db.icon(forSubject: s) : (guessed.isEmpty ? "clock" : guessed)
            out.append(DayBlock(id: "p\(i)", title: title, icon: safeSymbol(icon, "book.closed"), start: p.start, end: p.end,
                                tone: isLesson ? db.tone(forSubject: s) : nil, lesson: isLesson ? p.period : nil,
                                subject: isLesson ? s : ""))
            if i + 1 < ps.count, mins(p.end, ps[i + 1].start) > 0 {
                out.append(DayBlock(id: "b\(i)", title: breakLabel(from: p.end, to: ps[i + 1].start), icon: "fork.knife",
                                    start: p.end, end: ps[i + 1].start, tone: nil, lesson: nil, subject: ""))
            }
        }
        return out
    }

    @ViewBuilder
    private func row(_ b: DayBlock, now: Int) -> some View {
        let a = hm(b.start) ?? 0, z = hm(b.end) ?? 0
        let current = now >= a && now < z
        let done = now >= z
        let fraction: CGFloat = done ? 1 : (current && z > a ? CGFloat(now - a) / CGFloat(z - a) : 0)
        let accent = b.tone?.barColor ?? swatch.ribbon

        let content = HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.6))
                Image(systemName: b.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(b.title).font(.boardRow).foregroundStyle(swatch.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if current {
                        Text("NOW").font(.boardLabel).tracking(1).foregroundStyle(swatch.ribbon)
                    }
                }
                HStack(spacing: 10) {
                    Text(fmtTime(b.start))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(swatch.ink.opacity(0.18))
                            Capsule().fill(accent).frame(width: g.size.width * fraction)
                        }
                    }
                    .frame(height: 8)
                    Text(fmtTime(b.end))
                }
                .font(.boardTime)
                .foregroundStyle(swatch.ink.opacity(0.85))
                .monospacedDigit()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.boardTile, style: .continuous)
            .fill(current ? Color.white.opacity(0.55) : swatch.soft.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: Radius.boardTile, style: .continuous)
            .stroke(current ? swatch.ribbon : Color.clear, lineWidth: 3))
        .opacity(done ? 0.75 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(current ? "Now" : (done ? "Finished" : ""))

        if let per = b.lesson {
            Button { openLesson(per) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .help("Show this lesson on the Class screen")
                .accessibilityHint("Shows this lesson")
                .contextMenu { iconMenu(b.subject) }
        } else {
            content
        }
    }

    @ViewBuilder
    private func iconMenu(_ subject: String) -> some View {
        let current = model.db.subjectInfo(subject).icon
        Menu("Icon for \(subject)") {
            Button("Choose for me") { model.db.setSubjectIcon(subject, "") }
                .disabled(current.isEmpty)
            Divider()
            ForEach(BoardIcons.choices, id: \.name) { c in
                Button { model.db.setSubjectIcon(subject, c.name) } label: {
                    Label(c.label, systemImage: safeSymbol(c.name))
                }
            }
        }
    }

    private func minutesOf(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - What you need today, and the weather

struct NeedsCard: View {
    @Environment(AppModel.self) private var model
    var date: String
    @State private var typed = ""
    private let swatch = BoardStyle.pink

    var body: some View {
        let db = model.db
        let items = db.needs(on: date)
        let last = db.lastNeeds(before: date)
        let haveNames = Set(items.map { $0.s("item").lowercased() })
        let missing = last.filter { !haveNames.contains($0.lowercased()) }

        BoardCard(swatch: swatch, title: "What you need today", titleFont: .boardHand(26)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    TextField("Add something…", text: $typed)
                        .textFieldStyle(.plain)
                        .font(.boardBody)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(swatch.soft))
                        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .strokeBorder(swatch.ribbon.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                        .onSubmit(add)
                        .accessibilityLabel("Add something the class needs today")
                    Button(action: add) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(swatch.ribbon))
                            .foregroundStyle(Color.onAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Add to today's list")
                    .accessibilityLabel("Add")
                }

                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { r in
                        chip(r)
                    }
                }

                HStack(spacing: 8) {
                    if !missing.isEmpty {
                        Button("Copy the last list") { db.copyLastNeeds(to: date) }
                            .buttonStyle(ChipButtonStyle(fill: swatch.ribbon, ink: .onAccent))
                            .help("Add the items from the last day that had a list")
                    }
                }
                if items.isEmpty && missing.isEmpty {
                    Text("Ideas").font(.boardLabel).foregroundStyle(swatch.ink.opacity(0.8))
                    FlowLayout(spacing: 8) {
                        ForEach(BoardIcons.suggestedNeeds, id: \.self) { s in
                            Button { db.addNeed(s, on: date) } label: {
                                Label(s, systemImage: "plus")
                            }
                            .buttonStyle(ChipButtonStyle(fill: swatch.soft.opacity(0.6), ink: swatch.ink.opacity(0.8)))
                            .help("Add \(s)")
                        }
                    }
                }

                Rectangle().fill(swatch.ribbon.opacity(0.45)).frame(height: 2)
                    .padding(.vertical, 4)

                WeatherPanel(swatch: swatch, date: date)
            }
        }
    }

    private func add() {
        model.db.addNeed(typed, on: date)
        typed = ""
    }

    private func chip(_ r: Row) -> some View {
        let item = r.s("item")
        return HStack(spacing: 6) {
            Image(systemName: safeSymbol(BoardIcons.need(item), "checkmark.circle"))
                .foregroundStyle(swatch.ribbon)
            Text(item)
            Button { model.db.removeNeed(id: r.s("id")) } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(swatch.ink.opacity(0.75))
            .help("Take \(item) off the list")
            .accessibilityLabel("Remove \(item)")
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(swatch.ink)
        .padding(.leading, 12).padding(.trailing, 4)
        .frame(minHeight: 36)
        .background(Capsule().fill(swatch.soft))
    }
}

struct WeatherPanel: View {
    @Environment(AppModel.self) private var model
    var swatch: BoardSwatch
    var date: String
    @State private var editing = false

    var body: some View {
        let db = model.db
        let place = db.weatherPlace
        let days = WeatherService.schoolDays(model.weather.days, from: date)

        VStack(alignment: .leading, spacing: 12) {
            if place == nil {
                Text("Show the weather for the week here.").font(.boardBody).foregroundStyle(swatch.ink)
                Button("Add your town") { editing = true }
                    .buttonStyle(ChipButtonStyle(fill: swatch.ribbon, ink: .onAccent))
                    .popover(isPresented: $editing) { WeatherPlaceEditor() }
            } else if let today = days.first, today.date == date {
                HStack(spacing: 14) {
                    Image(systemName: safeSymbol(WeatherService.symbol(today.code), "cloud.fill"))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 50))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(deg(today.high)) / \(deg(today.low))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .accessibilityLabel("High \(Int(today.high.rounded())), low \(Int(today.low.rounded()))")
                        HStack(spacing: 6) {
                            Text(WeatherService.words(today.code))
                            Text("·")
                            Image(systemName: "drop.fill").foregroundStyle(Color.appBlue)
                            Text("\(today.rain)%")
                        }
                        .font(.system(size: 19, weight: .medium))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(WeatherService.words(today.code)), \(today.rain) percent chance of rain")
                    }
                }
                .foregroundStyle(swatch.ink)
                if today.sunSmart {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill").symbolRenderingMode(.multicolor)
                        Text("Sun smart: wear a hat and sunscreen")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(swatch.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(swatch.soft))
                }
                VStack(spacing: 2) {
                    ForEach(days, id: \.date) { d in dayRow(d, isToday: d.date == date) }
                }
                footer(place)
            } else if model.weather.failed {
                Text("The weather is not available right now.").font(.boardBody).foregroundStyle(swatch.ink)
                footer(place)
            } else if !days.isEmpty {
                VStack(spacing: 2) {
                    ForEach(days, id: \.date) { d in dayRow(d, isToday: false) }
                }
                footer(place)
            } else {
                ProgressView().controlSize(.small).accessibilityLabel("Loading the weather")
                footer(place)
            }
        }
        // Fetches when the town changes, then every 30 minutes while the board is showing.
        .task(id: place.map { "\($0.latitude),\($0.longitude)" } ?? "") {
            while !Task.isCancelled {
                await model.weather.refresh(place)
                // Tries again in a minute while there is no forecast (no connection at first, say).
                try? await Task.sleep(for: .seconds(model.weather.days.isEmpty ? 60 : 30 * 60))
            }
        }
    }

    private func footer(_ place: WeatherPlace?) -> some View {
        HStack(spacing: 6) {
            Text(place?.name ?? "")
            Text("·")
            Button("change") { editing = true }
                .buttonStyle(.plain)
                .underline()
                .frame(minHeight: 28)
                .contentShape(Rectangle())
                .help("Change the town for the weather, or turn it off")
                .popover(isPresented: $editing) { WeatherPlaceEditor() }
        }
        .font(.boardBody)
        .foregroundStyle(swatch.ink.opacity(0.85))
    }

    private func dayRow(_ d: WeatherDay, isToday: Bool) -> some View {
        HStack(spacing: 10) {
            Text(Cal.weekdayLong[dayIdx(d.date)].prefix(3)).frame(width: 44, alignment: .leading)
                .fontWeight(isToday ? .bold : .medium)
            Image(systemName: safeSymbol(WeatherService.symbol(d.code), "cloud.fill"))
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)
            Text("\(deg(d.high)) / \(deg(d.low))").monospacedDigit()
            Spacer(minLength: 4)
            Image(systemName: "drop.fill").font(.system(size: 12)).foregroundStyle(Color.appBlue)
            Text("\(d.rain)%").monospacedDigit().frame(minWidth: 40, alignment: .trailing)
        }
        .font(.system(size: 17))
        .foregroundStyle(swatch.ink)
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(isToday ? Color.white : Color.clear))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Cal.weekdayLong[dayIdx(d.date)]), \(WeatherService.words(d.code)), high \(Int(d.high.rounded())), low \(Int(d.low.rounded())), \(d.rain) percent chance of rain")
    }

    private func deg(_ v: Double) -> String { "\(Int(v.rounded()))°" }
}

/// Where the forecast is for. What is typed is sent once to Open-Meteo to find the town; after that only its location.
struct WeatherPlaceEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var finding = false
    @State private var message = ""
    @State private var lookup: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather").font(.hSheet)
            Text("Type your town or suburb. Holocron sends what you type to Open-Meteo once, to find the town, and after that only its location, for the forecast. Nothing about your class is sent.")
                .font(.body1).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("Town or suburb", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(find)
                Button("Find", action: find)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || finding)
            }
            if finding { ProgressView().controlSize(.small) }
            if !message.isEmpty { Text(message).font(.body1).foregroundStyle(Color.ink2) }
            if model.db.weatherPlace != nil {
                Divider()
                Button("Turn off weather") {
                    model.db.setWeatherPlace(nil)
                    dismiss()
                }
                .help("Stop showing the weather. Nothing more is sent.")
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { name = model.db.weatherPlace?.name ?? "" }
        // Closing the popover before the answer comes back saves nothing.
        .onDisappear { lookup?.cancel() }
    }

    private func find() {
        let q = name.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !finding else { return }
        finding = true
        message = ""
        lookup = Task {
            let p = await BoardWeather.findPlace(q)
            guard !Task.isCancelled else { return }
            finding = false
            if let p {
                model.db.setWeatherPlace(p)
                dismiss()
            } else {
                message = "Could not find that town, or there is no internet connection. Check the spelling and try again."
            }
        }
    }
}

// MARK: - Timer and work modes

struct BoardTimerCard: View {
    @Environment(AppModel.self) private var model
    var swatch: BoardSwatch
    @State private var showWatch = false

    var body: some View {
        let t = model.classTimer
        let ring = t.finished ? Color.appRed : swatch.ribbon
        let fraction: CGFloat = t.total > 0 ? CGFloat(t.left) / CGFloat(t.total) : 0

        BoardCard(swatch: swatch) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.55), lineWidth: 18)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(ring, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.4), value: t.left)
                    VStack(spacing: 2) {
                        Button { t.addMinute() } label: {
                            Image(systemName: "plus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 30)
                        }
                        .buttonStyle(.plain)
                        .help("Add a minute")
                        .accessibilityLabel("Add a minute")
                        Text(t.finished ? "Time's up" : clockText(t.left))
                            .font(.system(size: t.finished ? 30 : 50, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .foregroundStyle(t.finished ? Color.appRed : swatch.ink)
                        Button { t.subtractMinute() } label: {
                            Image(systemName: "minus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 30)
                        }
                        .buttonStyle(.plain)
                        .disabled(t.left == 0)
                        .help("Take a minute off")
                        .accessibilityLabel("Take a minute off")
                    }
                    .foregroundStyle(swatch.ink)
                    .padding(.horizontal, 24)
                }
                .frame(width: 210, height: 210)
                .frame(maxWidth: .infinity)

                HStack(spacing: 24) {
                    Button { t.toggle() } label: {
                        Image(systemName: t.running ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.onAccent)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(swatch.ribbon))
                    }
                    .buttonStyle(.plain)
                    .disabled(t.left == 0)
                    .help(t.running ? "Pause the timer (Space)" : "Start the timer (Space)")
                    .accessibilityLabel(t.running ? "Pause" : "Start")
                    Button { t.reset() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(swatch.ribbon)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(swatch.ribbon, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(t.total == 0)
                    .help("Stop and go back to the start")
                    .accessibilityLabel("Reset")
                }

                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20], id: \.self) { m in
                        Button("\(m)m") { t.start(minutes: m) }
                            .buttonStyle(ChipButtonStyle(fill: swatch.soft, ink: swatch.ink, font: .system(size: 17, weight: .semibold)))
                            .help("Start a \(m) minute timer")
                            .accessibilityLabel("\(m) minutes")
                    }
                }

                WorkModeRow(swatch: swatch)

                HStack(spacing: 12) {
                    Button { t.sound.toggle() } label: {
                        Image(systemName: t.sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .help(t.sound ? "Sound when time is up: on" : "Sound when time is up: off")
                    .accessibilityLabel(t.sound ? "Sound on" : "Sound off")
                    Button { showWatch.toggle() } label: { Image(systemName: "stopwatch") }
                        .help(showWatch ? "Hide the stopwatch" : "Show the stopwatch")
                        .accessibilityLabel(showWatch ? "Hide stopwatch" : "Show stopwatch")
                    if showWatch || model.stopwatch.running {
                        StopwatchLine(swatch: swatch)
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(ChipButtonStyle(fill: swatch.soft, ink: swatch.ink))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.board, style: .continuous)
            .stroke(Color.appRed, lineWidth: t.finished ? 4 : 0))
        .animation(.easeInOut(duration: 0.3), value: t.finished)
    }
}

/// Counts up, for timing an activity. It keeps running when you leave the screen.
private struct StopwatchLine: View {
    @Environment(AppModel.self) private var model
    var swatch: BoardSwatch

    var body: some View {
        let watch = model.stopwatch
        HStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(clockText(Int(watch.now(context.date))))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(swatch.ink)
            }
            Button { watch.toggle() } label: { Image(systemName: watch.running ? "pause.fill" : "play.fill") }
                .help(watch.running ? "Pause the stopwatch" : "Start the stopwatch")
                .accessibilityLabel(watch.running ? "Pause stopwatch" : "Start stopwatch")
            Button { watch.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                .help("Reset the stopwatch")
                .accessibilityLabel("Reset stopwatch")
        }
    }
}

struct WorkModeRow: View {
    @Environment(AppModel.self) private var model
    var swatch: BoardSwatch

    var body: some View {
        let t = model.classTimer
        HStack(spacing: 6) {
            ForEach(WorkModes.all) { w in
                let on = t.work == w.id
                Button { t.work = on ? "" : w.id } label: {
                    VStack(spacing: 4) {
                        Image(systemName: w.symbol).font(.system(size: 20, weight: .semibold))
                        Text(w.short).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    // Dark text on the light mode colours (green, orange, sky blue), so the label stays readable when chosen.
                    .foregroundStyle(on ? (["partner", "group", "whisper"].contains(w.id) ? Color.black.opacity(0.8) : Color.onAccent) : Color(hex: w.hex))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(RoundedRectangle(cornerRadius: Radius.inset, style: .continuous).fill(on ? Color(hex: w.hex) : Color.white.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help(on ? "Clear \(w.label)" : "Show \(w.label) on the screen")
                .accessibilityLabel(w.label)
                .accessibilityValue(on ? "Selected" : "")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: t.work)
    }
}

// MARK: - Documents for today

struct DocsCard: View {
    @Environment(AppModel.self) private var model
    var date: String
    @State private var dropping = false
    /// Linked files that cannot be found, checked in the background.
    @State private var missing: Set<String> = []
    private let swatch = BoardStyle.lilac

    var body: some View {
        let docs = model.db.docs(on: date)
        BoardCard(swatch: swatch, title: "Documents for today") {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: choose) {
                    Label("Add documents", systemImage: "arrow.up.doc")
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(Color.onAccent)
                        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(swatch.ribbon))
                }
                .buttonStyle(.plain)
                .help("Choose files for today. They stay where they are; Holocron only keeps a link.")

                if docs.isEmpty {
                    Text("Add slides, Word files, PDFs and pictures for today. Drag them here, or choose Add documents. The files stay where they are.")
                        .font(.boardBody).foregroundStyle(swatch.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Nothing added for today yet.").font(.boardBody).foregroundStyle(swatch.ink.opacity(0.85))
                } else {
                    VStack(spacing: 6) {
                        ForEach(docs, id: \.self) { r in docRow(r) }
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.board, style: .continuous)
            .stroke(swatch.ribbon, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            .opacity(dropping ? 1 : 0))
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            for u in files { model.db.addDoc(u, on: date) }
            return !files.isEmpty
        } isTargeted: { dropping = $0 }
        .task(id: docs.map { $0.s("path") }) {
            missing = await Database.missingDocPaths(docs.map { $0.s("path") })
        }
    }

    private func docRow(_ r: Row) -> some View {
        let path = r.s("path")
        let ext = (path as NSString).pathExtension
        let here = !missing.contains(path)
        return Button { open(r) } label: {
            HStack(spacing: 10) {
                Image(systemName: safeSymbol(BoardIcons.file(ext), "doc"))
                    .font(.system(size: 20))
                    .foregroundStyle(swatch.ribbon)
                    .frame(width: 28)
                Text(r.s("title")).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                Spacer(minLength: 0)
                if !here {
                    Text("Moved?").font(.boardLabel).foregroundStyle(swatch.ink.opacity(0.85))
                }
            }
            .foregroundStyle(swatch.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(swatch.soft))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(r.s("title"))")
        .contextMenu {
            Button("Open") { open(r) }
            Button("Show in Finder") {
                if let u = model.db.locateDoc(r) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
                else { model.showToast("Cannot find \(r.s("title")). It may have been moved or deleted.") }
            }
            Divider()
            Button("Remove from today", role: .destructive) { model.db.removeDoc(id: r.s("id")) }
                .help("Takes the link off today. The file itself is not touched.")
        }
    }

    private func open(_ r: Row) {
        if let u = model.db.locateDoc(r) { NSWorkspace.shared.open(u) }
        else if model.db.downloadDocFromCloud(r) { model.showToast("Downloading \(r.s("title")) from iCloud. Try again in a moment.") }
        else { model.showToast("Cannot find \(r.s("title")). It may have been moved or deleted.") }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"
        panel.message = "Choose files for today. They stay where they are."
        guard panel.runModal() == .OK else { return }
        for u in panel.urls { model.db.addDoc(u, on: date) }
    }
}

// MARK: - Question of the day

struct PromptCard: View {
    @Environment(AppModel.self) private var model
    var date: String
    /// How far from today's question the teacher has stepped with the arrows.
    @State private var step = 0
    @State private var playing = false
    @State private var editing = false
    private let swatch = BoardStyle.yellow

    var body: some View {
        let list = model.db.prompts
        let start = (Cal.dayNumber(date) ?? 0)
        let text = list.isEmpty ? "" : list[((start + step) % list.count + list.count) % list.count]

        BoardCard(swatch: swatch) {
            Text("QUESTION")
                .font(.system(size: 18, weight: .bold, design: .rounded)).tracking(1)
                .foregroundStyle(swatch.ink)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 0)
                Text(list.isEmpty ? "Add some questions with Prompts." : text)
                    .font(.boardHand(40))
                    .foregroundStyle(swatch.ink)
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: text)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Spacer()
                    Button { step -= 1 } label: { Image(systemName: "chevron.left") }
                        .help("The question before").accessibilityLabel("Previous question")
                    Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }
                        .help(playing ? "Stop changing the question" : "Show a new question every two minutes")
                        .accessibilityLabel(playing ? "Stop changing" : "Change every two minutes")
                    Button { step += 1 } label: { Image(systemName: "chevron.right") }
                        .help("The next question").accessibilityLabel("Next question")
                    Button {
                        if model.canWrite(.prompts) { editing = true }
                        else { model.showToast("prompts.csv could not be read, so it cannot be changed. Check the file in the student folder.") }
                    } label: { Label("Prompts", systemImage: "pencil") }
                        .help("Edit the list of questions")
                }
                .buttonStyle(ChipButtonStyle(fill: swatch.soft, ink: swatch.ink))
            }
        }
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                if !Task.isCancelled { step += 1 }
            }
        }
        .onChange(of: date) { step = 0 }
        .sheet(isPresented: $editing) { PromptsSheet() }
    }
}

struct PromptsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var original = ""

    var body: some View {
        SheetFrame(title: "Question prompts", subtitle: "One question per line. A different one shows each day.", width: 520,
                   dirty: text != original, confirmTitle: "Save", onConfirm: {
            model.db.setPrompts(text.components(separatedBy: .newlines))
            dismiss()
        }, confirmKey: KeyboardShortcut("s", modifiers: .command)) {
            TextEditor(text: $text)
                .font(.body2)
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(Color.fieldBG))
                .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(Color.fieldStroke))
        }
        .onAppear {
            original = model.db.prompts.joined(separator: "\n")
            text = original
        }
    }
}
