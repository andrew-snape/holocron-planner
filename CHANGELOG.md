# Changelog

## 1.6.1

- Fixed the mini calendar in the sidebar. The first and last week of a month were drawn twice as tall as the others, leaving uneven gaps between the rows. All weeks are now evenly spaced.

## 1.6

- New Copy lessons button on the Today screen (and Edit, then Copy Day as Markdown, Option+Cmd+C). It copies every lesson and time for the day you are looking at as Markdown, ready to paste into the school LMS for a relief teacher: each period with its times, subject, summary, learning intention, success criteria, lesson sequence, resources as links, curriculum codes, and the day's devotion on Circle Time. Student records are never included.
- Assessments: the Result can now be typed as a score, as before, or picked from a dropdown of Extending, Mastering, Consolidating, Developing, Emerging and Modified. A Score or Achievement switch sits on Mark class and on each student's Assessment tab, and Holocron remembers your choice. Reopening a task shows it the way it was marked, and results are still saved as plain text.

## 1.5.1

- Print Week: the year no longer prints as 2,026, the page margins are tighter so more of each lesson summary fits, and summaries always print in plain black.

## 1.5

- New Print button on the Week screen, and File, then Print Week (Cmd+P). It lays the week out on one A4 landscape page, with the subject colours, lesson summaries, learning intentions (you can switch these off), camps, carnivals and days off, and opens it ready to print. Save as PDF (Shift+Cmd+P) keeps a copy instead.

## 1.4

- New Start over button in Settings, then Data. Clear just the planner or everything and begin again with a typical school day and a list of subjects. Your old files are moved into a dated folder in Holocron archive, next to your data folder, never deleted. A shared planner folder is only disconnected, so colleagues keep their planner.

## 1.3

- New app icon, matching the original Holocron web app, made for the macOS 26 icon style.

## 1.2.1

- Settings is now split into tabs across the top (General, Timetable, Calendar, Updates and Data) instead of one long page.
- Holocron, Check for Updates in the menu now opens Settings on the Updates tab.

## 1.2

- Update test: no changes to how Holocron works.

## 1.1

- A new data folder starts with a typical school day and a list of subjects (existing files are never changed).
- New Class name setting, so the sidebar and exported summaries show your class instead of a fixed name.
- Built-in updates from GitHub Releases: Settings, Updates, and Holocron, Check for Updates in the menu. Installing downloads the new version, checks it against its checksum, swaps it in and restarts. Data folders are never touched.
- Targets macOS 26 and Apple silicon only.
- Much faster Week, Term, Hours and Units screens: schedule lookups use an index instead of scanning every row.
- Faster CSV reading and writing. A field containing a Windows line break (CR LF) is now always quoted when saved.
- Saves happen on a background queue. Quitting and switching folders wait for them to finish.
- Reloading when you switch back to the app skips files that have not changed.
- Change notifications are per table, so an edit only redraws the screens that show that table.
- Subject colour maths is cached.
- Student photos load as small thumbnails and are cached.

## 1.0

- First native version: Today, Week, Class screen, Term, Units, Devotion, Students, Quick log, Mark class, Hours and Settings, with the two-folder data split.
