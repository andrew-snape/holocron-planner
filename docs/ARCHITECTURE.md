# Architecture

How Holocron is put together. For the data itself see [DATA.md](DATA.md). For rules when changing code see [../CLAUDE.md](../CLAUDE.md).

Holocron is one SwiftUI app target with no packages. UI code is in `Holocron/Views`, logic that needs only Foundation is in `Holocron/Core`, and Siri and Shortcuts are in `Holocron/Intents`. There is no test target.

## App entry and scenes

[HolocronApp.swift](../Holocron/HolocronApp.swift) is the `@main` entry. In `init` it forces the Aqua appearance (light mode, on purpose), creates one `AppModel`, and hands it to `IntentHost.model` so App Intents can reach it. It sets an Australian locale and a Monday-first Gregorian calendar in the environment of every window.

| Scene | What it is |
|---|---|
| `WindowGroup` with `RootView` | The main window. Minimum 520 by 480, default 1280 by 860. |
| `WindowGroup("Class screen", for: ClassTarget.self)` | The popped-out Class screen, one window per lesson. |
| `Settings` | The Settings window (Cmd+comma). A sidebar with search and eight panes in three groups: General, Timetable, Calendar; Apple Intelligence; Folders, Privacy, Year End, Updates. Minimum 720 by 500, ideal 780 by 600. The chosen pane is kept in the `settingsTab` default. |
| `Window("Holocron Help")` | The Help window. |

Menus: File gets New Student (Cmd+N), Log Note (Cmd+L), Import Results, Reload from folder (Shift+Cmd+R). A Go menu has one item per enabled screen (Cmd+1 to Cmd+0). Edit gets Copy Day as Rich Text (Option+Cmd+C). Print Week (Cmd+P) and Save Week as PDF (Shift+Cmd+P) replace the print items. `HelpCommands` replaces the Help menu. `AppCommands` adds Check for Updates.

## AppModel

[AppModel.swift](../Holocron/AppModel.swift) is an `@Observable` class and the one object screens receive with `@Environment(AppModel.self)`. It holds:

- Navigation and view state: `nav` (`NavItem`), `cursor` (the date on Today), `weekMonday`, `termKey`, `selectedStudent`, and `sheet` (an `ActiveSheet` enum that `SheetRouter` turns into a sheet).
- The `Database` (`db`), the `DataFolder` (`folder`), `folderOK`, `badLoads` and a toast.
- The Class screen timer (`ClassTimer`) and the set of open Class screens.
- The `Updater`.
- Work that spans files: loading, saving, privacy merge of lessons, photos, folder import, results import, year end archive, Start over, and the Siri vocabulary.

`ModuleSettings.swift` adds `isEnabled`, `setEnabled` and `visibleNav` so each screen except Today can be switched off. The switch is a `module_<name>` row in `settings.csv`.

## Database

[Core/Database.swift](../Holocron/Core/Database.swift) holds every table as `[String: [Row]]` where `Row` is `[String: String]`, exactly as in the CSV files. It also defines the small typed views (`Period`, `SubjectInfo`, `Term`, `Student`, `LessonContent`) and the lookup index. Everything is a string until a view or helper parses it.

Extensions add the logic. There is no persistence code inside them: they change rows and call `touch`.

| File | Adds |
|---|---|
| [Database+Schedule.swift](../Holocron/Core/Database+Schedule.swift) | Terms, term week, A/B letter, non-teaching days, day overrides, `plannedSubject`, one-off and standing changes, swaps, lesson read and write, subject rename, day types, units. |
| [Database+Bump.swift](../Holocron/Core/Database+Bump.swift) | Push and pull of lessons (see Bumping lessons). |
| [Database+Hours.swift](../Holocron/Core/Database+Hours.swift) | Face to face, release and DOTTL minutes for a day, a range or a fortnight. |
| [Database+Students.swift](../Holocron/Core/Database+Students.swift) | Student add, update and remove (with every attached note), log tables, today's entries, timeline, birthdays, to-do, SSG and report packs, report judgements and comment text. |
| [Database+Settings.swift](../Holocron/Core/Database+Settings.swift) | `settings.csv` as key and value, class name, and the private subject and private Devotion settings. |

Other extensions on `Database` sit beside their feature: `SiriAnswers.swift`, `DayMarkdown.swift`, `StrandComments.swift`, `ResultsImport.swift`, `CommentDraft.swift`, `Intelligence.swift`.

### Per-table change notifications

Each `TableName` has a `TableStamp` (an `@Observable` counter). `db.rows(t)` and `db.index(t)` call `watch(t)`, so SwiftUI registers a dependency on that one table. `changed(t)` bumps the stamp and drops the cached lookups built from that table. Typing in a lesson summary therefore redraws lesson views and leaves the sidebar calendar and Students alone. Always read through `rows` or `index`, never `tables` directly, or the view will not redraw.

### Lookup tables

`Database.Index` builds dictionaries and sorted lists once, on first use: periods by number, subjects by name, terms sorted, non-teaching labels, day overrides, the day plan, the timetable, lessons by (date, period), students by id, the roster, settings, and privacy. `invalidate(t)` clears only the lists built from `t`. Where a table has duplicate keys the first row wins, as the old scans did. Colour maths (`Tone`) is cached for good.

### Change flow

1. A view calls a `Database` method such as `setSummary`.
2. The method changes rows (`append`, `update`, `remove`, `setRows`), which bumps the table stamp.
3. It calls `touch(.table)`, which calls `persistHandler`, which is `AppModel.schedule`.
4. `schedule` collects the table names and waits 0.18 seconds, then calls `flushNow`.
5. `flushNow` skips any table in `badLoads`, builds a write job per table, and runs it on a serial background queue (`au.holocron.save`). Quitting, switching folders, imports and Siri use `flushNow(wait: true)`.
6. After each write the file signature (modified time and size) is stored in `fileSigs` so a later reload can tell the file is unchanged.

## CSV reading and writing

[Core/CSV.swift](../Holocron/Core/CSV.swift) parses and writes on UTF-8 bytes. The parser handles quoted fields with commas, doubled quotes and line breaks, skips a byte order mark and drops rows with every field empty. Header names are trimmed. The writer quotes a field only when it contains a comma, quote or line break, and always writes the table's header order.

[Core/DataFolder.swift](../Holocron/Core/DataFolder.swift) is a value type that knows where each file lives:

- `url` is the student folder. `plannerURL` is the planner folder, or nil when everything is in one folder. `privateTables` holds planner tables moved to the student folder (Devotion and quotes).
- `root(for:)` returns the folder for a table: planner tables go to `plannerURL` unless private; everything else goes to `url`.
- `read` returns `.ok`, `.missing` or `.failed`. An iCloud placeholder (`.name.csv.icloud`) starts a download and counts as failed ("still downloading"). A file that is not UTF-8 is tried as Latin-1.
- `write` is atomic: `Data.write(to:options: .atomic)`.
- `signature` returns modified time and size.
- `defaultURL()` is `~/Library/Mobile Documents/com~apple~CloudDocs/Holocron/data`.

The rule for failed reads: `AppModel.loadAll` records the table in `badLoads`, and `flushNow` refuses to write it and shows a toast. A missing file is created blank, with starter rows for `periods` and `subjects` ([Core/Starter.swift](../Holocron/Core/Starter.swift)).

## Folder selection, iCloud and reload

- First run shows `SetupSheet` ([Views/RootView.swift](../Holocron/Views/RootView.swift)) to use iCloud Drive or choose a folder, or to import an existing folder. The chosen paths are kept in `UserDefaults` (`dataFolderPath`, `plannerFolderPath`).
- `useFolder` flushes pending saves, switches, clears the photo cache and reloads. `usePlannerFolder` copies planner files the new folder lacks (never overwriting) and reloads.
- `FolderBanner` shows when the folder is missing or a file could not be read.
- When the app becomes active it calls `reloadIfIdle`. If nothing is waiting to save, `loadAll(force: false)` re-reads only files whose signature changed since the app last read or wrote them. Shift+Cmd+R forces a full reload.
- There are no lock files. Two copies of the app, or the app and an editor, can race. The signature check and "reload on focus" are the only guards. See [PROBLEMS.md](PROBLEMS.md), known limitations.
- Photos live in `photos/<student id>.jpg` in the student folder. They are shrunk to at most 480 pixels and saved as JPEG. Avatars load 256 pixel thumbnails through ImageIO and cache them, and remember students with no photo.

## The A/B fortnight cycle

Holocron has no stored "which week is it". It is worked out from `terms.csv` in [Database+Schedule.swift](../Holocron/Core/Database+Schedule.swift):

- `termOf(date)` finds the term whose `start` and `end` include the date. Outside any term (holidays) there is no week.
- `termWeek(date)` is the number of whole weeks between the Monday of the term's first day and the Monday of the date, plus 1.
- `weekLetter(date)` is A for odd term weeks and B for even. Week 1 of every term is A, so the cycle restarts each term.
- `timetable.csv` holds the template by week letter, day (0 Monday to 4 Friday) and period.
- `plannedSubject(date, period)` is the single answer to "what is on": a row in `dayplan.csv` for that date and period wins, otherwise the template for that date's week letter.

## Day overrides and non-teaching days

- `nonteaching.csv` lists whole days off by date, with a label (pupil free days, public holidays). `isNonTeaching` is true for those dates.
- `dayoverrides.csv` marks a date as Camp, Sports carnival, Excursion, Pupil free day or Other, with a note (`Lists.dayTypes`). "Normal" with no note removes the row.
- `isSchoolDay` is a weekday inside a term and not non-teaching. `runsNormally` also needs no override other than Normal. Hours, bumping, Siri answers and Copy lessons all use these two.
- `SiriAnswers.noLessonsReason` turns the same checks into a spoken reason.

## Bumping lessons

[Database+Bump.swift](../Holocron/Core/Database+Bump.swift). When a day is lost or a lesson needs to move, lessons for one subject shift along that subject's slots.

- `canBump` allows only `teach` subjects, not Circle Time or Devotion (`Lists.noBump`).
- `slotsAfter` lists the subject's later slots (by `plannedSubject`) up to the end of the last term, only on days that run normally.
- `planPush` empties the chosen slots and moves each lesson to the next slot of that subject. Lessons pushed past the last slot are counted as lost. `planPull` fills an empty slot from the next one.
- `dayBumpPlans` builds a push for every subject on a lost day.
- Plans are shown in `BumpSheet` before anything changes. `applyBump` writes all changes in one pass (`putContents`) and returns a snapshot of the lessons table, which the sheet offers as Undo (`undoBump`). Only `lessons.csv` changes.

## Privacy routing

- `TableName.isPlanner` marks the 12 planner tables. `DataFolder.root(for:)` sends everything else to the student folder.
- Private subjects: `settings.csv` rows `private_subject_<name>,on`. In memory, `lessons` is the shared file's rows for non-private subjects plus the private file's rows for private subjects (`mergeLessons`). `hiddenShared` and `hiddenPrivate` keep each file's other rows so they are written back untouched.
- Private Devotion: `private_devotion,on` moves `devotion.csv` and `quotes.csv` to the student folder (`DataFolder.privateTables`). Files are copied across when missing and never overwritten.
- `readPrivacy` reads `settings.csv` first on every load. If the answer changed, all file signatures are cleared so everything is re-read.
- Siri names: `siri_names,on` (off by default), and never while a Class screen is open.

## Import and export

| Piece | File | What it does |
|---|---|---|
| Folder import | [Core/ImportPlan.swift](../Holocron/Core/ImportPlan.swift), [Views/YearEndSheets.swift](../Holocron/Views/YearEndSheets.swift) | Plans first (nothing changes), rejects a source that is the folder in use or does not look like Holocron, waits for iCloud downloads, copies replaced files into `Holocron archive/Before import <stamp>`, swaps files in, rolls back on failure. A shared planner folder is left out unless asked. Runs off the main thread. |
| Year end archive | [Core/YearEnd.swift](../Holocron/Core/YearEnd.swift) | Copies the data folder into `Holocron archive/<year> year end`, built in a hidden folder and renamed when complete. Checks sizes, counts photos, writes `README.txt`. Changes nothing in the data folder. |
| Start over | [Core/StartOver.swift](../Holocron/Core/StartOver.swift), [Views/StartOverSheet.swift](../Holocron/Views/StartOverSheet.swift) | Moves files into `Holocron archive/Start over <stamp>` (planner only, or everything including photos), rolling back if a move fails. A shared planner is disconnected, not cleared. Then reloads with starter rows. |
| Results import | [Core/ResultsImport.swift](../Holocron/Core/ResultsImport.swift), [Views/ImportResultsSheet.swift](../Holocron/Views/ImportResultsSheet.swift), [Core/XLSX.swift](../Holocron/Core/XLSX.swift) | Reads CSV or the first sheet of an .xlsx, maps columns by header (Essential Assessment recognised as is), matches students (exact, remembered by file student ID, or likely), leaves out students not on the roll, updates results already imported, keeps typed comments. Copies `assessments.csv` into `Before results import` first. |
| Column suggestions | [Core/ColumnSuggest.swift](../Holocron/Core/ColumnSuggest.swift) | Optional on-device model suggestion of columns from headers and one example each. The teacher checks every column. |
| Strand comments | [Core/StrandComments.swift](../Holocron/Core/StrandComments.swift), [Views/StrandCommentsSheet.swift](../Holocron/Views/StrandCommentsSheet.swift) | Imports an Essential Assessment Report Comments export (Areas of Success, Growth, Improvement) into `strandcomments.csv`, one strand at a time. Used as the main source for Mathematics and English dot points. |
| Starter | [Core/Starter.swift](../Holocron/Core/Starter.swift) | Starter periods and subjects for a new folder. |
| Copy lessons | [Core/DayMarkdown.swift](../Holocron/Core/DayMarkdown.swift), [Views/CopyDay.swift](../Holocron/Views/CopyDay.swift) | Builds a day as Markdown (no student information), then puts HTML, RTF and plain text on the clipboard. |
| Print week | [Views/PrintWeek.swift](../Holocron/Views/PrintWeek.swift) | Draws the shown week on A4 landscape and writes a PDF. |

## Updater

[Core/Updates.swift](../Holocron/Core/Updates.swift) has no AppKit: `VersionCompare`, `GitHubRelease` (decoded from the API JSON), and `ReleasePick` (choose the zip, find the `.sha256`, parse the checksum, trust only `https://github.com/<repo>/releases/download/...`). [Views/Updater.swift](../Holocron/Views/Updater.swift) is the `Updater` class plus the banner and the Settings, Updates pane.

1. `checkIfDue` runs at launch and when the app becomes active, at most every six hours, if auto check is on.
2. `runCheck` asks `api.github.com/repos/andrew-snape/holocron-planner/releases/latest`. The repository is a constant (`Updater.defaultRepo`).
3. A release is offered only if it is newer, has a Holocron zip, and has a `<zip>.sha256` file, both on the trusted download path.
4. `install` refuses a copy running from Xcode (`/DerivedData/`) or in a folder it cannot write. It downloads the zip, downloads the checksum, compares SHA-256, unzips with `ditto` into a hidden stage folder, then checks the bundle identifier matches, the version is newer, and `codesign --verify --deep --strict` passes.
5. It saves everything (`prepareToQuit`), starts a small shell script and quits. The script waits for the app to exit, moves the old app to `Holocron.app.previous`, moves the new one in, deletes the old one only after that works, and removes quarantine. If a step fails it puts the old app back and reveals the new one in Finder, then opens the app.

Updates never touch the data folders.

## Apple Intelligence

All on device, all optional ([Core/Intelligence.swift](../Holocron/Core/Intelligence.swift)). `Intelligence.status` reads `SystemLanguageModel.default.availability`. `Intelligence.can(feature, db)` is true when the model is ready and the feature is not switched off (`AIFeature`: `ai_dictation`, `ai_drafts`, `ai_columns`, `ai_lessonDraft`, `ai_noteTags`). Features that use no model (to-do wording, text scan) are listed after the table.

| Feature | Files | Notes |
|---|---|---|
| Dictate notes | [Core/Dictation.swift](../Holocron/Core/Dictation.swift), [Core/NoteSorter.swift](../Holocron/Core/NoteSorter.swift), [Views/DictateSheet.swift](../Holocron/Views/DictateSheet.swift) | Speech framework on device. The model only splits words into notes; names are matched to the roll in code. The teacher checks every note before saving. |
| Report comments | [Core/CommentDraft.swift](../Holocron/Core/CommentDraft.swift), [Views/DraftViews.swift](../Holocron/Views/DraftViews.swift) | General comment in the teacher's voice (earlier comments as examples), English and Mathematics dot points, then style checks and tidying. Retries on refusal with fewer notes. |
| Learning intentions | `IntentDrafter` in CommentDraft.swift | Drafts a lesson's learning intention and success criteria from its summary, explicit teaching and unit. |
| Column suggestions | [Core/ColumnSuggest.swift](../Holocron/Core/ColumnSuggest.swift) | Results import. |
| Draft lesson (unreleased) | [Core/LessonDraft.swift](../Holocron/Core/LessonDraft.swift), `LessonDraftArea` in [Views/AssistViews.swift](../Holocron/Views/AssistViews.swift), used in the lesson editor in [Views/Sheets.swift](../Holocron/Views/Sheets.swift) | Draft lesson… drafts tuning in, explicit teaching, independent work and reflection from the summary (`@Generable DraftedLesson`, 700 tokens at most). Reads planner text only: subject, summary, learning intention, success criteria, steps already written, and the unit of inquiry for TDL. Every name on the roll becomes "a student" first. Too long retries once with less. Fills empty steps, or all of them if Replace is ticked. Preview with Use, Write again, Discard. |
| Suggest subject and kind (unreleased) | [Core/NoteTagger.swift](../Holocron/Core/NoteTagger.swift), `NoteSuggestBar` in [Views/AssistViews.swift](../Holocron/Views/AssistViews.swift), used in [Views/StudentsView.swift](../Holocron/Views/StudentsView.swift) | A Suggest button under a typed note (the Lesson notes form and the Quick log form). Runs only when chosen, with greedy sampling. The answer is a dynamic schema limited to lesson, behaviour or wellbeing and one of the teacher's own subjects (or none), so nothing can be invented. Shown as a suggestion with Use; nothing changes until then. A note of under 8 characters is refused. |

Every draft appears in a `DraftBox` with Use, Try again and Discard (the lesson draft has its own preview with the same three). Nothing reaches a CSV until Use. See [../CLAUDE.md](../CLAUDE.md) for what is never sent to the model.

### Without the model

- **To-do wording** ([Core/TodoParse.swift](../Holocron/Core/TodoParse.swift), unreleased). `TodoParse.parse` takes "remind me to print excursion forms Friday" and returns the text, the same wording with only the lead-in removed, and a due date. It is regular expressions and calendar maths on `Cal`, in Australian day-month order, with weeks starting Monday and a bare weekday meaning the coming one. It works with Apple Intelligence off. `TodoPanel` in [Views/TodayView.swift](../Holocron/Views/TodayView.swift) uses it while the teacher types and shows what it will add. The Add a To-Do intent calls it with `strict: true`: a day or relative word is only taken when it comes last or follows by, on, due, before or until (so "Friday sports uniform letter" is left alone), and without a date the words are kept exactly as given. A due date given as the intent parameter wins.
- **Scan text** ([Core/TextScan.swift](../Holocron/Core/TextScan.swift), unreleased). Vision `RecognizeTextRequest` (accurate, language correction, en-AU, en-GB then en-US when supported) reads an image or PDF file. PDFs are rendered a page at a time, up to 12 pages. Nothing is written to disk and nothing is sent. The UI is in [Views/AssistViews.swift](../Holocron/Views/AssistViews.swift): `TextScanner` (an `NSOpenPanel` file choice, one picture at a time), `ScanTextButton`, and `ScanCheckSheet`, where the teacher fixes the words and chooses Add to the end. `NoteBox(scannable: true)` ([Views/Theme.swift](../Holocron/Views/Theme.swift)) turns it on for a field: a lesson's Summary and Resources, and the student note boxes in Students. Continuity Camera is not hooked in, because macOS cannot say which of several fields on a screen should get the image.

### Warm-up and the warm cache

`Intelligence.prewarm(session, prefix:)` calls `LanguageModelSession.prewarm`, so the model is loaded before the first request. `prewarm` functions exist on `CommentDrafter`, `DotPointDrafter`, `IntentDrafter`, `NoteSorter` and `ColumnSuggest`, and are called when the Report tab, class drafts, learning intention box, Dictate sheet and Import results open. Each stores its session in `WarmSessions` ([Core/Intelligence.swift](../Holocron/Core/Intelligence.swift)):

- A warmed session is used once (`take` removes it) and only if its instructions and fingerprint match what the request would build now. Both are kept as SHA256 digests, never as text. `CommentDrafter` and `DotPointDrafter` use `Database.warmFingerprint`: the report facts, the roll (ids and names) and the number of saved comments.
- Entries last 180 seconds and at most six are kept. Expired entries are dropped on every call.
- A warmed session holds student text in its instructions and examples, so the screens discard theirs on disappear (`WarmSessions.discard`, or `discard(prefix:)` for `CommentDrafter.warmPrefix` and `DotPointDrafter.warmPrefix`). It is in memory only.
- If nothing matches, the request makes a new session as before, so warm-up can only make the first draft faster, never different.

### Report filters and lookup tools

`Database.reportEligibleNotes` and `reportEligibleTests` ([Core/CommentDraft.swift](../Holocron/Core/CommentDraft.swift)) are the one place that decides which lesson notes and results a report draft may see (in the semester, covered by the kind of comment, no private words). `reportFacts` and `reportLookup` both read from them. `TeacherNotesTool`, `TestResultsTool` and `UnitOfInquiryTool` let the model fetch notes, results and the unit by subject instead of reading them all in the prompt. They are complete but **off** (`CommentDrafter.useLookupTools = false`): they have not been run against the model, and the small on-device model may not call them. A draft that makes no lookup is discarded and redone the old way. Switch them on only after comparing drafts side by side. Generation options: `GenerationOptions(samplingMode: .greedy)` is used by `NoteSorter` and `NoteTagger`, and `Intelligence.message` has a generic too-long message (the lesson draft shows its own, which says to shorten the summary or steps).

## App Intents, Siri and Shortcuts

[Intents/HolocronIntents.swift](../Holocron/Intents/HolocronIntents.swift) defines the intents and two entities (`StudentEntity`, `SubjectEntity`). [Intents/HolocronShortcuts.swift](../Holocron/Intents/HolocronShortcuts.swift) lists the Siri and Spotlight phrases, each naming the app. [Core/SiriAnswers.swift](../Holocron/Core/SiriAnswers.swift) works out the spoken answers from `Database`.

- `IntentHost.model` is set once at launch. `IntentHost.require()` throws if the folder is missing. `require(writing:)` also throws if the table could not be read.
- Questions only read. Actions that change data ask first (`requestConfirmation`) or say what they did. A save is checked on disk (`saveNow`) before Siri says Saved.
- Student names are spoken or suggested only when `siri_names` is on and no Class screen is open. The roster is only given to Siri then (`refreshSiriVocabulary`).
- Birthdays, Log a Note and Copy Today require an unlocked Mac (`authenticationPolicy`).
- `AIGuide` (new, unreleased) is described below.

## AI guide

[Core/AIGuide.swift](../Holocron/Core/AIGuide.swift) writes `README-for-AI.md` into the student folder, and into the planner folder when it is separate. The tables, columns and routing come from `TableName`, `header` and `DataFolder.root(for:)`, so they always match. `AIGuide.describe` gives each table one line. The file is written on a background queue (`AIGuideWriter`) and only when its text changes; an in-memory cache means an unchanged focus reload does no disk I/O. The planner guide depends only on the app version, so colleagues on the same version produce identical files, and an older Holocron never overwrites a guide written by a newer one. An iCloud placeholder is downloaded rather than written over, and an unreadable guide is left alone. Help, then Copy Guide for AI Assistants and the Describe Holocron action expose it. The student copy starts with a privacy notice; the Shortcuts action returns the planner guide only.

## Theme

[Views/Theme.swift](../Holocron/Views/Theme.swift) holds colour tokens, `CardStyle`, headers, chips, `FlowLayout`, `Avatar`, `NoteBox` and the other shared views. `Tone` (in [Core/Tone.swift](../Holocron/Core/Tone.swift)) works out a subject's bar, background and text colours from its hex code with a contrast search.

## File map

Line counts are approximate. Paths are relative to the repository root.

| File | Responsibility |
|---|---|
| `Holocron/HolocronApp.swift` | App entry, scenes, menus, shortcuts, forced light mode, Australian locale. |
| `Holocron/AppModel.swift` | Observable app state, folder choice, load and save, private lesson merge, photos, folder import, results import, archive, Start over, Siri vocabulary. |
| `Holocron/ModuleSettings.swift` | Switching screens on and off through `settings.csv`. |
| `Holocron/Core/Schema.swift` | `TableName` (26 tables, columns, `isPlanner`), `PYP` lists, `Lists` fixed values. |
| `Holocron/Core/CSV.swift` | Byte-level CSV parse and write. |
| `Holocron/Core/DataFolder.swift` | File locations, routing, safe read, atomic write, signatures, photo path. |
| `Holocron/Core/Database.swift` | Row storage, typed views, per-table stamps, lookup index, helpers for links and ids. |
| `Holocron/Core/Database+Schedule.swift` | Terms, A/B weeks, planned subject, one-off and standing changes, swaps, lessons, rename, day types, units. |
| `Holocron/Core/Database+Bump.swift` | Push and pull lesson plans, undo snapshot. |
| `Holocron/Core/Database+Hours.swift` | Face to face, release and DOTTL minutes. |
| `Holocron/Core/Database+Students.swift` | Students, logs, timeline, birthdays, to-do, packs, report judgements and text. |
| `Holocron/Core/Database+Settings.swift` | Key and value settings, class name, private subject settings. |
| `Holocron/Core/Dates.swift` | `Cal` integer calendar maths, date and time formatting, `uid()`. |
| `Holocron/Core/Tone.swift` | Subject colour to bar, background and text colours. |
| `Holocron/Core/Starter.swift` | Starter periods and subjects for a new folder. |
| `Holocron/Core/ImportPlan.swift` | Plan and carry out folder import with backup and rollback. |
| `Holocron/Core/YearEnd.swift` | Year end archive plan and carry out, size and row checks, README. |
| `Holocron/Core/StartOver.swift` | Start over plan and carry out, archive folder naming. |
| `Holocron/Core/ResultsImport.swift` | Spreadsheet table, column mapping, name matching, result rows, apply to `assessments.csv`. |
| `Holocron/Core/XLSX.swift` | Minimal .xlsx reader (first sheet) using zip and Compression. |
| `Holocron/Core/ColumnSuggest.swift` | On-device column suggestions for imports, warm-up. |
| `Holocron/Core/StrandComments.swift` | Essential Assessment report comments file, matching, storage. |
| `Holocron/Core/CommentDraft.swift` | Report facts, shared report filters (`reportEligibleNotes`, `reportEligibleTests`), drafting, privacy filters, style checks, dot points, intent drafting, warm-up, and the lookup tools (off). |
| `Holocron/Core/NoteSorter.swift` | Sorting dictated notes, name matching rules, warm-up. |
| `Holocron/Core/NoteTagger.swift` | Suggests a kind and subject for a typed note, limited to the teacher's own choices. |
| `Holocron/Core/LessonDraft.swift` | Drafts a lesson's four steps from its summary, with every roll name masked. |
| `Holocron/Core/TodoParse.swift` | To-do wording and due date from plain words, in code. No model. |
| `Holocron/Core/TextScan.swift` | Vision text recognition from an image or PDF file. No model, nothing kept. |
| `Holocron/Core/Dictation.swift` | Speech recognition session with start, stop and failure handling. |
| `Holocron/Core/Intelligence.swift` | Model availability, `AIFeature` switches, `Intelligence.prewarm`, `WarmSessions` cache, error messages, Siri names setting. |
| `Holocron/Core/Updates.swift` | Version compare, release JSON, trusted download, checksum parsing. |
| `Holocron/Core/DayMarkdown.swift` | A day as Markdown for relief teachers. |
| `Holocron/Core/SiriAnswers.swift` | Spoken answers for what is on, why there are no lessons, birthdays. |
| `Holocron/Core/AIGuide.swift` | Guide for AI assistants written into each data folder. |
| `Holocron/Intents/HolocronIntents.swift` | App Intents, entities, `IntentHost`. |
| `Holocron/Intents/HolocronShortcuts.swift` | Siri and Spotlight phrases. |
| `Holocron/Views/Theme.swift` | Colours, card style and shared small views, including `NoteBox` (with `scannable` for Scan text…). |
| `Holocron/Views/RootView.swift` | Window, sidebar with mini calendar, folder banner and setup, sheet and detail routers. |
| `Holocron/Views/TodayView.swift` | Today list, quote card, to-do panel (plain-words due dates through `TodoParse`), birthdays. |
| `Holocron/Views/WeekView.swift` | Week grid, slot cells, drag to swap, subject filter. |
| `Holocron/Views/TermUnitsDevotion.swift` | Term grid and stats, units of inquiry, devotion scripts. |
| `Holocron/Views/ClassScreen.swift` | Class screen, timer, work modes, First Then Next steps, Now and Next strip. |
| `Holocron/Views/Sheets.swift` | Shared sheet frame, plan, change, move, day type, swap and bump sheets. The lesson editor holds Draft lesson… and Scan text…. |
| `Holocron/Views/StudentsView.swift` | Student list and detail tabs, Quick log, report tab, pack sheet, new student. Typed note forms have Suggest subject and kind and Scan text…. |
| `Holocron/Views/MarkClassView.swift` | Mark the whole class on one task, rubric descriptors. |
| `Holocron/Views/ResultInput.swift` | Score or achievement level input shared by Mark class and Assessment tab. |
| `Holocron/Views/HoursView.swift` | Hours tables, DOTTL bar chart, DOTTL log form. |
| `Holocron/Views/IntelligenceSettings.swift` | Settings, Apple Intelligence pane (feature switches, Siri and Shortcuts). |
| `Holocron/Views/Updater.swift` | `Updater`, update banner and the Settings Updates pane (`UpdatesSettings`). |
| `Holocron/Views/SettingsView.swift` | Settings window shell: sidebar, search, `SettingsTab`, icon tiles and pane headers. |
| `Holocron/Views/SettingsPanes.swift` | The Settings panes General, Timetable, Calendar, Folders, Privacy and Year End (the Apple Intelligence and Updates panes live in their own files), and `SettingsEdit`, the row bindings the Timetable and Calendar panes share. |
| `Holocron/Views/AssistViews.swift` | Scan text (`TextScanner`, `ScanTextButton`, `ScanCheckSheet`), `NoteSuggestBar` for typed notes, and `LessonDraftArea` for Draft lesson…. |
| `Holocron/Views/ImportResultsSheet.swift` | Results import sheet. |
| `Holocron/Views/StrandCommentsSheet.swift` | Essential Assessment report comments import sheet. |
| `Holocron/Views/YearEndSheets.swift` | Archive this year and Import from folder sheets. |
| `Holocron/Views/StartOverSheet.swift` | Start over confirmation and result. |
| `Holocron/Views/DictateSheet.swift` | Dictate notes sheet. |
| `Holocron/Views/DraftViews.swift` | Draft box, general comment drafting, class drafts, dot points, learning intention drafting. |
| `Holocron/Views/PrintWeek.swift` | A4 landscape week page and PDF writer. |
| `Holocron/Views/CopyDay.swift` | Copy a day as HTML, RTF and plain text. |
| `Holocron/Views/HelpView.swift` | Help window, topics, Help menu, shared help pieces. |
| `Holocron/Views/HelpContent.swift` | Help pages and `CSVGuide`, the older text guide for AI chats. |
