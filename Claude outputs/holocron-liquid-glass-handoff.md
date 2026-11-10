# Holocron Liquid Glass: handoff for phases 2 to 6

Step-by-step instructions for whoever picks up the Liquid Glass work. Read this alongside [holocron-liquid-glass-plan.md](holocron-liquid-glass-plan.md), which has the reasons, the HIG guidance and the API list. This file has the exact files, line areas, code shapes, checks and known traps.

Line numbers are from commit `b4596c0` (8 Nov 2026) and will drift. Search for the quoted code rather than trusting the number.

## 1. Where things stand

- **Branch:** `claude/peaceful-goodall-61mcek`. Draft PR [andrew-snape/holocron-planner#11](https://github.com/andrew-snape/holocron-planner/pull/11).
- **Phase 1 is done** and passed the CI build. The tokens are in `Holocron/Views/Theme.swift`:
  - Colours: `fieldBG`, `fieldStroke`, `rule`, `fillFaint`, `fill`, `fillStrong`, `onAccent`, plus the older `appBG`, `cardBG`, `ink2`, `ink3`, `hairline`, `appBlue`, `appGreen`, `appAmber`, `appRed`, `weekB`, `weekBBG`.
  - `enum Radius` (`tiny` 6, `block` 7, `field` 8, `inset` 10, `panel` 12, `card` 14, `large` 16, `boardTile` 18, `board` 22), `enum Space` (`page` 24, `card` 14, `gap` 12), `Font.hPage`, `Font.hSheet`, `Font.hSection`.
- **Not yet checked on a real Mac.** The teacher should open every screen once and confirm phase 1 looks the same before phase 2 starts.
- **Teacher's decisions** (do not reopen them):
  1. One new house look. No accent colour picker (phase 7 is dropped).
  2. Plain white pages, confirmed with before and after screenshots in phase 3.
  3. Screen titles move to the window toolbar. The big in-page titles go.
  4. The Class screen controls become an auto-hiding glass bar.
  5. Light mode only stays. No dark mode.
  6. Sidebar icons are coloured per module.

## 2. Ground rules for every phase

- **One phase per PR.** Ask the teacher before starting each phase. Each phase is a visible change.
- **The working environment has no Swift compiler** (Linux container). The only build check is CI (`.github/workflows/build.yml`, job "Build Holocron", about 2 minutes). Push, wait for the check, fix and push again. Never claim a phase looks right: say it builds, and list what the teacher should check by eye.
- **Do not touch `Holocron/Core`** or any file reading, writing or archiving code. None of the phases need it. If you find yourself in `Core`, stop and run the `code-reviewer` agent.
- **Run the `ui-design-check` agent** after each phase (required by CLAUDE.md for any change in `Holocron/Views`). Fix real findings. Treat its "nice to have" items as optional.
- **Add one `## Unreleased` bullet to `Holocron/CHANGELOG.md`** per visible phase, in the teacher's voice: short sentences, full stops, no jargon. Example: "Screen titles and buttons now sit in the window toolbar, in the new macOS style."
- **Australian English**, no em dashes, no emoji, in code comments, UI text and docs.
- **Keep light mode forced.** Do not remove `NSApplication.shared.appearance = .aqua` or `.preferredColorScheme(.light)`.
- **Leave `PrintWeek.swift` alone.** It renders for paper, not the screen.
- **Commit attribution and PR rules** are in the session system prompt. Draft PRs only. Never merge.
- **Search for the API before using it.** All glass APIs below are macOS 26 SwiftUI. The deployment target is macOS 26.0, so they need no `#available` check. Anything that exists only in the macOS 27 SDK must be wrapped in `if #available(macOS 27, *)`, or the CI build on Xcode 26 fails (see `docs/PROBLEMS.md`, the `LanguageModelError` entry).

## 3. Phase 2: toolbar, titles and accent colour (M)

Goal: each screen's title and control row moves from the top of the scroll view into the window toolbar. This is the biggest visible change.

### 3.1 How the toolbar works here

- `RootView` (`Holocron/Views/RootView.swift`) owns the `NavigationSplitView`. The detail column already sets `.navigationTitle(model.nav.title)` and adds one `ToolbarItem(placement: .primaryAction) { SettingsButton() }`.
- A `.toolbar { }` placed on a screen view (for example inside `WeekView.body`) **merges** with the root toolbar while that screen is shown. Put each screen's items on that screen's own view, not in `RootView`, so they come and go with the screen.
- macOS placements to use:
  - `.navigation`: leading, just after the title. Use it for previous, today and next.
  - `.primaryAction`: trailing. Use it for the main action and menus.
  - Avoid `.principal`. It centres items and clashes with the title on macOS 26.
- Use `ToolbarItemGroup(placement:)` to group related buttons into one glass capsule. Use `ToolbarSpacer(.fixed)` to split groups and `ToolbarSpacer(.flexible)` to push items apart.
- The title comes from `.navigationTitle`, and the second line from `.navigationSubtitle` (macOS only). Set both on the screen view. The screen's title overrides the root title.

### 3.2 Screen by screen

For each screen: remove the in-page title block and the control row, and add a `.toolbar` plus `.navigationTitle` and `.navigationSubtitle`. Keep every `.help(...)` tooltip and `accessibilityLabel` when you move a button.

| Screen | File and current code | Title / subtitle | Toolbar items |
|---|---|---|---|
| Today | `TodayView.swift`, `header(_:)` (about line 30) and `dayBar(_:)` (about line 50) | Title: "Today", or the weekday, or "Weekend" (the existing `title`). Subtitle: the existing `sub` string (long date, week letter, term and week). | `.navigation` group: Yesterday (chevron.left), Today, Tomorrow (chevron.right), then the compact `DatePicker`. `.primaryAction`: Copy lessons, Class screen, Set day type. Use icons with labels: `Label("Copy lessons", systemImage: "doc.on.doc")`, `Label("Class screen", systemImage: "tv")`, `Label("Set day type", systemImage: "calendar.badge.clock")`. |
| Week | `WeekView.swift`, the first two `HStack`s in `body` (about lines 20 to 49) | Title: the `lead` string ("Term 4 Week 5" or "Outside term"). Subtitle: "10 Nov to 14 Nov · Week B" from `shortDate(mon)` and `wk`. | `.navigation` group: Last Week, This Week, Next Week. `.primaryAction`: the subject filter `Picker` (keep `.frame(width: 160)`), then the Print `Menu`. |
| Term | `TermUnitsDevotion.swift`, `TermView` (about lines 98 to 130). It uses `PageHeader("Term")` for the empty state and a 28 pt "Term N" heading. | Title: "Term 4". Subtitle: the year and dates if shown nearby. | `.navigation`: Previous term, Next term (keep the `.disabled` rules). `.primaryAction`: the subject `Picker`. |
| Units | `TermUnitsDevotion.swift`, `UnitsView` (about line 329) | "Units of inquiry" | `.primaryAction`: New unit (`.buttonStyle(.borderedProminent)` becomes the default toolbar look, see 3.4). |
| Devotion | `TermUnitsDevotion.swift`, `DevotionView` (about lines 574 to 600) | "Devotion". Subtitle: the selected date. | `.navigation`: Previous, Today, Next (keep `.disabled`). `.primaryAction`: the date `Picker`. |
| Students | `StudentsView.swift`. The list header row in `wide` (about line 55) has "Students", a count and a + button. | "Students". Subtitle: "26 students" from `roster.count`. | `.primaryAction`: Add student (`Label("Add student", systemImage: "plus")`). Search is already in the toolbar (`StudentSearch`, `.searchable(placement: .toolbar)`). Keep it. Remove the + from the list header but keep the header's count only if it still reads well. The compact layout (about line 97) has its own + button. Leave that one in place, because compact is used when the window is narrow. |
| Quick log | `QuickLogView` (find with `grep -rn "struct QuickLogView"`) | "Quick log" | Whatever its top row holds. |
| Mark class | `MarkClassView.swift` (about line 28) | "Mark class" | `.primaryAction`: Import results… (keep the `Label` and icon). |
| Hours | `HoursView.swift` (about line 42) | "Hours" | None needed unless the top row has buttons. |
| Class screen module | `ClassScreen.swift`, `ClassScreenModule` (about line 112, `PageHeader("Class screen")`) | "Class screen" | None. The embedded `ClassScreenView` keeps its own top bar until phase 5. |

After this, `PageHeader` may be unused. Check with `grep -rn "PageHeader(" Holocron/Views`. If it is still used in empty states, keep it. Do not delete it in this phase.

### 3.3 Menu bar commands (HIG: every toolbar item is also in the menu bar)

Add to `HolocronApp.swift`, inside the existing `CommandMenu("Go")` after the module list, with a `Divider()`:

- **Previous** (Cmd+[) and **Next** (Cmd+]). They act on the current screen: Today steps a day (`model.cursor`), Week steps a week (`model.weekMonday`), Term steps a term (`model.termKey`), Devotion steps a devotion (`model.devotionDate`). Disable them on other screens. Name them by screen when you can ("Previous Week", "Next Week"), because the HIG wants titles that say what they do.
- **Go to Today** (Cmd+T): sets `model.cursor = todayISO()` and `model.weekMonday = nil`, and goes to Today. Holocron has no Font panel, so Cmd+T is free. Confirm with `grep -rn 'keyboardShortcut("t"' Holocron` first.

Put the stepping logic in `AppModel` (a `func step(_ by: Int)`) so the toolbar buttons and the menu call the same code. This adds no file reading or writing.

### 3.4 Buttons in the toolbar

- Toolbar buttons get glass automatically. Do not add `.buttonStyle(.glass)` to them.
- Give at most **one** item per screen the prominent look: `.buttonStyle(.glassProminent)` or `.borderedProminent`. Units' New unit is a good candidate. Week and Today have none.
- Use `Label(title, systemImage:)` for toolbar buttons. macOS shows the icon in the toolbar and the title in the overflow menu and in Customize Toolbar.
- The Settings gear (`SettingsButton` in `RootView`) stays trailing on its own. If it merges into a screen's group, add `ToolbarSpacer(.fixed)` before it, or `.sharedBackgroundVisibility(.hidden)` on its `ToolbarItem`.

### 3.5 Accent colour

`Holocron/Assets.xcassets/AccentColor.colorset/Contents.json` is set to system blue (0.000, 0.478, 1.000). `Color.appBlue` is (0.000, 0.443, 0.890). The project already uses `AccentColor` (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`). Set the colour set to the `appBlue` values so system controls, sidebar selection and toolbar tint match the app's own blue. A one-file change. Mention it in the PR, because it changes every prominent button slightly.

### 3.6 Phase 2 traps and fixes

| Problem | Why | Fix |
|---|---|---|
| Toolbar items from the last screen stay after switching screens | The `.toolbar` was attached to a view that does not change with `model.nav`, such as `DetailRouter` | Attach `.toolbar` inside each screen's `body`. |
| Items appear twice | Both `RootView` and the screen add the same item | Only `RootView` adds the gear. Screens add their own items only. |
| Items vanish into a `>>` overflow at narrow widths | Too many items at 520 pt | Expected below about 700 pt. Check every item is still in the overflow menu with its title. Group Yesterday, Today and Tomorrow so they collapse together. |
| `DatePicker` in the toolbar is too wide or too tall | The default style is used | Use `.datePickerStyle(.compact)`, `.labelsHidden()` and `.fixedSize()`. |
| A `Picker` in the toolbar shows an empty label | `Picker("", ...)` with `.labelsHidden()` | Give it a real title, such as `Picker("Subject", ...)`, keep `.labelsHidden()`, and add `.help`. The title is used for accessibility and the overflow menu. |
| The subtitle does not show | `.navigationSubtitle` was set on a view inside a `ScrollView` that is not the detail root | Set it next to `.navigationTitle`, on the outermost view of the screen. |
| Content runs under the toolbar with no separation | The macOS 26 toolbar is glass over content | Normal. If text under it is hard to read, add `.scrollEdgeEffectStyle(.soft, for: .top)` to that screen's `ScrollView`. |
| The window title shows "Holocron" in the Dock menu and Mission Control | `navigationTitle` sets the window title | Fine. This is what the HIG wants. |
| The build fails on `ToolbarSpacer` or `sharedBackgroundVisibility` | Wrong signature | Check them in Apple's SwiftUI documentation. Both are macOS 26. If unsure, drop them and use `Divider()` inside a `ToolbarItemGroup`. |
| The Students search field moves or disappears | Another `.toolbar` on the same view changed the order | Keep `StudentSearch` as the last modifier, or set `.searchable` placement to `.toolbar` explicitly (already done). |

### 3.7 Phase 2 checks for the teacher

- Every screen: the title and subtitle are right, and every button that used to be in the page is now in the toolbar or the menu bar.
- Narrow the window to its minimum (520 pt). Nothing is lost: every item is reachable from the `>>` menu.
- Cmd+[, Cmd+] and Cmd+T work on Today, Week, Term and Devotion.
- Prominent buttons are Holocron blue.

## 4. Phase 3: content surfaces and white pages (M)

Goal: a cleaner content layer. White pages, flatter cards and nested corners.

### 4.1 Steps

1. **Take before screenshots** of Today, Week, Term, Units, Students, Mark class, Hours and Settings, or ask the teacher to.
2. **Card style** (`Theme.swift`, `CardStyle`):
   - Remove the `.shadow(...)` line.
   - Keep the `hairline` stroke.
   - Change the radius to `Radius.large` (16). Do it in the token use, not by editing `Radius.card`, so one-off panels that share 14 do not all move.
3. **Page background.** In `RootView`, the detail `ZStack` starts with `Color.appBG.ignoresSafeArea()`. Try `Color.cardBG`. Because cards are also white, they now rely on the hairline alone. Check that this reads well on Today and Units. If it does not, keep `appBG` behind those screens only, with a `.background(Color.appBG)` on that screen. The teacher chose white, but the screenshots decide each screen.
4. **Week grid panel** (`WeekView.swift`, the `ScrollView(.horizontal)` with `.background(Color.cardBG)` and `Radius.card`). On a white page, change the background to `Color.fillFaint` so the grid still reads as a block, or add a `hairline` stroke. The lesson blocks inside use `Radius.block` (7). Keep that, so the corners stay nested (outer 14 minus 10 padding is about 4 to 7).
5. **Text boxes** already use `fieldBG` and `fieldStroke` (phase 1). On a white page, a white field with a 0.14 stroke is enough. No change is needed unless the screenshots say otherwise.
6. **Sheets** (`SheetFrame`, `.background(Color.appBG)`): leave until phase 4.
7. **Banners** (`FolderBanner`, `UpdateBanner`): keep the tinted backgrounds. They are messages.
8. **Phase 1 design-check suggestions.** The white overlays on tinted subject blocks (`Color.cardBG.opacity(0.7)` in the `TagLabel` backgrounds in `TodayView` and `TermUnitsDevotion`, the `0.4`, `0.8` and `0.62` opacities in `WeekView`, and the `Stripes` colour) should get their own token, such as `static let veil = Color.white` with a comment "white veil over a subject tint". Then a later change to `cardBG` does not affect them.

### 4.2 Phase 3 traps and fixes

| Problem | Fix |
|---|---|
| White cards on a white page disappear | Keep the hairline, or use `fillFaint` for grouped panels. Do not bring the shadow back. |
| `EmptyNote` (fillFaint background) looks grey and heavy on white | Fine as is, or use `fill` at 0.03. Check by eye. |
| The `Avatar` circle placeholder vanishes | It uses `fillStrong`. That is fine on white. |
| The Class screen looks different | The Class screen has its own backgrounds. Do not change them in this phase. |
| `Settings` looks wrong | Settings uses `settingsForm()` with `appBG`. Leave it for phase 6. |

## 5. Phase 4: sheets (M)

Goal: sheets get a system title bar with Cancel on the leading side and the main button on the trailing side, both drawn on glass, with Return and Esc wired up.

### 5.1 Current state

- `SheetFrame` (`Holocron/Views/Sheets.swift`, top of file) has the parameters `title`, `subtitle`, `width`, `dirty`, `discardMessage` and `content`. It draws its own title row and an `xmark.circle.fill` close button with `.keyboardShortcut(.cancelAction)`. When `dirty` is true it shows the "Discard your changes?" dialog.
- 14 callers:

| Caller | File | Main button now | Notes |
|---|---|---|---|
| Check the scanned text | `AssistViews.swift:119` | "Add" in body, `.defaultAction`; Cancel in body | Easy. |
| Dictate notes | `DictateSheet.swift:20` | Several prominent buttons (record, save) | Leave its buttons in the body. Only the title bar changes. |
| Draft comments for the class | `DraftViews.swift:346` | "Done" at the bottom, `.defaultAction` | Done moves to the toolbar. |
| Change subject | `Sheets.swift:74` | Prominent button in body (about line 91) | Move to toolbar. |
| Move | `Sheets.swift:128` | Prominent button (about line 149) | Move to toolbar. |
| Day type | `Sheets.swift:174` | Prominent plus `.defaultAction` (about line 197) | Move to toolbar. |
| Swap two sessions | `Sheets.swift:223` | Prominent (about line 243) | Move to toolbar. |
| Bump (Lessons moved) | `Sheets.swift:272` | Two states: "Move lessons", then "Done" or "Close" with Undo | Keep in the body. The two-step flow and Undo are delicate (`snapshot`, `undoBump`). Only the title bar changes. |
| Plan (lesson) | `Sheets.swift:347` | "Edit plan" or "Done", editing state | Keep in the body. The dirty guard matters here. |
| New student | `StudentsView.swift:868` | Prominent plus `.defaultAction` (about line 880) | Move to toolbar. |
| SSG or report pack | `StudentsView.swift:900` | Prominent "Copy" style button | Keep in the body (it is not a confirm). |
| Quick log | `StudentsView.swift:1046` | Prominent plus `.defaultAction` (about line 1085) | Move to toolbar. |
| New or edit unit | `TermUnitsDevotion.swift:458` | Save (Cmd+S) and Cancel at the bottom (about line 492) | Move both to the toolbar. Keep Cmd+S on Save. |

- These sheets do **not** use `SheetFrame`: `ImportResultsSheet`, `ArchiveYearSheet`, `ImportSheet` (year end), `StartOverSheet`, `StrandCommentsSheet`, `SetupSheet`. They hold data-safety flows (archive, import, Start over). **Leave them alone in this phase.** If changed later, run `code-reviewer`.

### 5.2 New `SheetFrame` shape

Keep every existing parameter and default, so callers that pass nothing new behave the same. Add two optional parameters:

```swift
var confirmTitle: String? = nil          // "Save", "Add", "Move", "Swap"
var confirmDisabled: Bool = false
var onConfirm: (() -> Void)? = nil
```

Body sketch:

```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle(title)
    .navigationSubtitle(subtitle)           // only if not empty
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button(onConfirm == nil ? "Close" : "Cancel") { close() }   // close() keeps the dirty check
        }
        if let onConfirm, let confirmTitle {
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmTitle) { onConfirm() }.disabled(confirmDisabled)
            }
        }
    }
}
.frame(minWidth: width, idealWidth: width, minHeight: 280, idealHeight: 420)
.confirmationDialog(...)                    // unchanged
```

- `.cancellationAction` binds Esc and `.confirmationAction` binds Return. **Remove** `.keyboardShortcut(.defaultAction)` and `.keyboardShortcut(.cancelAction)` from any button you move, or the shortcut is claimed twice.
- `close()` is the existing logic: `if dirty { askDiscard = true } else { dismiss() }`.
- **The dirty guard must not change.** It protects unsaved lesson plans.
- Move callers over **one at a time**, each with its own commit, in this order: New student, Change subject, Move, Day type, Swap, Quick log, Check the scanned text, New or edit unit, Draft comments. Leave Bump, Plan, Dictate and SSG pack with their body buttons. They get only the new title bar.

### 5.3 Phase 4 traps and fixes

| Problem | Why | Fix |
|---|---|---|
| The sheet is blank or tiny | `NavigationStack` inside a sheet sizes to zero on macOS | Keep the `.frame(minWidth:idealWidth:minHeight:idealHeight:)` on the outside of the `NavigationStack`. |
| Two title bars | The old `HStack` title row was not removed | Remove it entirely. |
| Return does nothing | The button also has `.keyboardShortcut(.defaultAction)`, or a focused `TextField` with `axis: .vertical` takes Return | Remove the duplicate shortcut. For multi-line `NoteBox` fields, Return adds a new line by design. Cmd+Return can confirm: add `.keyboardShortcut(.return, modifiers: .command)` to the confirm button. |
| Esc closes a dirty sheet without asking | The toolbar Cancel calls `dismiss()` directly | Call `close()`. Also check that clicking outside the sheet and pressing Esc both go through the dirty check (`interactiveDismissDisabled(dirty)` on the sheet content). |
| The confirm button acts on stale state | The closure captured old `@State` | Pass a closure that reads the current state at call time (`onConfirm: { save() }`), not a value. |
| The subtitle line is too long | Long subtitles such as lesson titles | Keep the subtitle short. Move detail into the body. |
| `navigationSubtitle` is empty but takes space | An empty string was passed | Only apply it when `!subtitle.isEmpty`. |

## 6. Phase 5: toast and Class screen bar (S)

### 6.1 Toast

`RootView.swift`, inside the detail `ZStack`:

```swift
Text(t)
    ...
    .background(.regularMaterial)
    .clipShape(Capsule())
    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
```

Replace the background, clip and shadow with `.glassEffect(.regular, in: .capsule)`. Keep the padding, font, transition and `accessibilityLabel`.

### 6.2 Class screen

The plan said "timer, next slide, hide names". That was wrong. The real controls are in `ClassScreenView.topBar(...)` (`ClassScreen.swift`, about lines 302 to 336):

- Previous and next lesson chevrons.
- "Pop out" when embedded.
- "Full screen" and "Done" in its own window.

The timer (`TimerCard`), work mode (`WorkCard`) and steps (`StepCard`) are **content**. Leave them solid.

Steps:

1. Keep the subject title, period line and clock as they are. They are content the class reads.
2. Move the chevrons, Pop out, Full screen and Done into a floating bar at the bottom centre of `ClassScreenView`:
   ```swift
   GlassEffectContainer(spacing: 8) {
       HStack(spacing: 8) { /* buttons */ }
   }
   .padding(10)
   .glassEffect(.regular, in: .capsule)
   ```
   Use `.buttonStyle(.glass)` on the buttons, or leave the default.
3. **Auto-hide** (decision 4):
   - Keep `@State private var barVisible = true` and a `@State private var hideTask: Task<Void, Never>?`.
   - On `.onContinuousHover` (or `.onHover` over the whole screen) and on any key press, set `barVisible = true`, cancel `hideTask`, and start a new task that sleeps 3 seconds and sets `barVisible = false`.
   - Do not hide while the pointer is over the bar itself.
   - Show the bar with `.opacity(barVisible ? 1 : 0)` and `.animation(.easeInOut(duration: 0.25), value: barVisible)`. Use `.allowsHitTesting(barVisible)`.
   - Keep keyboard control working while the bar is hidden: left and right arrows step lessons, and Esc closes. Add `.onKeyPress(.leftArrow)` and `.onKeyPress(.rightArrow)` if they are not already there. Check with `grep -n "onKeyPress\|keyboardShortcut" ClassScreen.swift`.
4. **Embedded mode** (`ClassScreenModule`, `embedded == true`): do not auto-hide. The teacher is at the Mac, not the projector. Show the bar all the time.

### 6.3 Phase 5 traps and fixes

| Problem | Fix |
|---|---|
| The bar never comes back on a projector with no mouse | Any key press must show it, and the arrows and Esc must work while it is hidden. |
| The bar hides while the teacher is reaching for a button | Do not start the hide timer while hovering the bar. |
| Glass over a bright subject tint looks washed out | Use `.regular`, never `.clear`. If needed, put the bar on a neutral strip at the bottom. |
| Reduce Transparency is on | The system makes glass solid automatically. Check the bar is still visible. |
| `Task.sleep` keeps running after the window closes | Cancel `hideTask` in `.onDisappear`. |

## 7. Phase 6: sidebar, Settings and Help (S)

### 7.1 Coloured sidebar icons (decision 6)

`NavItem` is in `Holocron/AppModel.swift` (top of file), with `title` and `symbol`. Add `var tint: Color` in a View-layer extension, because `AppModel.swift` must not import colours it does not need. Put it in `RootView.swift`: `extension NavItem { var tint: Color { ... } }`.

Suggested colours (System Settings style, distinct from the `appRed`, `appAmber` and `appGreen` status colours where possible):

| Item | Colour |
|---|---|
| Today | `.blue` |
| Week | `.indigo` |
| Term | `.teal` |
| Units | `.orange` |
| Devotion | `.purple` |
| Class screen | `.cyan` |
| Students | `.green` |
| Quick log | `.yellow` |
| Mark class | `.pink` |
| Hours | `.brown` |

In `SidebarView`, change `Label(item.title, systemImage: item.symbol)` to:

```swift
Label {
    Text(item.title)
} icon: {
    Image(systemName: item.symbol).foregroundStyle(item.tint)
}
```

Check:
- The selected row (accent highlight) still shows the icon clearly. If the coloured icon disappears on the blue selection, use `.symbolRenderingMode(.hierarchical)`, or let the selected row fall back to white.
- On macOS 26 a tinted icon in a sidebar can be flattened to the accent colour when selected. That is expected.

### 7.2 Sidebar header

- `SidebarView` has a custom header (HOLOCRON, the class name, `WeekBox`), `MiniCalendar` and `FolderStatus`.
- `WeekBox` has `.background(Color.cardBG)`, a `Radius.panel` clip and a hairline. On the glass sidebar, a solid white box can look pasted on. Try `Color.fillFaint` or no background. Check both ends of the macOS 27 opacity slider.
- `MiniCalendar` uses plain buttons. Leave it.

### 7.3 Settings

- `settingsForm()` (`SettingsView.swift`, top of file) applies `.formStyle(.grouped)`, `.scrollContentBackground(.hidden)`, `.background(Color.appBG)` and `.listRowBackground(Color.cardBG)`.
- Remove the last three. Keep `.formStyle(.grouped)`.
- Check every pane: General, Timetable, Calendar, Intelligence, Folders, Privacy, Year end, Updates.
- Compare with `Claude outputs/settings-redesign-plan.md`, so nothing that plan relied on is lost.

### 7.4 Help window

`HelpView.swift` has its own `NavigationSplitView`. Apply the phase 2 pattern: title in the toolbar, and remove any custom bar background.

### 7.5 Phase 6 traps and fixes

| Problem | Fix |
|---|---|
| Settings rows lose their white background and look grey | That is the system grouped style on macOS 26. If the teacher dislikes it, put back `.listRowBackground(Color.cardBG)` only. |
| The coloured icons clash with subject colours in the Week grid | They are in the sidebar only. If the clash still shows, use `.hierarchical` rendering at lower saturation. |
| `AppModel.swift` gets a SwiftUI colour import | Keep `tint` in the View-layer extension. |

## 8. Testing checklist (every phase)

The teacher runs these, because the working environment cannot run macOS apps:

1. The CI build is green on the PR.
2. Open every screen at the default size (1280 x 860) and at the minimum size (520 x 480).
3. System Settings, Accessibility, Display:
   - Turn on Reduce transparency and check every screen.
   - Turn on Increase contrast and check again.
4. On macOS 27, move the Liquid Glass opacity slider to both ends.
5. Show the Class screen on a projector or second display, and read it from the back of the room.
6. Print Week and Save Week as PDF: the output is unchanged.
7. Every sheet touched: Return confirms, Esc cancels, and a sheet with unsaved changes asks first.
8. Turn on Full Keyboard Access and check the toolbar can be reached.

## 9. Things not to do

- No `.glassEffect()` on cards, lesson blocks, notes, the week grid, the term grid, results tables or the Class screen content. Glass is for controls only.
- No `Glass.clear`. Holocron has no photo or video backgrounds.
- No dark mode, semantic colours or `Color(nsColor: .labelColor)` swaps. Light mode is forced on purpose.
- No changes to `PrintWeek.swift`.
- No changes to the data-safety sheets (`ImportResultsSheet`, `ArchiveYearSheet`, `ImportSheet`, `StartOverSheet`, `SetupSheet`, `StrandCommentsSheet`) as part of this work.
- No accent colour picker (decision 1).
- No new third-party packages.
- No real student names in screenshots committed to the repo. Better: commit no screenshots.

## 10. Order and sizes

| Order | Phase | Size | Changelog bullet |
|---|---|---|---|
| 1 | 2 Toolbar, titles, accent | M | Yes |
| 2 | 3 White pages and flatter cards | M | Yes |
| 3 | 5 Toast and Class screen bar | S | Yes |
| 4 | 4 Sheets | M | Yes |
| 5 | 6 Sidebar colours, Settings, Help | S | Yes |

Phase 5 comes before phase 4 because it is small and self-contained. Phase 4 touches the most callers and the unsaved-changes guard, so it goes once the rest has settled.
