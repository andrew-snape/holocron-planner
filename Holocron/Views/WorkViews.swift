import SwiftUI
import AppKit
import PDFKit
import QuickLookUI
import UniformTypeIdentifiers

// MARK: - Photos of students' work
//
// The Work tab on a student, the Class gallery, the Add work sheet and the edit sheet. The image is
// read for display only. Grid thumbnails are made in memory and never written to disk, and Quick Look
// shows the full file as it is.

/// In-memory thumbnails for the grid. The file on disk is read, never changed.
enum WorkThumbs {
    private static let cache = NSCache<NSString, NSImage>()

    /// Decodes off the main thread. The key includes the modification date, so a file replaced by Import is drawn again.
    static func imageAsync(for url: URL, maxSide: CGFloat = 420) async -> NSImage? {
        await Task.detached(priority: .utility) { image(for: url, maxSide: maxSide) }.value
    }

    static func image(for url: URL, maxSide: CGFloat = 420) -> NSImage? {
        let stamp = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(Int(maxSide))|\(stamp)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        var out: NSImage? = nil
        if url.pathExtension.lowercased() == "pdf" {
            if let page = PDFDocument(url: url)?.page(at: 0) {
                out = page.thumbnail(of: NSSize(width: maxSide, height: maxSide), for: .mediaBox)
            }
        } else if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxSide,
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) {
                out = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
        }
        if let out { cache.setObject(out, forKey: key) }
        return out
    }
}

/// A grid thumbnail. It shows a spinner while the picture decodes in the background, then the picture or "No preview".
struct WorkThumbImage: View {
    var url: URL
    @State private var image: NSImage? = nil
    @State private var finished = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if finished {
                Label("No preview", systemImage: "photo")
                    .font(.label).foregroundStyle(Color.ink2)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: url.path) {
            finished = false
            image = await WorkThumbs.imageAsync(for: url)
            finished = true
        }
    }
}

/// The date range of a term, or nil when its dates do not make sense.
func workTermRange(_ t: Term) -> ClosedRange<String>? {
    t.start <= t.end ? t.start...t.end : nil
}

/// Newest first, by date and then when it was added.
func workNewestFirst(_ a: Row, _ b: Row) -> Bool {
    (a.s("date") + a.s("added")) > (b.s("date") + b.s("added"))
}

/// Apple's Quick Look preview of one file, at full size. The file is only shown, never changed.
struct QuickLookView: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? NSURL) != (url as NSURL) { view.previewItem = url as NSURL }
    }
}

// MARK: - Filters

struct WorkFilterBar: View {
    @Environment(AppModel.self) private var model
    @Binding var filter: WorkFiles.Filter
    var showStudent: Bool

    var body: some View {
        let db = model.db
        FlowLayout(spacing: 8) {
            Picker("Subject", selection: $filter.subject) {
                Text("All subjects").tag("")
                ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 180)
            .accessibilityLabel("Filter by subject")

            Picker("Term", selection: Binding(
                get: { filter.termID },
                set: { id in
                    filter.termID = id
                    filter.range = db.termsSorted.first(where: { $0.id == id }).flatMap(workTermRange)
                })) {
                Text("All terms").tag("")
                ForEach(db.termsSorted) { t in Text("Term \(t.term), \(t.year)").tag(t.id) }
            }
            .labelsHidden()
            .frame(maxWidth: 160)
            .accessibilityLabel("Filter by term")

            Picker("Unit", selection: $filter.unit) {
                Text("All units").tag("")
                ForEach(db.unitsSorted, id: \Row.["id"]) { u in
                    Text(u.s("title").isEmpty ? "Untitled unit" : u.s("title")).tag(u.s("id"))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)
            .accessibilityLabel("Filter by unit")

            if showStudent {
                Picker("Student", selection: $filter.student) {
                    Text("All students").tag("")
                    ForEach(db.roster) { s in Text(s.fullName).tag(s.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
                .accessibilityLabel("Filter by student")
            }

            TextField("Search task or caption", text: $filter.search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 210)
        }
    }
}

// MARK: - Grid and tiles

struct WorkGrid: View {
    var rows: [Row]
    var showStudent: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 12, alignment: .top)],
                  alignment: .leading, spacing: 12) {
            ForEach(rows, id: \Row.["id"]) { r in
                WorkTile(row: r, showStudent: showStudent)
            }
        }
    }
}

struct WorkTile: View {
    @Environment(AppModel.self) private var model
    var row: Row
    var showStudent: Bool
    @State private var previewURL: URL? = nil
    @State private var confirmRemove = false

    var body: some View {
        let db = model.db
        let url = model.folder.workFileURL(for: row)
        let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let sharedCount = db.rows(.work).filter { $0.s("file") == row.s("file") && $0.s("id") != row.s("id") }.count
        let title = row.s("task").isEmpty ? (row.s("caption").isEmpty ? "Work" : row.s("caption")) : row.s("task")
        let student = db.student(row.s("student_id")) == nil ? "Not on the roll" : db.studentName(row.s("student_id"))

        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle().fill(Color.fillFaint)
                if let url, exists {
                    WorkThumbImage(url: url)
                } else {
                    Label(url == nil ? "No file" : "File not found", systemImage: "photo")
                        .font(.label).foregroundStyle(Color.ink2)
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .accessibilityLabel("Photo of \(title)")

            Text(title).font(.body1Semibold).lineLimit(2)
            HStack(spacing: 6) {
                if !row.s("subject").isEmpty { TagLabel(text: row.s("subject")) }
                Text(shortDate(row.s("date"))).font(.label).foregroundStyle(Color.ink2)
            }
            if showStudent {
                Text(student).font(.label).foregroundStyle(Color.ink2).lineLimit(1)
            }
            if !row.s("caption").isEmpty && !row.s("task").isEmpty {
                Text(row.s("caption")).font(.label).foregroundStyle(Color.ink2).lineLimit(2)
            }

            Menu {
                actions(url: url, exists: exists)
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
                    .font(.caption1)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Actions for \(title)")
        }
        .card(padding: 10)
        .contextMenu { actions(url: url, exists: exists) }
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) {
            if let previewURL {
                SheetFrame(title: title, width: 760) {
                    QuickLookView(url: previewURL)
                        .frame(height: 560)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
            }
        }
        .confirmationDialog("Remove this photo?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { remove() }
        } message: {
            Text(sharedCount > 0
                 ? "The photo moves to the removed folder inside the work folder. Other students who share it keep their copy. Nothing is deleted."
                 : "The photo moves to the removed folder inside the work folder. Nothing is deleted.")
        }
    }

    /// The tile's actions, in the Actions menu and in the right-click menu.
    @ViewBuilder
    private func actions(url: URL?, exists: Bool) -> some View {
        Button("Quick Look") { previewURL = url }
            .disabled(!exists)
        Button("Edit details…") { model.sheet = .editWork(id: row.s("id")) }
        Button("Show in Finder") {
            if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        .disabled(!exists)
        Divider()
        Button("Remove…", role: .destructive) { confirmRemove = true }
    }

    private func remove() {
        do {
            try model.removeWork(row)
            model.showToast("Removed")
        } catch {
            model.showToast((error as? WorkError)?.message ?? "The photo could not be removed")
        }
    }
}

// MARK: - The Work tab on a student

struct StudentWorkTab: View {
    @Environment(AppModel.self) private var model
    var sid: String
    @State private var filter = WorkFiles.Filter()

    var body: some View {
        let rows = model.db.logRows(.work, student: sid)
        let shown = rows.filter { filter.matches($0) }.sorted(by: workNewestFirst)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { model.sheet = .addWork(studentID: sid) } label: {
                    Label("Add work…", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
            }
            WorkFilterBar(filter: $filter, showStudent: false)
            if rows.isEmpty {
                EmptyNote(title: "No work yet",
                          message: "Add photos or scans of this student's work. Captions can be used in report drafts.")
            } else if shown.isEmpty {
                EmptyNote(title: "Nothing matches", message: "Try another subject, term or search.")
            } else {
                WorkGrid(rows: shown, showStudent: false)
            }
        }
    }
}

// MARK: - Class gallery

struct WorkGalleryView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = WorkFiles.Filter()

    var body: some View {
        let db = model.db
        let all = db.rows(.work)
        let onRoll = Set(db.roster.map { $0.id })
        let matched = all.filter { filter.matches($0) }.sorted(by: workNewestFirst)
        let linked = matched.filter { onRoll.contains($0.s("student_id")) }
        let unlinked = matched.filter { !onRoll.contains($0.s("student_id")) }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkFilterBar(filter: $filter, showStudent: true)

                if all.isEmpty {
                    EmptyNote(title: "No work yet",
                              message: "Add photos or scans of students' work. Choose the students for each one, then find it here or on the student's Work tab.")
                } else if linked.isEmpty && unlinked.isEmpty {
                    EmptyNote(title: "Nothing matches", message: "Try another subject, term, unit or search.")
                } else {
                    WorkGrid(rows: linked, showStudent: true)
                }

                if !unlinked.isEmpty {
                    SectionTitle("Unlinked")
                    Text("These pieces belong to students who are no longer on the roll. Their files are kept, but they are not shown as pictures here.")
                        .font(.caption1).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 6) {
                        ForEach(unlinked, id: \Row.["id"]) { r in
                            HStack(spacing: 8) {
                                Text(shortDate(r.s("date"))).font(.caption1).foregroundStyle(Color.ink2)
                                if !r.s("subject").isEmpty { TagLabel(text: r.s("subject")) }
                                Text(r.s("task").isEmpty ? (r.s("caption").isEmpty ? "Work" : r.s("caption")) : r.s("task"))
                                    .font(.body1).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .card(padding: 10)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Work")
        .navigationSubtitle("\(linked.count) \(linked.count == 1 ? "piece" : "pieces")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.sheet = .addWork(studentID: nil) } label: { Label("Add work…", systemImage: "plus") }
                    .help("Add photos or scans of students' work")
            }
        }
    }
}

// MARK: - Shared detail fields

/// The lesson, unit, task, caption and linked result for a piece of work. Used by the Add and Edit sheets.
struct WorkDetailFields: View {
    @Environment(AppModel.self) private var model
    @Binding var date: String
    @Binding var period: String
    @Binding var subject: String
    @Binding var unitID: String
    @Binding var task: String
    @Binding var caption: String
    @Binding var assessmentID: String
    /// Results to link to. Empty when more than one student is chosen, because a result belongs to one student.
    var assessments: [Row]
    var linkNote: String = ""
    /// Fills the unit and subject from the timetable when the date or period changes. Off when editing,
    /// so a saved row is shown as it was.
    var autofill = true

    var body: some View {
        let db = model.db
        VStack(alignment: .leading, spacing: 12) {
            DateField(label: "Date", iso: $date)
                .onChange(of: date) { _, new in
                    guard autofill else { return }
                    if unitID.isEmpty, let u = db.unitOn(new) { unitID = u.s("id") }
                    if let n = Int(period), subject.isEmpty {
                        let planned = db.plannedSubject(new, n)
                        if !planned.isEmpty { subject = planned }
                    }
                }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Lesson period")
                    Picker("Lesson period", selection: $period) {
                        Text("No period").tag("")
                        ForEach(db.index(.periods).periods) { p in
                            Text(p.name.isEmpty ? "Period \(p.period)" : p.name).tag(String(p.period))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: period) { _, new in
                        guard autofill else { return }
                        if let n = Int(new), subject.isEmpty {
                            let planned = db.plannedSubject(date, n)
                            if !planned.isEmpty { subject = planned }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Subject")
                    Picker("Subject", selection: $subject) {
                        Text("Not set").tag("")
                        ForEach(db.subjectNames, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Unit")
                    Picker("Unit", selection: $unitID) {
                        Text("No unit").tag("")
                        ForEach(db.unitsSorted, id: \Row.["id"]) { u in
                            Text(u.s("title").isEmpty ? "Untitled unit" : u.s("title")).tag(u.s("id"))
                        }
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: "Task")
                TextField("For example, Persuasive poster", text: $task)
                    .textFieldStyle(.roundedBorder)
            }
            NoteBox(label: "Caption", hint: "Can be used in report drafts", text: $caption, lines: 2,
                    placeholder: "What the work shows, in a sentence or two")

            if !assessments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(text: "Linked result", hint: linkNote)
                    Picker("Linked result", selection: $assessmentID) {
                        Text("None").tag("")
                        ForEach(assessments, id: \Row.["id"]) { a in
                            Text([shortDate(a.s("date")), a.s("subject"), a.s("task"), a.s("result")]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                                .tag(a.s("id"))
                        }
                    }
                    .labelsHidden()
                }
            }
        }
    }
}

// MARK: - Add work

struct AddWorkSheet: View {
    @Environment(AppModel.self) private var model
    var studentID: String?
    @State private var drafts: [WorkDraft] = []
    @State private var results: [UUID: WorkImportResult] = [:]
    @State private var summary = ""
    @State private var targeted = false

    var body: some View {
        let db = model.db
        let ready = drafts.contains { $0.problem.isEmpty && !$0.students.isEmpty }
        SheetFrame(title: "Add work",
                   subtitle: "Choose the students for each photo. Files are copied into the student folder. Your originals are not changed.",
                   width: 640,
                   dirty: !drafts.isEmpty,
                   discardMessage: "The photos have not been added yet.",
                   confirmTitle: drafts.isEmpty ? nil : "Add",
                   confirmDisabled: !ready,
                   onConfirm: confirm) {
            HStack(spacing: 12) {
                Button { chooseFiles() } label: {
                    Label("Choose files…", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                Text("JPEG, PNG, HEIC, TIFF or PDF").font(.caption1).foregroundStyle(Color.ink2)
                Spacer(minLength: 0)
            }

            if drafts.isEmpty && summary.isEmpty {
                dropZone
            }

            ForEach($drafts) { $d in
                draftCard($d, db: db)
            }

            if !summary.isEmpty {
                Label(summary, systemImage: "checkmark.circle")
                    .font(.body1Semibold)
                    .foregroundStyle(Color.ink2)
            }
        }
    }

    /// Add is offered only while there are files on the list. Once they are all added, the sheet only closes.
    private var confirm: (() -> Void)? {
        drafts.isEmpty ? nil : { runImport() }
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 22)).foregroundStyle(Color.ink2)
            Text("Drop photos or PDFs here").font(.body2Semibold)
            Text("or choose files above").font(.caption1).foregroundStyle(Color.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(targeted ? Color.appBlue.opacity(0.12) : Color.fillFaint)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(targeted ? Color.appBlue : Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [5])))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers, _ in handleDrop(providers) }
        .accessibilityLabel("Drop photos or PDFs here")
    }

    @ViewBuilder
    private func draftCard(_ d: Binding<WorkDraft>, db: Database) -> some View {
        let v = d.wrappedValue
        let copies = db.rows(.work)
        let already = v.students.filter { WorkFiles.hasCopy(copies, student: $0, sha: v.sha) }
        let chosen = v.students.count == 1 ? db.logRows(.assessments, student: v.students[0]) : []

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: v.problem.isEmpty ? "photo" : "exclamationmark.triangle")
                    .foregroundStyle(v.problem.isEmpty ? Color.ink2 : Color.appRed)
                Text(v.name).font(.body1Semibold).lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    drafts.removeAll { $0.id == v.id }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ink2)
                }
                .buttonStyle(.plain)
                .help("Take this file off the list. It is not copied.")
                .accessibilityLabel("Take \(v.name) off the list")
            }

            if !v.problem.isEmpty {
                Text(v.problem).font(.caption1).foregroundStyle(Color.appRed)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Students", hint: "Choose one, or several for a group photo")
                    FlowLayout(spacing: 6) {
                        ForEach(db.roster) { s in
                            let on = v.students.contains(s.id)
                            Button {
                                var cur = d.wrappedValue.students
                                if let i = cur.firstIndex(of: s.id) { cur.remove(at: i) } else { cur.append(s.id) }
                                d.students.wrappedValue = cur
                            } label: {
                                HStack(spacing: 4) {
                                    if on { Image(systemName: "checkmark").font(.smallBold) }
                                    Text(s.fullName)
                                }
                                    .font(.labelMedium)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(on ? Color.appBlue : Color.fill)
                                    .foregroundStyle(on ? Color.onAccent : Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    if !already.isEmpty {
                        Label("\(already.map { db.studentName($0) }.joined(separator: ", ")) already has this photo. It will not be added again for them.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption1).foregroundStyle(Color.appAmber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                WorkDetailFields(date: d.date, period: d.period, subject: d.subject, unitID: d.unitID,
                                 task: d.task, caption: d.caption, assessmentID: d.assessmentID,
                                 assessments: chosen,
                                 linkNote: "Only when one student is chosen")
            }

            if let r = results[v.id] {
                Label(r.message, systemImage: r.succeeded ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.caption1)
                    .foregroundStyle(r.succeeded ? Color.appGreen : Color.appRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func chooseFiles() {
        let p = NSOpenPanel()
        p.title = "Choose photos of work"
        p.message = "JPEG, PNG, HEIC, TIFF or PDF. The files are copied into the student folder. Your originals are not changed."
        p.prompt = "Choose"
        p.allowedContentTypes = TextScan.imageTypes
        p.allowsMultipleSelection = true
        if p.runModal() == .OK { addFiles(p.urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url { urls.append(url) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { addFiles(urls) }
        return !providers.isEmpty
    }

    private func addFiles(_ urls: [URL]) {
        let preset = studentID.map { [$0] } ?? []
        for u in urls {
            var d = AppModel.workDraft(for: u)
            d.students = preset
            d.unitID = model.db.unitOn(d.date)?.s("id") ?? ""
            drafts.append(d)
        }
        summary = ""
    }

    private func runImport() {
        let todo = drafts.filter { $0.problem.isEmpty && !$0.students.isEmpty }
        let outcomes = model.importWork(todo)
        var done = Set<UUID>()
        for (d, r) in zip(todo, outcomes) {
            results[d.id] = r
            if r.succeeded { done.insert(d.id) }
        }
        drafts.removeAll { done.contains($0.id) }
        let added = outcomes.filter { $0.succeeded }.count
        let failed = outcomes.count - added
        summary = "\(added) \(added == 1 ? "file" : "files") added" + (failed > 0 ? ", \(failed) could not be added" : "") + "."
        if !outcomes.isEmpty && failed == 0 { model.showToast("Added") }
    }
}

// MARK: - Edit details

struct EditWorkSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var rowID: String
    @State private var loaded = false
    @State private var date = todayISO()
    @State private var period = ""
    @State private var subject = ""
    @State private var unitID = ""
    @State private var task = ""
    @State private var caption = ""
    @State private var assessmentID = ""

    var body: some View {
        let db = model.db
        if let row = db.rows(.work).first(where: { $0.s("id") == rowID }) {
            let sid = row.s("student_id")
            let onRoll = db.student(sid) != nil
            SheetFrame(title: "Edit work", subtitle: onRoll ? db.studentName(sid) : "Not on the roll", width: 580,
                       confirmTitle: "Save", onConfirm: { save(row) }) {
                WorkDetailFields(date: $date, period: $period, subject: $subject, unitID: $unitID,
                                 task: $task, caption: $caption, assessmentID: $assessmentID,
                                 assessments: onRoll ? db.logRows(.assessments, student: sid) : [],
                                 autofill: false)
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                date = row.s("date"); period = row.s("period"); subject = row.s("subject")
                unitID = row.s("unit_id"); task = row.s("task"); caption = row.s("caption")
                assessmentID = row.s("assessment_id")
            }
        } else {
            SheetFrame(title: "Edit work", width: 420) {
                EmptyNote(title: "This work is no longer here", message: "It may have been removed.")
            }
        }
    }

    private func save(_ row: Row) {
        let values = (date, period, subject, unitID, task.trimmed, caption.trimmed, assessmentID)
        model.updateWork(id: row.s("id")) { r in
            r["date"] = values.0
            r["period"] = values.1
            r["subject"] = values.2
            r["unit_id"] = values.3
            r["task"] = values.4
            r["caption"] = values.5
            r["assessment_id"] = values.6
        }
        model.showToast("Saved")
        dismiss()
    }
}
