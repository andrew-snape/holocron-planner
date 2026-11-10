# Holocron: teacher-first plan

Written 10 Nov 2026 against version 1.24.2. This plan looks at Holocron as a Year 6 teacher uses it (IB PYP, Australian Curriculum v9.0, ILPs, NCCD, SIMON, parent emails) and lists what to build next, why, and how.

It sits beside the existing plans and does not replace them:

- [docs/ROADMAP.md](../docs/ROADMAP.md) for tests, HIG items and Apple Intelligence tasks.
- [holocron-liquid-glass-handoff.md](holocron-liquid-glass-handoff.md) for the look (phase 1 is done, phases 2 to 6 are written up step by step).

Sizes: S is under a day, M a few days, L about a week or more.

## Summary

Holocron already covers the planning loop well (Today, Week, Term, Units, lesson plans, Class screen) and the report loop (notes, results, drafts, Copy for SIMON). The gaps, from a teacher's seat, are:

1. **Too many places.** 11 sidebar items in one flat list and 10 tabs on a student. Finding the right spot takes thought.
2. **Right-click and undo are missing.** There is no context menu anywhere, and only Bump can be undone.
3. **The lesson plan has no place for differentiation**, and curriculum codes are typed but never counted.
4. **ILP, NCCD and parent contact are free text.** Nothing reminds you a review is due or shows the evidence in one place.
5. **The class view of results and notes is missing.** You can see one student or one task, not the whole class at a glance.
6. **The look is half way** between the old cards and the macOS 26 style, with 452 fixed font sizes.

The recommended order is in [Release order](#release-order). The decisions that need your call are in [Decisions for Andrew](#decisions-for-andrew).

## Rules every item keeps

These come from `CLAUDE.md` and do not bend.

- Nothing leaves the Mac. Model features stay on device, hide when the model is off, and stay drafts until **Use**.
- Wellbeing, behaviour, medical, adjustments and plan notes never go to the model.
- New student tables live in the student folder (`TableName.isPlanner` returns false). New planner columns hold no student names.
- New tables need a line in `AIGuide.describe`, and changed columns need the recipes in `AIGuide.swift` checked.
- Older files without a new column still load (`row.s("col")` returns "").
- Light mode stays forced. Theme tokens only, no raw colours.
- Each feature gets a `CHANGELOG.md` bullet in the same change.

## Part 1. Simpler to use

### 1.1 Group the sidebar (S)

**Now:** `SidebarView` in `RootView.swift` lists Today, Week, Term, Units, Devotion, Class screen, Students, Work, Quick log, Mark class and Hours in one run.

**Change:** three headed sections in the `List`.

| Section | Screens |
|---|---|
| Plan | Today, Week, Term, Units, Devotion |
| Teach | Class screen, Quick log, Mark class |
| Class | Students, Work, Hours |

**How:** add `var group: NavGroup` to `NavItem` in `AppModel.swift`, and wrap `ForEach(model.visibleNav)` in `Section`s. The Modules order arrows in Settings (1.23) then reorder within a group. Cmd+1 to Cmd+0 stay as they are. Units uses a magnifying glass and Devotion a plus sign, so swap those for `globe.asia.australia` and `book.closed` while there.

### 1.2 Fewer tabs on a student (M)

**Now:** `StudentTab` has 10 chips (Summary, Lesson notes, Interviews, Assessment, ILP and NCCD, Wellbeing, Behaviour, Work, Report, Details). Summary is a plain timeline.

**Change:**

- Merge Lesson notes, Wellbeing and Behaviour into one **Notes** tab with a filter (All, Lesson, Wellbeing, Behaviour) and one add form with a kind picker. The files stay separate (`lessonnotes`, `wellbeing`, `behaviour`), so the report guardrails do not change. `NoteTagger` already suggests the kind.
- Make **Summary** a real overview: flags (adjustments, NCCD, medical), latest result per subject, note counts this term, days since the last note, ILP review date (see 2.4), then the timeline.
- Show a count on each tab chip.

Result: 8 tabs (Summary, Notes, Assessment, Plans, Interviews, Work, Report, Details).

**How:** `StudentsView.swift`. Reuse `LogEntries` and the three existing forms behind a `switch` on kind. Build the overview from `db.index(.assessments)`, `db.timeline(sid)` and the note tables.

### 1.3 Jump to anything, Cmd+K (M)

One box that finds a student, a screen, a unit, or a lesson by its summary, and goes there. Typing "Mat Thu" finds Thursday's Maths. Worked out in code from rows already in memory, with no index written to disk.

**How:** a new `JumpSheet` in `Views/`, a `SheetKind.jump` case, and a Go menu command. Results come from `db.roster`, `NavItem.allCases`, `db.rows(.units)` and `db.rows(.lessons)` (current term first). Student results are hidden while a Class screen window is open, matching the Siri rule.

### 1.4 Right-click menus (M)

HIG item 7, not started. Highest value places:

| Place | Menu |
|---|---|
| Week slot (`SlotCell`) | Edit plan, Change subject, Move, Push, Pull, Copy lesson, Paste lesson, Show on Class screen |
| Today block (`BlockRow`) | Edit plan, Show on Class screen, Copy lesson |
| Student row (`StudentListRow`) | Log note, Open report, Copy pack |
| Note card (`EntryCard`) | Edit, Copy, Copy for SIMON (see 2.6), Delete |
| To-do row | Edit, Set due date, Delete |
| Work tile | Open, Edit details, Show in Finder |

Each menu item calls what the existing buttons call, so no new logic. Copy and Paste lesson is new (see 2.9).

### 1.5 Undo (L)

Already in the roadmap. Do it before any new delete or move feature. Recommended design: `Database` keeps the last 20 changes in memory as (table, rows before), registered with `UndoManager` under plain names ("Undo Delete Note"). Deleting a student snapshots every table that holds their id as one step. Nothing extra is written to disk.

### 1.6 Smaller frictions (S each)

- **Empty states with a button.** `EmptyNote` gets an optional action ("Add a unit", "Import results"). 14 places.
- **Mark class Tab order.** Tab moves down the result column, not across to Comment. Return saves and moves on.
- **Quick log keeps the last subject and kind** for the session.
- **Week: type to plan.** Return in a slot opens the full plan sheet. Arrow keys move between slots.
- **Search on Units and Work** in the toolbar, as Students has.
- **Work gets a number key** once the sidebar is grouped, or Cmd+K covers it.

## Part 2. New things a teacher needs

### 2.1 Differentiation in the lesson plan (S)

**Why:** every plan needs support and extension, and there is nowhere to put them except inside Independent work.

**Change:** two new columns on `lessons` and `lessonsprivate`: `support` and `extension`. Shown in `PlanSheet` under the lesson sequence, in Copy lessons (`DayMarkdown.swift`), and filled by Draft lesson (`LessonDraft.swift`, planner text only, names masked as now).

**How:** add to `header` in `Schema.swift`, to `planFields` and the `Lesson` struct in `Database.swift`, to `PlanSeq`, and to the lesson recipe in `AIGuide.swift`. No student names belong in these fields, because lessons may be shared. Say so in the field hint ("for groups, not named students").

### 2.2 Curriculum coverage (M)

**Why:** the `codes` field takes "AC9M6N05, AC9E6LY06" but nothing shows which Year 6 codes have been taught and which have not.

**Change:**

- A planner table `curriculum.csv`: `code, subject, strand, description`. The description is in your own plain, action-focused wording. Fill it by import or by an AI assistant using the guide. Holocron ships it empty.
- In `PlanSheet`, typing in Curriculum codes suggests matching codes with their description.
- A **Coverage** view on the Term screen: every code for a subject, how many lessons used it, the date last taught, and the ones not yet touched this year.
- Hovering a code chip shows its description.

**How:** new `TableName.curriculum` (planner), a `Database+Curriculum.swift` with `coverage(subject:year:)` that counts `codeList` across `lessons`, and a `CoverageView` reached from the Term toolbar.

### 2.3 Lessons belong to units (M)

**Why:** a unit of inquiry has dates and concepts, but its lessons are not linked, so the unit page cannot show what was taught.

**Change:** a `unit_id` column on `lessons`. The plan sheet has a Unit picker (defaulting to a unit that covers the date). The unit card lists its lessons by week, the codes covered, and a tally of ATL skills and learner profile attributes used, which helps with the PYP reflection.

**How:** `Schema.swift`, `PlanSheet`, `UnitCard` in `TermUnitsDevotion.swift`. `work.csv` already has `unit_id`, so use the same id.

### 2.4 ILP goals and NCCD evidence (L)

**Why:** `plannotes` is a flat list of typed notes, and `students.nccd` is free text. An ILP goal has a life: set, worked on, reviewed. NCCD needs evidence across the four areas and a level.

**Change:**

- New student table `ilpgoals.csv`: `id, student_id, goal, strategies, measure, start, review, status` (Active, Achieved, Changed).
- Plans tab shows goals as cards with the review date. A lesson note can be linked to a goal as evidence (new `goal_id` column on `lessonnotes`, empty for most).
- Today's side panel shows "ILP reviews due" within 14 days.
- NCCD as fixed choices on the student: level (QDTP, Supplementary, Substantial, Extensive) and category (Physical, Cognitive, Sensory, Social and emotional). New columns `nccd_level` and `nccd_category`; the old `nccd` text stays as the note.
- **NCCD evidence pack:** extend `PackSheet` to gather adjustments, plan notes, linked evidence and results for a date range into one document.

**Privacy:** all of it stays in the student folder and out of every model prompt, as plan notes are now. Add `ilpgoals` to the exclusions checked in `CommentDrafter`.

### 2.5 Parent contact log (M)

**Why:** emails, calls and meetings with families are not recorded anywhere, and `parents` holds names only.

**Change:** new student table `contacts.csv`: `id, student_id, date, method, who, summary, follow_up, done`. Method is Email, Phone, Meeting or Note home. Shown inside the Notes tab filter (1.2) and on Summary. An open follow-up appears in the To-do panel on Today. Optionally counts towards Hours as Parent teacher.

**Privacy:** never sent to the model, never spoken by Siri.

### 2.6 Parent email and SIMON wording, without a model (S)

**Why:** you write these often and they follow a pattern.

- **Copy for SIMON** on a wellbeing or behaviour entry: date, time, and the note as written. Plain text on the clipboard.
- **Start an email** from any note: builds a skeleton in code with a greeting that matches the time of day, the facts in order, an open invitation to get in touch and your sign-off. It copies to the clipboard for Outlook. The sign-off name is a setting.

Both are string building in a new `Core/Wording.swift`. No model is involved, so the report guardrails are untouched. A model-drafted email from behaviour notes is listed under decisions, not planned.

### 2.7 Class markbook (M)

**Why:** results can be seen per student or per task. At report time you need the class in one grid.

**Change:** a Markbook view in Mark class: students down, tasks across for one subject, coloured by achievement level through `Tone`. Sortable (HIG item 12, `Table`). Empty cells show who is missing a result. A pre and post pair shows growth. Export to CSV.

**How:** `db.index(.assessments)` grouped by subject and task. Add a small growth chart per student on the Assessment tab with Swift Charts, as `HoursView` already does.

### 2.8 Who have I not written about (S)

A list on Quick log: each student with the days since their last lesson note, and a count per subject this term, least recent first. It makes report evidence even across the class. Counts only, in code.

### 2.9 Reuse lessons (M)

- **Copy and Paste lesson** between slots (Week context menu).
- **Repeat weekly** for routines such as spelling or library: copies the plan to the same slot for the rest of the term, skipping non-teaching days, shown first with Undo, like Bump.
- **Bring forward from last year:** pick a week in a year end archive and copy its planner lessons into this term. Read only from the archive.

**How:** a `Database+Reuse.swift` built on the same slot lookups as `Database+Bump.swift`. Run `code-reviewer` on this one, because it reads from archives.

### 2.10 Groups (M)

**Why:** reading groups, maths groups and inquiry teams come up every day.

**Change:** new student table `groups.csv`: `id, name, subject, student_ids`. Pick a group in Quick log and Mark class to select its students. A group maker (random, or mixed by latest result) builds a set to save.

On the Class screen, groups show names on a projector, so it is off unless you switch it on, and it follows the same rule as Siri names.

### 2.11 Report progress board (S)

One screen for report season: a row per student with judgements entered per subject, general comment and dot points (none, draft, used), word count against the 100 to 150 rule, and a Copy for SIMON button. Built from `reportjudge` and `reportcomment`. Sits beside Draft for the class.

### 2.12 Paper for others (M)

- **Relief teacher day** as a one page A4 PDF (roadmap item): times, lessons, resources, duties, no student names. Extends `PrintWeek.swift` and Copy lessons.
- **Print a rubric** as an A4 sheet from `rubrics.csv`, one per student or blank.
- **Print a lesson plan** with learning intention, success criteria, sequence, support and extension.

### 2.13 Events and duties (S)

A planner table `events.csv` (`date, start, end, title, kind`) for assemblies, yard duty, staff meetings and incursions. Shown on Today between blocks, in the Week grid header, on Print week and in What's On Today. Yard duty can add its minutes to Hours.

### 2.14 Rosenshine prompts (S)

No new data. The four lesson steps get small hints in `PlanSheet`, switched on in Settings: Tuning in (daily review), Explicit teaching (small steps, models, check for understanding), Independent work (guided then independent practice), Reflection (review). Draft lesson is told the same structure.

## Part 3. Looks

### 3.1 Finish the Liquid Glass phases (M to L)

Follow the handoff as written: toolbar and titles, content surfaces, sheets, toast and Class screen bar, sidebar and Settings. Run `ui-design-check` after each.

### 3.2 A type scale (M)

452 `.font(.system(size:))` calls. Add `Font.body1`, `caption1`, `label` and `metric` to `Theme.swift` beside `hPage`, `hSheet` and `hSection`, then replace per file. No visible change is the test, as it was for phase 1 tokens.

### 3.3 Today as the home screen (M)

- A **Now card** at the top: current lesson in its subject colour, a thin progress line through the period, what is next, and one button to the Class screen.
- Past blocks fade back, so the eye lands on now.
- The side panel becomes Due today, ILP reviews (2.4), follow-ups (2.5), birthdays, events (2.13).
- The quote moves to the bottom of the side panel.

### 3.4 Subject colours (S)

A set of 12 tested colours in the subject editor (each readable with dark text under the `veil` token) in place of free hex. Keeps the Week grid and Print week even.

### 3.5 Week grid polish (S)

Today's column gets a soft tint, as Term has for this week. Slots with a full plan show a small filled dot, and a summary only shows a hollow one. A drag shows the swap target clearly.

### 3.6 Class screen for Year 6 eyes (S)

Larger minimum type, a calm colour per work mode, and a clear timer end state (colour change, optional sound). Check from the back of the room at projector size.

## Part 4. Foundations to do first

From the roadmap, and needed before new columns land.

| Item | Why now | Size |
|---|---|---|
| Schema version in `settings.csv` | Parts 2.1 to 2.5 add columns and tables. A version makes later changes safe, with a copy to `Holocron archive` first. | M |
| Tests for `Holocron/Core` | New reuse and coverage logic moves real lessons. | M |
| File change guard | More tables means more chances of a hand edit clashing with a save. | M |
| Undo (1.5) | Before Paste lesson and Repeat weekly. | L |
| Update `docs/FEATURES.md` and `ROADMAP.md` | Both stop before 1.20 to 1.24 (Work, Classroom, Done ticks, spell check). | S |

## Release order

Each release is small enough to test in a school week.

| Release | Theme | Items |
|---|---|---|
| 1.25 | Easier to get around | 1.1 sidebar groups, 1.4 context menus, 1.6 frictions, docs catch-up |
| 1.26 | Safer | Schema version, first Core tests, 1.5 undo |
| 1.27 | Better plans | 2.1 differentiation, 2.14 Rosenshine prompts, 2.9 copy, paste and repeat, 2.13 events |
| 1.28 | Curriculum and units | 2.2 coverage, 2.3 lessons in units |
| 1.29 | Student record | 1.2 tabs and overview, 2.5 contact log, 2.6 SIMON and email wording, 2.8 note gaps |
| 1.30 | ILP and NCCD | 2.4 goals, levels, evidence pack |
| 1.31 | Results and reports | 2.7 markbook, 2.11 report board, 2.10 groups |
| 1.32 | Look | 3.1 glass phases, 3.2 type scale, 3.3 Today, 3.4 to 3.6 |
| Later | | 1.3 Cmd+K if not pulled forward, 2.12 printing, roadmap AI items T1 to T7 |

The look could run in parallel, one phase per release, if you would rather see it sooner.

## Decisions for Andrew

| # | Question | My suggestion |
|---|---|---|
| 1 | Sidebar groups: is Plan, Teach, Class the right split? | Yes. Try it for a week before renaming. |
| 2 | Merge the three note tabs into one Notes tab? | Yes, with the filter. The files stay separate. |
| 3 | Should differentiation fields allow student names? | No. Lessons can be shared. Named adjustments belong on the student. |
| 4 | Who fills `curriculum.csv`? | You, once, with an AI assistant and the guide. Not bundled in the app. |
| 5 | Groups on the projector? | Off by default, behind a switch. |
| 6 | A model-drafted parent email from a note? | Not now. It would send behaviour or wellbeing text to the model, which the guardrails rule out. The code-built skeleton (2.6) covers most of the typing. |
| 7 | Contact log minutes in Hours? | Optional tick per entry. |
| 8 | Look first or functions first? | Functions first, look in parallel when a release is light. |
