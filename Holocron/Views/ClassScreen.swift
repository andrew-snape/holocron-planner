import SwiftUI
import AppKit

// MARK: - Shared timer
//
// One timer for the whole app, so it keeps running if you leave the Class screen module
// or pop it out into its own window.

@Observable
final class ClassTimer {
    var left = 0
    var total = 0
    var running = false
    var work = ""
    @ObservationIgnored private var ticker: Timer?

    func start(minutes: Int) {
        total = minutes * 60
        left = total
        run()
    }

    func run() {
        guard left > 0 else { return }
        running = true
        ticker?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func pause() {
        running = false
        ticker?.invalidate()
        ticker = nil
    }

    func toggle() {
        if running { pause() } else { run() }
    }

    func addMinute() {
        left += 60
        total = max(total, left)
    }

    func reset() {
        pause()
        left = total
    }

    private func tick() {
        guard running else { return }
        left = max(0, left - 1)
        if left == 0 {
            pause()
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
    }
}

// MARK: - Work modes

struct WorkMode: Identifiable {
    var id: String
    var label: String
    var symbol: String
    var hex: String
}

enum WorkModes {
    static let all: [WorkMode] = [
        WorkMode(id: "silent", label: "Silent", symbol: "speaker.slash", hex: "#5856D6"),
        WorkMode(id: "whisper", label: "Whisper", symbol: "ear", hex: "#32ADE6"),
        WorkMode(id: "partner", label: "Partner", symbol: "person.2", hex: "#34C759"),
        WorkMode(id: "group", label: "Group", symbol: "person.3", hex: "#FF9500"),
        WorkMode(id: "ask", label: "Ask 3 then me", symbol: "questionmark.circle", hex: "#FF2D55")
    ]
}

extension ClassTarget {
    /// The lesson to open: the one running now, the next one today, or the first of the day.
    static func pick(_ model: AppModel, date: String) -> ClassTarget? {
        let db = model.db
        let ps = db.periods.filter { p in
            let s = db.plannedSubject(date, p.period)
            return !s.isEmpty && db.subjectInfo(s).kind != "dottl"
        }
        if date == todayISO() {
            let n = nowMinutes()
            if let c = ps.first(where: { (hm($0.start) ?? 0) <= n && n < (hm($0.end) ?? 0) }) {
                return ClassTarget(date: date, per: c.period)
            }
            if let nx = ps.first(where: { (hm($0.start) ?? 0) > n }) {
                return ClassTarget(date: date, per: nx.period)
            }
        }
        return ps.first.map { ClassTarget(date: date, per: $0.period) }
    }
}

// MARK: - Sidebar module

struct ClassScreenModule: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let t = ClassTarget.pick(model, date: todayISO()) {
            ClassScreenView(initial: t, embedded: true)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader("Class screen")
                EmptyNote(title: "No lessons today", message: "The Class screen shows the learning intention, success criteria and a timer for a lesson. It appears on school days.")
                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - The screen itself

struct ClassScreenView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    var initial: ClassTarget
    var embedded: Bool
    @State private var date: String
    @State private var pn: Int

    init(initial: ClassTarget, embedded: Bool = false) {
        self.initial = initial
        self.embedded = embedded
        _date = State(initialValue: initial.date)
        _pn = State(initialValue: initial.per)
    }

    private var lessons: [Period] {
        let db = model.db
        return db.periods.filter { p in
            let s = db.plannedSubject(date, p.period)
            return !s.isEmpty && db.subjectInfo(s).kind != "dottl"
        }
    }

    var body: some View {
        let db = model.db
        let p = db.period(pn)
        let subj = db.plannedSubject(date, pn)
        let c = db.content(date, pn)
        let sc = linesOf(c.sc)
        let tone = subj.isEmpty ? Tone(bar: RGB(142, 142, 147), tint: RGB(237, 237, 238), ink: RGB(99, 99, 103)) : db.tone(forSubject: subj)
        let ps = lessons
        let ix = ps.firstIndex(where: { $0.period == pn })
        let unit: Row? = subj == "TDL" ? db.unitOn(date) : nil

        VStack(alignment: .leading, spacing: 0) {
            topBar(subj: subj, p: p, tone: tone, ps: ps, ix: ix)
                .padding(.bottom, 18)

            ScrollView {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let u = unit {
                            let ut = ToneMaths.tone(hex: PYP.themeHex(u.s("theme")))
                            Text(u.s("title") + (u.s("central_idea").isEmpty ? "" : " · " + u.s("central_idea")))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(ut.inkColor)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(ut.tintColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        if !c.li.isEmpty {
                            Text("LEARNING INTENTION").font(.system(size: 15, weight: .bold)).tracking(1).foregroundStyle(tone.inkColor)
                            Text(c.li).font(.system(size: 50, weight: .bold)).tracking(-1)
                        } else {
                            Text("LESSON").font(.system(size: 15, weight: .bold)).tracking(1).foregroundStyle(tone.inkColor)
                            Text(c.summary.isEmpty ? "No plan for this lesson yet" : c.summary)
                                .font(.system(size: 44, weight: .bold)).tracking(-1)
                        }
                        if !sc.isEmpty {
                            Text("SUCCESS CRITERIA").font(.system(size: 15, weight: .bold)).tracking(1).foregroundStyle(tone.inkColor).padding(.top, 14)
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(sc, id: \.self) { x in
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "checkmark.circle").foregroundStyle(tone.barColor)
                                        Text(x)
                                    }
                                    .font(.system(size: 28, weight: .medium))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 16) {
                        TimerCard(tone: tone)
                        WorkCard()
                    }
                    .frame(width: 320)
                }
                .padding(.trailing, 4)
            }
        }
        .padding(24)
        .background(Color.white)
        .onExitCommand { if !embedded { dismiss() } }
    }

    // MARK: Top bar

    @ViewBuilder
    private func topBar(subj: String, p: Period?, tone: Tone, ps: [Period], ix: Int?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(subj.isEmpty ? "No lesson" : subj)
                    .font(.system(size: 38, weight: .bold)).tracking(-0.8)
                    .foregroundStyle(tone.inkColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 10) {
                    Text("\(p?.name ?? "") · \(fmtTime(p?.start ?? "")) to \(fmtTime(p?.end ?? ""))")
                    if date != todayISO() { Text(longDate(date)) }
                    remaining(p)
                }
                .font(.system(size: 14)).foregroundStyle(Color.ink2)
            }
            Spacer(minLength: 8)
            TimelineView(.periodic(from: Date(), by: 10)) { _ in
                Text(fmtTime(nowHHMM())).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink2)
            }
            Button { if let i = ix, i > 0 { pn = ps[i - 1].period } } label: { Image(systemName: "chevron.left") }
                .disabled((ix ?? 0) <= 0)
                .help("Previous lesson")
            Button { if let i = ix, i < ps.count - 1 { pn = ps[i + 1].period } } label: { Image(systemName: "chevron.right") }
                .disabled(ix == nil || (ix ?? 0) >= ps.count - 1)
                .help("Next lesson")
            if embedded {
                Button("Pop out") { openWindow(id: "classscreen", value: ClassTarget(date: date, per: pn)) }
                    .help("Open on its own window for the projector")
            } else {
                Button("Full screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
    }

    /// "Ends in 23 min" while the lesson is running today.
    @ViewBuilder
    private func remaining(_ p: Period?) -> some View {
        if let p = p, date == todayISO() {
            TimelineView(.periodic(from: Date(), by: 20)) { _ in
                let n = nowMinutes()
                let a = hm(p.start) ?? 0, b = hm(p.end) ?? 0
                if n >= a && n < b {
                    Text("Ends in \(b - n) min").fontWeight(.semibold).foregroundStyle(Color.appBlue)
                } else if n < a {
                    Text("Starts in \(a - n) min")
                }
            }
        }
    }
}

// MARK: - Timer card

struct TimerCard: View {
    @Environment(AppModel.self) private var model
    var tone: Tone

    private func mmss(_ s: Int) -> String { "\(s / 60):" + (s % 60 < 10 ? "0" : "") + String(s % 60) }

    var body: some View {
        let t = model.classTimer
        VStack(spacing: 12) {
            Text(mmss(t.left))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .foregroundStyle(t.total > 0 && t.left == 0 ? Color.appRed : (t.running ? tone.inkColor : Color.primary))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(tone.barColor)
                        .frame(width: t.total > 0 ? geo.size.width * CGFloat(t.left) / CGFloat(t.total) : 0)
                }
            }
            .frame(height: 8)
            FlowLayout(spacing: 6) {
                ForEach([1, 2, 5, 10, 15, 20], id: \.self) { m in
                    Button("\(m) min") { t.start(minutes: m) }
                }
            }
            HStack {
                Button(t.running ? "Pause" : "Start") { t.toggle() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.space, modifiers: [])
                Button("+1 min") { t.addMinute() }
                Button("Reset") { t.reset() }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.appBG)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Work modes card

struct WorkCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.classTimer
        let current = WorkModes.all.first(where: { $0.id == t.work })
        VStack(spacing: 12) {
            if let w = current {
                HStack(spacing: 12) {
                    Image(systemName: w.symbol).font(.system(size: 34))
                    Text(w.label).font(.system(size: 30, weight: .bold))
                }
                .foregroundStyle(Color(hex: w.hex))
                .padding(.vertical, 6)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(WorkModes.all) { w in
                    let on = t.work == w.id
                    Button { t.work = on ? "" : w.id } label: {
                        VStack(spacing: 6) {
                            Image(systemName: w.symbol).font(.system(size: 24))
                            Text(w.label).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        }
                        .foregroundStyle(on ? Color.white : Color(hex: w.hex))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(on ? Color(hex: w.hex) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.appBG)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
