# Roadmap

Suggestions, not promises. Each one is tied to something in the code or the history. Sizes are rough: S is under a day, M a few days, L about a week or more. Problems already known are in [PROBLEMS.md](PROBLEMS.md). A teacher-first plan for the interface, new functions and the look, with a release order, is in [Claude outputs/holocron-teacher-plan.md](../Claude%20outputs/holocron-teacher-plan.md).

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
| Undo for more actions | Done (unreleased) for deletes, swaps and bump, as a short in-memory history of table snapshots ([Core/UndoLog.swift](../Holocron/Core/UndoLog.swift)). Still to do: day type changes, subject changes, Mark class saves, imports of results, and a row-level history so a later edit does not end an earlier undo. | M |
| Remaining HIG items | See the table below. Empty states, context menus and search on Units are not done. | M |
| Schema version | There is no version in the data folders, so a renamed or split column has no migration path. A `holocron.version` row in `settings.csv`, or a small `schema.json`, lets a later release upgrade files on load, with a copy into `Holocron archive` first. | M |
| File change guard | There are no lock files. Before writing, compare the file's signature with the one stored at the last read, and if it changed on disk, reload or ask. `DataFolder.signature` and `fileSigs` already exist. | M |
| Developer ID signing and notarisation | The app is ad hoc signed, so a first launch needs right-click, Open. Notarising needs a paid Apple Developer account, a signing step in `release.sh` and a notarytool step. It would also let the updater check a team identifier, not just a valid signature. | M |
| Fail CI on a missing changelog section | `build.yml` only warns. | S |
| File coordination | See the section below. Live updates from a partner's Mac, safer saves and proper iCloud conflict handling. | M |

### File coordination (from Apple's Shared data overview)

Source: [Shared data](https://developer.apple.com/documentation/technologyoverviews/shared-data), checked 17 Nov 2026. Apple says file coordination is essential for files read and written in iCloud or any shared space. Holocron does not use it yet: no `NSFileCoordinator` or `NSFilePresenter` anywhere. Today it writes with `Data.write(.atomic)`, spots outside changes by modification date and size (`DataFolder.signature`, [Core/DataFolder.swift](../Holocron/Core/DataFolder.swift)), merges row by row before each save ([Core/MergedSave.swift](../Holocron/Core/MergedSave.swift), [Core/RowMerge.swift](../Holocron/Core/RowMerge.swift)) and does not watch the folder while the app is open (see Merge by row in [PROBLEMS.md](PROBLEMS.md)).

Apple documentation to read before starting (for whoever does the work, person or AI assistant):

- [Shared data overview](https://developer.apple.com/documentation/technologyoverviews/shared-data), the File coordination section
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [coordinate(writingItemAt:options:error:byAccessor:)](https://developer.apple.com/documentation/foundation/nsfilecoordinator/coordinate(writingitemat:options:error:byaccessor:))
- [coordinate(readingItemAt:options:error:byAccessor:)](https://developer.apple.com/documentation/foundation/nsfilecoordinator/coordinate(readingitemat:options:error:byaccessor:))
- [NSFileCoordinator.WritingOptions](https://developer.apple.com/documentation/foundation/nsfilecoordinator/writingoptions) (`.forMerging`, `.forReplacing`)
- [addFilePresenter(_:)](https://developer.apple.com/documentation/foundation/nsfilecoordinator/addfilepresenter(_:)) and [removeFilePresenter(_:)](https://developer.apple.com/documentation/foundation/nsfilecoordinator/removefilepresenter(_:))
- [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)
- [presentedSubitemDidChange(at:)](https://developer.apple.com/documentation/foundation/nsfilepresenter/presentedsubitemdidchange(at:))
- [NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion)
- [unresolvedConflictVersionsOfItem(at:)](https://developer.apple.com/documentation/foundation/nsfileversion/unresolvedconflictversionsofitem(at:))
- [startDownloadingUbiquitousItem(at:)](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)) (what Holocron uses now)
- [iCloud design guide (HIG)](https://developer.apple.com/design/human-interface-guidelines/icloud)

What it would add, in the suggested order:

1. **Live updates from a partner.** An `NSFilePresenter` on the planner folder and the student folder. iCloud calls `presentedSubitemDidChange(at:)` when a colleague's changed CSV arrives. Run the existing merge and reload then, instead of at the next save or when the app becomes active. Debounce, ignore Holocron's own writes, and skip anything in `badLoads`. Register in `AppModel` when a folder opens and remove the presenter on folder switch and quit (`NSFileCoordinator.removeFilePresenter`). Biggest visible gain.
2. **Coordinated saves.** Wrap the read, merge and write in `MergedSave` in one `coordinate(writingItemAt:options:.forMerging)` call, still writing with `.atomic` inside it. iCloud's sync process then cannot upload or replace the file midway, which narrows the same-instant clash. It is still not a lock between Macs, so the row merge stays. Coordinated calls block, so keep them on the background save queue, never the main thread. `flushNow(wait: true)` on quit must still finish.
3. **iCloud conflict versions.** Use `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` to find conflicts directly, instead of spotting copies by name such as `lessons 2.csv`. Copy each version into `Holocron archive/Before merge` first, verify the copy, merge it, and only then mark it resolved. Never remove a version without a verified copy. Keep the name-based check as well, for copies made by other tools.
4. **Coordinated reads instead of placeholder polling.** A coordinated read of a file that is not downloaded makes iCloud fetch it and waits. This could replace much of the hand-written `.name.icloud` handling in `ImportPlan`, `YearEnd`, `WorkFiles`, `WorkImport`, `StartOver`, `Interview`, `AIGuide` and `Database+Board`. Do this last and one file at a time, because those paths guard imports and archives.

Limits:

- Coordination only protects against programs that also coordinate. Finder, iCloud and Apple's apps do. A script or AI assistant editing the CSVs directly does not, so keep the "quit Holocron first" advice in `AIGuide.swift`.
- It works on one Mac only. Two Macs saving in the same instant still rely on the row merge.
- When done, update the Merge by row entry in PROBLEMS.md, the File change guard row above, ARCHITECTURE.md and the AI guide wording if behaviour changes.

Checks: build, then test with `swiftc` scripts against temporary folders, including a temporary folder in iCloud Drive edited from a second Mac or from Finder while the app is open. Never the real data folder. Run the `code-reviewer` agent before committing.

Looked at and not suggested:

- **CloudKit, SwiftData, Core Data sync.** They replace the CSV files (see Not suggested below).
- **iCloud app container** (`url(forUbiquityContainerIdentifier:)`). Hides the files in a folder only Holocron uses, which breaks shared planner folders and hand editing.
- **App groups.** For sharing between several of your own apps or extensions. Holocron is one app.
- **iCloud key-value storage.** Would sync settings through Apple's servers. Settings are private and stay in the student folder.
- **File Provider.** For apps with their own server.
- **GameSave.** For games.

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
| 5 Empty states | Partly done. `EmptyNote` is used (14 places) and takes an optional button (unreleased: Students, Quick log, Mark class, Units). No `ContentUnavailableView`. |
| 6 Search | Students and Units (unreleased), plus Cmd+K Jump across students, screens, units and lessons. |
| 7 Context menus | Done for Week and Today lessons, students, note entries, to-dos and work (unreleased). Not on Term, Units or Devotion cards. |
| 8 Undo and redo | Done for deletes, swaps and bump (unreleased), with Cmd+Z and Shift+Cmd+Z. |
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

- Any feature that sends student data off the Mac. The privacy model depends on the only network requests being the update check and the opt-in weather forecast, which carries only the town's coordinates.
- Replacing CSV with a database. Teachers hand-edit and share the files, and that is the point of the project.
