import SwiftUI

// MARK: - Classroom board
//
// A projector board in the spirit of Classroom Screen: a large clock and date, today's
// timetable, Now and Next, and a timer and stopwatch. It shows timetable text only,
// never student names or records. The timer is the shared class timer, so it matches
// the Class screen.

/// Counts up from zero. Kept in memory only, so it starts again when the app quits.
@Observable
final class Stopwatch {
    private(set) var elapsed: TimeInterval = 0
    private(set) var running = false
    @ObservationIgnored private var since: Date?

    func toggle() {
        if running {
            elapsed += Date().timeIntervalSince(since ?? Date())
            since = nil
            running = false
        } else {
            since = Date()
            running = true
        }
    }

    func reset() {
        elapsed = 0
        since = nil
        running = false
    }

    func now(_ date: Date) -> TimeInterval {
        running ? elapsed + date.timeIntervalSince(since ?? date) : elapsed
    }
}

/// mm:ss, or h:mm:ss past an hour.
func clockText(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    let pad = { (n: Int) in n < 10 ? "0\(n)" : "\(n)" }
    return h > 0 ? "\(h):\(pad(m)):\(pad(sec))" : "\(m):\(pad(sec))"
}

// MARK: - Sidebar module

struct ClassroomModule: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Space.gap + 2) {
            PageHeader("Classroom", subtitle: "A board for the class to see: clock, timetable, timer.") {
                Button("Open on screen") { openWindow(id: "classroom") }
                    .help("Open the board in its own window to put on the projector. Choose Enter Full Screen from the View menu to fill the display.")
            }
            ClassroomBoard()
        }
        .padding(Space.page)
    }
}

// MARK: - The board

struct ClassroomBoard: View {
    /// The projector window uses larger type and spacing, so the board fills the screen.
    var large = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    /// Registered while the board is on show, so Siri leaves student names out, as it does for a Class screen.
    @State private var screenID = UUID()

    /// Scales every size on the board. 1 in the sidebar, larger on the projector.
    private var k: CGFloat { large ? 1.8 : 1 }
    private func sz(_ base: CGFloat) -> CGFloat { base * k }
    private var cardMinHeight: CGFloat { 220 * k }

    var body: some View {
        ScrollView {
            // Only the stopwatch needs every second. Everything else only changes by the minute.
            // The timer updates on its own, because ClassTimer is @Observable.
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Space.gap * k) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220 * k), spacing: Space.gap * k, alignment: .top)],
                              alignment: .leading, spacing: Space.gap * k) {
                        clockCard(context.date)
                        timetableCard(context.date)
                        timerCard
                    }
                    nowNextStrip(context.date)
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        // Esc closes the projector window. The sidebar copy has nothing to close.
        .onExitCommand { if large { dismissWindow(id: "classroom") } }
        .onAppear { model.classScreens.insert(screenID) }
        .onDisappear { model.classScreens.remove(screenID) }
    }

    // MARK: Clock

    private func clockCard(_ now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6 * k) {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: sz(64), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: sz(18), weight: .medium))
                .foregroundStyle(Color.ink2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .card()
    }

    // MARK: Timetable

    private func timetableCard(_ now: Date) -> some View {
        let db = model.db
        let date = todayISO()
        let t = db.termOf(date)
        let off = dayIdx(date) > 4 || t == nil || db.isNonTeaching(date)
        let ov = db.overrideOf(date)
        let n = nowMinutes()

        return VStack(alignment: .leading, spacing: 8 * k) {
            Text("Today").font(.system(size: sz(17), weight: .semibold))
            if off {
                Text(dayIdx(date) > 4 ? "It's the weekend." : "No timetable today.")
                    .font(.system(size: sz(14)))
                    .foregroundStyle(Color.ink2)
            } else if let ov = ov, ov.s("type") != "Normal" {
                Text(ov.s("type")).font(.system(size: sz(15), weight: .semibold))
                Text(ov.s("note").isEmpty ? "Timetable does not run today." : ov.s("note"))
                    .font(.system(size: sz(14)))
                    .foregroundStyle(Color.ink2)
            } else {
                let ps = db.periods
                // Periods are shown by position, so a repeated period number cannot clash.
                ForEach(Array(ps.enumerated()), id: \.offset) { idx, p in
                    timetableRow(p, date: date, now: n, db: db)
                    if idx + 1 < ps.count, mins(p.end, ps[idx + 1].start) > 0 {
                        Text("\(breakLabel(from: p.end, to: ps[idx + 1].start))  \(fmtTime(p.end)) to \(fmtTime(ps[idx + 1].start))")
                            .font(.system(size: sz(13)))
                            .foregroundStyle(Color.ink2)
                            .padding(.leading, 12 * k)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .card()
    }

    private func timetableRow(_ p: Period, date: String, now: Int, db: Database) -> some View {
        let s = db.plannedSubject(date, p.period)
        let current = (hm(p.start) ?? 0) <= now && now < (hm(p.end) ?? 0)
        let tone = s.isEmpty ? nil : db.tone(forSubject: s)
        return HStack(spacing: 10 * k) {
            Capsule()
                .fill(tone?.barColor ?? Color.hairline)
                .frame(width: 4 * k, height: 30 * k)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.isEmpty ? p.name : s)
                    .font(.system(size: sz(16), weight: current ? .bold : .semibold))
                    .lineLimit(2).minimumScaleFactor(0.85)
                Text("\(fmtTime(p.start)) to \(fmtTime(p.end))")
                    .font(.system(size: sz(12.5)))
                    .foregroundStyle(Color.ink2)
            }
            Spacer(minLength: 0)
            // A word as well as the tint, so the current lesson is clear without colour.
            if current {
                Text("Now")
                    .font(.system(size: sz(12), weight: .bold))
                    .foregroundStyle(Color.ink2)
            }
        }
        .padding(8 * k)
        .background(current ? (tone?.tintColor ?? Color.fillFaint) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Timer and stopwatch

    private var timerCard: some View {
        let t = model.classTimer
        let watch = model.stopwatch
        return VStack(alignment: .leading, spacing: 12 * k) {
            Text("Timer").font(.system(size: sz(17), weight: .semibold))
            Text(clockText(t.left))
                .font(.system(size: sz(52), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(t.left == 0 && t.total > 0 ? Color.appRed : Color.primary)
            if t.left == 0 && t.total > 0 {
                Text("Time is up.")
                    .font(.system(size: sz(15), weight: .semibold))
                    .foregroundStyle(Color.appRed)
            }
            // Wraps onto a second line in a narrow window, rather than cutting the labels short.
            FlowLayout(spacing: 8 * k) {
                ForEach([5, 10, 15], id: \.self) { m in
                    Button("\(m) min") { t.start(minutes: m) }
                }
                // Space starts and pauses the timer, as on the Class screen.
                // Only the projector window takes Space, so the sidebar copy and the Class screen do not clash.
                Button(t.running ? "Pause" : "Start") { t.toggle() }
                    .keyboardShortcut(large ? KeyboardShortcut(.space, modifiers: []) : nil)
                    .disabled(t.left == 0)
                Button("Reset") { t.reset() }
            }
            .controlSize(large ? .large : .regular)

            Divider()

            Text("Stopwatch").font(.system(size: sz(17), weight: .semibold))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(clockText(Int(watch.now(context.date))))
                    .font(.system(size: sz(32), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            HStack(spacing: 8 * k) {
                Button(watch.running ? "Pause" : "Start") { watch.toggle() }
                Button("Reset") { watch.reset() }
            }
            .controlSize(large ? .large : .regular)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .card()
    }

    // MARK: Now and Next

    /// What the strip says now and next. Follows the timetable for the day, including day overrides
    /// (camp, carnival and so on), and names the break between lessons, as the Class screen does.
    private func nowNextTexts(db: Database, date: String, n: Int, ps: [Period]) -> (now: String, next: String) {
        if dayIdx(date) > 4 || db.termOf(date) == nil || db.isNonTeaching(date) {
            return ("No lessons today", "")
        }
        if let ov = db.overrideOf(date), ov.s("type") != "Normal" {
            return (ov.s("type").isEmpty ? "No lessons today" : ov.s("type"), "")
        }

        func label(_ p: Period) -> String {
            let s = db.plannedSubject(date, p.period)
            return s.isEmpty ? p.name : s
        }
        func at(_ p: Period) -> String { "\(label(p))  at \(fmtTime(p.start))" }

        if let i = ps.firstIndex(where: { (hm($0.start) ?? 0) <= n && n < (hm($0.end) ?? 0) }) {
            let c = ps[i]
            guard i + 1 < ps.count else { return (label(c), "Home time") }
            let nx = ps[i + 1]
            let nextText = mins(c.end, nx.start) > 0
                ? "\(breakLabel(from: c.end, to: nx.start))  at \(fmtTime(c.end))"
                : at(nx)
            return (label(c), nextText)
        }

        // Between lessons, before school, or after the last lesson.
        guard let j = ps.firstIndex(where: { (hm($0.start) ?? 0) > n }) else {
            return (ps.isEmpty ? "No lessons today" : "Finished for today", "")
        }
        if j == 0 { return ("Not started yet", at(ps[j])) }
        return (breakLabel(from: ps[j - 1].end, to: ps[j].start), at(ps[j]))
    }

    private func nowNextStrip(_ now: Date) -> some View {
        let db = model.db
        let texts = nowNextTexts(db: db, date: todayISO(), n: nowMinutes(), ps: db.periods)

        return HStack(alignment: .firstTextBaseline, spacing: Space.page * k) {
            VStack(alignment: .leading, spacing: 4 * k) {
                Text("Now").font(.system(size: sz(13), weight: .semibold)).foregroundStyle(Color.ink2)
                Text(texts.now)
                    .font(.system(size: sz(26), weight: .bold))
                    .lineLimit(2).minimumScaleFactor(0.6)
            }
            if !texts.next.isEmpty {
                VStack(alignment: .leading, spacing: 4 * k) {
                    Text("Next").font(.system(size: sz(13), weight: .semibold)).foregroundStyle(Color.ink2)
                    Text(texts.next)
                        .font(.system(size: sz(22), weight: .semibold))
                        .lineLimit(2).minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
