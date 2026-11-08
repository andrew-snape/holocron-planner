# AGENTS.md

Orientation manual for any AI coding or data assistant working with Holocron. It assumes you know Swift and nothing about this project, Australian schools or this teacher. Read it once, top to bottom, before you change anything. Claude Code users also get [CLAUDE.md](CLAUDE.md), which holds the same hard rules in a shorter form.

## 1. Start here

This file is the entry point for the repository. It points to the detailed docs and records the rules that are easy to break by accident. Where this file and the code disagree, the code is right. Tell the teacher about the mismatch.

Holocron in five lines:

- A native macOS 26 SwiftUI classroom planner for a Year 6 primary school teacher in Victoria, Australia.
- It keeps a fortnightly A/B timetable, lesson plans, student notes, results, report drafts and teaching hours.
- All data is plain CSV in two folders: a planner folder (can be shared with colleagues) and a private student folder.
- About 16,000 lines of Swift (15,971 at time of writing), no dependencies, no test target, Apple silicon only (`ARCHS = arm64`, `MACOSX_DEPLOYMENT_TARGET = 26.0`).
- Everything runs on the Mac. Apple Intelligence features use the on-device model. The only network request is the update check to GitHub Releases.

### If you are about to...

| If you are about to... | Do this first |
|---|---|
| Change app code (Swift) | Read sections 5, 7, 8 and 11 here, then [CLAUDE.md](CLAUDE.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Do not run anything against the teacher's real data folder. |
| Edit a teacher's CSV data (add a lesson, mark a day off, log a note) | **Stop. Do not use this file for that.** Read `README-for-AI.md` in the teacher's data folder instead (details below). Ask the teacher to quit Holocron first. |
| Answer a question about what Holocron can do | [docs/FEATURES.md](docs/FEATURES.md), then [README.md](README.md) and [CHANGELOG.md](CHANGELOG.md). |
| Understand a table, column or format | Section 6 here, then [docs/DATA.md](docs/DATA.md) and `TableName.header` in [Holocron/Core/Schema.swift](Holocron/Core/Schema.swift). |
| Fix a bug that looks familiar | [docs/PROBLEMS.md](docs/PROBLEMS.md) lists past bugs with cause and fix. |
| Pick what to build next | [docs/ROADMAP.md](docs/ROADMAP.md). It lists suggestions, not promises. Ask the teacher. |
| Cut a release | Section 10 here. Releases are only made when the teacher asks. |
| Review a change | Use the project agents: `code-reviewer` for anything touching files, the updater or the release script; `ui-design-check` for anything in `Holocron/Views`. See section 8. |

### README-for-AI.md: the guide for editing live data

`README-for-AI.md` is **not in this repository**. Holocron writes it into the teacher's data folders:

- Into the student folder (always), and into the planner folder when the planner has a folder of its own (`DataFolder.writeAIGuides`, [Holocron/Core/AIGuide.swift](Holocron/Core/AIGuide.swift)).
- It is generated from `TableName`, `TableName.header` and `DataFolder.root(for:)`, so its file list and columns always match the installed version. It is rewritten only when its text changes, at every load (launch, Shift+Cmd+R, focus reload if a file changed).
- It holds a before-you-edit checklist, formats, allowed values, step-by-step recipes with sample rows, a do-not list and after-editing steps. The student copy opens with a privacy notice. The planner copy holds no student information.
- The default data location is `~/Library/Mobile Documents/com~apple~CloudDocs/Holocron/data` (iCloud Drive, `Holocron/data`). The teacher can choose other folders in Settings, then Folders. The path is in `UserDefaults` (`dataFolderPath`, `plannerFolderPath`).
- The teacher can also copy it from Help, then Copy Guide for AI Assistants, or run the Describe Holocron action in Shortcuts (planner guide only).
- It is not a CSV, so import, archive and Start over never touch it. Do not edit it. Holocron replaces it.
- **Quit Holocron (Cmd+Q) before editing any CSV.** Holocron holds all rows in memory and rewrites whole files a moment after any change, so an edit made while the app is open can be overwritten. If it must stay open, the teacher presses Shift+Cmd+R straight after.

If you change a column, allowed value, id rule or file folder in the app, update the recipes in `AIGuide.swift` too (section 8).

## 2. Who uses it and why

- **One teacher** owns the project and uses it daily: a Year 6 class teacher at a primary school in Victoria. The class name defaults to `6AS` (`Database.defaultClassName`) and is editable in Settings. The code is public (MIT), shared in case it helps other teachers.
- **Colleagues** may share the planner folder (timetable, lessons, terms, units) through a shared iCloud Drive folder. They never see student records.
- **The classroom**: the teacher plans a fortnight at a time, projects the Class screen to students, logs notes quickly during lessons, and writes semester reports. A relief teacher sometimes needs the day's plan pasted into the school LMS.

Priorities, in order of how hard to break them:

1. **Student privacy.** Real names, notes, wellbeing, behaviour, medical details and photos live only in the student folder on the teacher's Mac. Nothing leaves the Mac.
2. **Never lose data.** The CSV files are the product. Writes are atomic, unreadable files are never overwritten, replacements are archived first.
3. **A plain, classic Mac look.** Native controls, grouped forms, no novelty styling.
4. **Australian English** everywhere: organise, colour, licence, judgement, "Mathematics" in full in reports. Dates read 13 Oct 2026 or Tuesday 13 October. Weeks start on Monday.
5. **Light mode on purpose.** It is forced in `HolocronApp.init` (`NSApplication.shared.appearance = NSAppearance(named: .aqua)`) and `.preferredColorScheme(.light)`. Do not add dark mode or semantic colours unless asked.

## 3. Glossary

Terms are verified against code or UI text unless marked "(expansion from general knowledge)". Victorian and school terms an outsider would not know are included.

### Timetable and calendar

| Term | Meaning in Holocron |
|---|---|
| A/B fortnight cycle | A two-week timetable. Week 1 of every term is A, then B, A, B. The cycle restarts each term. Not stored: `Database.weekLetter(date)` works it out from `terms.csv` (odd term weeks are A). |
| Term | One of four school terms a year, with a start and end date in `terms.csv`. Holidays fall between terms, so a date outside every term has no week and is not a school day. |
| Period | One block of the day, numbered in `periods.csv` with bell times. The starter folder numbers them 1 to 7 and period 1 is "Morning circle". Always look periods up. Do not assume. |
| Circle Time | A morning session at the start of the day (starter period 1, subject "Circle Time"). Never bumped (`Lists.noBump`). |
| Devotion | A daily scripture-based reflection script, for a faith-based school. Has its own screen, `devotion.csv` (scripture, reading, message, prayer and more) and subject "Devotion". Never bumped. Can be kept private. |
| Face to face | Minutes taught by the teacher: periods whose subject `kind` is `teach` (`Database.dayMinutes`). |
| Release time | Minutes taught by a specialist (PE, Art, Music, STEM, French in the starter list) while the teacher is released: subject `kind` is `release`. |
| DOTTL | "Duties other than teaching and learning": meetings, yard duty, planning and so on, logged by hand in `dottl.csv`, plus wellbeing minutes from students. Shown on Hours. |
| Relief teacher (CRT) | A visiting teacher covering the class. "Copy lessons" pastes a day's plan for them. The code says "relief teacher". CRT is casual relief teacher (expansion from general knowledge). |
| LMS | The school's learning management system, where plans are pasted (`DayMarkdown.swift`). |
| Non-teaching day | A whole day off with a label (pupil free day, public holiday) in `nonteaching.csv`. `isNonTeaching`. |
| Day override | A date that does not follow the timetable: Camp, Sports carnival, Excursion, Pupil free day, Other (`Lists.dayTypes`, `dayoverrides.csv`). "Normal" cancels an override. |
| School day | Weekday, inside a term, not non-teaching (`isSchoolDay`). `runsNormally` also needs no override other than Normal. |
| Bump, push, pull | Pushing moves a lesson and later lessons for that subject forward to the subject's next slot. Pulling moves them back into an empty slot. A lost day pushes every subject (`Database+Bump.swift`). Previewed first, with Undo. |
| One-off change vs standing change | A one-off writes `dayplan.csv` for one date and period. A standing change edits `timetable.csv` for every matching A or B week. |
| Semester (S1, S2) | Report periods written `2026-S1`, `2026-S2`. Semester 2 starts in July (`Database.semesterTwoStartMonth = 7`). Reporting is by semester. |
| Unit of inquiry | A multi-week topic in `units.csv` with start and end dates. The `TDL` subject slot shows the current unit (`unitOn`). TDL is likely transdisciplinary learning (expansion from general knowledge). |

### Curriculum and PYP

PYP is the International Baccalaureate Primary Years Programme. The school uses it, so lessons and units carry its vocabulary (`PYP` in [Schema.swift](Holocron/Core/Schema.swift)).

| Term | Meaning |
|---|---|
| Transdisciplinary themes | Six themes a unit sits under (`PYP.themes`): Who we are; Where we are in place and time; How we express ourselves; How the world works; How we organise ourselves; Sharing the planet. Each has a colour. |
| Key concepts | Form, Function, Causation, Change, Connection, Perspective, Responsibility (`PYP.keyConcepts`). A unit has several. |
| Central idea, lines of inquiry | A unit's big statement and the questions under it. Lines of inquiry are one per line in a cell. |
| ATL skills | Approaches to learning: Thinking, Research, Communication, Social, Self-management (`PYP.atlSkills`). Tagged on lessons and units. |
| Learner profile | Ten attributes, Inquirers to Reflective (`PYP.profile`). Tagged on lessons and units. |
| WALT, learning intention (LI) | "We are learning to...". Column `li` in `lessons.csv`. The Class screen shows it under the heading "We are learning to". |
| Success criteria, "I can" | How students show they met the intention. Column `sc`. Shown on the Class screen under "I can". |
| Curriculum codes | Codes such as those of the Victorian Curriculum, in `lessons.codes` (split on commas or spaces). |
| Strands | Areas inside Mathematics or English (for example a number strand). Used by Essential Assessment and `strandcomments.csv`. |
| Essential Assessment | An online maths and English assessment tool. Holocron imports its results exports and its Report Comments exports (Areas of Success, Growth, Improvement), by strand and substrand. |

### Students and reporting

| Term | Meaning |
|---|---|
| Achievement levels | `Lists.achievement`: Extending, Mastering, Consolidating, Developing, Emerging, Modified, Not assessed. Used for results and semester judgements. "Modified" is for students with an ILP (the Report tab warns otherwise). |
| Engagement scale | `Lists.engagement`: Comprehensive, Appropriate, Inconsistent, Minimal. |
| Rubric levels | `Lists.rubricLevels`: Working Towards, At Standard, Working Beyond. |
| ILP | Individual Learning Plan. `students.ilp` is `yes` or empty. Report drafts end with the teacher's ILP sentence, added by code, never by the model. |
| SSG | Student Support Group, a meeting about a student with additional needs in Victoria (expansion from general knowledge). The code has an "SSG meeting" plan note type and an "SSG or report pack" button. |
| NCCD | Nationally Consistent Collection of Data on School Students with Disability (expansion from general knowledge). Plan note types "NCCD adjustment" and "NCCD evidence"; `students.nccd`. |
| Adjustments | Changes made to teaching for a student with additional needs (`students.adjustments`). Private. Never sent to the model. |
| House | A school sport and community team. `students.house`. The four with colours are Deakin, Barton, Parkes, Higgins (`Lists.houseColours`). Other text is accepted. |
| Preferred name | The name a student uses at school (`students.preferred`). Reports write the formal name first, then the preferred name in brackets. |
| Report pack | A copy or save of one student's notes, results and wellbeing for a date range, with an option to leave out medical details. Opened by "SSG or report pack". |
| SIMON | The school's report and records system. "Copy for SIMON" puts English and Mathematics dot points on the clipboard with `%*` starting each one (`DotPointDrafter.forSIMON`). |
| Report comment | A general comment per student per semester (100 to 150 words in the school style), plus English and Mathematics dot points. Drafted on device, saved only when the teacher chooses Use. |

### Screens and app terms

| Term | Meaning |
|---|---|
| Planner folder vs student folder | The planner folder holds the 12 planner tables (`TableName.isPlanner`) and may be shared. The student folder holds everything else, photos and `settings.csv`, and is always private. If no planner folder is chosen, everything is in one folder. |
| Private subject | A subject whose lessons are kept in `lessonsprivate.csv` in the student folder instead of the shared `lessons.csv`. Set by a `private_subject_<name>,on` row in `settings.csv`. |
| Class screen | A projector view of the current lesson for students: learning intention, "I can", First, Then and Next steps, a Now and Next strip, a timer and work modes (Silent, Whisper, Partner, Group, Ask 3 then me). Shows no student records. |
| Quick log | Pick several students from a photo grid and log one note to all. Can be dictated. |
| Mark class | Mark the whole class on one task, by score or achievement level. Internal name `NavItem.assess`. Results import lives here. |
| Copy lessons / Copy day | Copies a day's times, lessons and resources as rich text (HTML, RTF, plain text). No student information. |
| Holocron archive | A folder beside the student folder where year end archives, import backups, results import backups and Start over archives go. Nothing in it is read by the app. |
| Module | A screen that can be switched off in Settings (`module_<name>,off`). Today always stays on. |
| Toast | The short message at the bottom of the window, for example "Saved". |

## 4. Repository map

```
AGENTS.md                  this file
CLAUDE.md                  Claude Code rules: build, conventions, data safety, guardrails, release
README.md                  teacher-facing overview, install, privacy, maintainer notes
CHANGELOG.md               release history in plain language; "## Unreleased" is the draft notes
LICENSE                    MIT
Holocron.xcodeproj/        Xcode project, folder-synced groups, ad hoc signing, no packages
Holocron/
  HolocronApp.swift        @main, scenes, menus, forced light mode, en_AU locale
  AppModel.swift           @Observable app state, folder, load/save, privacy merge, photos, imports
  ModuleSettings.swift     switch screens on and off via settings.csv
  Core/                    logic that needs only Foundation (plus FoundationModels, Speech, Compression)
  Intents/                 App Intents for Siri, Spotlight and Shortcuts
  Views/                   every SwiftUI screen, sheet and shared style
  Assets.xcassets/         accent colour and app icon
  Holocron.icon/           macOS 26 icon source
docs/                      ARCHITECTURE, DATA, FEATURES, PROBLEMS, ROADMAP, icon.png
scripts/release.sh         build, checksum, tag, publish
.github/workflows/build.yml  CI
.claude/agents/            code-reviewer.md, ui-design-check.md
Claude outputs/            Apple Human Interface Guidelines reference notes and holocron-hig-plan.md
build/, dist/              local build output (ignored)
state/                     tool leftovers (see below)
```

Inside `Holocron/Core`: `Schema.swift` (tables, columns, fixed lists), `CSV.swift`, `DataFolder.swift`, `Database.swift` plus `Database+Schedule/Bump/Hours/Students/Settings.swift`, `Dates.swift`, `Tone.swift`, `Starter.swift`, `ImportPlan.swift`, `YearEnd.swift`, `StartOver.swift`, `ResultsImport.swift`, `XLSX.swift`, `ColumnSuggest.swift`, `StrandComments.swift`, `CommentDraft.swift`, `LessonDraft.swift`, `NoteSorter.swift`, `NoteTagger.swift`, `Dictation.swift`, `Intelligence.swift`, `TodoParse.swift`, `TextScan.swift`, `Updates.swift`, `DayMarkdown.swift`, `SiriAnswers.swift`, `AIGuide.swift`. `TodoParse` is plain Foundation and has no model. `TextScan` uses Vision, PDFKit and AppKit, not Foundation only. The full file-by-file table is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Inside `Holocron/Views`: one file per screen (`TodayView`, `WeekView`, `TermUnitsDevotion`, `ClassScreen`, `StudentsView`, `MarkClassView`, `HoursView`), Settings (`SettingsView` is the sidebar shell, `SettingsPanes` holds the General, Timetable, Calendar, Folders, Privacy and Year End panes, `IntelligenceSettings` the Apple Intelligence pane, and `Updater` the Updates pane), shared pieces (`Theme`, `Sheets`, `RootView`, `AssistViews`), feature sheets (`ImportResultsSheet`, `StrandCommentsSheet`, `YearEndSheets`, `StartOverSheet`, `DictateSheet`, `DraftViews`, `ResultInput`), output (`PrintWeek`, `CopyDay`), `Updater`, and Help (`HelpView`, `HelpContent`).

### Never commit

- **CSV files** and **`photos/`**. `.gitignore` has `*.csv` and `photos/`. CI and `scripts/release.sh` fail if `git ls-files` shows either. These are real student and planner data. Never put real names or data in fixtures, comments, docs or logs.
- **`build/`, `dist/`, `*.zip`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`** (all in `.gitignore`).
- **`state/`.** `state/inuse.26997.lock` is tracked by mistake (added by the 1.9.1 release commit). It is not Holocron's. `.gitignore` does not list `state/` yet, and `scripts/release.sh` runs `git add -A`, so it can happen again. Do not add anything under `state/`. Removing it (`git rm`, then ignore `state/`) is on the roadmap. Ask first.
- **README-for-AI.md** generated into a data folder. It belongs to the data folders, not this repository.

`Claude outputs/` is tracked on purpose. It holds Apple HIG reference notes written during a design review. [holocron-hig-plan.md](Claude%20outputs/holocron-hig-plan.md) ranks the remaining interface improvements. Treat the rest as reference.

## 5. How the app works

Detail is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). This is the mental model.

1. **Launch.** `HolocronApp.init` forces light mode, creates one `AppModel`, and gives it to `IntentHost.model` so App Intents can reach it. Every window gets the `en_AU` locale and a Monday-first Gregorian calendar.
2. **Folder resolution.** `AppModel.init` reads `dataFolderPath` and `plannerFolderPath` from `UserDefaults`, falling back to `DataFolder.defaultURL()`. If the folder exists it calls `loadAll()`. Otherwise `SetupSheet` offers iCloud Drive, a chosen folder, or import of an existing one.
3. **Load.** `loadAll` reads the privacy settings first (`readPrivacy`, from `settings.csv`), then every `TableName` through `DataFolder.read`, which returns `.ok`, `.missing` or `.failed`. Missing files are created blank (periods and subjects get starter rows from `Starter`). Failed reads go into `badLoads` and are never written. An iCloud placeholder (`.name.csv.icloud`) starts a download and counts as failed. Lessons are merged with `lessonsprivate` (`mergeLessons`).
4. **Database.** `Database` holds each table as `[String: [Row]]`, where `Row` is `[String: String]`. Everything is text until a helper parses it. `load` keeps any extra columns a file has. Lookup dictionaries live in `Database.Index`, built on first use and invalidated per table.
5. **Per-table stamps.** Each `TableName` has a `TableStamp`. `db.rows(t)` and `db.index(t)` register a dependency on that table's stamp, so SwiftUI redraws only views that read the changed table. Read through `rows` and `index`, never `tables`, or the view will not redraw.
6. **Edits.** A view calls a `Database` method (for example `setSummary`). It changes rows with `append`, `update`, `remove` or `setRows`, then calls `touch(.table)`.
7. **Save.** `touch` calls `AppModel.schedule`, which waits 0.18 seconds and calls `flushNow`. `flushNow` skips tables in `badLoads`, builds one write job per table, and writes on a serial background queue (`au.holocron.save`) with `Data.write(to:options: .atomic)`. Lessons are written to two files (shared and private). Quit, folder switch, import and Siri use `flushNow(wait: true)`.
8. **Reload.** When the app becomes active, `reloadIfIdle` re-reads only files whose modified time and size changed (`DataFolder.signature`). Shift+Cmd+R (`reloadFromFolder`) forces a full reload. There are no lock files.
9. **Privacy routing.** `DataFolder.root(for:)` is the only place that decides a table's folder. Planner tables go to the planner folder unless in `privateTables` (Devotion and quotes when `private_devotion,on`). Everything else, including `settings.csv`, `todo.csv`, `dottl.csv` and photos, goes to the student folder. Private subjects use `lessonsprivate.csv`.
10. **Schedule resolution.** For a date and period, `plannedSubject(date, period)` returns the `dayplan.csv` row if one exists, otherwise the `timetable.csv` row for that date's week letter, day (0 Monday to 4 Friday) and period. The week letter comes from `terms.csv` (`termOf`, `termWeek`, `weekLetter`). `nonteaching.csv` and `dayoverrides.csv` decide whether the day runs (`isSchoolDay`, `runsNormally`). Hours, bumping, Siri answers and Copy lessons all use those checks.
11. **Updater.** `Updater` (in `Views/Updater.swift`) checks `api.github.com/repos/andrew-snape/holocron-planner/releases/latest` at launch and on focus, at most every six hours. `defaultRepo` is a constant. `ReleasePick` (in `Core/Updates.swift`) only accepts a release that is newer, has a Holocron zip and a `.sha256` file, with downloads under `https://github.com/<repo>/releases/download/`. `install` refuses a copy running from DerivedData, compares SHA-256, unzips with `ditto`, checks bundle id, version and `codesign --verify --deep --strict`, saves everything, then a shell script swaps the app and rolls back on failure.
12. **Apple Intelligence.** `Intelligence.status` reads `SystemLanguageModel.default.availability`. `Intelligence.can(feature, db)` is true when the model is ready and the feature is not off (`AIFeature`: dictation, drafts, columns, lessonDraft, noteTags; settings keys `ai_dictation`, `ai_drafts`, `ai_columns`, `ai_lessonDraft`, `ai_noteTags`). Features: dictated notes (`Dictation`, `NoteSorter`), report comments and learning intentions (`CommentDrafter`, `DotPointDrafter`, `IntentDrafter`), import column suggestions (`ColumnSuggest`), Draft lesson… in the lesson editor (`LessonDrafter`, `LessonDraftArea`), and Suggest subject and kind on typed notes (`NoteTagger`, `NoteSuggestBar`). Drafts appear in a `DraftBox` (or the lesson draft preview); nothing reaches a CSV until the teacher chooses Use. Two helpers need no Apple Intelligence: `TodoParse` works out a to-do and its due date from plain words in code (the to-do box on Today, and the Add a To-Do intent in `strict` mode, which only takes a date that is safe without asking), and `TextScan` reads a photo, scan or PDF with Vision (`Scan text…` on `NoteBox(scannable: true)`, file choice only; the picture is never kept and nothing is sent). **Warm-up:** the places that draft call `prewarm` when they open (`CommentDrafter`, `DotPointDrafter`, `IntentDrafter`, `NoteSorter`, `ColumnSuggest`), which builds a session and loads the model through `Intelligence.prewarm`. The session is held in `WarmSessions` (Intelligence.swift) and used once, only if its instructions and `warmFingerprint` (the facts and the roll) still match, compared as SHA256 digests. Entries expire after 180 seconds, at most six are held, and the screen discards its own on `onDisappear` (`WarmSessions.discard`), because a warmed session holds student text. Nothing is written to disk.
13. **App Intents.** `Intents/HolocronIntents.swift` defines 11 intents and two entities (`StudentEntity`, `SubjectEntity`). `HolocronShortcuts.swift` lists the Siri phrases for 10 of them (the Describe Holocron intent has no phrase). `SiriAnswers.swift` works out spoken answers. `IntentHost.require()` throws when the folder is missing and `require(writing:)` when the table could not be read. Names are only used when `siri_names` is on and no Class screen is open. Birthdays, Log a Note and Copy Today need an unlocked Mac.
14. **AI guide writer.** After each load, `AppModel.writeAIGuides` calls `DataFolder.writeAIGuides`, which makes the Markdown and hands it to `AIGuideWriter` on a background queue. It writes atomically and only when the text changed. It skips an unreadable guide and never replaces one written by a newer Holocron version.

Windows: main `WindowGroup` with `RootView` (sidebar plus `DetailRouter`), a Class screen `WindowGroup` (one per lesson), `Settings` (a sidebar with search and eight panes in three groups: General, Timetable and Calendar; Apple Intelligence; Folders, Privacy, Year End and Updates; minimum 720 by 500), and a Help `Window`.

## 6. Data model at a glance

Source of truth: `TableName` and `TableName.header` in [Schema.swift](Holocron/Core/Schema.swift). 26 cases, 12 of them planner tables. Full columns, meanings and relationships are in [docs/DATA.md](docs/DATA.md).

| File | Folder | Key columns | Purpose |
|---|---|---|---|
| `subjects.csv` | planner | `subject`, `kind`, `colour` | Subjects. `kind` is `teach`, `release` or `dottl`. The name is the key everywhere. |
| `periods.csv` | planner | `period`, `start`, `end` | Bell times. |
| `timetable.csv` | planner | `week`, `day`, `period`, `subject` | The A/B template. |
| `dayplan.csv` | planner | `date`, `period`, `subject` | One-off change for one slot. |
| `lessons.csv` | planner | `date`, `period`, `subject`, `summary`, `li`, `sc` | Lesson plan for a date and period. |
| `rubrics.csv` | planner | `rubric`, `element`, `level` | Marking descriptors. |
| `terms.csv` | planner | `year`, `term`, `start`, `end` | Term dates. They drive weeks and school days. |
| `nonteaching.csv` | planner | `date`, `label` | Whole days off. |
| `dayoverrides.csv` | planner | `date`, `type`, `note` | Camps, carnivals, excursions. |
| `devotion.csv` | planner (can be private) | `date`, `theme`, `scripture` | Devotion and Circle Time scripts. |
| `quotes.csv` | planner (can be private) | `date`, `quote`, `artist` | Quote card on Today. |
| `units.csv` | planner | `id`, `title`, `theme`, `start`, `end` | Units of inquiry. |
| `students.csv` | student | `id`, `first`, `surname`, `ilp` | The roll, with private details. |
| `assessments.csv` | student | `id`, `student_id`, `subject`, `task`, `result` | Results. |
| `plannotes.csv` | student | `id`, `student_id`, `type`, `note` | ILP, SSG, NCCD notes. |
| `wellbeing.csv` | student | `id`, `student_id`, `period_lost`, `minutes` | Wellbeing entries. Minutes count as DOTTL. |
| `behaviour.csv` | student | `id`, `student_id`, `note` | Behaviour entries. |
| `lessonnotes.csv` | student | `id`, `student_id`, `time`, `subject`, `note` | Notes made in a lesson. |
| `reportjudge.csv` | student | `student_id`, `sem`, `subject`, `achievement`, `engagement` | Report ratings. |
| `reportcomment.csv` | student | `student_id`, `sem`, `general`, `english`, `maths`, `context` | Report text. |
| `strandcomments.csv` | student | `student_id`, `sem`, `strand`, `substrand` | Imported Essential Assessment comments. |
| `classsteps.csv` | student | `date`, `period`, `first`, `then`, `next` | Class screen steps. |
| `dottl.csv` | student | `id`, `date`, `type`, `minutes` | Hours log (duties other than teaching). |
| `todo.csv` | student | `id`, `text`, `due`, `done`, `created` | To-do list. |
| `lessonsprivate.csv` | student | same as `lessons.csv` | Lessons for private subjects. Created when first needed. |
| `settings.csv` | student | `key`, `value` | Holocron's own settings (module switches, privacy, AI switches, class name, report rules). First row for a key wins. |

Formats:

- **Files:** UTF-8 (Latin-1 accepted on read), heading row, comma separated, fields quoted only when needed. Rows with every cell empty are dropped. Extra columns are kept and written back.
- **Date:** `yyyy-MM-dd` text, compared as text. **Time:** 24-hour `HH:mm`. **Week:** `A` or `B`. **Day:** `0` Monday to `4` Friday, in `timetable.csv` only. **Period:** a whole number matching `periods.csv`.
- **Ids:** `uid()` in [Dates.swift](Holocron/Core/Dates.swift): the time in milliseconds in base 36 plus four random characters from `0-9a-z`. Unique, no spaces, never changed.
- **Semester:** `yyyy-S1` or `yyyy-S2`. **Lists in a cell:** comma separated, except lines of inquiry and report dot points (one per line).
- **No booleans.** `students.ilp` is `yes` or empty. `todo.done` is the date ticked off, or empty.

## 7. Hard rules (never break)

**Data safety**

- Writes stay atomic (`DataFolder.write`). Never write a CSV another way.
- A table in `badLoads` is never written. Outside a screen (intents, new import code) check `canWrite(_:)` first.
- A missing file is created blank. An existing file is never reset.
- Replacing, moving or clearing files needs a verified copy first, a rollback on failure, and a destination inside `Holocron archive`. Wait for iCloud placeholders before copying. Nothing is ever deleted. Follow `ImportPlan`, `YearEnd` and `StartOver`.
- A shared planner folder is only ever disconnected, never cleared or overwritten without an explicit choice.
- Older files that lack a newer column must still load. Read with `row.s("col")`, which returns `""`.
- Do not run any code, script, `swiftc` test or build-and-launch against the teacher's real data folder. Use temporary folders and invented data.

**Privacy**

- `TableName.isPlanner` and `DataFolder.root(for:)` decide folders. Never put student information in a planner table or the planner guide.
- Student names, photos, notes, wellbeing, behaviour, medical details, adjustments and plan notes must not reach the Class screen, Copy lessons, print output, logs, the update check, or any shared folder.
- No student data in this repository: no CSVs, photos, real names in fixtures, tests, comments, docs or commit messages.
- The only network request is the update check. (macOS itself may download its speech model the first time the teacher dictates. That is the system, not Holocron.)

**AI guardrails** (see `Intelligence.swift`, `CommentDraft.swift`, `NoteSorter.swift`)

- All model use is on device (FoundationModels, Speech). Never add a feature that sends student data off the Mac or to a third-party service.
- Never sent to the model for report drafts: wellbeing, behaviour, medical notes, adjustments, plan notes (ILP, SSG, NCCD), parents, birth dates, photos. Other students' names become "a classmate" (`maskingNames`). Notes matching `CommentDrafter.privateWords` are dropped, and a draft that mentions a private term is refused.
- The ILP sentence is added by Holocron (`finish`), never written by the model.
- Dictation only splits words. Names are matched to the roll in code, a name must have been said, "whole class" needs those words, and shared first names ask which student.
- Drafts stay drafts until the teacher chooses Use. They can be edited, retried or discarded. A discarded draft never returns (`Task.checkCancellation`, run tokens).
- On a model refusal, `CommentDrafter.draft` retries with fewer notes (`Omit`: unit notes, lesson notes, all notes) and says what was left out.
- Every feature has an off switch (`AIFeature`, keys `ai_*`) and hides itself when the model is unavailable.
- Lesson drafts (`LessonDrafter`) read planner text only, and every name on the roll becomes "a student" first, because lessons may sit in a shared folder. Known limitation: masking is by whole word, so a real word that is also a student name (Mark, Grace) is masked too.
- Note tagging (`NoteTagger`) is limited to a dynamic schema of the three kinds and the teacher's own subjects, so it cannot invent an answer, and it only runs when the teacher chooses Suggest. The note is read on this Mac and never logged.
- Warmed sessions (`WarmSessions`) hold student text in memory: 180 seconds, discarded on `onDisappear`, compared by digest. Do not log them or write them to disk.
- The lookup tools for report drafts (`TeacherNotesTool`, `TestResultsTool`, `UnitOfInquiryTool`) are built but off (`CommentDrafter.useLookupTools = false`) pending a side-by-side comparison of drafts. They read through the same filters as the packed facts (`reportEligibleNotes`, `reportEligibleTests`), so the exclusions cannot differ. Do not switch them on without that comparison.
- Siri and Shortcuts say no student names unless `siri_names` is on, and never while a Class screen is open.

**Update security**

- A release without a `.sha256` file is never offered. The checksum is always compared.
- The repository is the constant `Updater.defaultRepo`. Do not add a setting for it.
- Do not loosen `ReleasePick.isTrustedDownload` (HTTPS, `github.com/<repo>/releases/download/`).
- Do not weaken the bundle id, newer version or `codesign --verify --deep --strict` checks in `Updater.install`.

**Project**

- No new dependencies (Swift packages, scripts needing installs) without asking the teacher.
- Keep light mode. Do not add dark mode or semantic colours.
- Australian English in UI copy, comments and docs.
- Do not edit `Holocron.xcodeproj` for a new Swift file. Groups are folder-synced.
- Do not commit, tag, push or release unless the teacher asks.

## 8. Working on the code: recipes

Each recipe names real functions and files. When one step says "compile error", the build enforces it, so follow the error rather than skipping it.

### Add a column to an existing table

1. Add the column name to `TableName.header` for that case in [Schema.swift](Holocron/Core/Schema.swift). Append at the end unless there is a reason not to.
2. Read it with `row.s("newcol")`. Older files lack the column and `s` returns `""`. `Database.load` builds the heading from the known columns plus any extra columns the file has, so the next save writes the new heading. Never assume the key exists.
3. Write it in the `Database` extension that owns the feature (for example `Database+Students.swift`), then call `touch(.table)`. If the table has a typed view (`Student`, `Term`, `SubjectInfo`, `LessonContent`), add the field there and where the view is built in `Database.swift`.
4. **AI guide.** The file list and columns update by themselves. Then check the hand-written parts of [AIGuide.swift](Holocron/Core/AIGuide.swift): `describe(_:)` (one-line description), `valueRules` (allowed values and required cells), `recipes` (sample rows are built with `header.count`, but check the text and the `tail`/comma counts), and `doNot`. If the column takes fixed values, add them to `Lists` or `PYP` and reference them from the guide, not as copied strings.
5. Check the older Help text: `CSVGuide.detail` and `CSVGuide.summary` in [Views/HelpContent.swift](Holocron/Views/HelpContent.swift).
6. If the column holds student information, check the AI exclusions in `CommentDraft.swift` (`reportFacts`, `privateWords`) and that nothing shared or printed includes it.
7. Update [docs/DATA.md](docs/DATA.md) (tables, formats, fixed lists) and add a user-facing bullet to `## Unreleased` in [CHANGELOG.md](CHANGELOG.md).

### Add a new table

1. Add a `case` to `TableName` in `Schema.swift` with a doc comment, and its heading in `header` (a switch with no default, so every case must be listed).
2. Decide the folder in `isPlanner`. Student information and anything personal is **not** planner. If it could be made private like Devotion, see `DataFolder.privateTables` and `AppModel.readPrivacy`.
3. Add the one-line description in `AIGuide.describe` (no default, so a missing case is a compile error). Add the same table to the switches in `CSVGuide.summary` and `CSVGuide.detail` in `HelpContent.swift` (also compile errors).
4. If a new folder should start with rows, add them to `Starter.rows(for:)`. Otherwise the file is created blank on first load.
5. Verified automatic behaviour through `TableName.allCases`: `Database.init` (storage and change stamp), `AppModel.loadAll` (read, create blank, `badLoads`), `flushNow` (via `touch`), `ImportPlan` (`.planner` filters on `isPlanner`, `.everything` takes all), `YearEnd.archivePlan`, `StartOverPlan` and the README-for-AI file list.
6. **Not automatic:** Start over with the planner-only scope clears only `t.isPlanner || t == .lessonsprivate || t == .classsteps` (`StartOver.swift`). A new student-side table that belongs to the planner reset must be added there. Also check `AppModel.usePlannerFolder`, which copies only planner tables.
7. Add a recipe to `AIGuide.recipes` only if an assistant is likely to edit the table, with `valueRules` entries to match.
8. Update [docs/DATA.md](docs/DATA.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (file map and counts), `CHANGELOG.md`.

### Add a screen (module)

1. Add a case to `NavItem` in [AppModel.swift](Holocron/AppModel.swift) with `title` and `symbol`. Both switches are exhaustive.
2. Add its `blurb` in [ModuleSettings.swift](Holocron/ModuleSettings.swift) (exhaustive). The Settings module list and the on/off switch (`module_<rawValue>` in `settings.csv`) come from `NavItem.allCases.filter { $0.canDisable }` and `isEnabled`.
3. Route it in `DetailRouter` in [Views/RootView.swift](Holocron/Views/RootView.swift) (exhaustive switch). The sidebar uses `visibleNav`.
4. **Go menu shortcut:** `HolocronApp.swift` gives item `idx` the key `(idx + 1) % 10`, so ten screens use Cmd+1 to Cmd+0. An eleventh would reuse Cmd+1. Decide a different shortcut before adding one, and keep the order text in Help and README in step.
5. Update Help: the shortcuts row in `HelpContent.swift` (hand-written list), the "Using Holocron" page, and the shortcuts section in `README.md`.
6. Add `docs/FEATURES.md`, `docs/ARCHITECTURE.md` (file map) and `CHANGELOG.md` entries. Run `ui-design-check`.

### Add a Settings option

1. Pick a `settings.csv` key. Keep the prefix style: `module_<name>`, `ai_<feature>`, `private_subject_<name>`, `pronoun_<student id>`.
2. Read with `db.setting(key)` and write with `db.setSetting(key, value)` ([Database+Settings.swift](Holocron/Core/Database+Settings.swift)). A missing row must mean the default. `setSetting` calls `touch(.settings)` for you.
3. Add a typed accessor beside the others in `Database+Settings.swift` or the feature's extension, with a `static let` for the key.
4. Add the control in the right pane of [Views/SettingsPanes.swift](Holocron/Views/SettingsPanes.swift) (`SettingsTab` in [Views/SettingsView.swift](Holocron/Views/SettingsView.swift): general, timetable, calendar, intelligence, folders, privacy, yearend, updates). Use `settingsForm()` and `.labelsHidden()` on text fields.
5. Add the key to the Settings keys table in [docs/DATA.md](docs/DATA.md). `settings.csv` is private, and the AI guide tells assistants not to touch it, so the guide needs no change unless the setting affects file routing.
6. If it affects privacy routing, extend `Database.privacy(from:)`, `AppModel.readPrivacy` and the guide context in `AIGuide.Context`.

### Add an App Intent

1. Add an `AppIntent` struct in [Intents/HolocronIntents.swift](Holocron/Intents/HolocronIntents.swift). Reach data only through `IntentHost.require()`, or `IntentHost.require(writing: .table)` for a change, which also fails when the table could not be read.
2. Put the answer logic in `Database` (see [SiriAnswers.swift](Holocron/Core/SiriAnswers.swift)) so it can be reasoned about without UI.
3. Honour privacy: names only through `IntentHost.mayUseNames`. Student-related actions set `authenticationPolicy = .requiresAuthentication`. Actions that change data ask with `requestConfirmation`, call `saveNow(_:)`, and say "Saved" only after it returns true.
4. **App Shortcuts limit:** `HolocronShortcuts.appShortcuts` holds 10 `AppShortcut`s, which is the system maximum. It is full. A new intent is still available in the Shortcuts app without a phrase (as `DescribeHolocronIntent` is). To give it a phrase, replace or merge an existing one, and keep every phrase containing `\(.applicationName)`.
5. Update `HolocronShortcuts.examples` if you replace a phrase, the Integrations table in `docs/FEATURES.md`, the Help text and `CHANGELOG.md`.

### Add or change an Apple Intelligence feature

1. Read section 7 guardrails and `CommentDraft.swift` first. State what the model sees, and show that the list excludes the private categories.
2. Add an `AIFeature` case (`Intelligence.swift`) with `title` and `blurb` (both are exhaustive switches, so the build fails until each case has them), so the switch appears in Settings, Apple Intelligence (`ForEach(AIFeature.allCases)`). Its key is `ai_<rawValue>`. Gate every entry point with `Intelligence.can(feature, db)` so it hides when the model is unavailable or switched off.
3. Run the model on the main actor with cancellation checks (`Task.checkCancellation`) and run tokens, as `CommentDrafter` does. Show the result in a `DraftBox` (Use, Try again, Discard). Never write to a CSV before Use.
4. Mask other students' names, drop private notes, and handle a refusal and a too-long input (`Intelligence.isTooLong`, the `Omit` retry in `CommentDrafter.draft`). Do not name `LanguageModelError` directly: it only exists in the macOS 27 SDK and broke CI. Use the type-name check in `Intelligence.swift`.
   Prefer guided output (`@Generable`, or a `DynamicGenerationSchema` with `anyOf` for a fixed set of answers, as `NoteTagger` does). Use `GenerationOptions(samplingMode: .greedy)` for classification.
   If the feature drafts from student text and opens on a screen, warm it: build the session in a `prewarm` (call `Intelligence.prewarm(session, prefix:)`), store it with `WarmSessions.put(key, session:, instructions:, fingerprint:)`, and in the request use `WarmSessions.take(key, instructions:, fingerprint:)?.session ?? LanguageModelSession(...)`. Put whatever the session was built from in the instructions or fingerprint so a stale one is never used. Call `WarmSessions.discard` in `onDisappear`. Warm only when `Intelligence.can` is true.
   Check any FoundationModels API in the SDK, not from memory: read `FoundationModels.swiftinterface` under `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/FoundationModels.framework/Versions/A/Modules/FoundationModels.swiftmodule/` (the `arm64e-apple-macos` file). CI uses a different SDK from a development Mac, so avoid anything newer than the macOS 26 SDK.
5. Update `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, the guardrail list in `CLAUDE.md` and this file if rules change, and `CHANGELOG.md`. Run `code-reviewer`.

### Change the UI

1. Use the tokens in [Views/Theme.swift](Holocron/Views/Theme.swift): `Color.appBG`, `cardBG`, `ink2`, `ink3`, `hairline`, `appBlue`, `appGreen`, `appAmber`, `appRed`, `.card()`, `PageHeader`, `EmptyNote`, `NoteBox`. No raw `Color(red:...)` or hex values that duplicate a token. Subject colours come from `Tone`.
2. Sheets use `SheetFrame` ([Views/Sheets.swift](Holocron/Views/Sheets.swift)): title 18 bold, Escape closes (`.cancelAction`), Return confirms (`.defaultAction`), and `dirty:` asks before discarding. Settings forms use `settingsForm()`.
3. Text sizes follow neighbours (`.system(size: 13)` body, 12 to 12.5 for notes). Icon-only buttons need `accessibilityLabel`. Destructive actions use `role: .destructive`, `Color.appRed` and a confirmation.
4. The Class screen is projected. Check contrast and size, and never show student information there.
5. Run the `ui-design-check` agent (after any change in `Holocron/Views`).

### Change anything that touches files

Anything that reads, writes, moves, imports or archives CSVs, photos or the update path needs the `code-reviewer` agent before commit. Trace the failure path of every file operation: what is on disk if this step throws halfway? Also run it for `Updates.swift`, `Updater.swift` and `scripts/release.sh`.

### Always

- Add a bullet to `## Unreleased` in `CHANGELOG.md`, in the same plain voice (section 11).
- Keep [docs/](docs/) accurate where you changed behaviour. Docs describe code. Do not copy a doc claim into code or into this file without checking.

## 9. Build, run and verify

- **Xcode:** open `Holocron.xcodeproj`, press Cmd+R. Ad hoc signing, no developer account. Sandbox is off (`ENABLE_APP_SANDBOX = NO`) so the app can reach iCloud Drive. `SWIFT_VERSION = 5.0`.
- **Release build, as CI does:**
  `xcodebuild -quiet -project Holocron.xcodeproj -target Holocron -configuration Release SYMROOT="$TMPDIR/holocron-build" CODE_SIGN_IDENTITY=- build`
- **Debug build, unsigned:**
  `xcodebuild -project Holocron.xcodeproj -scheme Holocron -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- **Build outside iCloud-synced folders for Release.** iCloud adds Finder attributes under Documents and code signing then fails with "detritus not allowed". The repository itself may sit under Documents, so point `SYMROOT` at `$TMPDIR` or `/tmp`.
- **No tests.** Verify by building, by reading the failure path of each file operation, and by hand in the app against a throwaway data folder. For `Holocron/Core` logic that needs only Foundation, compile the needed files with `swiftc` together with a small script in a scratch folder and run it against temporary directories. Use invented data only.
- **Do not launch a build against the teacher's real folder.** If you must run the app, point it at a temporary folder first (Settings, Folders).
- **CI** ([.github/workflows/build.yml](.github/workflows/build.yml)) runs on `macos-26` for every push to `main`, every pull request and on demand:
  1. Fails if any `.csv` file or `photos/` path is tracked.
  2. Warns (does not fail) if `CHANGELOG.md` has no `## <MARKETING_VERSION>` line.
  3. Builds the Release app with `SYMROOT` in the runner temp folder.
  4. Checks the app exists, prints version and architectures, runs `codesign --verify --deep --strict`, zips with `ditto`, and keeps the zip for 7 days.
- CI uses a different SDK from a development Mac (macOS 26 SDK on CI). Code that compiles locally against a newer SDK can fail there. See section 12.

## 10. Release process

Only when the teacher asks. Steps from [scripts/release.sh](scripts/release.sh) and [CLAUDE.md](CLAUDE.md):

1. Add the changes' bullets under `## Unreleased` as you work. To release, rename `## Unreleased` to `## X.Y` (or `## X.Y.Z`). The script requires a line exactly `## X.Y`. Its bullets become the release notes. Add a fresh `## Unreleased` afterwards if the teacher wants one.
2. Commit everything. The script refuses to run with uncommitted tracked changes (`git status --porcelain --untracked-files=no`).
3. Run `scripts/release.sh X.Y` (a version of numbers and dots).
4. The script then:
   - fails if the changelog section is missing or if `git ls-files` shows a CSV or `photos/`;
   - sets `MARKETING_VERSION` and adds 1 to `CURRENT_PROJECT_VERSION` in `project.pbxproj` with `sed`, and restores the project file if any later step fails;
   - builds Release in `mktemp -d /tmp/holocron-build.XXXXXX` (outside iCloud), logging to `dist/build.log`;
   - checks the built app's version matches and `codesign --verify --deep --strict` passes;
   - zips with `ditto -c -k --keepParent --norsrc --noextattr --noqtn` to `dist/Holocron-X.Y-mac.zip`;
   - writes `Holocron-X.Y-mac.zip.sha256` with `shasum -a 256`;
   - extracts the `## X.Y` section into `dist/notes.md`;
   - with `gh` installed and signed in: `git add -A`, commits "Holocron X.Y", tags `vX.Y`, pushes, pushes the tag and runs `gh release create` with the zip, the checksum and the notes. Without `gh` it prints manual steps for GitHub Desktop and github.com.
5. **A release must carry the `.sha256` file.** The updater ignores a release without it. If publishing by hand, attach both files.
6. Because the script runs `git add -A`, check `git status` first so stray files (for example under `state/`) are not swept into the release commit.
7. Running copies of Holocron then offer the update. Updates never touch data folders.

CI warns when the project version has no changelog section. Do not change `Updates.swift`, `Updater.swift` or the release script without running `code-reviewer`.

## 11. Style and conventions

**Code**

- Swift 5 language mode, SwiftUI, Observation. `AppModel` is `@Observable` and owns navigation and the folder. `Database` owns rows. Screens receive the model through `@Environment(AppModel.self)`.
- Logic lives in `Holocron/Core` and needs only Foundation (plus FoundationModels, Speech, Compression where unavoidable). Views stay thin. Feature logic is added as `extension Database` in a file beside its feature (`Database+Bump.swift`, `SiriAnswers.swift`, `StrandComments.swift`).
- Files group with `// MARK: -` headings. `///` documentation comments explain intent and failure cases in plain sentences, with no tags. Comments say why, not what.
- Naming: types are nouns (`ImportPlan`, `StartOverPlan`, `AIGuideWriter`), plain functions are verbs (`planPush`, `applyBump`, `flushNow`). Short, readable names such as `per` for period appear in existing code. Match the surrounding file.
- Four-space indentation, trailing closures, `guard` for early exit. Plan then apply: operations that touch files build a plan without changing anything (`startOverPlan`, `importPlan`, `archivePlan`), show it, then carry it out.
- Row access is `row.s("col")`. Tables are read through `db.rows(.t)` and `db.index(.t)`, and each change ends with `touch`.
- Keep values as text and parse where used. Dates are `yyyy-MM-dd` strings, compared directly. Use `Cal` in `Dates.swift` for calendar maths and `uid()` for ids.

**User-facing copy** (see [CHANGELOG.md](CHANGELOG.md))

- Short sentences with full stops. Verbs on buttons: "Make archive", "Import", "Draft comment", "Copy for SIMON". No jargon, no emoji, no exclamation marks except where the app already has one ("Get ready to learn!").
- Say what changed for the teacher, not how. Examples from the changelog:
  - "Report drafts no longer stop when Apple Intelligence refuses a note."
  - "Adding a non-teaching day for a date that already has one now updates its label instead of adding a second row, and a message says whether it was added or updated."
  - "Student names stay private. Siri only says or suggests them once you switch that on."
- Errors say what happened and what is safe: "teachers.csv could not be read, so it was not overwritten."

**Commits** (from `git log`)

- Short, sentence-case, imperative, no prefix and no full stop: "Retry comment drafts without notes on refusal", "Import Essential Assessment report comments for drafting", "Make dictation and drafting safe after review".
- Release commits are exactly "Holocron X.Y" (made by the script). Changelog-only commits are "Changelog for X.Y". Pull requests were merged from short branches (for example `report-rules`).
- Commits made by an assistant end with the attribution line the session gives. Do not commit unless the teacher asks.

## 12. Known problems and gotchas

Full list with causes and fixes: [docs/PROBLEMS.md](docs/PROBLEMS.md).

- **iCloud placeholders.** A file not yet downloaded shows as `.name.csv.icloud`. `DataFolder.read` starts the download and reports `.failed`. That table is not written until a later load reads it. Copying code must wait for downloads (`ImportPlan`, `YearEnd`).
- **Release builds inside iCloud folders** fail signing with "detritus not allowed". Build in `/tmp` or `$TMPDIR`.
- **Whichever saves last wins.** There are no lock files. Two copies of the app, the app plus a text editor, or two colleagues on a shared planner can overwrite each other. The only guards are the signature check and reload on focus. Hand edits must happen with Holocron quit.
- **Shared planner folder.** Colleagues see every change. Never write there on your own initiative, never put student data there, and only disconnect it, never clear it.
- **Light mode is forced** on purpose. A screenshot that shows light UI on a dark system is correct.
- **On-device model refusals.** Apple Intelligence sometimes refuses ordinary class topics. Holocron retries with fewer notes and reports what it left out. Refusals can still happen. Features hide when the model is off, not ready or unavailable.
- **SDK differences.** CI builds with the macOS 26 SDK. `LanguageModelError` exists only in the macOS 27 SDK, so the code recognises it by name. Test new framework use against the CI SDK.
- **Subject names are keys.** A rename must follow through every table (`Database.renameSubject`, `AppModel.renameSubject` for the private setting and hidden lesson rows). A lesson whose subject is not in `subjects.csv` shows in a grey default.
- **Always read through `rows` or `index`.** Reading `tables` directly means the view never redraws. Index lists are cached per table, so change data only through `Database` methods.
- **No undo** except Bump (while the sheet is open). Deleting a student removes every note attached to them. The safety net is the archive folders and the teacher's own backup.
- **No schema version.** There is no migration. New columns work because missing columns read as empty. Renaming or splitting a column has no upgrade path.
- **Hand-edited CSVs are trusted.** Duplicate or missing ids and invalid dates are not checked.
- **Fixed lists in code.** House colours, PYP lists, achievement words and the July semester start are constants for one Victorian school.
- **Numbers and Excel** can turn `2026-10-14` into a date cell or drop the leading zero of a time. Check exports.
- **Not notarised.** Ad hoc signing means a first launch needs right-click, then Open. The updater removes quarantine after install.
- **Tracked stray file:** `state/inuse.26997.lock`.

## 13. Where to find more

| Document | What it holds |
|---|---|
| [AGENTS.md](AGENTS.md) | This file. Orientation for any assistant. |
| [CLAUDE.md](CLAUDE.md) | Claude Code specific instructions: build commands, conventions, data safety, guardrails, release, agents. |
| [README.md](README.md) | Teacher-facing overview, install, updates, where data lives, privacy, maintainer notes. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the app is built, change flow, schedule logic, import and updater detail, file-by-file map. |
| [docs/DATA.md](docs/DATA.md) | Every table and column, formats, relationships, fixed lists, settings keys, archive folders. |
| [docs/FEATURES.md](docs/FEATURES.md) | Everything built, grouped by area, with the version it arrived and keyboard shortcuts. |
| [docs/PROBLEMS.md](docs/PROBLEMS.md) | Past bugs with symptom, cause, fix and commit, plus known limitations. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Suggested next work, first tests to write, HIG status. |
| [CHANGELOG.md](CHANGELOG.md) | Release history. `## Unreleased` is the draft notes. |
| [.claude/agents/code-reviewer.md](.claude/agents/code-reviewer.md) | Review agent for data safety, privacy, correctness and release hygiene. |
| [.claude/agents/ui-design-check.md](.claude/agents/ui-design-check.md) | Review agent for design consistency, readability and accessibility. |
| [.github/workflows/build.yml](.github/workflows/build.yml) | CI definition. |
| [scripts/release.sh](scripts/release.sh) | Release script. |
| [Claude outputs/holocron-hig-plan.md](Claude%20outputs/holocron-hig-plan.md) | Ranked Apple HIG review. The other files in that folder are HIG reference notes. |
| `README-for-AI.md` (in each data folder, not in this repository) | Generated by Holocron from `Core/AIGuide.swift`. The operating manual for editing live CSVs. |
| [Holocron/Core/Schema.swift](Holocron/Core/Schema.swift) | The source of truth for tables, columns and fixed lists. |

## 14. Questions to ask the teacher before you act

Stop and ask in these cases. A short question costs less than a lost term of data.

- **Deleting or replacing anything.** Rows, files, folders, students, a Settings value, a git tag or branch. Say what, and that it cannot be undone if that is so. Prefer archiving.
- **Anything touching the shared planner folder.** Writing to it, changing which folder is used, or changing its tables' columns. Colleagues see it.
- **Real student data.** Before reading, opening or summarising the student folder, and before putting any of it in a prompt, a file, a log or a commit. Confirm that school policy allows an AI tool to see it. Default to not looking.
- **Editing live CSVs.** Confirm Holocron is quit, that a backup exists, and which files you will change.
- **New dependencies**, new entitlements, turning on the sandbox, adding a network call, or any new place data could leave the Mac.
- **Releases.** Version number, whether to publish, tagging, pushing, and `gh release create`. Also removing `state/inuse.26997.lock` and editing `.gitignore`.
- **Changing guardrails.** What the model may see, name masking, private-word lists, Siri name rules, the update trust checks, the checksum requirement, or the light-mode choice.
- **Changing the data format.** Renaming or removing a column, changing an id rule, an allowed value or a file's folder. This affects the teacher's existing files and the AI guide recipes.
- **Anything you could not verify** against the code, or where the school's own rules are unclear (reporting style, term dates, house names).
