import Foundation
import os

/// The "guide for AI assistants": a Markdown file Holocron keeps in each data folder, so an AI
/// assistant pointed at the folder can understand the files without being told. The file list and
/// columns come straight from `TableName`, so the guide always matches the version you are running.
///
/// There are two guides. The planner guide lists only planner files and holds no student
/// information, so it is safe in a folder shared with colleagues. The student guide covers the
/// private folder and opens with a privacy notice.
enum AIGuide {
    enum Kind {
        case planner
        case student
    }

    /// The file written into a data folder. It is not a CSV, so nothing that reads, imports,
    /// archives or clears the folder's tables ever touches it.
    static let fileName = "README-for-AI.md"

    /// Everything a guide depends on.
    struct Context {
        var version: String
        /// True when the planner has its own (often shared) folder, apart from the student folder.
        var plannerShared: Bool
        /// Planner tables kept in the student folder because they are private (Devotion and quotes).
        var privateTables: Set<TableName>
        /// Subjects whose lessons are kept in lessonsprivate.csv.
        var privateSubjects: [String]
        /// Where the planner folder is. Only the student guide names it.
        var plannerPath: String
        /// Where archives and backups are kept. Only the student guide names it.
        var archivePath: String
    }

    /// The files a guide lists, in the order of `TableName.allCases`. The student guide follows the
    /// same routing as the database (see `DataFolder.root(for:)`). The planner guide lists every planner
    /// table whatever one teacher has made private, so colleagues sharing the folder all write the
    /// same text.
    static func tables(for kind: Kind, _ c: Context) -> [TableName] {
        TableName.allCases.filter { t in
            switch kind {
            case .planner: return t.isPlanner
            case .student: return !t.isPlanner || c.privateTables.contains(t) || !c.plannerShared
            }
        }
    }

    /// The Holocron version a guide was written by, read from its "Holocron version:" line.
    static func version(in text: String) -> String? {
        for line in text.split(separator: "\n", maxSplits: 12, omittingEmptySubsequences: false).prefix(12) where line.hasPrefix(versionPrefix) {
            return String(line.dropFirst(versionPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    static let versionPrefix = "Holocron version: "

    /// The privacy notice that heads the student guide and is repeated when both guides are copied.
    static let studentNotice = """
    > **Privacy notice. Read this first.** This folder holds student records: names, notes, wellbeing, behaviour, medical details, adjustments, reports and photos. Do not upload or send any of it to an online service unless the teacher has confirmed that their school's policy allows it. Prefer summarising to quoting, and never include it in anything that is shared.
    """

    static func markdown(for kind: Kind, _ c: Context) -> String {
        var L: [String] = []
        L.append("# Holocron data folder — guide for AI assistants")
        L.append("")
        if kind == .student {
            L.append(studentNotice)
            L.append("")
        }
        L.append(versionPrefix + c.version)
        L.append("")
        L.append("This file is written by Holocron and is replaced when its content changes. Do not edit it.")
        L.append("")

        L.append("## What this is")
        L.append("")
        L.append("Holocron is a Mac app that a primary school teacher in Australia uses to plan lessons, keep student records and log teaching hours. All of its data is plain CSV files that the teacher owns. There is no server and no account.")
        L.append("")
        switch kind {
        case .planner:
            L.append("This is the **planner folder**: the timetable, lessons, terms, units and related files. It may be shared with colleagues. Student records are kept in a separate private folder and are not described here.")
            L.append("")
            L.append("`\(TableName.devotion.rawValue).csv` and `\(TableName.quotes.rawValue).csv` are listed below, but an individual teacher may keep them privately instead, in which case they are not in this folder.")
        case .student where c.plannerShared:
            L.append("This is the **student folder**: private records, photos and personal settings. The planner (timetable, lessons, terms, units) is in a separate folder, which may be shared with colleagues: `\(c.plannerPath)`")
            L.append("")
            L.append("Holocron also writes a guide like this one into the planner folder. That guide covers the planner files only and holds no student information.")
        case .student:
            L.append("This is the **data folder**. The planner files and the student files are kept together in it, because the planner has not been given a folder of its own.")
        }
        L.append("")
        L.append("The timetable runs on an A/B fortnight that restarts each term. Week 1 of every term is Week A, then B, A, B and so on.")
        L.append("")

        L += beforeYouEdit(kind, c)
        L.append("## Files in this folder")
        L.append("")
        L.append("| File | What it holds | Columns |")
        L.append("| --- | --- | --- |")
        for t in tables(for: kind, c) {
            let cols = t.header.map { "`\($0)`" }.joined(separator: ", ")
            L.append("| `\(t.rawValue).csv` | \(describe(t)) | \(cols) |")
        }
        L.append("")
        if kind == .student {
            if c.plannerShared {
                L.append("Planner files are not in this folder unless they are private. A table that is private is kept here instead of in the planner folder.")
            }
            if !c.privateSubjects.isEmpty {
                let names = c.privateSubjects.sorted().joined(separator: ", ")
                L.append("Private subjects: \(names). Their lessons are kept in `lessonsprivate.csv`. For these subjects, any rows in `lessons.csv` are ignored by the app, so edit `lessonsprivate.csv`. For every other subject, `lessonsprivate.csv` is ignored.")
            }
            if c.privateTables.contains(.devotion) {
                L.append("Devotion is set to private, so `devotion.csv` and `quotes.csv` are kept in this folder.")
            }
            L.append("")
            L.append("Other items here: `photos/` holds one JPEG per student, named with the student's id, for example `photos/<id>.jpg`. Files shown in Finder as `.name.csv.icloud` are iCloud placeholders for files that are not downloaded yet. Holocron creates a file the first time it needs it, so a file listed above may not exist yet. `lessonsprivate.csv` only exists once a subject has been made private.")
            L.append("")
        } else {
            L.append("`lessonsprivate.csv` is never kept in this folder. Holocron creates a file the first time it needs it, so a file listed above may not exist yet. Files shown in Finder as `.name.csv.icloud` are iCloud placeholders for files that are not downloaded yet.")
            L.append("")
        }

        L.append("## Formats")
        L.append("")
        L.append("- **Files:** UTF-8 text with a heading row. Cells containing a comma, a double quote or a line break are wrapped in double quotes, and a double quote inside is doubled. Empty cells are fine and rows with every cell empty are ignored.")
        L.append("- **Date:** `yyyy-mm-dd`, for example `2026-10-14`.")
        L.append("- **Time:** 24 hour `HH:mm`, for example `13:45`.")
        L.append("- **Week:** `A` or `B`.")
        L.append("- **Day:** a number from `0` (Monday) to `4` (Friday), in `timetable.csv`.")
        L.append("- **Period:** a whole number that matches `period` in `periods.csv`. The starter timetable numbers them from 1 (period 1 is morning circle), but the teacher can change them, so always look them up in `periods.csv`.")
        L.append("- **Ids:** short unique text with no spaces, such as `lq3k9x2a7b1c`, made from the time and random characters. Never change an existing id.")
        if kind == .student {
            L.append("- **Yes and no:** there are no true or false columns. `students.csv` `ilp` is `yes` or empty. In `todo.csv`, `done` is the date it was ticked off, or empty when it is not done.")
            L.append("- **Lists in one cell:** values are separated by commas, for example `Thinking,Research` in an `atl` cell. In `reportcomment.csv` the `english` and `maths` cells hold one dot point per line.")
        } else {
            L.append("- **Lists in one cell:** values are separated by commas, for example `Thinking,Research` in an `atl` cell.")
        }
        L.append("- **Subject kind:** in `subjects.csv`, `kind` is `teach`, `release` or `dottl`.")
        L.append("")

        L.append("## How the files relate")
        L.append("")
        if kind == .planner {
            L.append("- `subject` in `timetable.csv`, `dayplan.csv` and `lessons.csv` must match `subject` in `subjects.csv` exactly.")
            L.append("- `period` must match `period` in `periods.csv`.")
            L.append("- A lesson is found by `date` plus `period`. A lesson only shows on a date that falls inside a term in `terms.csv`.")
        } else {
            L.append("- `student_id` in `assessments.csv`, `plannotes.csv`, `wellbeing.csv`, `behaviour.csv`, `lessonnotes.csv`, `reportjudge.csv`, `reportcomment.csv` and `strandcomments.csv` matches `id` in `students.csv`.")
            L.append("- `subject` in `lessonnotes.csv`, `assessments.csv` and the lesson files matches `subject` in `subjects.csv` exactly.")
            L.append("- `period` matches `period` in `periods.csv`.")
            L.append("- A lesson is found by `date` plus `period`, and so are its Class screen steps in `classsteps.csv`.")
            L.append("- Photos are named with the student's `id`.")
            if c.plannerShared {
                L.append("- `subjects.csv`, `periods.csv`, `timetable.csv`, `dayplan.csv`, `lessons.csv`, `terms.csv`, `nonteaching.csv` and `dayoverrides.csv` are in the planner folder, not this one.")
            }
        }
        L.append("")

        L += valueRules(kind, c)
        L += recipes(kind, c)

        L.append("## Common questions")
        L.append("")
        L.append("- **What is on in a period on a date?** Check `dayplan.csv` for that date and period first. It overrides the timetable. If there is no row, find the term in `terms.csv`, work out whether the date is in an A or B week, then look up `week`, `day` (Monday is 0) and `period` in `timetable.csv`. Then check `dayoverrides.csv` (a camp or carnival changes the whole day, unless its `type` is `Normal`) and `nonteaching.csv` (pupil free days and holidays, when there are no lessons).")
        L.append("- **What was taught or planned?** Find the row in `lessons.csv` with that `date` and `period`\(kind == .student ? " (or in `lessonsprivate.csv` for a private subject)" : "").")
        L.append("- **Is it an A or B week?** Take the term from `terms.csv`. The week containing the term's `start` is week 1, which is A. Odd weeks are A and even weeks are B.")
        L.append("- **Is it a school day?** Monday to Friday, inside a term, and not listed in `nonteaching.csv`.")
        L.append("- **When is a subject on?** Filter `timetable.csv` by `subject`, and add any `dayplan.csv` rows for that subject.")
        if kind == .student {
            L.append("- **A student's notes?** Use their `id` from `students.csv` and look in `lessonnotes.csv`, `behaviour.csv`, `wellbeing.csv` and `plannotes.csv` by `student_id`. Results are in `assessments.csv`.")
            L.append("- **A student's report?** `reportjudge.csv` (ratings), `reportcomment.csv` (general comment) and `strandcomments.csv` (imported strand comments), all by `student_id` and `sem`.")
            L.append("- **Teaching hours?** `dottl.csv` is the manual log of duties other than teaching. Teaching and release time come from the timetable and `subjects.csv` `kind`.")
        }
        L.append("")
        L += doNot(kind, c)
        L += afterEditing(kind)
        return L.joined(separator: "\n")
    }

    // MARK: Sections

    private static func beforeYouEdit(_ kind: Kind, _ c: Context) -> [String] {
        var L = ["## Before you edit", ""]
        L.append("You may be asked to update the live CSV files in this folder. Follow this checklist first.")
        L.append("")
        L.append("1. **Ask the teacher to quit Holocron (Cmd+Q) before you edit.** This is the safe way, and quitting saves everything first. Holocron keeps all of its data in memory and, a moment after any change in the app, rewrites the whole file for each table that changed from what it holds. It does not merge and it does not use lock files. If the app saves a table after you have edited that file, the app's version replaces yours, and your edit is lost without warning.")
        L.append("2. If Holocron has to stay open, make sure the teacher is not typing in it, wait a few seconds for the \"Saved\" message, edit, then press Shift+Cmd+R straight away (File, then Reload from folder) before anything else is done in the app. Holocron also reads changed files when it is switched back to, but only when it has nothing waiting to be saved. Any change made in the app to the same table before it has reloaded will overwrite your edit.")
        L.append("3. **Back up first.** Copy each file you will change, for example `lessons.csv` to `lessons.backup.csv` in another folder, or copy the whole folder. Do not leave backup copies inside this folder.")
        L.append("4. Read the current file and its heading row before writing. Work from what is really there, not from the sample rows in this guide.")
        L.append("5. Make the smallest change that does the job, usually adding rows. Save as UTF-8 with the same heading row.")
        L.append("6. If the teacher says the file looks wrong afterwards, put the backup back. Holocron never overwrites a file it could not read, and it keeps any extra columns it finds, but do not rely on that.")
        if kind == .planner {
            L.append("7. **This folder may be shared with colleagues.** Unless the teacher is the only person who uses it, confirm with the teacher before writing here, because colleagues see every change.")
        } else if c.plannerShared {
            L.append("7. The planner folder is shared with colleagues. Do not write to it unless the teacher has said so for this task. Everything in this folder is private to the teacher.")
        }
        L.append("")
        return L
    }

    private static func valueRules(_ kind: Kind, _ c: Context) -> [String] {
        func q(_ items: [String]) -> String { items.map { "`\($0)`" }.joined(separator: ", ") }
        var L = ["## Value rules", ""]
        L.append("**Writing a CSV file the way Holocron reads it**")
        L.append("")
        L.append("- The first row is the heading row. Holocron finds columns by their heading text, so keep every heading exactly as shown above, spelt the same, in the same order. A misspelt heading is not read. Holocron keeps a column it does not know but ignores it, so do not add columns.")
        L.append("- Separate cells with commas, one row per line, with LF line endings. Spaces are kept as part of a cell, so do not put a space after a comma.")
        L.append("- A cell that contains a comma, a double quote or a line break must be wrapped in double quotes. Inside a quoted cell write a double quote as two double quotes. A line break inside quotes is allowed and is how multi-line cells such as `lines` are stored.")
        L.append("- Every row needs a cell for every column, even when empty. A row with all cells empty is ignored.")
        L.append("- Empty means not set. Holocron treats an empty cell as no value, so leave a cell empty rather than writing `n/a`, `none` or `null`.")
        L.append("- **Dates** are `yyyy-mm-dd` with leading zeros. **Times** are 24 hour `HH:mm`. Never write `14/10/2026` or `1:45pm`. Whole numbers (`period`, `minutes`, `day`, `term`) have no decimals.")
        L.append("- **Ids** only need to be non-empty text with no spaces that no other row in the same file uses. Holocron makes its own from the time and four random characters, for example `mh2k4x9a1b3c`. Make yours 12 characters from `0-9a-z`, mostly random, and check the file for a clash. Never change the id of a row that already exists, because other files refer to it.")
        L.append("- Lists in one cell are separated by commas with no other punctuation, for example `Thinking,Research`. Curriculum `codes` may be separated by commas or spaces.")
        L.append("")
        L.append("**Allowed values**")
        L.append("")
        if kind == .planner || !c.plannerShared {
            L.append("- `week`: `A` or `B`. `day`: `0` Monday, `1` Tuesday, `2` Wednesday, `3` Thursday, `4` Friday.")
            L.append("- `subject` (`subjects.csv`) is any name. `kind` is `teach`, `release` or `dottl`. `colour` is a hex code such as `#34C759`.")
            L.append("- `dayoverrides.csv` `type`: \(q(Lists.dayTypes)).")
            L.append("- `units.csv` `theme`: \(q(PYP.themes.map { $0.name })). `concepts`: any of \(q(PYP.keyConcepts)). `atl`: any of \(q(PYP.atlSkills)). `profile`: any of \(q(PYP.profile)).")
            L.append("- `lessons.csv` `atl` and `profile` use the same lists as units.")
            L.append("- `rubrics.csv` `level`: \(q(Lists.rubricLevels)).")
        }
        if kind == .student {
            L.append("- `assessments.csv` `result` is a score such as `18/20` or one of \(q(Lists.achievement)).")
            L.append("- `reportjudge.csv` `achievement`: \(q(Lists.achievement)). `engagement`: \(q(Lists.engagement)). `sem` looks like `2026-S2`.")
            L.append("- `plannotes.csv` `type`: \(q(Lists.planNoteTypes)).")
            L.append("- `dottl.csv` `type`: \(q(Lists.dottlTypes)). `minutes` is a whole number.")
            L.append("- `students.csv` `house`: the houses with a colour are \(q(Lists.houseColours.keys.sorted())). Other text is accepted. `ilp` is `yes` or empty. `parents` is for parent names only, never emails or phone numbers. `birthdate` is `yyyy-mm-dd`.")
            L.append("- `wellbeing.csv` `period_lost` is a period number from `periods.csv`, or empty. `minutes` is a whole number.")
            L.append("- `lessonnotes.csv` `time` is `HH:mm`. `subject` is a subject name, or empty for a note that is not about a subject.")
            L.append("- `todo.csv` `due` is a date or empty. `done` is the date it was finished, or empty. `created` is a date.")
        }
        L.append("")
        L.append("**Required cells**")
        L.append("")
        if kind == .planner || !c.plannerShared {
            L.append("- `timetable.csv`: `week`, `day`, `period` and `subject`. There is one row for each week, day and period.")
            L.append("- `dayplan.csv`: `date`, `period` and `subject`. There is one row for each date and period.")
            L.append("- `lessons.csv`: `date`, `period`, `subject`, and at least one other cell with text. A lesson with every other cell empty is deleted by the app. There is one row for each date and period.")
            L.append("- `terms.csv`: all four cells. Terms must not overlap.")
            L.append("- `nonteaching.csv`: `date` and `label`. `dayoverrides.csv`: `date` and `type`. There is one row for each date in each file.")
            L.append("- `units.csv`: `id` and `title`.")
        }
        if kind == .student {
            L.append("- `students.csv`: `id` and `first`.")
            L.append("- Every log row (`assessments`, `plannotes`, `wellbeing`, `behaviour`, `lessonnotes`): `id`, `student_id` of a student who exists, and `date`.")
            L.append("- `dottl.csv`: `id`, `date`, `type` and `minutes`. `todo.csv`: `id` and `text`.")
        }
        L.append("")
        return L
    }

    private static func recipes(_ kind: Kind, _ c: Context) -> [String] {
        let wantsPlanner = kind == .planner || !c.plannerShared
        let wantsStudent = kind == .student
        let theme = PYP.themes[0].name
        let concepts = PYP.keyConcepts.prefix(2).joined(separator: ",")
        let atl = PYP.atlSkills.prefix(2).joined(separator: ",")
        let profile = PYP.profile.prefix(2).joined(separator: ",")
        var L = ["## Recipes", "", "Each recipe is for one job. The sample rows are examples: use the teacher's real subjects, dates, periods and ids, taken from the files.", ""]
        func recipe(_ title: String, _ steps: [String], _ file: TableName, _ row: String) {
            L.append("**\(title)**")
            L.append("")
            for (i, s) in steps.enumerated() { L.append("\(i + 1). \(s)") }
            L.append("")
            L.append("`\(file.rawValue).csv` heading: `\(file.header.joined(separator: ","))`")
            L.append("")
            L.append("```")
            L.append(row)
            L.append("```")
            L.append("")
        }
        let lessonCols = TableName.lessons.header.count
        let lessonFile = TableName.lessons.rawValue
        if wantsPlanner {
            let tail = String(repeating: ",", count: lessonCols - 6)
            recipe("Add a lesson plan for a date and period", [
                "Find the period number in `periods.csv` and the subject that is on that date and period (see Common questions).",
                "Check `\(lessonFile).csv` has no row yet for that `date` and `period`. If it has, change that row instead of adding another.",
                "Add a row with the `date`, `period` and `subject`, and fill `summary` and any other cells that apply. Leave the rest empty. Quote any cell with a comma.",
                "The date must fall inside a term in `terms.csv`, or the lesson will not show.",
            ] + (kind == .student && !c.privateSubjects.isEmpty ? ["For a private subject (\(c.privateSubjects.sorted().joined(separator: ", "))) use `lessonsprivate.csv` instead, with the same columns."] : []),
                   .lessons, "2026-10-14,3,Maths,Adding two-digit numbers,We are learning to add two-digit numbers by partitioning,\"I can partition each number, and I can add the tens then the ones\"" + tail)

            recipe("Change one day's lesson slot (this date only)", [
                "Look up the period in `periods.csv`, and the subject that should be on instead.",
                "Check `dayplan.csv` for a row with that `date` and `period`. If there is one, change its `subject`. Otherwise add a row.",
                "If `\(lessonFile).csv` already has a lesson for that date and period, change its `subject` cell to match.",
                "Do not change `timetable.csv` for a one-off change.",
            ], .dayplan, "2026-10-14,3,Art")

            recipe("Change a slot every cycle (the standing timetable)", [
                "Work out the `week` (`A` or `B`) and `day` (0 to 4) of the slot, and the `period`.",
                "Find the row in `timetable.csv` with that `week`, `day` and `period` and change its `subject`. If there is none, add a row.",
                "This changes every matching week in every term, including dates already past. Any `dayplan.csv` row for a particular date still wins over it.",
            ], .timetable, "A,2,3,Maths")

            recipe("Mark a non-teaching day", [
                "Add a row to `nonteaching.csv` with the date and a short label. There are then no lessons that day.",
                "Use this for pupil free days and public holidays. One row for each date.",
            ], .nonteaching, "2026-10-09,Pupil free day")

            recipe("Mark a camp, carnival or excursion", [
                "Add a row to `dayoverrides.csv` with the date, a `type` from the allowed list (\(Lists.dayTypes.map { "`\($0)`" }.joined(separator: ", "))), and an optional note.",
                "The day then does not follow the timetable. Use `Normal` only to cancel an override. One row for each date.",
            ], .dayoverrides, "2026-10-21,\(Lists.dayTypes[1]),Year 6 camp")

            recipe("Add a term", [
                "Add a row to `terms.csv` with the school year, the term number (1 to 4) and the first and last day.",
                "Week 1 is the week containing the start date, and it is Week A. Weeks then alternate B, A, B.",
                "Terms must not overlap. Lessons and school days only exist inside a term.",
            ], .terms, "2026,4,2026-10-05,2026-12-18")

            recipe("Add a unit of inquiry", [
                "Make a new unique `id`.",
                "Add a row with the `title` and, where known, the `theme`, `central_idea`, `concepts`, `atl`, `profile`, and the `start` and `end` dates. Use only the allowed values.",
                "`lines` holds one line of inquiry per line, so wrap that cell in double quotes.",
            ], .units, "mh2k4x9a1b3c,Our local community,\(theme),People depend on each other,\"What jobs do people do?\nHow do we help?\",\"\(concepts)\",,\"\(atl)\",\"\(profile)\",2026-10-05,2026-11-13,,")
        }
        if wantsStudent {
            recipe("Add a student", [
                "Make a new unique `id` and check no row in `students.csv` already has it.",
                "Add a row with `id`, `first` and `surname`. Leave the other cells empty unless the teacher gave them. `ilp` is `yes` or empty.",
                "A photo is optional: `photos/<id>.jpg`.",
            ], .students, "mh2k4x9a1b3c,Sam,Example" + String(repeating: ",", count: TableName.students.header.count - 3))

            recipe("Log a lesson note for a student", [
                "Find the student's `id` in `students.csv`.",
                "Make a new unique `id`, and add a row with `student_id`, the `date`, the `time` (`HH:mm`), the `subject` (or empty) and the `note`.",
            ], .lessonnotes, "mh2k5a1b2c3d,mh2k4x9a1b3c,2026-10-14,10:40,Maths,Counted in tens without prompting")

            recipe("Log a behaviour note", [
                "Find the student's `id`, make a new unique `id`, and add a row with the `date` and the `note`. State facts, not judgements.",
            ], .behaviour, "mh2k5b4c5d6e,mh2k4x9a1b3c,2026-10-14,Called out twice during the mat session")

            recipe("Log a wellbeing note", [
                "Find the student's `id`, make a new unique `id`, and add a row.",
                "`period_lost` is the number of a period from `periods.csv` that the student missed, or empty. `minutes` is a whole number (use `0` if none).",
            ], .wellbeing, "mh2k5c7d8e9f,mh2k4x9a1b3c,2026-10-14,,0,Seemed tired and quiet after lunch")

            recipe("Add an assessment result", [
                "Find the student's `id`. Use the `subject` exactly as in `subjects.csv`.",
                "Make a new unique `id`. `result` is a score or one of the achievement words (\(Lists.achievement.map { "`\($0)`" }.joined(separator: ", "))).",
            ], .assessments, "mh2k5d0e1f2g,mh2k4x9a1b3c,2026-10-14,Maths,Addition test,\(Lists.achievement[1]),Secure with regrouping")

            recipe("Add a to-do", [
                "Make a new unique `id`. Add a row with the `text`, an optional `due` date, an empty `done`, and today's date in `created`.",
                "To mark one done, put the date it was finished in `done`.",
            ], .todo, "mh2k5e3f4g5h,Print excursion forms,2026-10-16,,2026-10-14")

            recipe("Add duties other than teaching (DOTTL) hours", [
                "Make a new unique `id`. Add a row with the `date`, a `type` from the allowed list (\(Lists.dottlTypes.map { "`\($0)`" }.joined(separator: ", "))), the `minutes` as a whole number and a short `note`.",
            ], .dottl, "mh2k5f6g7h8i,2026-10-14,\(Lists.dottlTypes[0]),45,Staff meeting")
        }
        return L
    }

    private static func doNot(_ kind: Kind, _ c: Context) -> [String] {
        var L = ["## Do not", ""]
        L.append("- Do not rename, reorder, add or remove columns, or change the heading row. Holocron would keep an added column but ignores it.")
        L.append("- Do not change the `id` of a row that already exists.")
        L.append("- Do not delete rows or files unless the teacher asked you to. Prefer adding rows.")
        L.append("- Do not invent ids, names, dates or marks. Leave a cell empty if the value is not known.")
        L.append("- Do not put dates in any format other than `yyyy-mm-dd`.")
        if kind == .planner {
            L.append("- Do not put student information in any file in this folder. It holds no student records and may be shared.")
            L.append("- Do not write here unless the teacher has confirmed, because colleagues see the changes.")
        } else {
            L.append("- Do not touch `settings.csv` unless the teacher asked. It holds Holocron's own settings.")
            L.append("- Do not copy student information into any planner file, or into anything that is shared.")
            if c.plannerShared {
                L.append("- Do not write to the planner folder (`\(c.plannerPath)`) unless the teacher has confirmed. Colleagues see it.")
            }
            L.append("- Private subjects: Holocron keeps lessons for a private subject in `lessonsprivate.csv` and for every other subject in `lessons.csv`. A subject is private when `settings.csv` has a row `\(Database.privateSubjectPrefix)<subject>,on`. \(c.privateSubjects.isEmpty ? "No subject is private at the moment, so every lesson goes in `lessons.csv`." : "Private now: \(c.privateSubjects.sorted().joined(separator: ", ")). Their lessons go in `lessonsprivate.csv`, and every other subject's lessons go in `lessons.csv`.") A row in the wrong file is hidden by the app, not shown.")
            if c.plannerShared {
                L.append("- Devotion scripts and quotes are kept in this folder only when `settings.csv` has `\(Database.privateDevotionKey),on`. \(c.privateTables.contains(.devotion) ? "That is the case now." : "That is not the case now, so they are in the planner folder.")")
            } else {
                L.append("- Devotion scripts and quotes are in this folder with everything else. `settings.csv` has a `\(Database.privateDevotionKey)` row that only matters when the planner has its own folder.")
            }
        }
        L.append("")
        return L
    }

    private static func afterEditing(_ kind: Kind) -> [String] {
        var L = ["## After editing", ""]
        L.append("1. Tell the teacher what you changed and which files, and where the backup is.")
        L.append("2. The teacher reopens Holocron, or if it stayed open presses Shift+Cmd+R (File, then Reload from folder).")
        L.append("3. A red banner or a message naming a file means that file could not be read. Holocron has not changed it. Open it, fix the problem or put the backup back, then reload.")
        L.append("4. Check the change shows up:")
        L.append("   - Lessons, one-off changes, the timetable, non-teaching days and camps: **Week** and **Today** for that date. Terms: Settings, then **Calendar**, and the **Term** screen.")
        L.append("   - Units: **Units**. DOTTL hours: **Hours**.")
        if kind == .student {
            L.append("   - Students, notes, behaviour, wellbeing and results: **Students**, then open the student. To-dos: **Today**.")
        }
        L.append("   - If rows do not appear, check the date format, that subject names and period numbers match exactly, that the date is inside a term, and that the app was reloaded.")
        L.append("")
        return L
    }

    /// One line for each file. There is no default, so a new table cannot be added without a description.
    static func describe(_ t: TableName) -> String {
        switch t {
        case .students: return "One row per student: names, birth date, parents, house, roles, adjustments, NCCD, medical details, notes and whether they have an ILP."
        case .subjects: return "Subjects with a kind (teach, release or dottl) and a hex colour."
        case .periods: return "The bell times for the school day."
        case .timetable: return "The A/B fortnight template: which subject is on in each week, day and period."
        case .dayplan: return "One-off changes to the timetable for a single date and period. They override the template."
        case .lessons: return "Lesson plans by date and period: summary, learning intention, success criteria, teaching sequence, reflection, resources, curriculum codes."
        case .assessments: return "Results and comments for a student's task in a subject."
        case .rubrics: return "Rubric descriptors by rubric, element and level."
        case .plannotes: return "ILP and NCCD notes for a student: goals, reviews, meetings, adjustments and evidence."
        case .wellbeing: return "Wellbeing entries for a student, with the period lost and the minutes."
        case .behaviour: return "Behaviour entries for a student."
        case .lessonnotes: return "Short notes about a student made during a lesson, with date, time and subject."
        case .dottl: return "The teacher's manual log of duties other than teaching and learning, with minutes."
        case .terms: return "Term start and end dates by year. They set the A/B weeks and which dates are school days."
        case .nonteaching: return "Pupil free days and public holidays, each with a label."
        case .dayoverrides: return "Whole days that do not follow the timetable, such as camps and carnivals."
        case .devotion: return "Daily Devotion and Circle Time scripts by date."
        case .quotes: return "Quotes shown on the Today screen."
        case .units: return "Units of inquiry: title, theme, central idea, concepts, ATL skills and dates."
        case .todo: return "The teacher's to-do list."
        case .reportjudge: return "Semester report ratings for achievement and engagement, by student and subject."
        case .reportcomment: return "Semester report comments by student: general comment, English and maths dot points, and the teacher's notes for drafting."
        case .lessonsprivate: return "Lessons for subjects marked private. Same columns as `lessons.csv`."
        case .classsteps: return "The First, Then and Next steps typed on the Class screen for a lesson."
        case .strandcomments: return "Report comments imported from Essential Assessment, by student, semester and strand."
        case .interviews: return "Interviews recorded for a student: the date, minutes, the audio file in `recordings/`, the transcript and an optional summary. Private to the student folder."
        case .settings: return "Holocron's own key and value settings, such as which subjects are private. Leave this file alone."
        }
    }
}

// MARK: - Writing the guide

extension DataFolder {
    /// The folder a guide is written to. The planner guide is only written when the planner has a
    /// folder of its own. Otherwise the student guide already covers everything in the one folder.
    private func guideFolder(_ kind: AIGuide.Kind) -> URL? {
        func path(_ u: URL) -> String { u.resolvingSymlinksInPath().standardizedFileURL.path }
        switch kind {
        case .student: return url
        case .planner:
            guard let p = plannerURL, path(p) != path(url) else { return nil }
            return p
        }
    }

    /// True when the planner lives in a folder apart from the student folder.
    var plannerIsSeparate: Bool { guideFolder(.planner) != nil }

    func aiGuideContext(version: String, privateSubjects: Set<String>) -> AIGuide.Context {
        AIGuide.Context(
            version: version,
            plannerShared: plannerIsSeparate,
            privateTables: privateTables,
            privateSubjects: privateSubjects.sorted(),
            plannerPath: plannerURL?.path ?? url.path,
            archivePath: archiveRoot.path)
    }

    /// Writes README-for-AI.md into the student folder and, when there is one, the planner folder.
    /// The text is made here, but the disk is only touched on `AIGuideWriter.queue`, and not at all
    /// when the text is the same as the last time. Problems are logged and otherwise ignored: the
    /// guide is never worth interrupting the teacher for.
    func writeAIGuides(version: String, privateSubjects: Set<String>) {
        let ctx = aiGuideContext(version: version, privateSubjects: privateSubjects)
        for kind in [AIGuide.Kind.student, .planner] {
            guard let dir = guideFolder(kind) else { continue }
            AIGuideWriter.write(AIGuide.markdown(for: kind, ctx), version: version, in: dir)
        }
    }

    /// Both guides as one piece of text for the clipboard: the planner guide first, then the student
    /// guide under its privacy notice. When there is one folder, its single guide covers everything.
    func combinedAIGuide(version: String, privateSubjects: Set<String>) -> String {
        let ctx = aiGuideContext(version: version, privateSubjects: privateSubjects)
        let student = AIGuide.markdown(for: .student, ctx)
        guard plannerIsSeparate else { return student }
        let rule = "\n\n---\n\n"
        return AIGuide.markdown(for: .planner, ctx) + rule
            + "# Part two: the student folder\n\n" + AIGuide.studentNotice + rule + student
    }

    /// The planner guide alone, with no student information. Used by the Describe Holocron shortcut.
    func plannerAIGuide(version: String, privateSubjects: Set<String>) -> String {
        AIGuide.markdown(for: .planner, aiGuideContext(version: version, privateSubjects: privateSubjects))
    }
}

/// Writes the guide file on a background queue. Everything it remembers is touched only on that queue.
enum AIGuideWriter {
    static let queue = DispatchQueue(label: "au.holocron.planner.aiguide", qos: .utility)
    private static let log = Logger(subsystem: "au.holocron.planner", category: "AIGuide")

    /// The text last written or found already in place, by folder path. While it matches, nothing is read.
    nonisolated(unsafe) private static var verified: [String: String] = [:]
    /// Failed writes by folder path. A write is tried twice at most in a session.
    nonisolated(unsafe) private static var failures: [String: Int] = [:]

    static func write(_ text: String, version: String, in dir: URL) {
        queue.async { writeNow(text, version: version, in: dir) }
    }

    private static func writeNow(_ text: String, version: String, in dir: URL) {
        let fm = FileManager.default
        let key = dir.path
        guard verified[key] != text, failures[key, default: 0] < 2, DataFolder.isDirectory(dir) else { return }
        let file = dir.appendingPathComponent(AIGuide.fileName)

        // An iCloud file that is not downloaded yet: ask for it and try again next time.
        let placeholder = dir.appendingPathComponent("." + AIGuide.fileName + ".icloud")
        if fm.fileExists(atPath: placeholder.path) {
            try? fm.startDownloadingUbiquitousItem(at: file)
            return
        }
        if fm.fileExists(atPath: file.path) {
            // A file that cannot be read is not treated as missing, and is left alone.
            guard let data = try? Data(contentsOf: file), let old = String(data: data, encoding: .utf8) else { return }
            if old == text { verified[key] = text; return }
            // Never let an older Holocron replace a guide written by a newer one.
            if let v = AIGuide.version(in: old), VersionCompare.isNewer(v, than: version) { verified[key] = text; return }
        }
        do {
            try Data(text.utf8).write(to: file, options: .atomic)
            verified[key] = text
        } catch {
            failures[key, default: 0] += 1
            log.error("Could not write \(AIGuide.fileName, privacy: .public)")
        }
    }
}
