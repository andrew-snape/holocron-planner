import SwiftUI
import AppKit

// MARK: - Page router

struct HelpBody: View {
    var topic: HelpTopic

    var body: some View {
        switch topic {
        case .start: HelpStartPage()
        case .using: HelpUsingPage()
        case .data: HelpDataPage()
        case .ai: HelpAIPage()
        case .shortcuts: HelpShortcutsPage()
        }
    }
}

// MARK: - Getting started

struct HelpStartPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Group {
        HelpTitle("Getting started")
        HelpPara("Holocron is a planner for one class. It keeps your fortnightly timetable, lesson summaries, student notes and teaching hours in plain CSV files that you own, so you can back them up, edit them in Numbers, or share the planner part with colleagues.")

        HelpHeading("Set it up in five steps")
        HelpSteps([
            "**Choose where your data lives.** On first launch, pick **Use iCloud Drive / Holocron / data**, or choose another folder. A new folder starts with a typical school day and a list of subjects.",
            "**Add your term dates.** Open **Settings**, then the **Calendar** tab. Week 1 of every term is Week A, so Holocron can show whether it is an A or B week.",
            "**Check your periods and subjects.** In Settings, open the **Timetable** tab and make sure the bell times and subjects match your school day. Subjects marked as release are your specialist lessons.",
            "**Build your A and B timetable.** Open **Week** and click a subject name in a slot. Choose **This date only** for a one-off change, or **Every A week** (or **Every B week**) to change the standing timetable.",
            "**Add lessons.** Type a short summary into the **Summary** box in any slot on the Week screen, or click a lesson on **Today** to open it with more room. A couple of sentences or a link is plenty.",
        ])

        HelpHeading("Where is my data?")
        HelpPara("Choose **Help, then Open Data Folder**, or use the **Open Data Folder** button at the bottom of this window, to see your CSV files in Finder. The Loading data and CSV files page explains what each file holds and how to edit them.")

        HelpCallout(kind: .care, title: "Student privacy",
                    text: "Check your school's policy on where student information may be stored before putting real student details into iCloud Drive or any other service, including AI tools.")

        HelpHeading("Read next")
        HStack(spacing: 10) {
            HelpTopicLink(topic: .using)
            HelpTopicLink(topic: .data)
            HelpTopicLink(topic: .ai)
        }
        }
        }
    }
}

// MARK: - Using Holocron

struct HelpUsingPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Group {
        HelpTitle("Using Holocron")
        HelpPara("The sidebar on the left has every screen. The class name and the current term week (A or B) stay at the top.")

        HelpHeading("Your screens")
        HelpBullets([
            "**Today:** every block of the day in a list, with the current period highlighted and any birthdays coming up. Nothing shows on weekends and holidays. **Copy lessons** copies the day as rich text, ready to paste into your school LMS for a relief teacher.",
            "**Week:** plan the fortnight in a grid. Type a lesson summary into a slot, click a subject name to change it, and drag one lesson onto another to swap them. Last Week, This Week and Next Week move you along. Use the subject filter to show just one subject. Print the week on one A4 page or save it as a PDF.",
            "**Term:** an overview of one subject across the term.",
            "**Units:** your units of inquiry.",
            "**Devotion:** daily devotion and Circle Time scripts.",
            "**Class screen:** the lesson name, learning intention, success criteria and a timer, ready for the projector. **Pop out** opens it in its own window.",
            "**Students:** the class list on the left and a record on the right, with tabs for notes, assessments, wellbeing, behaviour and plan notes, plus a report pack.",
            "**Quick log:** pick several students from the photo grid and add one note to all of them.",
            "**Mark class:** mark the whole class on one task. Type a score or pick an achievement level.",
            "**Hours:** face to face time, release time and duties other than teaching and learning (DOTTL), by term and for the year. Wellbeing entries record which period was lost.",
            "**Settings:** class name, which screens are switched on, periods, subjects, terms, non-teaching days, updates and your data folders.",
        ])

        HelpHeading("Good to know")
        HelpBullets([
            "**Whole days can be different.** On **Today**, choose **Set day type** to mark a camp, carnival, excursion or pupil free day. The normal timetable steps aside for that day.",
            "**Switch off what you do not use.** In Settings, then General, each screen except Today and Settings can be turned off.",
            "**Saving is automatic.** Every change is written to your CSV files and a small confirmation appears. If a red banner says No data folder connected, nothing is saved until you reconnect a folder.",
            "**Sharing the planner.** In Settings, then Data, you can point the planner at a shared folder so colleagues use the same timetable. Student records stay in your private folder.",
            "**Updates.** Holocron checks GitHub when it opens. Choose **Holocron, then Check for Updates** at any time.",
        ])
        }
        }
    }
}

// MARK: - Loading data

struct HelpDataPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Group {
        HelpTitle("Loading data and CSV files")
        HelpPara("Everything in Holocron is stored as CSV files, which are plain text tables. There is no account and no server. You can open them in Numbers or TextEdit, copy the folder for a backup, and edit them by hand.")

        HelpHeading("Your folders")
        HelpFolderPanel()
        HelpPara("You can also choose **Help, then Open Data Folder** (or Open Student Folder and Open Planner Folder if you share your planner). Settings, then Data has a Show in Finder button too.", secondary: true)

        HelpHeading("Two folders")
        HelpBullets([
            "**Student folder (private):** students, their records, assessments, wellbeing, behaviour, reports, photos, your hours log, your to-do list and your settings.",
            "**Planner folder:** the timetable, lessons, terms, subjects, periods, units, devotions, quotes and rubrics. By default this is the same folder. Point it at a shared iCloud Drive folder in Settings, then Data, to share the planner with colleagues.",
        ])

        HelpHeading("Three ways to get data in")
        HelpBullets([
            "**Start fresh.** Choose a folder at setup. Files that do not exist yet are created with a typical day and a list of subjects. Existing files are never changed.",
            "**Bring across an older copy.** In Settings, then Data, choose **Change folder...**, then **Import my existing planner data...** and pick the old data folder. Its CSV files and photos are copied across.",
            "**Edit the CSV files.** Good for adding a whole term of lessons, a class list or a year of term dates at once. Steps below.",
        ])

        }
        Group {
        HelpHeading("Editing a CSV file")
        HelpSteps([
            "**Back up first.** Copy the whole data folder somewhere safe.",
            "**Open the folder** with Help, then Open Data Folder.",
            "**Open the file.** Right-click it, choose **Open With**, then **Numbers** for a table or **TextEdit** for plain text.",
            "**Edit it.** Leave the first row (the column headings) exactly as it is. Add rows underneath or change cells. If TextEdit shows a formatting bar, choose **Format, then Make Plain Text** before you save.",
            "**Save it as CSV.** In Numbers choose **File, then Export To, then CSV** and replace the original file. TextEdit saves as it is.",
            "**Reload.** Back in Holocron press **Shift+Cmd+R** (File, then Reload from folder). Holocron also picks up changed files when you switch back to it.",
        ])

        HelpCallout(kind: .care, title: "One place at a time",
                    text: "Holocron writes your changes straight to the files. Avoid typing in Holocron while the same file is open for editing elsewhere, because whichever saves last wins.")

        HelpHeading("Rules for CSV files")
        HelpBullets([
            "Keep the column headings exactly as they are. Holocron finds columns by their heading, so the order does not matter, but a misspelt heading will not be read.",
            "Dates are written `yyyy-mm-dd`, for example `2026-10-14`. Times use the 24 hour clock, for example `13:45`.",
            "A cell with a comma, a quote or a line break inside it needs double quotes around it. For example: `\"Tuning in, then group work\"`.",
            "Subject names must match the subjects file exactly, period numbers must match the periods file, and a `student_id` must match an `id` in the students file.",
            "Empty cells are fine. Rows where every cell is empty are ignored.",
            "In the timetable file, `day` runs from 0 for Monday to 4 for Friday, and `week` is A or B.",
        ])

        }
        Group {
        HelpHeading("What each file holds")
        HelpFileTable()
        HelpPara("Planner files sit in the student folder unless you have chosen a separate planner folder. Holocron also keeps a settings.csv of its own, so leave that one alone.", secondary: true)

        HelpHeading("If something looks wrong")
        HelpBullets([
            "**A red banner says No data folder connected.** Choose Set up data folder, or use Settings, then Data, to pick the folder again. If the folder is in iCloud Drive, check it is downloaded.",
            "**A message says a file is still downloading from iCloud.** Wait a moment, then press Shift+Cmd+R.",
            "**New rows do not show up.** Check you edited the right file, that dates look like `2026-10-14`, that subject names and period numbers match exactly, and that you pressed Shift+Cmd+R. Lessons only appear on dates inside a term you have added.",
            "**A file could not be read.** Holocron never overwrites a file it cannot read. Open it in TextEdit, fix the problem or restore your backup, then reload.",
            "**Want to begin again?** Settings, then Data, then Start over. Your old files move into a dated folder called Holocron archive. Nothing is deleted.",
        ])
        }
        }
    }
}

/// Where the folders are, with buttons to open and reload them.
struct HelpFolderPanel: View {
    @Environment(AppModel.self) private var model
    @State private var reloaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(title: model.folder.plannerURL == nil ? "Data folder" : "Student folder (private)",
                symbol: model.folder.plannerURL == nil ? "folder.fill" : "lock.fill",
                url: model.folder.url)
            if let p = model.folder.plannerURL {
                Divider()
                row(title: "Planner folder", symbol: "person.2.fill", url: p)
            }
            Divider()
            HStack(spacing: 10) {
                Button("Reload from folders") {
                    model.flushNow(wait: true)
                    model.loadAll()
                    reloaded = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { reloaded = false }
                }
                if reloaded {
                    Text("Reloaded").font(.system(size: 12.5)).foregroundStyle(Color.appGreen)
                }
                if !model.folderOK {
                    Text("Not connected").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Color.appRed)
                }
            }
        }
        .card()
    }

    private func row(title: String, symbol: String, url: URL) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Color.ink2).frame(width: 18).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(url.path)
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Color.ink2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open in Finder") { HelpActions.open(url) }
                .disabled(!DataFolder.isDirectory(url))
        }
    }
}

struct HelpFileTable: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(CSVGuide.documented.enumerated()), id: \.element) { idx, t in
                if idx > 0 { Divider() }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.rawValue + ".csv")
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        TagLabel(text: t.isPlanner ? "Planner" : "Student",
                                 fg: t.isPlanner ? Color.appBlue : Color.ink2,
                                 bg: t.isPlanner ? Color.appBlue.opacity(0.12) : Color.black.opacity(0.06))
                    }
                    .frame(width: 180, alignment: .leading)
                    Text(CSVGuide.summary(t))
                        .font(.system(size: 13)).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9).padding(.horizontal, 12)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
    }
}

// MARK: - Entering data with AI

struct HelpAIPage: View {
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Group {
        HelpTitle("Entering data with AI")
        HelpPara("An AI assistant such as Claude or ChatGPT can turn messy material, like a term overview, a class list or a list of meetings, into rows that Holocron can read. The assistant never connects to Holocron. It only writes text, and you check that text and paste it into your CSV files. The steps are the same for any assistant.")

        HelpCallout(kind: .care, title: "Student privacy comes first",
                    text: "Check your school's policy before pasting real student details into any AI tool. Where you can, use first names or made-up ids, leave out birth dates, medical details and anything sensitive, and add those in Holocron yourself afterwards. Timetables, term dates and lesson summaries carry no student information at all, so they are the easiest place to start.")

        HelpHeading("The method")
        HelpSteps([
            "**Copy the guide.** Choose **Help, then Copy CSV Guide for AI**, or use the button below. It copies a plain description of every file, its columns and the rules for filling them in.",
            "**Paste it into a new chat.** Open Claude, ChatGPT or any assistant and paste the guide as your first message.",
            "**Give it your material.** Paste your text or attach a document, and say what you want. Examples are below. If the result needs your existing subjects, periods or student ids, paste those files in too, so the names and numbers match.",
            "**Ask for CSV only.** Say: *Reply with CSV only, in a code block, with the heading row exactly as in the guide.* Ask for a few rows first, check them, then ask for the rest.",
            "**Check it.** Read the rows. Are the dates right? Do subject names and period numbers match yours? Tell the assistant what to fix and ask for the corrected version.",
            "**Add it to your file.** Follow *Adding the rows to your file* further down this page.",
            "**Reload and check.** Press **Shift+Cmd+R** in Holocron, then look at the screen to confirm the rows turned up where you expected.",
        ])

        HelpPara("If your assistant can make files, you can ask for a downloadable `.csv` instead. Open it, copy the rows, and paste them into the real file in the same way.", secondary: true)

        }
        Group {
        HelpHeading("Adding the rows to your file")
        HelpSteps([
            "**Back up your data folder.** Copy it somewhere safe first.",
            "**Open the folder.** Choose Help, then Open Data Folder, or use the button at the bottom of this window.",
            "**Open the file as plain text.** Right-click the CSV, choose **Open With**, then **TextEdit**. The file name matches what you asked for, for example `lessons.csv`.",
            "**Click at the very end of the last row and press Return.** This makes sure the new rows start on their own line. A spare blank line is harmless.",
            "**Paste the new rows, without the heading row.** Use Paste rather than typing, so the quotes stay straight. If the file is empty, paste the whole block, heading row included.",
            "**Save, then reload.** Save the file, switch back to Holocron and press **Shift+Cmd+R**. Open the screen the rows belong to and check they turned up.",
        ])

        HelpHeading("The CSV guide")
        HStack(spacing: 10) {
            Button {
                HelpActions.copy(CSVGuide.text)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
            } label: {
                Label(copied ? "Copied" : "Copy CSV guide for AI", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            Text("Made from the files in this version of Holocron.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        }
        DisclosureGroup("Preview the guide") {
            HelpCode(text: CSVGuide.text, copyLabel: "Copy guide")
                .padding(.top, 8)
        }
        .font(.system(size: 13.5))

        }
        Group {
        HelpHeading("Example requests")
        HelpPara("Copy one, replace the [square brackets] with your own details, and send it after the guide.", secondary: true)
        HelpCode(text: "Here are my term dates for [year]. Make terms.csv rows.\nTerm 1: [first day] to [last day]\nTerm 2: [first day] to [last day]\nTerm 3: [first day] to [last day]\nTerm 4: [first day] to [last day]")
        HelpCode(text: "Here are my timetable.csv, subjects.csv, periods.csv and terms.csv (pasted below). I am planning maths for [dates]. Make lessons.csv rows for every period where the subject is Maths in that date range, following the A and B week pattern in timetable.csv and my term dates in terms.csv. Use the unit overview below to write a two sentence summary for each lesson.\n\n[paste the four files and the unit overview]")
        HelpCode(text: "Make nonteaching.csv rows for these pupil free days and public holidays, using the date and a short label:\n[paste your dates]")
        HelpCode(text: "Here is my class list. Make students.csv rows with ids s01, s02 and so on, in alphabetical order by first name. Fill in first and surname only and leave every other column empty.\n[paste the list]")
        HelpCode(text: "Make dottl.csv rows for these meetings and duties. Choose the closest type from the guide and give the minutes as a whole number.\n[paste your list with dates and lengths]")

        }
        Group {
        HelpHeading("Tips for good results")
        HelpBullets([
            "**Say what today's date is and which school year you mean.** Assistants guess otherwise.",
            "**Paste the file the new rows depend on.** A lesson row needs your subject names and period numbers. A behaviour or wellbeing row needs student ids from students.csv.",
            "**Start small.** Ask for a week, check it in Holocron, then ask for the term.",
            "**If it adds chatter inside the code block,** say: *Output the CSV only.*",
            "**Ask it to list anything it was unsure about** instead of guessing a date, a subject or a name.",
            "**Keep your own backup.** A quick copy of the folder takes seconds and makes any slip easy to undo.",
        ])
        }
        }
    }
}

// MARK: - Shortcuts

struct HelpShortcutsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Group {
        HelpTitle("Keyboard shortcuts")
        HelpHeading("Moving around")
        HelpKeyRow(keys: "Cmd+1 to Cmd+0", action: "Jump between screens, in sidebar order: Today, Week, Term, Units, Devotion, Class screen, Students, Quick log, Mark class, Hours")
        HelpKeyRow(keys: "Cmd+,", action: "Open Settings")
        HelpKeyRow(keys: "Shift+Cmd+/", action: "Open Help")
        HelpPara("Each screen keeps its own number. If you switch a screen off in Settings, its number is simply unused. The Go menu always shows what is available.", secondary: true)

        }
        Group {
        HelpHeading("Working with data")
        HelpKeyRow(keys: "Shift+Cmd+R", action: "Reload from the data folders after editing a CSV file")
        HelpKeyRow(keys: "Option+Cmd+C", action: "Copy the day as rich text (on Today)")

        }
        Group {
        HelpHeading("Printing")
        HelpKeyRow(keys: "Cmd+P", action: "Print the week (on Week)")
        HelpKeyRow(keys: "Shift+Cmd+P", action: "Save the week as a PDF (on Week)")
        }
        }
    }
}

// MARK: - CSV guide

/// Describes every CSV file. The columns come straight from `TableName.header`, so the guide
/// that is copied for an AI assistant always matches the version of Holocron you are running.
enum CSVGuide {
    /// Files that are described. settings.csv is Holocron's own, and lessonsprivate.csv has the same columns as lessons.csv.
    static var documented: [TableName] {
        TableName.allCases.filter { $0 != .settings && $0 != .lessonsprivate }
    }

    /// One line for the file list in the Help window.
    static func summary(_ t: TableName) -> String {
        switch t {
        case .students: return "Your class list and each student's details"
        case .subjects: return "Subjects, their colours, and which are release lessons"
        case .periods: return "The bell times for the school day"
        case .timetable: return "The A and B fortnight template"
        case .dayplan: return "One-off changes to the timetable on a single date"
        case .lessons: return "Lesson summaries and plans"
        case .assessments: return "Marks and results"
        case .rubrics: return "Rubric descriptors"
        case .plannotes: return "ILP and NCCD notes"
        case .wellbeing: return "Wellbeing log, including the period lost"
        case .behaviour: return "Behaviour entries"
        case .lessonnotes: return "Notes on students made during a lesson"
        case .dottl: return "Your manual DOTTL log"
        case .terms: return "Term start and end dates"
        case .nonteaching: return "Pupil free days and public holidays"
        case .dayoverrides: return "Camps, carnivals and other whole-day changes"
        case .devotion: return "Devotion and Circle Time scripts"
        case .quotes: return "Quotes shown on the Today screen"
        case .units: return "Units of inquiry"
        case .todo: return "Your to-do list"
        case .reportjudge: return "Report ratings for achievement and engagement"
        case .reportcomment: return "Report general comments"
        case .lessonsprivate, .settings: return ""
        }
    }

    /// A precise description for the AI guide.
    static func detail(_ t: TableName) -> String {
        switch t {
        case .students:
            return "One row per student. id must be unique and must never change, because other files refer to it. birthdate is yyyy-mm-dd. parents holds parent names only, never emails or phone numbers."
        case .subjects:
            return "One row per subject. kind is teach, release (a specialist lesson) or dottl. colour is a hex code such as #34C759."
        case .periods:
            return "The bell times for a school day. period is 1, 2, 3 and so on. start and end are 24 hour times such as 09:30."
        case .timetable:
            return "The fortnightly template. week is A or B. day is 0 for Monday up to 4 for Friday. period matches periods.csv. subject matches subjects.csv."
        case .dayplan:
            return "A one-off change for one date. A row here replaces the timetable for that date and period."
        case .lessons:
            return "A lesson on a date and period. summary is a sentence or two, or a link. li is the learning intention and sc the success criteria. The other columns are optional and can be left empty."
        case .assessments:
            return "One row per result. student_id matches an id in students.csv. result is a score or one of: " + Lists.achievement.joined(separator: ", ") + "."
        case .rubrics:
            return "Rubric descriptors. level is one of: " + Lists.rubricLevels.joined(separator: ", ") + "."
        case .plannotes:
            return "ILP and NCCD notes for a student. student_id matches students.csv. type is one of: " + Lists.planNoteTypes.joined(separator: ", ") + "."
        case .wellbeing:
            return "A wellbeing entry for a student. period_lost is the number of the period that was lost, or empty. minutes is a whole number."
        case .behaviour:
            return "A behaviour entry for a student: a date and free text. student_id matches students.csv."
        case .lessonnotes:
            return "A short note on a student during a lesson. time is HH:mm. student_id matches students.csv."
        case .dottl:
            return "Duties other than teaching and learning. type is one of: " + Lists.dottlTypes.joined(separator: ", ") + ". minutes is a whole number."
        case .terms:
            return "Term dates. year is the school year, term is 1 to 4, start and end are the first and last day. Week 1 of each term is Week A."
        case .nonteaching:
            return "Days off, such as pupil free days and public holidays. label is a short name."
        case .dayoverrides:
            return "A whole day that does not follow the timetable. type is one of: " + Lists.dayTypes.joined(separator: ", ") + "."
        case .devotion:
            return "Daily devotion scripts. These are easiest to write in the app. If you edit them here, copy the pattern of an existing row."
        case .quotes:
            return "Quotes shown on the Today screen. Copy the pattern of an existing row."
        case .units:
            return "Units of inquiry. Copy the pattern of an existing row."
        case .todo:
            return "The to-do list. Copy the pattern of an existing row."
        case .reportjudge:
            return "Semester report ratings. achievement is one of: " + Lists.achievement.joined(separator: ", ") + ". engagement is one of: " + Lists.engagement.joined(separator: ", ") + ". Copy the pattern of an existing row."
        case .reportcomment:
            return "Semester report general comments. Copy the pattern of an existing row."
        case .lessonsprivate, .settings:
            return ""
        }
    }

    /// The whole guide, ready to paste into an AI chat.
    static var text: String {
        var lines: [String] = [
            "HOLOCRON CSV GUIDE",
            "",
            "Holocron is a classroom planner for a primary school teacher in Australia. Its data is stored as plain CSV files. I will ask you to create or edit rows for these files. Please follow the rules below exactly.",
            "",
            "RULES",
            "- Reply with CSV only, in one code block per file, with no commentary inside the block.",
            "- Begin each file with its heading row, copied exactly from the Columns line below. Do not rename, add or reorder columns. If I say I am adding to an existing file, give the rows only, without the heading row.",
            "- Write dates as yyyy-mm-dd, for example 2026-10-14. Write times on the 24 hour clock as HH:mm, for example 13:45.",
            "- Put double quotes around any cell that contains a comma, a double quote or a line break, and double any double quote inside it.",
            "- Leave a cell empty if you do not know the value. Never invent dates, names, marks or ids. After the code block, list anything you were unsure about.",
            "- Subject names, period numbers and student ids must match the values in subjects.csv, periods.csv and students.csv exactly. If I have not given you those files, ask me for them.",
            "- Where a file has an id column, each id must be unique short text with no spaces. Use the ids I give you, or make simple ones such as n001, n002.",
            "- Use Australian English.",
            "",
            "FILES",
            "",
        ]
        for t in documented {
            lines.append(t.rawValue + ".csv")
            lines.append("Columns: " + t.header.joined(separator: ","))
            lines.append(detail(t))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
