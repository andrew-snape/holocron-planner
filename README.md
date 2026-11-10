<p align="center"><img src="docs/icon.png" width="128" height="128" alt="Holocron app icon"></p>

# Holocron

[![Build](https://github.com/andrew-snape/holocron-planner/actions/workflows/build.yml/badge.svg)](https://github.com/andrew-snape/holocron-planner/actions/workflows/build.yml) [![Latest release](https://img.shields.io/github/v/release/andrew-snape/holocron-planner)](../../releases/latest) [![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE) ![macOS 26+](https://img.shields.io/badge/macOS-26%2B-lightgrey.svg) ![Apple silicon](https://img.shields.io/badge/Apple%20silicon-arm64-lightgrey.svg)

A classroom planner for primary school teachers, built as a native Mac app. It started as the planner for one Year 6 class in Victoria, Australia, and is shared here in case it helps other teachers. Light mode, Australian English, and a classic Mac look.

Holocron keeps your fortnightly timetable, lesson summaries, student notes and teaching hours in plain CSV files that you own, so you can back them up, hand-edit them in Numbers, or share the planner part with colleagues.

## What it does

- **Today**: a Now card for the lesson on now, with what is next and a button for the Class screen. Every block of the day follows in a vertical list, with finished lessons faded, birthdays coming up, and a quote card.
- **Week and Term**: plan a whole fortnight in a grid. Type straight into a slot, drag to swap lessons, change a slot for one day or for every cycle, push or pull lessons when a day is lost, and print the week on one A4 page or save it as a PDF.
- **Copy lessons**: copy a whole day (times, lessons and resources) as rich text to paste into your school LMS for a relief teacher.
- **Class screen**: a student friendly view for the projector, with We are learning to and I can, First, Then and Next steps typed straight onto the screen, a Now and Next strip, and a timer.
- **Students**: a class list and a record for each student with notes, assessments, wellbeing, behaviour, plan notes and a report pack. Photos, birth dates and adjustments are kept on your Mac only.
- **Quick log and Mark class**: log a note for several students at once, or mark the whole class on one task, typing a score or picking an achievement level. Groups select the students you want, and the Markbook shows the whole class in one grid.
- **Hours**: face to face time, release time and duties other than teaching and learning, by term and for the year, including the period lost to wellbeing work.
- **Units and Devotion**: units of inquiry and daily devotion scripts. Every module can be switched off in Settings. When the planner is shared, subjects and devotion scripts can be kept private (see Your data).
- **Apple Intelligence and Siri**: dictate notes, draft report comments and learning intentions, and ask Siri or Shortcuts what is on next. It all runs on your Mac, every draft waits for you to choose Use, and each feature can be switched off in Settings.
- **Sidebar**: the class name and current week stay at the top, with a mini calendar that switches between Week and Month views.

The timetable runs on an A and B fortnightly cycle that restarts each term. Whole days can be marked as camps, carnivals and so on.

## What's new

- **1.32**: A new look for the Mac, with clearer type and sheets. Today opens with a Now card for the lesson on now, and subject colours come from twelve that read well. Work has its own toolbar. The Class screen text is larger, and the timer says Time's up.
- **1.31**: A Markbook for the whole class in one grid, a Growth chart on each student's Assessment tab, a report progress board, and groups for reading, maths and inquiry teams.
- **1.26**: Two teachers can share a planner folder safely. Changes are added together row by row, and a sheet asks which to keep when you both changed the same thing. A copy of each file is kept in Holocron archive first.
- **1.25**: Sidebar headings, Jump (Cmd+K) to any student, screen, unit or lesson, Undo and Redo for deletes and moves, right-click menus, and one Notes tab on each student.
- **1.13.1**: A report draft that Apple Intelligence refuses is tried again with fewer notes, and a message says which notes were left out.
- **1.13**: Import Essential Assessment report comments, and use them to draft the Mathematics and English points.
- **1.12**: Report drafts follow school reporting style and your own rules. Preferred names, an ILP sentence, and English and Mathematics dot points with Copy for SIMON.
- **1.11**: Dictate notes in Quick log, draft report comments and learning intentions, all on this Mac and never saved until you choose Use.
- **1.10**: Siri, Spotlight and Shortcuts actions, and a Settings tab for Apple Intelligence. Student names stay off until you switch them on.
- **1.9.2**: Import results from a spreadsheet, including Essential Assessment exports.
- **1.9.1**: Monday-first dates, clearer weekday letters, and tidier To-do and non-teaching day handling.
- **1.9**: Year end archive, a safer import from another folder, Mac-style sheets, Students search, an Hours chart and better VoiceOver support.
- **1.8.12**: Safer updates. An update is only installed if the release has a checksum file, and updates always come from the official releases page.
- **1.8.11**: Renaming a subject follows through everywhere it is used, screens are faster, imports are safer, and update check problems show in Settings.
- **1.8.8**: A student friendly Class screen, with We are learning to and I can, First, Then and Next steps you type on the screen, and a Now and Next strip.
- **1.7**: Subjects can be marked private when your planner folder is shared. Devotion scripts and quotes can be kept private in the same way.

The [changelog](Holocron/CHANGELOG.md) has the full history.

## Requirements

macOS 26 or later on a Mac with Apple silicon.

## Install

1. Download the latest `Holocron-x.y-mac.zip` from the [latest release](../../releases/latest). The [changelog](Holocron/CHANGELOG.md) lists what changed in each version.
2. Unzip it and drag Holocron into your Applications folder.
3. The first time, macOS will not recognise the developer, because the app is not signed with a paid Apple Developer ID. Right-click Holocron, choose **Open**, then **Open** again. It opens normally after that.
4. On first launch, Holocron offers to set up its data folder (see below). It starts you off with a typical school day and a list of subjects. Add your term dates under Settings, then Calendar, and adjust the periods and subjects to suit your school.

## Updates

Holocron checks this repository's Releases page when it opens (at most every six hours) and shows a banner when a newer version exists. **Install and restart** downloads it, checks it against its published checksum, swaps it in and reopens the app. You can also use Settings, then Updates, or the Holocron menu, then Check for Updates. A release without a checksum file is never offered.

Updates always come from this repository. If you fork the project, change `defaultRepo` in `Holocron/Views/Updater.swift` to your own `owner/repository` before building.

Updates never touch your data, which lives in its own folders.

## Your data

Everything is stored as CSV files in a folder you choose, by default `iCloud Drive/Holocron/data`. There is no account, no server, and no tracking. The only network request the app makes is the update check to GitHub. The first time you dictate, macOS itself may download its speech model from Apple. Your voice and notes are never sent.

The data is split in two folders:

- **Student folder (private)**: students, notes, assessments, wellbeing, behaviour, reports, photos, your hours log, your to-do list, your settings, and any private subject lessons or Devotion files (`lessonsprivate.csv`).
- **Planner folder**: the timetable, lessons, terms, units, devotions, quotes, rubrics, subjects and periods. In Settings, then Folders, you can point this at a folder shared with colleagues (for example a shared iCloud Drive folder) so a team can share one planner while keeping student records private. Subjects marked private keep their lessons in the student folder instead, and private Devotion scripts and quotes move there too. Your colleagues' own lessons are never touched.

If the planner folder is shared, Holocron merges a colleague's changes into yours when it saves, instead of overwriting them. Each merge copies the file into `Holocron archive/Before merge` first.

Edit a CSV in Numbers or a text editor, then press Shift+Cmd+R to reload. Files are written safely (to a temporary file, then swapped in), a file that cannot be read is never overwritten, and a warning shows if the data folder is not connected.

To begin again, use **Start over** in Settings, then Year End. You can clear just the planner (timetable, lessons, terms, subjects and so on) or everything. The current files are moved into a dated folder in `Holocron archive`, next to the data folder, so nothing is lost. A shared planner folder is only disconnected, never cleared.

**Please check your school's policy** on where student information may be stored before putting any real student data into iCloud Drive or any other service. This repository contains no student data, and the project's `.gitignore` is set up to keep CSV files and photos out of it.

## For AI assistants

The repository has [AGENTS.md](AGENTS.md), an orientation manual that AI coding assistants such as Codex, Cursor, Copilot, Gemini and Claude look for, and [CLAUDE.md](CLAUDE.md) with extra rules for Claude Code. Documentation is in the [docs](docs) folder.

Holocron also helps an assistant understand your own files. It writes `README-for-AI.md` into the planner folder and the student folder. The guide describes each file and its columns, and how to edit them safely. The student folder copy begins with a privacy notice. To use it, ask your assistant to read `README-for-AI.md` in your Holocron folder first, then ask it to make the change. Quit Holocron before an assistant edits the files, or follow the checklist in the guide, then press Shift+Cmd+R in Holocron afterwards.

You can also choose Help, then Copy Guide for AI Assistants, to put the guide on the clipboard. The Describe Holocron action in Shortcuts returns the planner guide, which has no student information.

**Please check your school's policy** before giving any AI tool access to the student folder. It holds real student information.

## Build it yourself

1. Open `Holocron.xcodeproj` in Xcode.
2. Press Cmd+R.

The app uses a local (ad hoc) signature, so no developer account is needed. The sandbox is off so the app can reach your iCloud Drive folder. The project has no external dependencies.

Every push to `main` and every pull request is also built on a Mac by GitHub Actions (`.github/workflows/build.yml`). The run checks that no CSV files or photos are in the repository, builds the Release app, checks its signature, and keeps the built app for a week under the run's Artifacts. A red cross next to a commit means the build broke.

### Make it yours

- **Class name**: Settings, then General. It appears in the sidebar and on exported summaries.
- **Periods, subjects, terms and non-teaching days**: all editable in Settings.
- **Houses and their colours**: `Lists.houseColours` in `Holocron/Core/Schema.swift`.
- **Other lists** (day types, duty types, plan note types, reporting scales): the same file.

## Keyboard shortcuts

Cmd+1 to Cmd+0 jump between screens in this order: Today, Week, Term, Units, Devotion, Class screen, Students, Quick log, Mark class, Hours. Cmd+comma opens Settings. Cmd+N adds a student and Cmd+L logs a note. Option+Cmd+C copies the day's lessons as rich text. Cmd+K jumps to any student, screen, unit or lesson. Cmd+Z and Shift+Cmd+Z undo and redo a delete, a swap or a lesson move. Shift+Cmd+R reloads from the folder. On the Week screen, Cmd+P prints the week and Shift+Cmd+P saves it as a PDF.

## Publishing a release (for maintainers)

Replace `X.Y` with the new version number (for example `1.3`).

1. Commit your changes.
2. Add a `## X.Y` section to `Holocron/CHANGELOG.md`. Its bullets become the release notes.
3. Commit the changelog, then run `scripts/release.sh X.Y`.

The script needs a clean working tree, so commit everything first.

With the GitHub CLI installed and signed in (`brew install gh`, then `gh auth login`) the script builds, zips, checksums, tags, pushes and creates the release. Without it, the script builds the files into a `dist` folder and prints the steps to publish them from GitHub Desktop and github.com. Either way, running copies of Holocron then offer the update. If you publish by hand, attach both the `.zip` and its `.sha256` file, because the updater ignores a release that has no checksum.

The updater only downloads from this repository's release files over HTTPS, requires a published checksum that matches the download, and checks that the new app is Holocron, is newer, and has an intact code signature. The old app is kept until the new one is in place and is put back if anything goes wrong.

## Performance notes

- Schedule questions (what is on in period 3 on this date, which colour is Maths, who is this student) are answered from lookup tables built once per change, not by scanning every row on every redraw.
- Screens are told about changes one table at a time, so typing in a lesson summary redraws the lesson views and leaves the rest alone.
- CSV files are read and written as UTF-8 bytes, and saves happen on a background queue. Quitting and switching folders still wait until everything is on disk.
- Switching back to the app only re-reads files that changed.
- Student photos load as small thumbnails and are cached.

## Licence

Holocron is released under the [MIT Licence](LICENSE). You are free to use, copy, modify and share it, including for your own classroom or school, as long as the licence notice stays with it. It is provided as is, without warranty.

Holocron is an independent personal project. It is not made, endorsed or supported by any school or employer.
