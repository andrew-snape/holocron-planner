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
                EmptyNote(title: "No lessons today", message: "The Class screen shows what the class is learning, the steps to follow, what comes next and a timer. It appears on school days.")
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
    /// Shows the First, Then, Next cards before anything has been typed in them.
    @State private var stepsOpen = false
    /// Which of First (1), Then (2) and Next (3) the class is on. 0 when none is picked.
    @State private var activeStep = 0

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
        let sc = linesOf(c.sc).map { KidWords.strip($0, KidWords.scLeads) }
        let tone = subj.isEmpty ? Tone(bar: RGB(142, 142, 147), tint: RGB(237, 237, 238), ink: RGB(99, 99, 103)) : db.tone(forSubject: subj)
        let ps = lessons
        let ix = ps.firstIndex(where: { $0.period == pn })
        let unit: Row? = subj == "TDL" ? db.unitOn(date) : nil
        let showSteps = stepsOpen || db.classSteps(date, pn).contains { !$0.isEmpty }

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
                            heading("We are learning to", tone)
                            Text(KidWords.strip(c.li, KidWords.liLeads))
                                .font(.system(size: 50, weight: .bold)).tracking(-1)
                        } else {
                            heading("Today", tone)
                            Text(c.summary.isEmpty ? "Get ready to learn!" : c.summary)
                                .font(.system(size: 44, weight: .bold)).tracking(-1)
                        }
                        if showSteps {
                            stepsRow(tone: tone)
                                .padding(.top, 10)
                        } else {
                            Button { stepsOpen = true } label: {
                                Label("Add First, Then, Next", systemImage: "list.number")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.ink3)
                            .help("Type three short steps for the class to follow")
                        }
                        if !sc.isEmpty {
                            heading("I can", tone).padding(.top, 14)
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

            nowNext(subj: subj, p: p, tone: tone)
                .padding(.top, 14)
        }
        .padding(24)
        .background(Color.white)
        .onExitCommand { if !embedded { dismiss() } }
        .onChange(of: pn) { stepsOpen = false; activeStep = 0 }
        .onChange(of: date) { stepsOpen = false; activeStep = 0 }
    }

    private func heading(_ s: String, _ tone: Tone) -> some View {
        Text(s).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(tone.inkColor)
    }

    // MARK: First, Then, Next

    private func stepsRow(tone: Tone) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
                StepCard(number: i + 1,
                         label: ["First", "Then", "Next"][i],
                         text: Binding(get: { model.db.classSteps(date, pn)[i] },
                                       set: { model.db.setClassStep(date, pn, i, $0) }),
                         tone: tone,
                         active: activeStep == i + 1,
                         onPick: { activeStep = activeStep == i + 1 ? 0 : i + 1 })
            }
        }
    }

    // MARK: Now and Next

    @ViewBuilder
    private func nowNext(subj: String, p: Period?, tone: Tone) -> some View {
        if let p = p {
            HStack(spacing: 14) {
                pill(tag: "Now", title: subj.isEmpty ? p.name : subj, sub: "until " + fmtTime(p.end),
                     tint: tone.tintColor, ink: tone.inkColor)
                if let n = nextBlock(after: p) {
                    Image(systemName: "arrow.right").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.ink3)
                    pill(tag: "Next", title: n.title, sub: "at " + fmtTime(n.time),
                         tint: n.tone?.tintColor ?? Color.appBG, ink: n.tone?.inkColor ?? Color.primary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func pill(tag: String, title: String, sub: String, tint: Color, ink: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(tag.uppercased()).font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(ink.opacity(0.8))
            Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 18, weight: .medium)).foregroundStyle(Color.ink2).lineLimit(1)
        }
        .padding(.vertical, 12).padding(.horizontal, 18)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// What follows a period: the next lesson, or Recess, Lunch or Home time when there is a gap.
    private func nextBlock(after p: Period) -> (title: String, time: String, tone: Tone?)? {
        let db = model.db
        guard let end = hm(p.end) else { return nil }
        let later = db.periods
            .filter { (hm($0.start) ?? 0) >= end }
            .sorted { (hm($0.start) ?? 0) < (hm($1.start) ?? 0) }
        guard let q = later.first, let qs = hm(q.start) else { return ("Home time", p.end, nil) }
        if qs - end >= 5 { return (end < 12 * 60 ? "Recess" : "Lunch", p.end, nil) }
        let s = db.plannedSubject(date, q.period)
        return (s.isEmpty ? q.name : s, q.start, s.isEmpty ? nil : db.tone(forSubject: s))
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


// MARK: - First, Then, Next card

struct StepCard: View {
    var number: Int
    var label: String
    @Binding var text: String
    var tone: Tone
    var active: Bool
    var onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onPick) {
                HStack(spacing: 8) {
                    Text("\(number)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(active ? Color.white : tone.inkColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(active ? tone.barColor : Color.white))
                    Text(label).font(.system(size: 22, weight: .bold)).foregroundStyle(tone.inkColor)
                    Spacer(minLength: 0)
                    if active {
                        Text("NOW").font(.system(size: 12, weight: .bold)).tracking(1).foregroundStyle(tone.barColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(active ? "Clear the highlight" : "Highlight this as the step the class is on")
            TextField("Type a step", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .semibold))
                .lineLimit(1...4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(tone.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(active ? tone.barColor : Color.clear, lineWidth: 3))
    }
}

// MARK: - Student friendly wording

/// The headings already say "We are learning to" and "I can", so the same words are trimmed
/// from the start of the learning intention and each success criterion.
enum KidWords {
    static let liLeads = ["we are learning to", "we are learning", "learning intention:", "walt:", "walt", "li:", "to "]
    static let scLeads = ["i can", "success criteria:", "sc:"]

    static func strip(_ s: String, _ leads: [String]) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        var changed = true
        while changed {
            changed = false
            for l in leads where t.lowercased().hasPrefix(l) {
                let after = t.dropFirst(l.count).first
                // "I can" must not trim "I can't", and "walt" must not trim "Walter".
                if l.last?.isLetter == true, let a = after, a.isLetter || a == "'" || a == "\u{2019}" { continue }
                let rest = String(t.dropFirst(l.count)).trimmingCharacters(in: CharacterSet(charactersIn: " :.,-"))
                if rest.isEmpty { return t }
                t = rest
                changed = true
                break
            }
        }
        return t
    }
}

// MARK: - Steps storage

extension Database {
    /// The First, Then and Next steps typed on the Class screen for one lesson.
    func classSteps(_ date: String, _ per: Int) -> [String] {
        let r = rows(.classsteps).first { $0.s("date") == date && Int($0.s("period")) == per }
        return ["first", "then", "next"].map { r?.s($0) ?? "" }
    }

    func setClassStep(_ date: String, _ per: Int, _ i: Int, _ value: String) {
        let keys = ["first", "then", "next"]
        guard keys.indices.contains(i) else { return }
        let match: (Row) -> Bool = { $0.s("date") == date && Int($0.s("period")) == per }
        if rows(.classsteps).contains(where: match) {
            update(.classsteps, where: match) { $0[keys[i]] = value }
            // A lesson whose steps are all cleared loses its row, so the file stays small.
            if let r = rows(.classsteps).first(where: match), keys.allSatisfy({ r.s($0).isEmpty }) {
                remove(.classsteps, where: match)
            }
        } else if !value.isEmpty {
            var row: Row = ["date": date, "period": String(per), "first": "", "then": "", "next": ""]
            row[keys[i]] = value
            append(.classsteps, row)
        }
        touch(.classsteps)
    }
}
