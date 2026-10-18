import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Print Week
//
// Draws the shown week on one A4 landscape page and writes it as a PDF. "Print Week" opens that PDF
// in Preview, where Cmd+P prints it. "Save as PDF" asks where to keep it. Only data that is already
// on the Week screen is used, so nothing new is stored anywhere.

enum PrintWeekPage {
    /// A4 landscape in points.
    static let size = CGSize(width: 842, height: 595)
}

@MainActor
enum PrintWeek {
    static let intentionsKey = "printIntentions"

    static var includeIntentions: Bool {
        (UserDefaults.standard.object(forKey: intentionsKey) as? Bool) ?? true
    }

    /// Draws the week and writes it to `url` as a one page PDF. Returns false if the PDF could not be made.
    static func makePDF(db: Database, mon: String, intentions: Bool, to url: URL) -> Bool {
        let page = PrintableWeek(db: db, mon: mon, showIntentions: intentions)
            .frame(width: PrintWeekPage.size.width, height: PrintWeekPage.size.height)
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(PrintWeekPage.size)
        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            wrote = true
        }
        return wrote
    }

    static func fileName(mon: String) -> String {
        "Week of \(mon).pdf"
    }

    /// Makes the PDF in a temporary folder and opens it, ready to print.
    static func open(model: AppModel) {
        let mon = model.shownMonday
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Holocron print", isDirectory: true)
        // Clear away pages printed earlier, so old copies do not pile up in the temporary folder.
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName(mon: mon))
        if makePDF(db: model.db, mon: mon, intentions: includeIntentions, to: url) {
            NSWorkspace.shared.open(url)
        } else {
            model.showToast("Could not make the print page")
        }
    }

    /// Asks where to save, then writes the PDF there.
    static func save(model: AppModel) {
        let mon = model.shownMonday
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName(mon: mon)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if makePDF(db: model.db, mon: mon, intentions: includeIntentions, to: url) {
            model.showToast("Saved PDF")
        } else {
            model.showToast("Could not save the PDF")
        }
    }
}

// MARK: - The page

struct PrintableWeek: View {
    let db: Database
    let mon: String
    let showIntentions: Bool

    private let margin: CGFloat = 20
    private let labelW: CGFloat = 70
    private let gap: CGFloat = 3
    private let headerH: CGFloat = 38
    private let dayRowH: CGFloat = 18
    private let footerH: CGFloat = 12

    var body: some View {
        let wk = db.weekLetter(mon) ?? "A"
        let ps = db.periods
        let term = db.termOf(mon)
        let lead = term.map { "Term \($0.term) Week \(db.termWeek(mon) ?? 0)" } ?? "Outside term"
        let size = PrintWeekPage.size
        let colW = (size.width - 2 * margin - labelW - 5 * gap) / 5
        let count = CGFloat(max(ps.count, 1))
        let spare = size.height - 2 * margin - headerH - dayRowH - footerH - gap * (count + 2)
        let rowH = max(36, spare / count)

        VStack(alignment: .leading, spacing: gap) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(db.className).font(.system(size: 20, weight: .bold))
                Text(lead).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ink2)
                Text("\(shortDate(mon)) to \(shortDate(addDays(mon, 4))) \(String(yearOf(mon)))")
                    .font(.system(size: 11)).foregroundStyle(Color.ink2)
                Spacer()
                WeekBadge(letter: wk)
            }
            .frame(height: headerH, alignment: .bottom)

            HStack(spacing: gap) {
                Color.clear.frame(width: labelW, height: dayRowH)
                ForEach(0..<5, id: \.self) { i in
                    let d = addDays(mon, i)
                    HStack(spacing: 5) {
                        Text(Cal.weekdayLong[i]).font(.system(size: 10.5, weight: .semibold))
                        Text(shortDate(d)).font(.system(size: 10))
                    }
                    .frame(width: colW, height: dayRowH, alignment: .leading)
                }
            }

            ForEach(ps) { p in
                HStack(alignment: .top, spacing: gap) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 9.5, weight: .semibold))
                        Text("\(p.start) to \(p.end)").font(.system(size: 8)).foregroundStyle(Color.ink2)
                    }
                    .frame(width: labelW, alignment: .leading)
                    .padding(.top, 4)
                    ForEach(0..<5, id: \.self) { di in
                        PrintCell(db: db, date: addDays(mon, di), wk: wk, period: p,
                                  isFirst: p.period == ps.first?.period,
                                  showIntentions: showIntentions)
                            .frame(width: colW, height: rowH, alignment: .topLeading)
                    }
                }
            }

            Spacer(minLength: 0)
            HStack {
                Text("Printed \(dLong(todayISO()))").font(.system(size: 7.5)).foregroundStyle(Color.ink3)
                Spacer()
                Text("Holocron").font(.system(size: 7.5)).foregroundStyle(Color.ink3)
            }
            .frame(height: footerH)
        }
        .padding(margin)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(Color.white)
    }
}

private struct PrintCell: View {
    let db: Database
    let date: String
    let wk: String
    let period: Period
    let isFirst: Bool
    let showIntentions: Bool

    /// Why the timetable is not running on this day, if it is not (camp, carnival, a day off).
    private var dayNote: String? {
        if db.isNonTeaching(date) {
            let l = db.nonTeachingLabel(date)
            return l.isEmpty ? "No school" : l
        }
        if let ov = db.overrideOf(date), !ov.s("type").isEmpty, ov.s("type") != "Normal" {
            let n = ov.s("note")
            return n.isEmpty ? ov.s("type") : ov.s("type") + ": " + n
        }
        if db.termOf(date) == nil { return "Not in term" }
        return nil
    }

    var body: some View {
        if let note = dayNote {
            ZStack(alignment: .topLeading) {
                Color(red: 0.95, green: 0.95, blue: 0.96)
                if isFirst {
                    Text(note)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.ink2)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            lesson
        }
    }

    /// The summary in plain black, so any link or other styling in the text does not change its colour.
    private func summaryText(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        a.swiftUI.foregroundColor = Color.black
        return a
    }

    private var lesson: some View {
        let subj = db.plannedSubject(date, period.period, fallbackWeek: wk)
        let info = db.subjectInfo(subj)
        let tone = subj.isEmpty ? Tone.unset : db.tone(forSubject: subj)
        let c = db.content(date, period.period)
        let li = c.li.trimmed
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(tone.barColor).frame(width: 6, height: 6)
                Text(subj.isEmpty ? "Not set" : subj)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tone.inkColor)
                    .lineLimit(1)
            }
            if info.isRelease {
                Text("Release").font(.system(size: 8)).foregroundStyle(tone.inkColor.opacity(0.75))
            } else {
                if !c.summary.isEmpty {
                    Text(summaryText(c.summary))
                        .font(.system(size: 8))
                        .lineLimit(6)
                }
                if showIntentions && !li.isEmpty {
                    Text("LI: " + li)
                        .font(.system(size: 7))
                        .foregroundStyle(Color.ink2)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tone.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
