# Features

Everything built so far, with the version it arrived in ([CHANGELOG.md](../CHANGELOG.md)). "Start" means it was there before the first changelog entry (1.1). "Unreleased" is not in a release yet. For how each part works see [ARCHITECTURE.md](ARCHITECTURE.md).

## Planning

| Feature | Version | Notes |
|---|---|---|
| Today | Start | Every block of the day in a list, current period highlighted, birthdays coming up, quote card, to-do panel. Nothing shows on weekends and holidays. |
| To-do on Today | Start | Add with an optional due date, tick off. Add is disabled while the box is empty, and the heading reads To-do (1.9.1). |
| To-do in plain words | Unreleased | Type "remind me to print excursion forms Friday". The lead-in and date words come out and the due date is filled in for you to change or untick. Worked out in code (Australian day-month order, weeks from Monday, a bare Friday is the coming one), so it works with Apple Intelligence off. The Add a To-Do shortcut uses a stricter version that only takes a date when it is safe. |
| Draft lesson | Unreleased | In the lesson editor, Draft lesson… drafts tuning in, explicit teaching, independent work and reflection from the summary. It fills the empty steps, or replaces yours if you tick Replace. Never uses student names (every name on the roll is masked, so a word that is also a name, such as Mark or Grace, is masked too). Needs Apple Intelligence. |
| Scan text | Unreleased | Scan text… on a lesson's Summary and Resources and on student note boxes reads the words from a photo, scan or PDF (up to 12 pages) with macOS text recognition. You check and fix the words before they are added to the end of the field. The picture is not kept. File choice only: Continuity Camera was tried and removed because macOS cannot say which of several fields should get the image. Does not need Apple Intelligence. |
| Week | Start | Fortnight grid. Type a summary into a slot, change a slot for one date or every A or B week, drag to swap, filter by subject, move to last or next week. |
| Push and pull lessons | Start | Push a lesson and later lessons for the subject forward, or pull them back. A lost day (camp, carnival) pushes each subject. Shown first, with Undo. |
| Day types and non-teaching days | Start | Mark a date as Camp, Sports carnival, Excursion, Pupil free day or Other. Adding a non-teaching day for a date that already has one updates it (1.9.1). |
| Term | Start | Overview of one subject across the term. Current week tagged This week with a blue tint (1.8.10). |
| Units | Start | Units of inquiry with theme, central idea, lines, concepts, ATL and profile. A unit covering this week is tagged (1.8.10). |
| Devotion | Start | Daily devotion and Circle Time scripts. This week tagged (1.8.10). Can be kept private (1.7). |
| Lesson plans | Start | Summary plus learning intention, success criteria, lesson sequence, resources, curriculum codes, ATL and profile. Links in summaries are clickable (1.8.10). Cmd+S saves, and closing with unsaved edits asks first (1.9.0). |
| Print week | 1.5 | One A4 landscape page with subject colours, summaries, optional learning intentions, camps and days off. Print (Cmd+P) or save as PDF (Shift+Cmd+P). Year and margin fixes in 1.5.1. |
| Copy lessons | 1.6 | Copies a day with times, lessons and resources, for a relief teacher. Option+Cmd+C. Pastes as rich text with links. Never includes student records. |
| Private subjects | 1.7 | Lessons for a subject are kept in `lessonsprivate.csv` in the student folder when the planner is shared. |
| Subject rename | 1.8.11 | Follows through timetable, one-offs, lessons, results, notes, reports and the private setting. |
| Week and Month mini calendar | 1.6.2 | In the sidebar. Week shows one row. Remembered. Even row heights fixed in 1.6.1. |
| Sidebar order | 1.6.2 | Today, Week, Term, Units, Devotion, Class screen, Students, Work, Quick log, Mark class, Hours. |
| Sidebar headings | Unreleased | Plan, Teach and Class (`NavItem.group`). The order chosen in Settings applies within each heading. |
| Jump (Cmd+K) | Unreleased | Finds students, screens, units and lessons from a few letters, worked out in code ([Core/JumpSearch.swift](../Holocron/Core/JumpSearch.swift), [Views/JumpSheet.swift](../Holocron/Views/JumpSheet.swift)). Students are left out while a Class screen is showing. |
| Undo and Redo | Unreleased | Delete a note, result, plan note, wellbeing or behaviour entry, unit, to-do, DOTTL entry or student, swap lessons, move lessons. A short history in memory ([Core/UndoLog.swift](../Holocron/Core/UndoLog.swift)). Cleared for a table when anything else changes it. Work photos and interviews are not undoable because their files move. |
| Right-click menus | Unreleased | Week and Today lessons, student list, note entries, to-dos, work tiles. |
| Week: Return opens the plan | Unreleased | In a lesson's summary. Shift+Return starts a new line. |

## In class

| Feature | Version | Notes |
|---|---|---|
| Class screen | Start | A projector view of a lesson, in the window or popped out. |
| Student friendly layout | 1.8.8 | We are learning to, I can, Get ready to learn! for lessons with no plan. |
| First, Then and Next steps | 1.8.8 | Typed on the screen, saved in `classsteps.csv` (student folder). Click a heading to highlight the step. Moved below I can in 1.8.9. |
| Now and Next strip | 1.8.8 | Current lesson and what follows, including Recess, Lunch and Home time. |
| Timer | Start | One class timer shared by the sidebar module and the pop-out window. Keeps running when you leave the screen. Start it from Siri (1.10.0). |
| Work modes | Start | Silent, Whisper, Partner, Group, Ask 3 then me. |

## Students

| Feature | Version | Notes |
|---|---|---|
| Student records | Start | Class list and a record with tabs: Summary, Notes, Assessment, ILP and NCCD, Interviews, Work, Report, Details. Notes holds lesson, wellbeing and behaviour entries together (unreleased), and the Summary starts with counts and the latest result per subject (unreleased). Photos, birth dates and adjustments stay in the student folder. |
| Search | 1.9.0 | A search field in the Students toolbar. |
| New Student, Log Note | 1.9.0 | File menu, Cmd+N and Cmd+L. |
| Quick log | Start | Pick several students from the photo grid and log one note. Badges show today's entries. |
| Mark class | Start | Mark the whole class on one task. |
| Score or achievement level | 1.6 | Type a score or pick Extending, Mastering, Consolidating, Developing, Emerging or Modified. Remembered. |
| SSG and report pack | Start | Copy or save a student's notes, results and wellbeing for a date range, with an option to leave out medical details. |
| Import results | 1.9.2 | Excel or CSV export. Columns, subjects and students checked first. Essential Assessment recognised. Students not on the roll left out. Re-importing updates results. `assessments.csv` backed up first. |
| Dictate notes | 1.11.0 | Quick log, Dictate. On-device speech, sorted into notes per student with subject and kind, checked before saving. |
| Draft report comments | 1.11.0 | Draft comment on the Report tab, or Draft for the class. She, he or they per student. Never uses wellbeing, behaviour, medical, adjustments or plan notes. |
| Draft learning intentions | 1.11.0 | From a lesson's summary, explicit teaching and unit. |
| Report style rules | 1.12.0 | School reporting style, your own rules, preferred names, ILP sentence, English and Mathematics dot points, Copy for SIMON, Notes for drafting. |
| Essential Assessment comments | 1.13.0 | Import a Report Comments export per strand. Used to draft Mathematics and English dot points. Subject capitals and less repetition. |
| Retry on refusal | 1.13.1 | A refused draft is tried again with fewer notes, and says what was left out. |
| Suggest subject and kind | Unreleased | Under a typed note (Lesson notes form and Quick log), Suggest suggests lesson, behaviour or wellbeing and one of your subjects. It only runs when you press it, can only pick from your own subjects, and changes nothing until you press Use. Needs Apple Intelligence. |
| Faster first draft | Unreleased | Opening the Report tab, class drafts, a learning intention, Dictate or Import results gets Apple Intelligence ready, so the first result arrives sooner. What it was given is kept in memory for up to three minutes and cleared when you leave the screen. Not a visible control. |
| Work photos | Unreleased | Photos or scans of students' work, linked to one or more students by hand, with date, lesson, unit, task, caption and an optional linked result. Work tab on a student, and the Work screen for the class. Files are copied in unchanged, and captions can be used in report drafts. Kept in the student folder. |
| Lookup tools for report drafts | Unreleased, off | The code for letting the model look up notes and results by subject is built but switched off (`CommentDrafter.useLookupTools`) until drafts with and without it are compared side by side. |

## Admin

| Feature | Version | Notes |
|---|---|---|
| Hours | Start | Face to face, release and DOTTL by term and year. Wellbeing entries count and record the period lost. |
| DOTTL chart | 1.9.0 | Bar chart of DOTTL time by type for the term. |
| Settings | 1.2.1 | Tabs. Moved to a gear in the toolbar and its own window in 1.8, reworked as native grouped forms in 1.8.5, colours matched in 1.8.6, privacy together under Data in 1.8.7. Apple Intelligence tab added in 1.10.0. Unreleased: a System Settings style sidebar with search and eight panes (General, Timetable, Calendar, Apple Intelligence, Folders, Privacy, Year End, Updates). The old Data tab became Folders, Privacy and Year End. |
| Modules | Start | Every screen except Today can be switched off. |
| Updates | Start | Banner, Install and restart, check every six hours at most. Checksum required and official releases page only since 1.8.12. Problems shown in Settings (1.8.11). |
| Help window | 1.8 | Getting started, Using Holocron, Loading data, Entering data with AI, Keyboard shortcuts. Opens the data folders and copies a CSV guide for AI. |
| Starter data | 1.1 | A new folder starts with a typical day and a list of subjects. |
| Start over | 1.4 | Clear the planner or everything. Files move to `Holocron archive`. |
| Year end archive | 1.9.0 | Copy the data folder into `Holocron archive`, checked and with a README. |
| Import from folder | 1.9.0 | Shows what it replaces, keeps a Before import copy, rolls back on failure. |
| Sheets follow Mac habits | 1.9.0 | Return confirms, Escape closes. |
| VoiceOver and click targets | 1.9.0 | Labels and larger targets across the main screens. |
| Australian locale | 1.9.1 | Monday-first calendar, weekday initials M, Tu, W, Th, F, Sa, Su. |
| App icon | 1.3 | macOS 26 style. |
| AI guide in the data folders | Unreleased | `README-for-AI.md` in each folder, and Help, then Copy Guide for AI Assistants. |

## Integrations

Siri, Spotlight and Shortcuts arrived in 1.10.0 ([Intents/HolocronIntents.swift](../Holocron/Intents/HolocronIntents.swift)). Every phrase names the app. Student names are off until switched on in Settings, then Apple Intelligence, and never spoken while a Class screen is open.

| Action | What it does | Needs unlocked Mac |
|---|---|---|
| What's Next | Says the lesson on now and the one after it. | No |
| What's On Today | Lists today's lessons and times. | No |
| What's On Tomorrow | Lists the next school day's lessons and times. | No |
| When Is a Subject On | Says when a subject is on for the rest of this week. | No |
| Upcoming Birthdays | Says whose birthday is in the next week. | Yes |
| Log a Note | Saves a lesson note for a student. Asks first. Says Saved only after the file is checked. | Yes |
| Add a To-Do | Adds an item to the to-do list. | No |
| Copy Today for a Relief Teacher | Copies today's times, lessons and resources as rich text. | Yes |
| Open the Class Screen | Shows the Class screen for the lesson on now. | No |
| Start the Class Timer | Starts the Class screen timer, 1 to 180 minutes. | No |
| Describe Holocron | Returns the guide to the planner files for an AI assistant. No student information. Unreleased. | No |

## Keyboard shortcuts

| Keys | Action |
|---|---|
| Cmd+1 to Cmd+0 | Today, Week, Term, Units, Devotion, Class screen, Students, Quick log, Mark class, Hours (only screens that are on). Work has no number key. |
| Cmd+comma | Settings |
| Cmd+N | New Student |
| Cmd+L | Log Note |
| Option+Cmd+C | Copy the day (Today) |
| Cmd+P, Shift+Cmd+P | Print the week, save it as a PDF (Week) |
| Shift+Cmd+R | Reload from the folder |
| Shift+Cmd+/ | Holocron Help |
| Cmd+S | Save a lesson or unit sheet |
| Return, Escape | Confirm or close a sheet |
| Cmd+Return | Save dictated notes |
