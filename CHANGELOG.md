# Changelog

## 1.8.6

- Fixed the Class name field in Settings showing the class name twice, with only one copy editable. The label beside each settings field is now hidden, so only the box shows.
- Settings forms now use Holocron's own grey background with white rows, instead of the system's default grey.

## 1.8.5

- Settings has been reworked to follow the usual Mac layout. The five tabs (General, Timetable, Calendar, Updates and Data) sit in the window toolbar with icons, and each tab is a grouped form with labels on the left and controls on the right. Periods, subjects and terms now line up in columns.
- Subjects no longer show the coloured preview chip. The colour swatch is still there, and Private is a checkbox.
- The Data tab is shorter: Student folder, Planner folder, Start over, and Reload with the version.

## 1.8

- Settings now lives in the toolbar. A gear button sits at the right of the window, and Settings opens in its own window, as in other Mac apps. Cmd+comma and the app menu open the same window. Settings is no longer in the sidebar or the Go menu.
- Check for Updates now opens Settings on the Updates tab.
- Today is the only screen that always stays on. Settings no longer appears in the module switches.

## 1.7

- Private subjects. In Settings, then Timetable, each subject now has a Private switch. When your planner folder is shared, the lessons for a private subject (Devotion, say) are saved in a file only you have, lessonsprivate.csv in your student folder, and the timetable slot stays shared. A colleague's own lessons for that subject are never touched, and switching a subject back to shared hides the private ones without deleting them. When you make a subject private that already has lessons, you can copy them across or start empty. The shared copies are left as they are.
- Devotion scripts and quotes can be kept private too. In Settings, then Data, turn on Keep Devotion scripts and quotes private. They move to your student folder (copied across, with the shared files left alone) and colleagues no longer see or change them.
- Start over, planner only, now also clears your private lessons.

## 1.6.2

- The sidebar calendar now has a Week and Month switch. Week shows just the current week in one row (use the arrows to step through weeks), which leaves room for every menu item. Holocron remembers your choice, and on a shorter window a month shows as a week automatically.
- The sidebar menu is reordered: Today, Week, Term, Units, Devotion, Class screen, Students, Quick log, Mark class, Hours, Settings. Planning screens now sit together, then the in-class tools, then student records, then admin. The Cmd+number shortcuts under the Go menu follow the new order.

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
