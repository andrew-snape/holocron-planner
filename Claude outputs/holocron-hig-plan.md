# Holocron: what to take from the Apple HIG

Holocron is a macOS SwiftUI app (NavigationSplitView sidebar, Settings scene, Help window, sheets, Week print, drag and drop in WeekView). It already follows much of the HIG: Cmd+, settings, a Go menu with Cmd+1..0, print/PDF shortcuts, tooltips (18 `.help`), collapsing the sidebar at narrow widths, drag and drop with `draggable`/`dropDestination`.

## Deliberate departures (leave alone unless you decide otherwise)

- **Light mode forced** (`HolocronApp.swift`). HIG (Dark Mode) says do not offer app-specific appearance and support both. You chose this on purpose, so it is parked as an optional item at the end.
- Custom card styling and hard-coded colours in `Theme.swift`. The HIG prefers system colours, but the house look is intentional.

## Usable findings, ranked

### P1: cheap, high value

1. **Sheet buttons: Cancel / Done pairing and Return/Escape.** HIG: always pair Done with Cancel, primary button responds to Return, Escape cancels. Only 11 `defaultAction`/`cancelAction` uses and several sheets in `Views/Sheets.swift` have lone "Done" or "Close". Audit every sheet, add `.keyboardShortcut(.defaultAction)` / `.cancelAction`, put Cancel on the leading side and the primary on the trailing side.
2. **Destructive actions and alerts.** Only one `role: .destructive` and one `confirmationDialog` in the whole app. HIG: confirm uncommon, irreversible actions (Start Over, year-end archive, import, delete student/unit/plan), use the destructive role, include Cancel, never make the destructive button the default, use specific titles (Erase, Archive), not OK/Yes/No. Audit `StartOver*`, `YearEnd*`, `ImportPlan`, deletes in `StudentsView`/`TermUnitsDevotion`.
3. **Menu bar completeness.** HIG: every command reachable from the menu bar, disable rather than hide, "..." on commands needing more input, toggle titles that reflect state. Add Edit > Undo/Redo wording, View > Show/Hide Sidebar (system one exists, verify), Cmd+N for new student/plan/quick log (HIG project note suggests Cmd+N and Cmd+F), Window menu items (Class screen, Help). `CommandGroup(replacing: .newItem) {}` currently removes New, so add real New items.
4. **Accessibility labels.** Only 10 `accessibility` uses across 11k lines. Icon-only buttons (toolbar gear, sheet close, Week slot controls) need labels; Tone colours need a non-colour cue (text/shape) per "do not rely on colour alone". Check contrast of `ink2` (0.43 grey on 0.949) against 4.5:1.
5. **Empty states.** Zero `ContentUnavailableView`. Add one per module (no students, no units, empty Today) with the reason and the next action.

### P2: worthwhile

6. **Search.** No `.searchable`. Students and Units are lists; HIG says search field on the toolbar trailing side, filter as you type, placeholder says what is searched. Add Cmd+F focus.
7. **Context menus.** Zero `contextMenu`. Add right-click on student rows, Week slots, unit rows with the 3-5 most likely actions (Plan, Change, Move, Swap, Delete last, destructive marked). Same actions must exist elsewhere (they do via sheets).
8. **Undo/redo.** No UndoManager. Highest-risk edits are CSV-backed deletes and bumps. Register undo for delete, move, swap, bump with named actions ("Undo Swap Lessons"). Larger task, needs a design pass because state lives in CSV files.
9. **Hours chart** (HIG note already in `components-e`). Add Swift Charts bar chart to `HoursView`: zero baseline, consistent colour per DOTTL type plus label/pattern, accessibility labels with real values ("Term 2, 14 hours"), Audio Graph title/summary, readable at 520 pt width. Keep the existing table.
10. **Toolbar hygiene.** Window title should be the current module, not the app name; keep to one prominent action; a View > Customize Toolbar is optional.
11. **Settings window.** Matches HIG (Cmd+, tabs). Add: restore last tab (already stores `settingsTab`), window title follows pane, dim minimise/zoom.
12. **Tables.** Use `Table` with sortable, resizable columns for Students if the list grows (HIG macOS: click heading to sort, resize columns). Evaluate before committing.

### P3: polish

13. Tooltips: audit the 18 against HIG (start with a verb, no control name, 60-75 chars).
14. Button hit regions: 28x28 pt minimum on macOS, 44 pt if iPad ever happens. Check small icon buttons.
15. Progress indicators for Import / Year-end archive / update download: determinate where measurable, Cancel available, no vague "Loading".
16. Copy pass using HIG writing rules: menu labels in title case, no articles, sentence case alert titles, `...` consistency (the code mixes `...` and the HIG ellipsis).
17. Dynamic Type equivalent: 306 fixed `.font(.system(size:))` calls. macOS has no Dynamic Type, so low priority, but prefer semantic styles in new code.
18. Dark Mode (optional, only if you reverse the light-only choice): needs semantic colours in `Theme.swift` and a pass over Tone colours.

### Not relevant

visionOS, watchOS, tvOS, iOS-only guidance, App icons beyond the existing icon, Privacy permissions (no permissions requested), Branding.

## Suggested sequencing

| Step | Items | Size | Notes |
|---|---|---|---|
| 1 | 1, 2 | S-M | One branch, run `code-reviewer` (touches destructive/data paths) |
| 2 | 3, 5, 10 | M | Menu and window structure |
| 3 | 4, 14 | M | Run `ui-design-check` agent after |
| 4 | 6, 7 | M | Search and context menus |
| 5 | 9 | M | Charts, self-contained |
| 6 | 8 | L | Undo needs design first |
| 7 | 13, 15, 16, 12 | S each | Opportunistic |

Each step: build, run the existing tests, `ui-design-check` for any Views change, `code-reviewer` before commit. Current branch is `year-end-archive-import`; start HIG work on a fresh branch from `main` once that merges.

## Open decisions for you

- Keep light-only? (Plan assumes yes.)
- Is iPad a real future target? (Raises priority of 14 and menu-hidden fallbacks.)
- Undo (item 8): worth the effort, or rely on the existing archive/reload-from-folder safety net?
