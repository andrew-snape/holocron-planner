import SwiftUI

// MARK: - Today's timetable strip
//
// Today's timetable, shown above the Class screen's lesson, with the current block
// highlighted and the breaks between lessons named. It shows timetable text only,
// never student names or records.

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

struct DayStrip: View {
    @Environment(AppModel.self) private var model
    /// Open or shut. Kept for this screen only, so the lesson gets the space when it is shut.
    @State private var open = true

    var body: some View {
        let date = todayISO()
        VStack(alignment: .leading, spacing: 10) {
            Button { open.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.ink2)
                    Text("Today").font(.hSection)
                    Text(longDate(date)).font(.system(size: 14)).foregroundStyle(Color.ink2)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(open ? "Hide today's timetable" : "Show today's timetable")
            .accessibilityLabel(open ? "Hide today's timetable" : "Show today's timetable")

            if open { timetable(date) }
        }
        .padding(Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBG)
        .clipShape(RoundedRectangle(cornerRadius: Radius.board, style: .continuous))
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func timetable(_ date: String) -> some View {
        let db = model.db
        let t = db.termOf(date)
        let off = dayIdx(date) > 4 || t == nil || db.isNonTeaching(date)
        let ov = db.overrideOf(date)

        if off {
            note(dayIdx(date) > 4 ? "It's the weekend." : "No timetable today.")
        } else if let ov = ov, ov.s("type") != "Normal" {
            note(ov.s("type").isEmpty ? "Timetable does not run today." : ov.s("type"))
            if !ov.s("note").isEmpty { note(ov.s("note")) }
        } else {
            let ps = db.periods
            // Re-reads the time every 30 seconds, so the Now tile moves on by itself.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let n = minutesOf(context.date)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        // Periods are shown by position, so a repeated period number cannot clash.
                        ForEach(Array(ps.enumerated()), id: \.offset) { idx, p in
                            periodTile(p, date: date, now: n, db: db)
                            if idx + 1 < ps.count, mins(p.end, ps[idx + 1].start) > 0 {
                                breakTile(from: p.end, to: ps[idx + 1].start)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func note(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 14))
            .foregroundStyle(Color.ink2)
    }

    private func breakTile(from: String, to: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(breakLabel(from: from, to: to))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.ink2)
                .lineLimit(2)
            Text("\(fmtTime(from)) to \(fmtTime(to))")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.ink2)
                .lineLimit(2)
        }
        .padding(8)
        .frame(width: 140, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Color.fillFaint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func periodTile(_ p: Period, date: String, now: Int, db: Database) -> some View {
        let s = db.plannedSubject(date, p.period)
        let current = (hm(p.start) ?? 0) <= now && now < (hm(p.end) ?? 0)
        let tone = s.isEmpty ? nil : db.tone(forSubject: s)
        let accent = tone?.barColor ?? Color.appBlue
        return HStack(spacing: 8) {
            Capsule()
                .fill(tone?.barColor ?? Color.hairline)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.isEmpty ? p.name : s)
                    .font(.system(size: 15, weight: current ? .bold : .semibold))
                    .lineLimit(2)
                // A word as well as the colour, so the current lesson is clear without colour.
                if current {
                    Text("NOW").font(.system(size: 12, weight: .bold)).tracking(1).foregroundStyle(accent)
                }
                Text("\(fmtTime(p.start)) to \(fmtTime(p.end))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.ink2)
            }
        }
        .padding(8)
        .frame(width: 156, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(current ? (tone?.tintColor ?? Color.fillFaint) : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            .stroke(current ? accent : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(current ? "Now" : "")
    }

    private func minutesOf(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
