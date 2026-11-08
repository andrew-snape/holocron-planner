# Roadmap

Suggestions, not promises. Each one is tied to something in the code or the history. Sizes are rough: S is under a day, M a few days, L about a week or more. Problems already known are in [PROBLEMS.md](PROBLEMS.md).

## Now

| Item | Why | Size |
|---|---|---|
| Remove `state/inuse.26997.lock` and ignore `state/` | It is tracked in git by accident (added in the 1.9.1 release commit), and `release.sh` uses `git add -A`. | S |
| CHANGELOG discipline | The `## Unreleased` section is the draft release notes. Entries like "Minor Updates" and "Fixing AI Guardrails" told teachers nothing and were rewritten. Add the bullet in the same change as the feature. CI only warns when the version section is missing. Consider making it fail. | S |
| Unit test target for `Holocron/Core` | 16k lines and no tests, while the code moves, bumps and imports real files. Most of `Core` needs only Foundation. See the list below. | M |
| Keep the AI guide honest | `README-for-AI.md` is generated from `TableName`, but the recipes and one-line descriptions are written by hand in `AIGuide.swift`. A test that every `TableName` has a description and every header column appears in the guide stops drift. | S |

### First tests to write

- **CSV round trip:** `CSV.parse(CSV.writeData(...))` returns the same rows for commas, quotes, line breaks, empty cells, a byte order mark and Unicode.
- **DataFolder:** a missing file reads as `.missing`, an unreadable one as `.failed`, and `flushNow` never writes a table in `badLoads`. Needs a temporary folder.
- **Schedule lookups:** `termWeek` and `weekLetter` across term boundaries and when a term starts on a Wednesday, `plannedSubject` with and without a `dayplan` row, `isSchoolDay` on non-teaching days.
- **Bump:** `planPush` and `planPull` skip camp days and weekends, report lost lessons past the last slot, and `undoBump` restores the table exactly.
- **ResultsImport matching:** exact, remembered by file ID, close names (Alex and Alexander) marked likely, students not on the roll left out, "ADAMS Ava" and "Adams, Ava" split correctly, re-import updates instead of duplicating.
- **StrandComments:** the export is recognised, matching works, importing a strand again replaces it.
- **Privacy routing:** `lessons` merge with `lessonsprivate`, hidden rows are written back untouched, `TableName.isPlanner` agrees with `DataFolder.root(for:)`.
- **Import, archive, Start over:** rollback leaves the folder as it was when a copy or move fails.
- **AIGuide:** every `TableName` has a description, planner guide lists no student tables, student guide opens with the privacy notice.
- **CommentDrafter helpers:** `mentionsPrivate`, `maskingNames`, `tidy`, `smallNumbersAsWords`, `styleProblems`, `copies`.

Setup: add a test target to `Holocron.xcodeproj` and run `xcodebuild test` in CI. The model-backed parts (`session`, `respond`) need protocols or closures so they can be faked.

## Next

| Item | Why | Size |
|---|---|---|
| Undo for delete, swap and bump | Only bump has Undo, and it lasts only while the sheet is open. Deleting a student removes every note attached to them. The HIG plan (item 8) asks for it. State is CSV-backed, so it needs a design pass: snapshot per table, or a short in-memory history, registered with `UndoManager` using named actions ("Undo Swap Lessons"). | L |
| Remaining HIG items | See the table below. Empty states, context menus and search on Units are not done. | M |
| Schema version | There is no version in the data folders, so a renamed or split column has no migration path. A `holocron.version` row in `settings.csv`, or a small `schema.json`, lets a later release upgrade files on load, with a copy into `Holocron archive` first. | M |
| File change guard | There are no lock files. Before writing, compare the file's signature with the one stored at the last read, and if it changed on disk, reload or ask. `DataFolder.signature` and `fileSigs` already exist. | M |
| Developer ID signing and notarisation | The app is ad hoc signed, so a first launch needs right-click, Open. Notarising needs a paid Apple Developer account, a signing step in `release.sh` and a notarytool step. It would also let the updater check a team identifier, not just a valid signature. | M |
| Fail CI on a missing changelog section | `build.yml` only warns. | S |

### Apple Intelligence

The T numbers come from the Apple Intelligence plan. Status checked against the code.

| Item | Status | Size |
|---|---|---|
| T1 Test kit with a made-up class | Not done. A fake roster, notes and results (no real names) in a temporary folder, so drafts, dictation and note tagging can be tried and compared without touching real data. It is also what T5 and T6 need. | M |
| T2 Warm-up | Done (unreleased). `Intelligence.prewarm` and `WarmSessions` (180 seconds, digests, discarded on `onDisappear`) for report comments, dot points, learning intentions, Dictate and column suggestions. | Done |
| T3 Choose which notes the model sees | Not done. Let the teacher tick or untick the notes a draft may use, beside the existing "left out" message. Builds on `reportEligibleNotes`. | M |
| T4 Tighter schemas | Not done. `GeneralParts`, `DotPoints` and `DraftedIntent` still take free text. Length and count limits in `@Guide`, or `anyOf` for fixed choices as `NoteTagger` does. | S |
| T5 Lookup tools | Built but off (`CommentDrafter.useLookupTools = false`). `TeacherNotesTool`, `TestResultsTool` and `UnitOfInquiryTool` are complete but never compared with packed facts. Needs T1, then a side-by-side comparison of drafts. Remove the code if the comparison shows no gain. | S |
| T6 Example comments by similarity | Not done. `voiceExamples` picks a random few from the last eight comments. Choose the ones closest to this student's notes instead. | M |
| T7 Learn from edits | Not done. Keep what the teacher changed between a draft and the saved comment, on this Mac, and feed the pattern back as rules. Needs a place to store it that is private and clearable. | L |
| T8 Relaxed guardrails | Not applicable now. It only helps free text. Every feature uses guided output (`generating:` or a schema), which the model's own safety check treats differently. Revisit if a feature moves to free text. The retry-on-refusal in `CommentDrafter.draft` stays. | n/a |

Ideas, not yet designed. Each must stay on device and keep the rule that nothing is saved until Use.

| Idea | Why | Size |
|---|---|---|
| Unit planner | Draft a unit of inquiry's lines, concepts and a week-by-week outline from its central idea. Planner text only, like Draft lesson…. | M |
| Term overview paste | Paste or scan a term overview and turn it into units and lesson summaries. `TextScan` already reads the paper. | M |
| Relief teacher plan | Turn a day's plans into a short, plain note for a relief teacher, next to Copy Day. Planner text only, no student names. | S |
| Newsletter summary | A few friendly lines on what the class did this fortnight, from lesson summaries. | S |
| Devotion drafts | Draft a devotion or Circle Time script in the style of the ones already saved. | S |
| Child-friendly I can | Rewrite a lesson's success criteria in the words the Class screen shows students. | S |
| Meeting brief | A one-page summary of a student's notes and results for a parent or SSG meeting. Student data, so it must follow the report exclusions and be shown as a draft. | M |
| Mark class feedback | Draft a line of feedback for each student from the score and level just entered. | M |
| DOTTL type suggestion | Suggest the DOTTL type from what was typed in the log, like Suggest subject and kind. | S |
| Semantic search | Search notes and lessons by meaning. Needs an on-device embedding and a private index, and must never be written to a shared folder. | L |
| Shortcuts Use Model | Offer Holocron's data to the Shortcuts Use Model action. Needs thought: the planner guide is safe, student data is not. | M |

### HIG items from `Claude outputs/holocron-hig-plan.md`

Status checked against the code.

| Item | Status |
|---|---|
| 1 Sheet buttons, Return and Escape | Mostly done in 1.9.0 (`defaultAction` 20, `cancelAction` 6). Audit any sheet with a lone Done or Close. |
| 2 Destructive actions | Partly done. 10 `role: .destructive`, 6 alerts or dialogs. Re-audit deletes in Students, Units and Term. |
| 3 Menu bar | Partly done. New Student, Log Note and a Go menu exist. No Window menu items for Class screen or Help. |
| 4 Accessibility labels | Done in 1.9.0 for the main screens (53 labels). New views need them. |
| 5 Empty states | Partly done. `EmptyNote` is used (14 places). No `ContentUnavailableView`. |
| 6 Search | Students only (`.searchable` in `StudentsView`). Not on Units. No Cmd+F. |
| 7 Context menus | Not done. No `contextMenu` anywhere. |
| 8 Undo and redo | Not done, apart from bump Undo. |
| 9 Hours chart | Done in 1.9.0 (Swift Charts in `HoursView`). |
| 10 Toolbar hygiene | Done. The window title is the current screen. |
| 11 Settings window | Done. Now a sidebar of eight panes with search (unreleased). The last pane is remembered and the title follows it. |
| 12 Tables | Not done. No sortable `Table` for students. Evaluate if the list grows. |
| 13 to 18 Polish | Not checked. 389 fixed `.font(.system(size:))` calls remain. Dark mode is out of scope by choice. |

## Later

| Item | Why | Size |
|---|---|---|
| Read-only local MCP server | An assistant could answer "what is on Thursday" or "when is Maths" from the planner without a person pasting files. The planner tables hold no student information, so a first version can expose only those, read-only, from the planner folder, with student tables excluded by default and switched on explicitly. It would reuse `CSV` and the `Database` lookups. The Siri answers in `SiriAnswers.swift` already show the questions worth answering. | L |
| Richer App Intents | Add questions for lessons by date, units and term weeks, and an action to add or move a lesson with confirmation. Student data stays behind the `siri_names` switch and the unlocked-Mac rule. | M |
| Tests for views | Snapshot or UI tests for the Class screen and Print week, which are shown to a class or printed. | M |
| Dark mode | Reverses a deliberate choice. Needs semantic colours in `Theme.swift` and a pass over `Tone`. Only if the choice changes. | L |
| Configurable school lists | House colours, PYP lists, the July semester start and report subjects are constants in code. Moving them to `settings.csv` would help other schools. | M |
| Intel build | Only if a teacher needs it. The app is `arm64` only. | S |

## Not suggested

- Any feature that sends student data off the Mac. The privacy model depends on the only network request being the update check.
- Replacing CSV with a database. Teachers hand-edit and share the files, and that is the point of the project.
