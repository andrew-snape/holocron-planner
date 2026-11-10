# Changelog

## Unreleased

- Mark class has a Markbook view. Choose a subject and see the whole class in one grid, students down and tasks across, coloured by result. Click a column heading to sort. Empty cells say Missing, and a list under the grid names who is missing each result. A pre-test and post-test of the same thing, such as Fractions pre-test and Fractions post-test, get a Growth column. Export CSV saves the grid for a spreadsheet.
- A student's Assessment tab has a Growth chart with a line for each subject. Scores show as a percentage and achievement levels from Emerging 20 up to Extending 100.
- Report progress, next to Draft for the class on a student's Report tab, lists every student with how many judgements are done, their general comment (None, Draft or Ready, with the word count against 100 to 150), and their English and Maths dot points. Copy for SIMON copies one comment ready to paste.
- Groups. Make reading groups, maths groups and inquiry teams from Mark class or Quick log, by chance or mixed by latest result. In Quick log, Groups selects a group's students. In Mark class, choose a group to mark just those students. They are kept in groups.csv in your student folder.
- The Class screen can show your groups. It is off until you switch on Show groups on the Class screen in Settings, because students' first names would be on the projector. The card has a Hide names button.
- Today has a Now card at the top. It shows the lesson on now in its subject colour, a line through the lesson, how many minutes are left, what comes next, and a button for the Class screen. Lessons that have finished fade back. The quote moves to the bottom of the side panel, and the to-do list says how many are due today or late.
- Subject colours are chosen from twelve that read well on the Week grid and on paper. Colours you chose earlier stay until you pick a new one.
- On Week, today's column has a soft blue tint. A lesson with a full plan has a filled dot, and one with only a summary has a hollow dot. A lesson you drag shows a blue edge over the slot it will swap with.
- The Class screen has larger small text. The work mode card takes a calm wash of its colour, and the timer turns red and says Time's up when it ends. A tick box under the timer turns the end sound off.
- Work has its title and Add work button in the window toolbar, like the other screens.
- Text sizes across the app now come from one set of named sizes, with no change to how anything looks.

## 1.26

- If a file in your folder changes while Holocron is open, for example because another teacher saved in the shared planner folder, Holocron now adds their changes to yours instead of overwriting them. It copies the file into Before merge in Holocron archive first, every time.
- If you and someone else changed the same thing, a sheet shows both versions side by side and asks which to keep. Until you choose, the file keeps their version and your version stays on screen. Your version is also copied into Before merge.
- If iCloud has made a copy of a file such as lessons 2.csv, Holocron offers to merge it in. The copy is never deleted.
- Holocron records which file layout your folder uses. Before it ever changes the layout of your files, it copies them into Holocron archive.
- If your folder was saved by a newer Holocron, Holocron copies all its files into Holocron archive before it changes anything, and tells you where the copy is.

## 1.25

- The sidebar has three headings: Plan (Today, Week, Term, Units, Devotion), Teach (Class screen, Quick log, Mark class) and Class (Students, Work, Hours). Units and Devotion have new icons. In Settings, the arrows under Modules move a screen within its heading.
- Jump (Cmd+K, or Go, Jump to…) finds a student, a screen, a unit or a lesson from a few letters. Type "mat thu" for Thursday's Maths, then press Return. While a Class screen is showing, Jump only finds screens, so no names or lesson text show on the Mac.
- Undo and Redo (Cmd+Z, Shift+Cmd+Z) take back a delete, a swap or a lesson move. The Edit menu names what it will undo, and the message after the change has an Undo button. A change can be undone until something else changes the same file. Nothing extra is saved on the Mac.
- A student's record has eight tabs. Lesson notes, Wellbeing and Behaviour are one Notes tab with a picker to add an entry and a filter to show one kind. Tabs show how many entries they hold.
- The Summary tab starts with notes this term, days since the last note, and the latest result in each subject.
- Right-click menus on Week and Today lessons (plan, change, move, show on the Class screen), on students, on note entries (Copy, Delete), on to-dos and on work.
- Deleting an entry from its right-click menu asks first.
- Empty screens have a button for the next step: Add student on Students, Quick log and Mark class, and New unit on Units.
- Units has a search field in the toolbar.
- On Week, press Return in a lesson's summary to open its plan. Shift+Return starts a new line.
- In Mark class, Return moves to the next student's box.
- Quick log starts on the kind of entry you saved last.

## 1.24.2

- Note boxes check spelling as you type, with the Mac's own spell checker. Words that look wrong get a red underline. Nothing is changed for you, and nothing leaves this Mac.

## 1.24.1

- Fixed: note boxes, such as Quick log and the lesson sheet, could not be clicked into in 1.24. The spell check added in 1.24 has been taken out for now.

## 1.23.1

- Mark class has a Done tick for each student. Use it to show who has finished a task, such as a TDL project, without giving it a mark. Ticks save with the rest of the class.
- Today's timetable on the Class screen is shorter and fits the window. Breaks show on one line, and the current lesson has a border and the word NOW.
- The stopwatch is one row under the timer, so the timer card fits on the screen.

## 1.23

- The date picker in the Today toolbar uses its normal size and spacing.
- Classroom is part of the Class screen. Today's timetable sits above the lesson, with the current block highlighted and the breaks named. Hide it with the Today heading when you need the space.
- The stopwatch is under the timer on the Class screen. It keeps running when you leave the screen and come back.
- Settings has arrows beside each screen under Modules, so you can choose the order of the sidebar and the Go menu. Use the standard order puts it back.
- The separate Classroom screen and its Open on screen window are gone. Use the Class screen, or Pop out for the projector. Its sidebar switch in Settings no longer appears.

## 1.22

- Classroom is a new screen for the projector. It shows a large clock and date, today's timetable from Holocron with the current block highlighted, Now and Next, and a timer and stopwatch.
- Open on screen opens Classroom in its own window. Use the green button for full screen. Pressing it again brings the same window forward.
- Classroom fills the screen with larger text, and wraps or scrolls rather than cutting things off in a small window.
- Classroom shows times the way the rest of Holocron does, such as 9:00 am. Space starts and pauses the timer, and Esc closes the window.
- Classroom's stopwatch keeps running when you leave the screen and come back.
- A file that has none of the columns Holocron expects, or is saved as UTF-16, is not read or changed, so it cannot be overwritten by mistake.
- Now and Next shows the break between lessons, such as Eating and recess, and follows camps, carnivals and other changes to the day.
- Student names are left out of Siri's answers while the Classroom board is showing, as they are for the Class screen.
- If a save fails, Holocron keeps your changes and shows a warning with a Try again button. It also tries again on your next change, when you quit, or when you come back to the app. A folder change, reload, import or Start over waits until the changes are saved.
- If settings.csv cannot be read, Holocron keeps the last private subject and Devotion settings and does not write lessons or Devotion until the file can be read again.

## 1.21

- The About Holocron window has a description of the app, the frameworks it is built on, a link to the source code on GitHub, and the licence.

## 1.20

- Work has photos and scans of students' work. Choose the students for each one, add the date, lesson, unit, task and a caption, and link a result if there is one. A group photo is stored once and shared.
- A student's Work tab shows their work with filters for subject, term and unit, and a search over task and caption. The Work screen shows the whole class and can be switched off in Settings.
- Work files are copied in exactly as they are, so the picture is the same as the original. Remove moves a picture to a removed folder rather than deleting it.
- Captions on work can be used in report drafts.
- Cmd+1 to Cmd+0 keep their old screens. Work has no number key, so use the sidebar to open it.
- Import now brings in work photos and interview recordings, and its preview and summary show them.

## 1.19

- A student's tabs wrap onto a second line, so Report and Details are no longer cut off.
- Each student tab has its own icon and colour. The selected tab shows its colour with a soft glow and a filled icon.
- Interviews is blue, to match the other note tabs.

## 1.18.1

- The date box in the Today toolbar sits level with the buttons beside it.

## 1.18

- Quick log's note for one student has Record interview…, which opens the interview recorder for that student.

## 1.17

- A student's header has Record interview…. Record, stop, and Holocron turns the recording into words on this Mac for you to check. The recording is kept in the student's folder, and the transcript starts with a note that it was recorded and needs checking.
- An interview can be summarised with Apple Intelligence only when you mark it not private. Private topics, such as wellbeing or plan details, are never sent, and a transcript with a private word is not summarised.
- The Interviews tab lists a student's interviews. Removing one moves its recording to `recordings/removed`, so nothing is deleted.

## 1.16

- Quick log has a Dictate… button in the note box. Say the note and the words are typed in, after anything already there, and you can edit them before you Save. Everything stays on this Mac.

## 1.15.1

- A maintenance release with the same features as 1.15. The release notes are tidied.

## 1.15

- Holocron now follows the new macOS look (Liquid Glass). Screen titles and buttons sit in the window toolbar. Today, Week, Term, Units, Devotion, Students, Quick log and Mark class have lost their big headings, and the date or week shows under the title.
- The Go menu has Previous and Next (Cmd+[ and Cmd+]) and Go to Today (Cmd+T). Help lists them.
- Blue buttons and the sidebar highlight now use Holocron's own blue.
- Pages are plain white. Cards are rounder, have no shadow and keep a thin edge. The week and term grids sit on a faint grey panel so they still stand out.
- The Class screen buttons (previous and next lesson, Pop out, Full screen, Done) sit in a glass bar at the bottom. On the projector window the bar floats over the page, fades after a few seconds and returns when you move the mouse or press a key. The left and right arrow keys still change lesson while it is hidden.
- Messages at the bottom of the window use the same glass look.
- Sheets have Cancel on the left and the main button on the right, such as Save or Add student. Esc still cancels, Return still confirms, and a sheet with unsaved changes still asks before it closes. The unit sheet keeps Cmd+S.
- Change subject, Move and Swap keep both their choices in the sheet, so Return does not change the timetable by accident.
- Draft comments for the class has one Close button, which asks before unused drafts are lost.
- Each screen has its own icon colour in the sidebar. The week box in the sidebar is softer, Settings uses the standard Mac look, and Help shows the page name in the window title.

## 1.14

- Settings now looks like System Settings, with a sidebar and search. The Data tab is split into Folders, Privacy and Year End.
- Holocron writes a guide for AI assistants into each data folder, and Help has Copy Guide for AI Assistants.
- New Describe Holocron action for Shortcuts.
- Documentation for contributors and AI assistants: CLAUDE.md, AGENTS.md and the docs folder.
- Draft lesson… in a lesson's plan drafts tuning in, explicit teaching, independent work and reflection from the summary. It fills the empty steps, or replaces yours if you ask, and never uses student names.
- Suggest subject and kind reads a note you have typed for a student and offers a subject and a kind of note. It only runs when you choose it, and nothing changes until you press Use.
- Type a to-do in plain words, such as "remind me to print excursion forms Friday". Holocron tidies the wording and fills in the due date for you to check. It works with Apple Intelligence off, and so does the Add a To-Do shortcut.
- Drafts start sooner. Apple Intelligence gets ready when you open the Report tab, class drafts, Dictate or Import results, and what it was given is cleared within three minutes or when you leave the screen.
- Scan text… reads the words from a photo, a scan or a PDF into a lesson's summary or resources, or a student's note. You check the words before they are added, and the picture is never kept.

## 1.13.1

- Report drafts no longer stop when Apple Intelligence refuses a note. Its safety check sometimes turns down ordinary class topics, such as a unit project on LGBTQIA+ rights. Holocron now tries again with fewer notes: first without your unit work notes, then without your lesson notes, then without any notes, including your Notes for drafting.
- When a draft was written without some of your notes, a message beside it says which ones were left out, so you can add them yourself.

## 1.13.0

- Import Essential Assessment report comments. Choose a Report Comments export in Import results… and Holocron recognises it, matches the students, and keeps each student's Areas of Success, Growth and Improvement with the semester. Import one file for each strand. Importing the same strand again replaces the earlier comments.
- Draft Mathematics points (and English, for literacy strands) now builds on those comments: what a student understands and has grown in becomes "[Name] has:", and what they still have to work on becomes "Areas for [Name] to focus on:". The imported comments are shown under the comment box on the Report tab.

- Report drafts write subject names with a capital, and "maths" in full as Mathematics, as the reporting style asks.
- Drafts are asked not to reuse their describing words or to say why a goal helps twice, and the list of things to check now points out a describing word used twice, such as skilful and skilfully.

## 1.12.0

- Report drafts follow school reporting style: plain Australian English, 100 to 150 words, short sentences, a positive opening, one area of need framed as growth and a warm close, with no labels, scores, exclamation marks or words such as good and nice. Spellings such as focused, benefited, judgement and program are fixed, and numbers up to ten are written as words. Anything left to check, such as two sentences that begin the same way, is listed beside the draft.
- Your own rules for report comments, in Settings, then Apple Intelligence, are followed in every draft.
- Students can have a preferred name. Reports write the formal name first, as Qixuan (Shirley), then the preferred name.
- Tick Has an ILP in a student's details and drafts end with your ILP sentence, which you can change in Settings. Holocron adds it; the drafter never writes about the plan. Choosing Modified for a student without an ILP shows a reminder.
- English and Mathematics comments on the Report tab, as dot points under "[Name] has:" and "Areas for [Name] to focus on:". Draft them from the semester's notes and results, then Copy for SIMON pastes them with %* dot points.
- Notes for drafting on the Report tab let you add what a draft should mention, such as the unit project or a specialist's comment.

## 1.11.0

- Dictate notes. In Quick log, choose Dictate… and say your notes for several students at once. With Apple Intelligence on, Holocron sorts what you said into a note for each student, with the subject and whether it is a lesson, behaviour or wellbeing note, for you to check before saving. A student who was not named is never added, and if two students share a first name you are asked which one.
- Draft report comments. On a student's Report tab, Draft comment writes a general comment in your voice, learnt from your earlier comments, using the semester's notes, results, report judgements and unit. Draft for the class… does every student without a comment, for you to go through one by one. Choose she, he or they for each student. Wellbeing, behaviour, medical notes, adjustments and plan notes are never used, and no score or report label is quoted.
- Draft learning intentions and success criteria from a lesson's summary, explicit teaching and unit.
- Every draft stays a draft until you choose Use, and can be edited, written again or discarded. Writing Tools is fully available in note and comment boxes.
- Each feature can be switched off in Settings, then Apple Intelligence. Everything runs on this Mac. The first time you dictate, macOS may download its English speech model from Apple; your voice and notes are never sent.
- Drafts never name other students, leave out notes that mention plans, meetings or diagnoses, and are written again if they copy from your earlier comments about other students.

## 1.10.0

- Siri, Spotlight and Shortcuts. Ask "What's next in Holocron?", "What's on today" or "tomorrow", "When is Maths in Holocron?" or "Any birthdays this week in Holocron?". You can also log a note for a student (Siri checks with you before saving), add a to-do, copy today for a relief teacher, open the Class screen or start the class timer. Every action is also in the Shortcuts app, ready to build into your own shortcuts.
- Student names stay private. Siri only says or suggests them once you switch that on in Settings, then Apple Intelligence, and never while the Class screen is showing. Birthdays, notes and copying a day need your Mac to be unlocked, and Siri only says Saved once the note is on disk.
- New Settings, then Apple Intelligence tab. It shows whether Apple Intelligence is ready on this Mac, lets you switch off each suggestion feature, and lists what you can ask Siri. Everything runs on this Mac.

## 1.9.2

- Import results from a spreadsheet. In Mark class (or File, then Import Results…), choose an Excel or CSV export and Holocron matches its columns, subjects and students before anything is saved. Essential Assessment exports are recognised as they are, with each strand and focus area, pre and post test, percentage, achievement level, range and growth. For other spreadsheets the columns are matched from their headers, and on a Mac with Apple Intelligence it can suggest them, on this Mac only.
- Students not on your roll are left out, so a whole-school export only brings in your class. Close names such as Alex and Alexander are marked for you to check, and a student you pick by hand is remembered by the file's student ID for next time.
- Importing a newer export of the same tests updates those results instead of adding them twice, and keeps anything you typed in the comment. assessments.csv is copied into a Before results import folder in Holocron archive first.

## 1.9.1

- Dates now follow Australian habits throughout Holocron: weeks start on Monday, and the calendar's day letters read M, Tu, W, Th, F, Sa, Su so Tuesday and Thursday can be told apart.
- Adding a non-teaching day for a date that already has one now updates its label instead of adding a second row, and a message says whether it was added or updated.
- On Today, the list is now called To-do, and Add stays greyed out until you have typed something.

## 1.9.0

- Year end. Archive this year copies your data folder into a Holocron archive folder without changing anything, checks each copy and writes a README. Import from folder now shows what it will replace, checks the source, saves the replaced files into a Before import folder first, and rolls back if a step fails.
- Sheets now follow Mac habits. Return confirms and Escape closes, Cmd+S saves a lesson or unit, and closing a lesson with unsaved edits asks before discarding them.
- New in the File menu: New Student (Cmd+N) and Log Note (Cmd+L). The window title now shows the screen you are on, and Settings shows the tab.
- Students has a search field in the toolbar, and Students and Quick log say what to do when there are no students yet.
- Hours has a bar chart of DOTTL time by type for the term.
- Better for VoiceOver and for small click targets across Week, Today, Class screen, Terms, Units, Help and Settings.

## 1.8.12

- Safer updates. Holocron now only installs an update if the release includes its checksum file, and the download is checked against it before anything is replaced.
- Updates always come from the official Holocron releases page. The GitHub repository field in Settings, then Updates has been removed.

## 1.8.11

- Renaming a subject in Settings now follows through everywhere it is used: the timetable, one-off changes, lessons, results, notes, reports and its private setting. The new name is applied when you press return or click away.
- Faster and smoother. Typing a lesson summary no longer rebuilds the subject, timetable and student lists, bumping or pushing a run of lessons is quicker, and the Hours, Term and Students screens no longer redo their sums on every keystroke.
- Importing data now saves your pending changes first and swaps each file in safely, so a failed copy cannot lose the file it was replacing.
- Fixed the Change photo button showing Photo saved twice, or after a failed save. Saving a student pack as a text file now reports a failure.
- Update check problems now show in Settings, then Updates.
- Tidier inside: shared code for reloading, copying and break labels, and Settings is now split into separate files.

## 1.8.10

- The current week is now highlighted on Term, Units and Devotion. On the Term grid the week gets a This week tag and a soft blue tint, with today still in a stronger blue. A unit whose dates include this week shows a This week tag, and the devotion for this week is tagged too.

## 1.8.9

- On the Class screen, the First, Then and Next steps now sit below the I can list, so the learning intention and success criteria come first.

## 1.8.8

- The Class screen is now student friendly. The learning intention sits under We are learning to and the success criteria under I can. If a lesson already starts with those words (or WALT), they are trimmed so they do not appear twice. A lesson with no plan shows Get ready to learn!
- New First, Then and Next steps on the Class screen. Choose Add First, Then, Next and type three short steps straight onto the screen. Click a step's heading to highlight the one the class is on. Steps are saved with the lesson in classsteps.csv in your student folder, so colleagues sharing the planner never see them.
- A Now and Next strip along the bottom of the Class screen shows the current lesson and what follows, including Recess, Lunch and Home time.

## 1.8.7

- Privacy settings are now in one place. Settings, then Data has a Privacy section with Devotion scripts and quotes, and a checkbox for each subject whose lessons you want to keep to yourself. The Private checkboxes have gone from the Timetable tab, and the section says when your planner is not shared, so the settings make no difference yet.
- Tidier Settings text. The GitHub repository field is wider, versions and folder paths use the normal font, terms read as Term 1 2026, and the Non-teaching days date no longer has its own caption.

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
