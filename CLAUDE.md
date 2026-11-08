# CLAUDE.md

New to this repo? Read [AGENTS.md](AGENTS.md) first.

Holocron is a native macOS SwiftUI classroom planner for a primary school teacher in Victoria, Australia. It keeps a fortnightly A/B timetable, lesson plans, student notes, results, report drafts and teaching hours as plain CSV files in two folders (a shareable planner folder and a private student folder). About 16k lines of Swift, no external dependencies, no test target, macOS 26 and Apple silicon only. Everything runs on the Mac. The only network request is the update check to GitHub Releases.

## Build

- Open `Holocron.xcodeproj` in Xcode and press Cmd+R. Signing is ad hoc, so no developer account is needed.
- Command line (as in [.github/workflows/build.yml](.github/workflows/build.yml)):
  `xcodebuild -quiet -project Holocron.xcodeproj -target Holocron -configuration Release SYMROOT="$TMPDIR/holocron-build" CODE_SIGN_IDENTITY=- build`
- Debug build without signing: `xcodebuild -project Holocron.xcodeproj -scheme Holocron -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- The project uses folder-synced groups, so a new `.swift` file under `Holocron/` is picked up without editing the Xcode project.
- Build outside iCloud-synced folders for Release (see [docs/PROBLEMS.md](docs/PROBLEMS.md)). `scripts/release.sh` already does.
- There are no tests. Verify by building and, for `Holocron/Core` logic that needs only Foundation, by compiling the files with `swiftc` plus a small script against temporary folders. Never run anything against the teacher's real data folder.

## Conventions

- **Australian English** in all UI copy, comments and docs: organise, colour, licence, programme only where the app already uses it. Dates read 13 Oct 2026 or Tuesday 13 October. Week starts Monday.
- **Light mode is forced on purpose** (`NSApplication.shared.appearance = .aqua` and `.preferredColorScheme(.light)` in [HolocronApp.swift](Holocron/HolocronApp.swift)). Do not add dark mode support or semantic colours without being asked.
- **House look** lives in [Holocron/Views/Theme.swift](Holocron/Views/Theme.swift): `Color.appBG`, `cardBG`, `ink2`, `hairline`, `appBlue`, `appGreen`, `appAmber`, `appRed`, `fieldBG`, `fieldStroke`, `fill` (`fillFaint`, `fillStrong`), `onAccent`, `Radius.*`, `Space.*`, `Font.hPage`/`hSheet`/`hSection`, `.card()`, `PageHeader`, `EmptyNote`, `NoteBox`. Use these tokens, not raw colours or corner numbers. The Liquid Glass plan is in [Claude outputs/holocron-liquid-glass-plan.md](Claude%20outputs/holocron-liquid-glass-plan.md). Sheets use `SheetFrame` ([Views/Sheets.swift](Holocron/Views/Sheets.swift)). Settings forms use `settingsForm()`.
- **Plain wording**, as in [CHANGELOG.md](CHANGELOG.md): short sentences, full stops, verbs on buttons ("Make archive", "Import"), no jargon, no emoji. Destructive actions use `role: .destructive` and a confirmation.
- State: `AppModel` (`@Observable`) owns navigation and the folder; `Database` owns rows. Screens read through `db.rows(.table)` or `db.index(.table)` so they redraw per table. Every change ends with `db.touch(.table)`.
- Older files may lack newer columns. Read with `row.s("col")`, which returns "".
- When you add or change a feature, add a bullet to `## Unreleased` in `CHANGELOG.md` in the same user-facing voice.

## Data safety (hard rules)

Teachers' files are the product. Do not weaken any of these.

- **Writes are atomic** (`Data.write(to:options: .atomic)` in `DataFolder.write`, [Core/DataFolder.swift](Holocron/Core/DataFolder.swift)). Saves run on a background queue; quitting and folder switches use `flushNow(wait: true)`.
- **A file that failed to read is never overwritten.** `loadAll` puts it in `badLoads`; `flushNow` skips it with a toast. Check `canWrite(_:)` before writing from outside a screen (as the Siri actions do).
- **A file that is missing is created blank** (with starter rows from [Core/Starter.swift](Holocron/Core/Starter.swift)). Existing files are never reset.
- **Replace, move or clear nothing without a copy first.** Import, results import, year end archive and Start over copy or move files into `Holocron archive` (next to the student folder), verify sizes or row counts, and roll back on failure. Nothing is ever deleted. Wait for iCloud placeholders (`.name.csv.icloud`) before copying.
- **Planner folder versus student folder** is decided by `TableName.isPlanner` in [Core/Schema.swift](Holocron/Core/Schema.swift). Planner tables (`subjects periods timetable dayplan lessons rubrics terms nonteaching dayoverrides devotion quotes units`) may sit in a shared folder. Everything else, including `settings.csv`, `todo.csv`, `dottl.csv` and photos, is private and stays in the student folder. `DataFolder.root(for:)` is the only place that routes a table. A shared planner folder is only ever disconnected, never cleared.
- **Private lessons** for subjects marked private live in `lessonsprivate.csv` in the student folder. In memory they merge with `lessons` (`AppModel.mergeLessons`); each file keeps the other's rows untouched. Devotion and quotes can also be routed to the student folder (`privateTables`).
- **Never commit CSV files or photos.** `.gitignore` has `*.csv` and `photos/`. CI and `scripts/release.sh` fail if `git ls-files` shows either. Never add real names or data to fixtures, comments or docs.
- `state/inuse.*.lock` was committed by mistake once. Do not add files under `state/`, `build/` or `dist/`.

## Apple Intelligence guardrails

All model use is on device (FoundationModels, Speech). Nothing is sent anywhere. See [Core/Intelligence.swift](Holocron/Core/Intelligence.swift), [Core/CommentDraft.swift](Holocron/Core/CommentDraft.swift), [Core/NoteSorter.swift](Holocron/Core/NoteSorter.swift), [Core/LessonDraft.swift](Holocron/Core/LessonDraft.swift), [Core/NoteTagger.swift](Holocron/Core/NoteTagger.swift).

- **Never sent to the model for report drafts:** wellbeing, behaviour, medical notes, adjustments, plan notes (ILP, SSG, NCCD), parents, birth dates and photos. Other students' names are masked as "a classmate" (`maskingNames`). Notes that match `CommentDrafter.privateWords` are dropped, and a draft that mentions a private term is refused.
- **ILP sentence** is added by Holocron (`finish`), never written by the model.
- **Dictation** only splits words. Names are matched to the roll in code, a name must have been said, "whole class" needs those words, and shared first names ask which student.
- **Drafts stay drafts** until the teacher chooses **Use**. They can be edited, written again or discarded. A discarded or cancelled draft never comes back (`Task.checkCancellation`, run tokens).
- On a model refusal, `CommentDrafter.draft` retries with fewer notes (`Omit`: unit notes, lesson notes, all notes) and tells the teacher what was left out. Too-long input retries with less detail. A draft that copies six words in a row from an example is redrafted without examples.
- Each feature has an off switch (`AIFeature`: dictation, drafts, columns, lessonDraft, noteTags; settings keys `ai_*`) and hides itself when the model is unavailable.
- **Lesson drafts** (`LessonDrafter`) use planner text only, with every name on the roll masked as "a student", because lessons may be shared. Masking is by whole word, so a real word that is also a student name (Mark, Grace) is masked too.
- **Note tagging** (`NoteTagger`) can only answer with a kind and one of the teacher's subjects, and runs only when the teacher chooses Suggest.
- **Warmed sessions** (`WarmSessions`, Intelligence.swift) hold student text in memory only: 180 seconds, discarded when the screen closes, compared by SHA256 digest and never logged or written. When a feature opens on a screen, warm it with `prewarm` and use the session once.
- **Lookup tools** for report drafts (`TeacherNotesTool`, `TestResultsTool`, `UnitOfInquiryTool`) are built but off (`CommentDrafter.useLookupTools = false`) until drafts with and without them are compared side by side. They share the filters in `reportEligibleNotes` and `reportEligibleTests` with the packed facts.
- **No model needed:** `TodoParse` (to-do and due date from plain words, worked out in code) and `TextScan` (Vision text recognition from a photo, scan or PDF, file choice only, the picture is never kept).
- Siri and Shortcuts never say student names unless `siri_names` is on, and never while a Class screen is open. Birthdays, notes and copying a day need an unlocked Mac.
- Do not add a feature that sends student data off the Mac or to a third-party service.

## AI guide in the data folders

Holocron writes `README-for-AI.md` into the student folder and, when the planner has its own folder, the planner folder too ([Core/AIGuide.swift](Holocron/Core/AIGuide.swift), written at load and only when the content changes). It is not a CSV, so imports, archives and Start over never touch it. It is generated from `TableName` and `header` in `Schema.swift`, so a new table or column appears in it automatically. **A new table needs a one-line description in `AIGuide.describe`**, which has no default so the build fails without one. The student copy starts with a privacy notice. Help, then Copy Guide for AI Assistants copies both. The Describe Holocron Shortcuts action returns the planner guide only, with no student information. Keep student data out of the planner guide.

The guide is also an operating manual for an AI assistant that edits the live CSVs (checklist, value rules, recipes with sample rows, a do-not list, after-editing steps). `AIGuide.swift` owns those recipes. **When you change a column, an allowed value (`Lists`, `PYP`), an id rule or a file's folder, check the recipes in `AIGuide.swift` still match.**

## Releasing

- Add a `## X.Y` section to `CHANGELOG.md` (rename `## Unreleased`). Its bullets become the release notes.
- Commit everything, then run `scripts/release.sh X.Y` on a clean tree. It sets `MARKETING_VERSION` and the build number, builds outside iCloud, checks the signature, zips with `ditto`, writes `Holocron-X.Y-mac.zip.sha256`, tags, pushes and creates the release with `gh`.
- A release **must** carry the `.sha256` file. The updater ignores a release without one. Updates only come from `andrew-snape/holocron-planner` over HTTPS. Do not add a repository setting or loosen `ReleasePick.isTrustedDownload`.
- CI warns when `CHANGELOG.md` has no section for the project version.

## Project agents

- `code-reviewer` ([.claude/agents/code-reviewer.md](.claude/agents/code-reviewer.md)): run before committing anything that reads, writes, moves, imports or archives files, or touches the updater or release script.
- `ui-design-check` ([.claude/agents/ui-design-check.md](.claude/agents/ui-design-check.md)): run after changing anything in `Holocron/Views`.

## Where to look

| Need | File |
|---|---|
| Overview, install, privacy for teachers | [README.md](README.md) |
| Orientation for any AI assistant | [AGENTS.md](AGENTS.md) |
| How the app is built, file-by-file map | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Every table, column, format and folder | [docs/DATA.md](docs/DATA.md) |
| Everything built, with version | [docs/FEATURES.md](docs/FEATURES.md) |
| Past bugs, causes, fixes, known limits | [docs/PROBLEMS.md](docs/PROBLEMS.md) |
| Suggested next work | [docs/ROADMAP.md](docs/ROADMAP.md) |
| Release history | [CHANGELOG.md](CHANGELOG.md) |
| Apple HIG notes and plan | [Claude outputs/holocron-hig-plan.md](Claude%20outputs/holocron-hig-plan.md) |
