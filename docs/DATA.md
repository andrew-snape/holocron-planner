# Data model

Developer reference for the CSV files. The source of truth for the columns is `TableName.header` in [Schema.swift](../Holocron/Core/Schema.swift). If this page and the code disagree, the code is right.

For an AI assistant that has to edit a teacher's live files, the operational source of truth is `README-for-AI.md`, which Holocron writes into each data folder ([Core/AIGuide.swift](../Holocron/Core/AIGuide.swift)). It carries the before-you-edit checklist, value rules and step-by-step recipes for the folder as it is set up today. This page is for people changing the app.

## Folders

| Folder | What is in it | Shared? |
|---|---|---|
| Student folder (default `iCloud Drive/Holocron/data`) | Every non-planner table, `settings.csv`, `photos/`, and any private planner tables | No |
| Planner folder | The 12 planner tables | Can be a folder shared with colleagues. When none is chosen, planner files sit in the student folder. |

`DataFolder.root(for:)` routes a table: planner tables go to the planner folder unless they are private; everything else goes to the student folder. Folders are chosen in Settings, then Folders.

- **Planner tables** (`TableName.isPlanner`): `subjects periods timetable dayplan lessons rubrics terms nonteaching dayoverrides devotion quotes units`.
- **Private lessons:** subjects marked private keep their lessons in `lessonsprivate.csv` in the student folder. Same columns as `lessons.csv`. In memory the two merge into one table. Each file keeps the other's rows untouched.
- **Private Devotion:** with Keep Devotion scripts and quotes private on, `devotion.csv` and `quotes.csv` live in the student folder.
- A shared planner folder is edited by colleagues too. Never put student information in a planner table.

## Formats

| Thing | Format |
|---|---|
| File | UTF-8 (Latin-1 is accepted when reading), heading row, comma separated. Cells with a comma, quote or line break are in double quotes with quotes doubled. Rows with every cell empty are dropped. Header names are trimmed. Extra columns are kept and written back. |
| Date | `yyyy-MM-dd` text (`2026-10-14`). Compared as text, so sorting works. Parsed by `Cal.parts` in [Dates.swift](../Holocron/Core/Dates.swift). Only the first 10 characters matter. |
| Time | 24 hour `HH:mm` (`13:45`). `H:mm` is also read. |
| Week | `A` or `B`. Week 1 of every term is A (see [ARCHITECTURE.md](ARCHITECTURE.md)). |
| Day | `0` Monday to `4` Friday, in `timetable.csv` only. |
| Period | Whole number matching `period` in `periods.csv`. The starter folder numbers them 1 to 7 with period 1 as morning circle. Look them up, do not assume. |
| Id | Text from `uid()`: the time in milliseconds in base 36 plus four random characters (`lq3k9x2a7b1c`). Unique, no spaces, never changed. |
| Semester | `yyyy-S1` or `yyyy-S2` (`2026-S2`). Semester 2 starts in July (`Database.semesterTwoStartMonth`). |
| Lists in a cell | Comma separated (`Thinking, Research`). Lines of inquiry and report dot points are one per line. |
| Booleans | None. `students.ilp` is `yes` or empty. `todo.done` is the date ticked off, or empty. |
| Minutes | Whole number. |

## Tables

### Planner tables

| File | Columns | Meaning |
|---|---|---|
| `subjects.csv` | `subject`, `kind`, `colour` | One row per subject. `kind` is `teach`, `release` (specialist, counts as release time) or `dottl`. `colour` is a hex code such as `#34C759`. The name is the key used by timetable, lessons, notes and results, so a rename must change every table (`Database.renameSubject`). |
| `periods.csv` | `period`, `name`, `start`, `end` | Bell times. `period` is the number, `start` and `end` are `HH:mm`. |
| `timetable.csv` | `week`, `day`, `period`, `subject` | The A/B template. Key is week, day, period. |
| `dayplan.csv` | `date`, `period`, `subject` | A one-off change. A row replaces the template for that date and period. A row equal to the template is deleted. |
| `lessons.csv` | `date`, `period`, `subject`, `summary`, `li`, `sc`, `tuning`, `teaching`, `independent`, `reflection`, `resources`, `codes`, `atl`, `profile` | A lesson for a date and period. `summary` is a sentence or link. `li` is the learning intention, `sc` the success criteria. `tuning`, `teaching`, `independent` and `reflection` are the lesson sequence. `resources` holds links. `codes` are curriculum codes split on commas or spaces. `atl` and `profile` are comma lists from `PYP.atlSkills` and `PYP.profile`. A lesson with every field empty has no row. |
| `rubrics.csv` | `rubric`, `element`, `order`, `level`, `descriptor` | Rubric descriptors shown when marking. `level` is one of `Lists.rubricLevels`. `order` sorts elements. |
| `terms.csv` | `year`, `term`, `start`, `end` | Term dates. Weeks, A/B letters and the school year come from these. |
| `nonteaching.csv` | `date`, `label` | A whole day off. One row per date. |
| `dayoverrides.csv` | `date`, `type`, `note` | A day that does not run as normal. `type` is one of `Lists.dayTypes`. |
| `devotion.csv` | `date`, `theme`, `scripture`, `time`, `domain`, `profile`, `focus`, `greeting`, `values`, `reading`, `message`, `questions`, `prayer`, `primer_name`, `primer`, `primer_note`, `went_well`, `transition` | One devotion or Circle Time script per date. Easiest to edit in the app. |
| `quotes.csv` | `date`, `quote`, `artist`, `band`, `source` | Quotes for the Today card. `date` is used as the key for the quote on show. |
| `units.csv` | `id`, `title`, `theme`, `central_idea`, `lines`, `concepts`, `related`, `atl`, `profile`, `start`, `end`, `notes`, `reflection` | A unit of inquiry. `theme` is one of `PYP.themes`. `lines` is one line per line of inquiry. `concepts` come from `PYP.keyConcepts`. `start` and `end` are dates (may be empty). |

### Student tables (private)

| File | Columns | Meaning |
|---|---|---|
| `students.csv` | `id`, `first`, `surname`, `birthdate`, `parents`, `house`, `roles`, `adjustments`, `nccd`, `medical`, `notes`, `preferred`, `ilp` | One row per student. `birthdate` is a date. `house` is a name such as those in `Lists.houseColours`. `preferred` is the name used at school when different. `ilp` is `yes` or empty. Photos are `photos/<id>.jpg`. |
| `taskdone.csv` | `id`, `student_id`, `date`, `subject`, `task` | A student has finished a task. Ticked as Done in Mark class. Keyed like `assessments.csv`, but it holds no result, so it never counts as a mark. Private, in the student folder. |
| `assessments.csv` | `id`, `student_id`, `date`, `subject`, `task`, `result`, `comment` | A result. `result` is a score such as `18/20`, a percentage such as `72%`, or one of `Lists.achievement`. Imports add an imported part to `comment` after ` · `. |
| `plannotes.csv` | `id`, `student_id`, `date`, `type`, `note` | Plan notes. `type` is one of `Lists.planNoteTypes`. |
| `wellbeing.csv` | `id`, `student_id`, `date`, `period_lost`, `minutes`, `note` | A wellbeing entry. `period_lost` is a period number or empty. `minutes` counts as DOTTL time of type Wellbeing. |
| `behaviour.csv` | `id`, `student_id`, `date`, `note` | A behaviour entry. |
| `lessonnotes.csv` | `id`, `student_id`, `date`, `time`, `subject`, `note` | A note made in a lesson. `time` is `HH:mm`. `subject` may be empty. |
| `reportjudge.csv` | `id`, `student_id`, `sem`, `subject`, `achievement`, `engagement` | A report rating per student, semester and subject. `achievement` is one of `Lists.achievement`, `engagement` one of `Lists.engagement`. |
| `reportcomment.csv` | `id`, `student_id`, `sem`, `general`, `english`, `maths`, `context` | One row per student and semester. `english` and `maths` are dot points, one per line starting with `- `. `context` is the teacher's notes for drafting. |
| `strandcomments.csv` | `id`, `student_id`, `sem`, `strand`, `substrand`, `success`, `growth`, `improve`, `imported` | Essential Assessment report comments by strand. One row per student, semester, strand and substrand. `imported` is the import date. |
| `interviews.csv` | `id`, `student_id`, `date`, `time`, `minutes`, `audio`, `transcript`, `summary`, `not_private` | An interview recorded for a student. `audio` is the file name in `recordings/` in the student folder. `not_private` is `yes` only when the teacher marked it not private, which allows a summary. Private. |
| `work.csv` | `id`, `student_id`, `date`, `period`, `subject`, `unit_id`, `task`, `caption`, `file`, `assessment_id`, `batch`, `sha`, `added` | Photos or scans of students' work. One row per student. See the Work section. Private. |
| `classsteps.csv` | `date`, `period`, `first`, `then`, `next` | Class screen steps for one lesson. A lesson with no steps has no row. |
| `dottl.csv` | `id`, `date`, `type`, `minutes`, `note` | Hours log. `type` is one of `Lists.dottlTypes`. |
| `todo.csv` | `id`, `text`, `due`, `done`, `created` | To-do items. `due` may be empty. `done` is the date ticked off. `created` is a date. |
| `lessonsprivate.csv` | same as `lessons.csv` | Lessons for private subjects. Only exists once a subject is made private. |
| `settings.csv` | `key`, `value` | Holocron's own settings. The first row for a key wins. Edit in the app. |

### Settings keys (`settings.csv`)

| Key | Value |
|---|---|
| `class_name` | Shown in the sidebar and on exports. Default `6AS`. |
| `module_<screen>` | `off` hides a screen. Missing means on. Screens: `week term units devotion classScreen students work quick assess hours`. |
| `private_subject_<name>` | `on` keeps that subject's lessons in `lessonsprivate.csv`. |
| `private_devotion` | `on` keeps Devotion and quotes in the student folder. |
| `ai_dictation`, `ai_drafts`, `ai_columns`, `ai_lessonDraft`, `ai_noteTags` | `off` switches the feature off. |
| `siri_names` | `on` lets Siri say student names. Off by default. |
| `sidebar_order` | Screen names in sidebar order, separated by commas (for example `today,week,classScreen`). Missing or empty means the standard order. Edit in Settings, under Modules. |
| `report_rules`, `ilp_sentence` | The teacher's report rules (up to 1200 characters) and the ILP sentence. |
| `pronoun_<student id>` | `she`, `he` or `they`, for drafting. |
| `import_ref:<file student id>` | A student id picked by hand in a results import. |

## Relationships

- `student_id` in `assessments`, `plannotes`, `wellbeing`, `behaviour`, `lessonnotes`, `reportjudge`, `reportcomment`, `strandcomments`, `interviews` refers to `students.id`. `removeStudent` deletes those rows with the student (its recordings are left in `recordings/`). There is no foreign key check when files are edited by hand.
- `subject` in `timetable`, `dayplan`, `lessons`, `lessonsprivate`, `lessonnotes`, `assessments`, `reportjudge` refers to `subjects.subject` by name.
- `period` in `timetable`, `dayplan`, `lessons`, `classsteps`, `wellbeing.period_lost` refers to `periods.period`.
- A lesson, one-off change and Class screen step are all found by (`date`, `period`).
- `lessons.atl` and `profile`, and `units.atl` and `profile`, use the lists in `PYP`.
- `units.start` to `units.end` decide which unit is on for a date (`unitOn`).
- `rubrics.rubric` names a rubric. Mark class picks one, and `element` becomes the task.

## Fixed lists ([Schema.swift](../Holocron/Core/Schema.swift))

| List | Values |
|---|---|
| `Lists.achievement` | Extending, Mastering, Consolidating, Developing, Emerging, Modified, Not assessed |
| `Lists.engagement` | Comprehensive, Appropriate, Inconsistent, Minimal |
| `Lists.rubricLevels` | Working Towards, At Standard, Working Beyond |
| `Lists.dayTypes` | Normal, Camp, Sports carnival, Excursion, Pupil free day, Other |
| `Lists.dottlTypes` | Meeting, Parent teacher, Professional development, Camp, Yard duty, Wellbeing, Behaviour, Planning, Other |
| `Lists.planNoteTypes` | ILP goal, ILP review, SSG meeting, NCCD adjustment, NCCD evidence |
| `Lists.noBump` | Circle Time, Devotion (never pushed or pulled) |
| `Lists.houseColours` | Deakin, Barton, Parkes, Higgins, with hex colours |
| `PYP.themes` | Who we are; Where we are in place and time; How we express ourselves; How the world works; How we organise ourselves; Sharing the planet (each with a hex colour) |
| `PYP.keyConcepts` | Form, Function, Causation, Change, Connection, Perspective, Responsibility |
| `PYP.atlSkills` | Thinking, Research, Communication, Social, Self-management |
| `PYP.profile` | Inquirers, Knowledgeable, Thinkers, Communicators, Principled, Open-minded, Caring, Risk-takers, Balanced, Reflective |

Changing a list changes what the app offers. Existing rows with other values are kept and shown, not rewritten.

## Archive folders

Created next to the student folder in `Holocron archive`. Nothing in them is read by the app. Names use a stamp like `2026-10-14 15.32`, and a number is added if the name is taken.

| Folder | Made by | Holds |
|---|---|---|
| `<year> year end` | Archive this year | A copy of the data folder, checked file by file, with a `README.txt` |
| `Before import <stamp>` | Import from folder | The files that import replaced |
| `Before results import <stamp>` | Results import | `assessments.csv` as it was |
| `Start over <stamp>` | Start over | The files (and photos, if everything) moved out |

## Safe hand-editing

- Edit in Numbers or a text editor. Keep the header row exactly as it is. Do not rename or reorder columns.
- Keep ids unique and unchanged.
- Quit Holocron first, or save and reload straight after. Holocron saves a file whenever something changes, so a long edit while the app is open can be overwritten by the app's copy.
- After editing, press Shift+Cmd+R in Holocron. Only files that changed on disk are re-read. A file that cannot be read is flagged and never overwritten.
- Keep a copy of the folder first, or use Archive this year.
- Numbers may change dates (`2026-10-14` becomes a date cell) or drop leading zeros on times. Export as CSV and check the date and time columns.

## Work

Photos and scans of students' work, in `work.csv` (student folder, private, never shared).

- One row for each student a piece of work belongs to. A group photo is stored once and every student's row points to the same `file`, with the same `batch` id.
- `file` is `<row id>.<original extension>`, for example `mh2k4x9a1b3c.jpg`. The image is in `work/<year>/`, where the year is the year of `added`. The file is copied byte for byte. Holocron does not resize, re-encode, rotate or strip the metadata, so the copy has the same SHA256 as the original.
- `sha` is the SHA256 of the original. A student who already has a row with the same `sha` is not given the file again.
- `period`, `subject`, `unit_id` and `date` describe the lesson, unit and day. `assessment_id` links one result from `assessments.csv`, used when one student is chosen.
- `caption` may be used in report drafts. Only the words are used, never the picture. Captions with a private word are left out, as lesson notes are.
- Allowed types: JPEG, PNG, HEIC, TIFF and PDF. The extension and the first bytes of the file must both match.
- Remove moves the image to `work/removed/` and removes the row. A file shared with another student is not moved while their row still uses it.
- Removing a student keeps their work files and leaves their rows, which then show under Unlinked.
- Start over (everything) moves `work/` into the archive. A year end archive copies it, and Import copies it with the students.

Files in `work/` are ignored by git.

## Photos

`photos/<student id>.jpg` in the student folder only. Saved as JPEG, at most 480 pixels on the long side, white background. Never in the planner folder. `photos/` is ignored by git.
