# Problems and fixes

Bugs and risks found so far, taken from `git log` and the commits. Each entry has the symptom, the cause, the fix and where to look. Versions are from [Holocron/CHANGELOG.md](../Holocron/CHANGELOG.md). Commit ids are short hashes.

## Release builds failed inside iCloud-synced folders

- **Symptom:** `scripts/release.sh` failed at code signing with "detritus not allowed".
- **Cause:** iCloud adds hidden Finder attributes to anything built under Documents, which breaks the signature.
- **Fix:** The release script builds in a temporary folder under `/tmp` (`mktemp`), cleaned up on exit, and zips with `ditto --norsrc --noextattr --noqtn`. A follow-up stopped passing `clean` to the build, and made the script restore the project file if a step fails, so a failed run does not use up a version number. The same follow-up rewrote two string concatenations in `TodayView.swift` that the Release build rejected.
- **Where:** Just before 1.1 (14 Oct 2026). `af89fe7` and `b997316`. Files: `scripts/release.sh`, `Holocron/Views/TodayView.swift`. Lesson: always build releases outside synced folders.

## Mini calendar rows drawn twice as tall

- **Symptom:** In the sidebar calendar the first and last week of a month were twice as tall as the others, leaving uneven gaps.
- **Cause:** The empty cell for days outside the month used `minHeight: 22`, so a row of only those cells could stretch.
- **Fix:** `Color.clear.frame(maxWidth: .infinity).frame(height: 22)`, a fixed height.
- **Where:** 1.6.1, `bbbcf44`, `Holocron/Views/RootView.swift` (`MiniCalendar`).

## Duplicate Class name field in Settings

- **Symptom:** Settings, General showed the class name twice, and only one copy could be edited.
- **Cause:** The text field's own label was drawn beside the form row's label.
- **Fix:** `.labelsHidden()` on Settings text fields. The same commit added the `settingsForm()` helper so every tab has Holocron's grey background with white rows.
- **Where:** 1.8.6, `b0eac56`, `Holocron/Views/SettingsView.swift` (then `MarkHoursSettings.swift`).

## Subject rename not following through, and slow lookups

- **Symptom:** Renaming a subject left the old name in some tables. Typing a lesson summary, and bumping a run of lessons, felt slow. Hours, Term and Students redid their sums on every keystroke.
- **Cause:** Rename changed only some tables. Screens answered "what is on" by scanning raw rows, and a change anywhere invalidated every cached list. Bumping wrote lessons one at a time and rebuilt the lesson lookup after each.
- **Fix:** `Database.renameSubject` covers `subjects`, `timetable`, `dayplan`, `lessons`, `assessments`, `lessonnotes` and `reportjudge`, and `AppModel.renameSubject` handles the private setting and hidden lesson rows. The lookup index is rebuilt per table (`Database.Index.invalidate`). Bumps write in one pass (`putContents`). Form state was split from lists on Hours, Term and Students. Importing now saves pending changes first.
- **Where:** 1.8.11, `b2f34dd`. Files: `Core/Database.swift`, `Core/Database+Schedule.swift`, `Core/Database+Bump.swift`, `AppModel.swift`, and the Hours, Term and Students views. Settings was also split out of `MarkHoursSettings.swift`.

## Update installed without a checksum, and a changeable repository

- **Symptom:** A release with no `.sha256` file could still be installed, unchecked. The update repository was a text field in Settings, so a typo or a changed value sent the updater elsewhere.
- **Cause:** `checksumURL` was optional and the check was skipped when it was nil. The repository was stored in `UserDefaults`.
- **Fix:** A release without a checksum file is never offered (`state = .failed(...)`), and the download is always compared with it. The repository is the constant `Updater.defaultRepo` and the Settings field was removed. Download URLs must be `https://github.com/<repo>/releases/download/...`.
- **Where:** 1.8.12, `2b3cb4d`, `Holocron/Views/Updater.swift`. README updated in `ddece13`.

## Year end review findings

A review of Archive this year and Import from folder (1.9.0) found these. All fixed in one commit.

- **Setup created the data folder too early.** Cancelling left an empty folder. Now it is created only when Import is pressed.
- **iCloud placeholders were not waited for.** An import or archive could replace or copy a file that had not downloaded. Now CSVs in the destination and photos on either side block the import until downloaded.
- **An interrupted archive looked finished.** Now the archive is built in a hidden `.<name>.making` folder and renamed when complete. Cancel is disabled while it runs.
- **Import blocked the main thread.** It now runs off it, with a progress indicator.
- **A failed rollback was silent.** It now reports the backup path.
- **Size checks passed when a size could not be read.** They now fail. Fresh photo copies go through a temporary file.
- **Where:** `80e832a`. Files: `Core/ImportPlan.swift`, `Core/YearEnd.swift`, `AppModel.swift`, `Views/YearEndSheets.swift`, `Views/RootView.swift`.

## Dictation and drafting safety after review

- **Symptom:** After the first Apple Intelligence release, a review found several ways to get wrong or unsafe output: a start overtaken by Stop, a microphone left on after a failure, notes assigned to students who were never named, and drafts that could carry private matters or other children's names.
- **Cause:** Dictation had no session token. The note sorter trusted the model's student names. Drafts included notes about plans and meetings, and masked nothing.
- **Fix:**
  - Dictation: a session token stops an overtaken start. Failures tear down the microphone and keep the words heard. Stop gives up waiting after four seconds.
  - Note sorting: whole-class notes need "whole class", "everyone" or "everybody" said. A student the model names who was not said is shown as not matched. The name fallback only uses names actually said.
  - Drafts: run on the main actor and check for cancellation, so a discarded draft never returns half written. Other students' names are masked. Notes about plans, meetings or diagnoses are left out, and a draft that mentions them is refused. A draft that copies six words in a row from an example is redrafted without examples.
  - Screens: Cmd+Return saves dictated notes, undo for skipped and retry for failed class drafts, confirmation before replacing a learning intention.
- **Where:** 1.11.0, `c015a04`. Files: `Core/CommentDraft.swift`, `Core/Dictation.swift`, `Core/NoteSorter.swift`, `Core/Intelligence.swift`, `Views/DictateSheet.swift`, `Views/DraftViews.swift`.

## CI build broke on the macOS 26 SDK

- **Symptom:** The GitHub Actions build failed on Xcode 26.6 while it built locally.
- **Cause:** `LanguageModelError` exists only in the macOS 27 SDK. Naming it in `Intelligence.swift` did not compile on the CI SDK.
- **Fix:** The error is recognised by its type name and case label (`isNewModelError`), which works with both SDKs. It was checked against a real context overflow on macOS 27.
- **Where:** Released in 1.12.0, `b302fa4`, `Holocron/Core/Intelligence.swift`. Lesson: CI uses a different SDK from a development Mac.

## On-device model refused ordinary class topics

- **Symptom:** A report draft failed with "Apple Intelligence would not write this one" when a note covered an ordinary topic, such as a unit project on LGBTQIA+ rights.
- **Cause:** The model's own safety check turns down some ordinary class topics. The drafter treated every refusal as final.
- **Fix:** On a refusal the drafter retries the same step with fewer notes, in order: unit notes, lesson notes, all notes including the teacher's Notes for drafting (`CommentDrafter.Omit`). `draft` returns the text and a notice naming what was left out, shown beside the draft. The class drafts sheet keeps only the text. Too-long and copied-example fallbacks advance the step explicitly.
- **Where:** `b8d2260`, released as 1.13.1. Files: `Core/CommentDraft.swift` (`Omit`, `draft`, `reportFacts(omit:)`), `Views/DraftViews.swift`.

## 1.13.1 "AI guardrails"

- **What the release is:** `v1.13.1` is the first tag that contains `b8d2260`. Between `d9359c9` (1.13.0) and `734ea75` (1.13.1) the only code change is `b8d2260`. The two commits after it (`63500c5`, a rebuild numbered 1.13.0, and the changelog commits) touch only `project.pbxproj` and `Holocron/CHANGELOG.md`.
- **Original changelog text:** "Fixing AI Guardrails". It has been rewritten to describe the retry on refusal.
- **Still true:** Refusals can still happen. If all notes are left out, the draft is written from the report judgements, results and unit only.

## A lock file was committed

- **Symptom:** `state/inuse.26997.lock` is tracked in git.
- **Cause:** It was added by the 1.9.1 release commit (`735dc9b`) with `git add -A`. It is a leftover from a tool, not from Holocron.
- **Fix:** Not fixed. Remove it with `git rm` and add `state/` to `.gitignore`. `scripts/release.sh` runs `git add -A`, so this can happen again.

## Known limitations

- **No Xcode test target.** `scripts/test-core.sh` compiles the Foundation-only Core files with `Tests/Core/main.swift` and runs them against temporary folders (CSV, row merge, saving with a merge, schema version). Everything else is checked by building and by hand.
- **Ad hoc signing, not notarised.** Gatekeeper does not recognise the developer, so a first launch needs right-click, Open. Updates remove the quarantine flag after install. Updates are checked by SHA-256 from the same GitHub release, so the checksum protects against a damaged download, not a compromised release.
- **Sandbox off** (`ENABLE_APP_SANDBOX = NO`) so the app can reach an iCloud Drive folder. The app can read whatever the user can.
- **Light mode only**, by choice. Dark mode is not supported.
- **Apple silicon and macOS 26 or later only** (`ARCHS = arm64`, `MACOSX_DEPLOYMENT_TARGET = 26.0`).
- **On-device model refusals can still happen.** Apple Intelligence may also be turned off or not ready, and the features then hide.
- **Draft lesson masks words that are also student names.** Every name on the roll becomes "a student" by whole word, so with a student called Mark or Grace the verb "mark" or the word "grace" in a summary is masked, and the draft can read oddly. It is the safe direction, as lessons may be shared. Fixing it needs a way to tell a name from a word.
- **Scan text has no Continuity Camera.** A photo from an iPhone cannot be taken straight into a field, because macOS cannot say which of several fields on a screen should get the image. Choose a file instead.
- **Lookup tools for report drafts are untested.** They are off (`useLookupTools = false`) and have never been run against the model. See [ROADMAP.md](ROADMAP.md).
- **Merge by row narrows the clash, it is not a lock.** Before every save Holocron compares the file with what it last saw. If the file changed (another Mac, a hand edit, an AI assistant), it copies the file into `Holocron archive/Before merge`, reads it again and merges row by row ([Core/RowMerge.swift](../Holocron/Core/RowMerge.swift), [Core/MergedSave.swift](../Holocron/Core/MergedSave.swift)), checking the file again just before it writes. Two Macs that save in the same instant can still clash, because iCloud is not a lock, and that window is very small. Two Macs with the same row key and the same column changed are asked about. Conflicts are saved to the file as theirs until answered, with my side kept in `Before merge` as `(mine)`. The folder is not watched while the app is open, so a partner's changes appear at the next save or when the app becomes active. If iCloud has made a copy such as `lessons 2.csv`, Holocron offers to merge it in and never deletes it. Every merge is copied first, dated to the minute, so no earlier version is lost. Known gaps: a lesson that is pushed, pulled or renamed changes its key, so it shows as removed and added and a colleague's simultaneous edit of it gives a duplicate rather than a question. Columns in their file that this version does not know are kept only in the Before merge copy. The first launch of a folder makes a Before migration copy of settings.csv even though nothing changes.
- **Undo is short and cautious.** Deletes, swaps and lesson moves can be undone ([Core/UndoLog.swift](../Holocron/Core/UndoLog.swift)), but only until something else changes the same file, because putting the old rows back would remove the newer change. Typing a lesson summary after a swap ends the swap's undo. The history is in memory and is gone when the app quits. Removing work photos and interviews cannot be undone, because their files move. The safety net is the archive folders and the teacher's own backup.
- **Schema version is a stamp so far.** `settings.csv` holds `schema_version` (1). Older files that lack a newer column still load because missing columns read as empty. `SchemaVersion.steps` is empty of real changes, so no file is rewritten yet. A folder from a newer Holocron is read as it is and not stamped.
- **Hand-edited CSVs are trusted.** Ids that are duplicated or missing are not checked. A lesson with a subject that is not in `subjects.csv` is shown with a grey default colour.
- **Network.** The only request the app makes is the update check, but macOS may download its English speech model from Apple the first time you dictate.
- **Semester 2 starts in July**, fixed in code (`Database.semesterTwoStartMonth`).
- **House colours are fixed** in `Lists.houseColours`. The school and PYP lists are set for one Victorian school.
- **No `TODO` or `FIXME` comments** are in the source (checked with `grep`).
