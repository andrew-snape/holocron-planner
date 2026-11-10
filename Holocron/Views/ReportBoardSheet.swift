import SwiftUI

/// Report season at a glance: a row for each student, with their judgements, general comment and dot points.
struct ReportBoardSheet: View {
    @Environment(AppModel.self) private var model
    var sem: String

    var body: some View {
        let db = model.db
        let subjects = db.reportSubjects
        SheetFrame(title: "Report progress", subtitle: "Semester " + sem, width: 700, cancelTitle: "Close") {
            Text("General comment: Ready is \(ReportBoard.wordRange.lowerBound) to \(ReportBoard.wordRange.upperBound) words. Dot points: Ready is \(ReportBoard.pointRange.lowerBound) to \(ReportBoard.pointRange.upperBound) points. Anything else with text is a Draft.")
                .font(.caption1).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if db.roster.isEmpty {
                EmptyNote(title: "No students on the roll", message: "Add them under Students first.")
            } else {
                header
                VStack(spacing: 0) {
                    ForEach(db.roster) { s in
                        row(s, subjects: subjects, db: db)
                        Divider()
                    }
                }
                summary(db)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Student").frame(width: 150, alignment: .leading)
            Text("Judgements").frame(width: 90, alignment: .leading)
            Text("General comment").frame(width: 170, alignment: .leading)
            Text("English").frame(width: 70, alignment: .leading)
            Text("Maths").frame(width: 70, alignment: .leading)
            Spacer(minLength: 0)
        }
        .font(.labelSemibold).foregroundStyle(Color.ink2)
        .accessibilityHidden(true)
    }

    private func row(_ s: Student, subjects: [String], db: Database) -> some View {
        let general = db.generalComment(s.id, sem: sem)
        let gs = ReportBoard.generalStatus(general)
        let english = db.reportText(s.id, sem: sem, "english")
        let maths = db.reportText(s.id, sem: sem, "maths")
        let judged = ReportBoard.judged(subjects) { db.judgement(s.id, sem: sem, subject: $0).achievement }
        return HStack(spacing: 10) {
            Text(s.fullName).font(.body1Medium).lineLimit(1)
                .frame(width: 150, alignment: .leading)
                .help(s.fullName)
            Text("\(judged) of \(subjects.count)")
                .font(.caption1)
                .foregroundStyle(judged == subjects.count && !subjects.isEmpty ? Color.appGreen : Color.ink2)
                .frame(width: 90, alignment: .leading)
            HStack(spacing: 6) {
                StatusPill(status: gs)
                if gs != .none {
                    Text("\(ReportBoard.words(general)) words").font(.label).foregroundStyle(Color.ink2)
                }
            }
            .frame(width: 170, alignment: .leading)
            StatusPill(status: ReportBoard.pointsStatus(english)).frame(width: 70, alignment: .leading)
            StatusPill(status: ReportBoard.pointsStatus(maths)).frame(width: 70, alignment: .leading)
            Spacer(minLength: 0)
            Menu("Copy for SIMON") {
                Button("General comment") { model.copyText(general, toast: "Copied the general comment") }
                    .disabled(gs == .none)
                Button("English points") { model.copyText(DotPointDrafter.forSIMON(english), toast: "Copied with %* dot points") }
                    .disabled(english.trimmed.isEmpty)
                Button("Mathematics points") { model.copyText(DotPointDrafter.forSIMON(maths), toast: "Copied with %* dot points") }
                    .disabled(maths.trimmed.isEmpty)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Copy a comment ready to paste into SIMON")
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
    }

    private func summary(_ db: Database) -> some View {
        let n = db.roster.count
        let ready = db.roster.filter { ReportBoard.generalStatus(db.generalComment($0.id, sem: sem)) == .ready }.count
        return Text("\(ready) of \(n) general comments are ready.")
            .font(.caption1Medium).foregroundStyle(Color.ink2)
    }
}

private struct StatusPill: View {
    var status: ReportBoard.Status

    var body: some View {
        let color: Color = status == .ready ? .appGreen : (status == .draft ? .appAmber : .ink3)
        Text(status.rawValue)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(status == .none ? Color.ink2 : Color.primary)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(status == .none ? 0.12 : 0.22), in: Capsule())
    }
}
