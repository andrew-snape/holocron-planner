import Foundation
import AppKit

// MARK: - A day as Markdown
//
// Everything on for one day (times, subjects, summaries and full lesson plans, plus the day's
// devotion), written as Markdown so it can be pasted into a school LMS, for example for a
// relief teacher. Nothing about students is included.

extension Database {
    func dayMarkdown(_ date: String, includeDevotion: Bool) -> String {
        var out: [String] = []
        var sub = className
        if let t = termOf(date) {
            sub += ", Term \(t.term) Week \(termWeek(date) ?? 0)"
            if let wk = weekLetter(date) { sub += " (Week \(wk))" }
        }
        out.append("# \(longDate(date)) \(yearOf(date))")
        out.append("")
        out.append(sub)

        let ps = periods
        for (idx, p) in ps.enumerated() {
            out += lessonMarkdown(date, p, includeDevotion: includeDevotion)
            if idx + 1 < ps.count {
                let next = ps[idx + 1]
                let gap = mins(p.end, next.start)
                if gap > 0 {
                    let label = gap >= 15 ? (p.end < "12:00" ? "Eating and recess" : "Eating and lunch") : "Eating"
                    out += ["", "*\(fmtTime(p.end)) to \(fmtTime(next.start)): \(label)*"]
                }
            }
        }
        return out.joined(separator: "\n") + "\n"
    }

    private func lessonMarkdown(_ date: String, _ p: Period, includeDevotion: Bool) -> [String] {
        let subj = plannedSubject(date, p.period)
        let info = subjectInfo(subj)
        let c = content(date, p.period)
        var L: [String] = ["", "## \(p.name) (\(fmtTime(p.start)) to \(fmtTime(p.end)))", ""]

        let kind = info.isRelease ? "release lesson with the specialist teacher" : "face to face, \(p.minutes) minutes"
        L.append("**\(subj.isEmpty ? "Not set" : subj)** (\(kind))")

        if !info.isRelease && c.isEmpty {
            L += ["", "*No lesson details entered yet.*"]
        }

        L += mdPara("Summary", c.summary)
        if subj == "TDL", let u = unitOn(date), !u.s("title").isEmpty {
            L += mdPara("Unit", u.s("title"))
        }
        L += mdPara("Learning intention", c.li)
        let sc = linesOf(c.sc)
        if !sc.isEmpty {
            L += ["", "**Success criteria:**", ""]
            L += sc.map { "- " + mdStripBullet($0) }
        }
        L += mdPara("Tuning in", c.tuning)
        L += mdPara("Explicit teaching", c.teaching)
        L += mdPara("Independent work", c.independent)
        L += mdPara("Reflection", c.reflection)

        let res = linesOf(c.resources)
        if !res.isEmpty {
            L += ["", "**Resources:**", ""]
            for line in res { L.append("- " + mdResource(line)) }
        }

        let codes = c.codes.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        if !codes.isEmpty { L += ["", "**Curriculum:** " + codes.joined(separator: ", ")] }
        let atl = listOf(c.atl), profile = listOf(c.profile)
        if !atl.isEmpty { L += ["", "**ATL skills:** " + atl.joined(separator: ", ")] }
        if !profile.isEmpty { L += ["", "**Learner profile:** " + profile.joined(separator: ", ")] }

        if includeDevotion, subj == "Circle Time" || c.summary.hasPrefix("Circle Time"),
           let d = rows(.devotion).first(where: { $0.s("date") == date }) {
            L += devotionMarkdown(d)
        }
        return L
    }

    private func devotionMarkdown(_ d: Row) -> [String] {
        var L: [String] = ["", "### Devotion" + (d.s("theme").isEmpty ? "" : ": " + d.s("theme"))]
        L += mdPara("Scripture", d.s("scripture"))
        L += mdPara("Focus", d.s("focus"))
        L += mdPara("Greeting and check-in", d.s("greeting"))
        L += mdPara("Values and expectations", d.s("values"))
        let reading = linesOf(d.s("reading"))
        if !reading.isEmpty {
            L += ["", "**Reading:**", ""]
            L += reading.map { "> " + $0 }
        }
        L += mdPara("The message", d.s("message"))
        let qs = linesOf(d.s("questions"))
        if !qs.isEmpty {
            L += ["", "**Reflection questions:**", ""]
            L += qs.map { "- " + mdStripBullet($0) }
        }
        L += mdPara("Prayer", d.s("prayer"))
        let primer = d.s("primer_name")
        L += mdPara(primer.isEmpty ? "Positive primer" : "Positive primer (Berry Street: \(primer))", d.s("primer"))
        L += mdPara("Primer note", d.s("primer_note"))
        L += mdPara("Transition", d.s("transition"))
        return L
    }
}

// MARK: - Markdown helpers

/// "**Label:** text" for one line, or the label on its own line followed by a paragraph per line.
private func mdPara(_ label: String, _ text: String) -> [String] {
    let lines = linesOf(text)
    guard !lines.isEmpty else { return [] }
    if lines.count == 1 { return ["", "**\(label):** \(lines[0])"] }
    var L = ["", "**\(label):**"]
    for l in lines { L += ["", l] }
    return L
}

/// Drops a leading "- ", "* " or bullet so a list item is not bulleted twice.
private func mdStripBullet(_ s: String) -> String {
    guard let f = s.first, "-*\u{2022}".contains(f) else { return s }
    let rest = s.dropFirst()
    guard rest.first == " " else { return s }
    return rest.trimmingCharacters(in: .whitespaces)
}

/// A resource line is a label then a link ("Slides https://..."). Links become Markdown links.
private func mdResource(_ line: String) -> String {
    guard let r = line.range(of: "https?://\\S+", options: .regularExpression) else { return line }
    var raw = String(line[r])
    while let last = raw.last, ").,".contains(last) { raw.removeLast() }
    var label = line.replacingCharacters(in: r, with: "")
    label = label.trimmingCharacters(in: CharacterSet(charactersIn: " \t:|-\u{2013}"))
    if label.isEmpty {
        var host = URL(string: raw)?.host ?? raw
        if host.hasPrefix("www.") { host.removeFirst(4) }
        label = host
    }
    label = label.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
    return "[\(label)](\(raw))"
}

// MARK: - Copy to the clipboard

extension AppModel {
    /// Puts the day's lessons and times on the clipboard as rich text (HTML and RTF), so they paste
    /// with headings, bold labels, bullets and clickable links. Plain text is kept as a fallback.
    func copyDay(_ date: String) {
        guard db.runsNormally(date) else { showToast("No lessons on this day"); return }
        let md = db.dayMarkdown(date, includeDevotion: isEnabled(.devotion))
        let html = htmlFromMarkdown(md)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(plainFromMarkdown(md), forType: .string)
        pb.setString(html, forType: .html)
        if let attr = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil),
           let rtf = try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pb.setData(rtf, forType: .rtf)
        }
        showToast("Copied the day as rich text")
    }
}

/// Converts the Markdown made by dayMarkdown into a plain HTML document.
func htmlFromMarkdown(_ md: String) -> String {
    var out: [String] = []
    var inList = false
    var inQuote = false

    func closeBlocks() {
        if inList { out.append("</ul>"); inList = false }
        if inQuote { out.append("</blockquote>"); inQuote = false }
    }

    for raw in md.components(separatedBy: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { closeBlocks(); continue }

        if line.hasPrefix("- ") {
            if !inList { closeBlocks(); out.append("<ul>"); inList = true }
            out.append("<li>\(mdInlineHTML(String(line.dropFirst(2))))</li>")
            continue
        }
        if line.hasPrefix("> ") {
            if !inQuote { closeBlocks(); out.append("<blockquote>"); inQuote = true }
            out.append("<p>\(mdInlineHTML(String(line.dropFirst(2))))</p>")
            continue
        }

        closeBlocks()
        if line.hasPrefix("### ") {
            out.append("<h3>\(mdInlineHTML(String(line.dropFirst(4))))</h3>")
        } else if line.hasPrefix("## ") {
            out.append("<h2>\(mdInlineHTML(String(line.dropFirst(3))))</h2>")
        } else if line.hasPrefix("# ") {
            out.append("<h1>\(mdInlineHTML(String(line.dropFirst(2))))</h1>")
        } else {
            out.append("<p>\(mdInlineHTML(line))</p>")
        }
    }
    closeBlocks()

    return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>\n"
        + out.joined(separator: "\n") + "\n</body></html>"
}

/// Escapes one line of text and turns the Markdown inline marks (bold, italic, links) into HTML.
private func mdInlineHTML(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
    t = mdReplace(t, "\\[([^\\]]+)\\]\\(([^)\\s]+)\\)", "<a href=\"$2\">$1</a>")
    t = mdReplace(t, "\\*\\*(.+?)\\*\\*", "<strong>$1</strong>")
    t = mdReplace(t, "(?<![*\\w])\\*(?!\\s)(.+?)\\*", "<em>$1</em>")
    return t
}

/// The same content as plain text, for apps that only take text: no symbols, links shown with their address.
private func plainFromMarkdown(_ md: String) -> String {
    md.components(separatedBy: "\n").map { line -> String in
        var s = line
        for p in ["### ", "## ", "# ", "> ", "- "] where s.hasPrefix(p) {
            s = String(s.dropFirst(p.count))
            break
        }
        s = mdReplace(s, "\\[([^\\]]+)\\]\\(([^)\\s]+)\\)", "$1 ($2)")
        s = mdReplace(s, "\\*\\*(.+?)\\*\\*", "$1")
        s = mdReplace(s, "(?<![*\\w])\\*(?!\\s)(.+?)\\*", "$1")
        return s
    }.joined(separator: "\n")
}

private func mdReplace(_ s: String, _ pattern: String, _ template: String) -> String {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
    return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
}
