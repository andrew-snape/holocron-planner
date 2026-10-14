# Changelog

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
