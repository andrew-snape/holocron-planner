import Foundation

// MARK: - Importing and keeping photos of students' work
//
// The teacher chooses each student by hand. A file chosen for several students is copied once and
// each student gets a row that points to it. The copy is made first, then the rows are added and
// saved. If the rows cannot be saved, the copy is left where it is and the rows are taken back out.
// The original file is never moved or changed.

struct WorkError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// One file being added on the Add work sheet, before anything is saved.
struct WorkDraft: Identifiable {
    let id = UUID()
    var url: URL
    /// Why the file cannot be added, or empty when it can.
    var problem: String = ""
    /// SHA256 of the file, worked out when it is chosen.
    var sha: String = ""
    var students: [String] = []
    var date: String = todayISO()
    var period: String = ""
    var subject: String = ""
    var unitID: String = ""
    var task: String = ""
    var caption: String = ""
    /// A result from the assessments file. Only used when one student is chosen.
    var assessmentID: String = ""

    var name: String { url.lastPathComponent }
}

/// What happened to one file on the Add work sheet.
struct WorkImportResult {
    var name: String
    /// Students who now have the file.
    var added: Int
    /// Students who already had this exact file, so were not given it again.
    var alreadyHad: [String]
    var message: String
    /// True when the file was saved for at least one student and nothing was left out.
    var succeeded: Bool
}

extension AppModel {
    /// Checks a chosen file and works out its SHA256, so the sheet can warn about duplicates straight away.
    /// Nothing is copied here.
    static func workDraft(for url: URL) -> WorkDraft {
        var d = WorkDraft(url: url)
        do {
            _ = try WorkFiles.check(url)
            d.sha = try WorkFiles.sha256(of: url)
        } catch WorkFiles.Failure.unsupportedType {
            d.problem = "\(url.lastPathComponent) is not a JPEG, PNG, HEIC, TIFF or PDF file."
        } catch {
            d.problem = "\(url.lastPathComponent) could not be read."
        }
        return d
    }

    /// Adds each file for the students chosen. Each file gets its own result.
    func importWork(_ drafts: [WorkDraft]) -> [WorkImportResult] {
        drafts.map { importWorkFile($0) }
    }

    private func importWorkFile(_ d: WorkDraft) -> WorkImportResult {
        func fail(_ text: String) -> WorkImportResult {
            WorkImportResult(name: d.name, added: 0, alreadyHad: [], message: text, succeeded: false)
        }
        guard d.problem.isEmpty else { return fail(d.problem) }
        guard !d.students.isEmpty else { return fail("Choose at least one student.") }
        // Refuse before anything is copied when the work file could not be read earlier.
        guard canWrite(.work) else {
            return fail("The work file could not be read, so nothing was added. Your photo was not changed.")
        }
        let sha = d.sha.isEmpty ? ((try? WorkFiles.sha256(of: d.url)) ?? "") : d.sha
        guard !sha.isEmpty else { return fail("\(d.name) could not be read.") }

        let existing = db.rows(.work)
        let already = d.students.filter { WorkFiles.hasCopy(existing, student: $0, sha: sha) }
        let toAdd = d.students.filter { !already.contains($0) }
        let alreadyNames = already.map { db.studentName($0) }
        guard !toAdd.isEmpty else {
            return WorkImportResult(name: d.name, added: 0, alreadyHad: already,
                                    message: "Already added for \(alreadyNames.joined(separator: ", ")). Not added again.",
                                    succeeded: false)
        }

        // The first row's id names the file, so a shared file is named after its first student's row.
        let rowIDs = toAdd.map { _ in uid() }
        let added = todayISO()
        let fileName: String
        do {
            fileName = try WorkFiles.stage(d.url, into: folder.workURL, id: rowIDs[0], added: added, sha: sha)
        } catch WorkFiles.Failure.unsupportedType {
            return fail("\(d.name) is not a file Holocron can import.")
        } catch WorkFiles.Failure.alreadyExists {
            return fail("\(d.name) is already in the work folder under that name. Nothing was added.")
        } catch {
            return fail("\(d.name) could not be copied, so nothing was added. The original is unchanged.")
        }

        let batch = uid()
        let rows: [Row] = toAdd.enumerated().map { i, sid in
            ["id": rowIDs[i], "student_id": sid, "date": d.date, "period": d.period, "subject": d.subject,
             "unit_id": d.unitID, "task": d.task.trimmed, "caption": d.caption.trimmed, "file": fileName,
             "assessment_id": toAdd.count == 1 ? d.assessmentID : "", "batch": batch, "sha": sha, "added": added]
        }
        let ids = Set(rowIDs)
        let saved = WorkFiles.commit(
            appendRows: {
                for r in rows { db.append(.work, r) }
                db.touch(.work)
            },
            undoRows: {
                db.remove(.work, where: { ids.contains($0.s("id")) })
                db.touch(.work)
            },
            save: { saveNow(.work) })
        guard saved else {
            showToast("The work could not be saved. The photo is still in the work folder.")
            return fail("\(d.name) was copied, but the work file could not be saved. Check the work folder before you try again.")
        }

        var message = "Added for \(toAdd.count) \(toAdd.count == 1 ? "student" : "students")."
        if !alreadyNames.isEmpty {
            message += " Already added for \(alreadyNames.joined(separator: ", ")), so not added again."
        }
        return WorkImportResult(name: d.name, added: toAdd.count, alreadyHad: already, message: message, succeeded: true)
    }

    /// Changes the details of one row. The image is not touched.
    func updateWork(id: String, _ change: (inout Row) -> Void) {
        db.update(.work, where: { $0.s("id") == id }, change)
        db.touch(.work)
    }

    /// Removes one row. When no other row uses the file, the image is moved to work/removed first, and the
    /// row goes only once that move has worked. A file shared by other students stays where it is.
    func removeWork(_ x: Row) throws {
        let fm = FileManager.default
        let name = x.s("file")
        let shared = !name.isEmpty && db.rows(.work).contains { $0.s("file") == name && $0.s("id") != x.s("id") }
        if !shared, let src = folder.workFileURL(for: x) {
            let stub = src.deletingLastPathComponent().appendingPathComponent("." + src.lastPathComponent + ".icloud")
            if fm.fileExists(atPath: stub.path) {
                throw WorkError(message: "This photo is still downloading from iCloud. Try again in a moment.")
            }
            do {
                try WorkFiles.moveToRemoved(src, removedDir: folder.removedWorkURL, fm: fm)
            } catch {
                throw WorkError(message: "The photo could not be moved to the removed folder, so it was not removed.")
            }
        }
        db.deleteRow(.work, id: x.s("id"))
    }
}
