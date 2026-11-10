# Settings redesign: System Settings style

## Goal

Replace the toolbar `TabView` in Settings with a layout like macOS System Settings (and iOS Settings): a sidebar of coloured icon tiles on the left, a grouped form on the right, a search field at the top of the sidebar, and a header at the top of each pane. No behaviour changes. Every control keeps the same binding and the same data path.

## What is there now

- `Holocron/Views/SettingsView.swift` (484 lines): `SettingsTab` enum, a `TabView` with six tabs (General, Timetable, Calendar, Apple Intelligence, Updates, Data), all panes as computed properties on one struct, plus binding helpers.
- `Holocron/Views/IntelligenceSettings.swift`: Apple Intelligence pane, which also holds Siri, Spotlight and Shortcuts.
- `Holocron/Views/Updater.swift` `UpdatesSettings`: Updates pane.
- `Holocron/HolocronApp.swift`: `Settings { SettingsView() ... .frame(minWidth: 540, idealWidth: 600, ...) }`, and "Check for Updates…" writes `SettingsTab.updates.rawValue` to the `settingsTab` default before `openSettings()`.
- The Data tab is very long: two folder sections, privacy, year end, start over, reload and version.

## What needs changing

1. **The Data tab is too long for one pane.** Split it into Folders, Privacy and Year End. Apple Intelligence also holds Siri, so split that into its own pane.
2. **The window is too narrow for a sidebar.** Raise the minimum to about 720 × 500 (ideal 780 × 600).
3. **Saved selection.** The `settingsTab` key must keep working. Old stored values: `data` maps to `folders`. `updates` keeps its raw value so the menu command still works.
4. **User-facing copy says "Settings, then Data"** in many places (HelpContent, StartOverSheet, YearEnd, Intelligence, Dictation, HolocronShortcuts, README, docs). These must name the new pane. Do not rewrite past release sections in Holocron/CHANGELOG.md.
5. **The subjects footer says "use Privacy on the Data tab"**. Change to "use Privacy in Settings".
6. **Sheets and dialogs** (Start over, Archive, Import, make-subject-private dialog) move with the pane that owns their buttons.

## New structure

Sidebar, in three groups with no group titles (like System Settings):

| Pane | Raw value | SF Symbol | Tile colour token | Contents |
|---|---|---|---|---|
| (header card) | – | app icon | – | App icon, class name, "Holocron 1.13.1". Selecting it opens General. |
| General | `general` | `gearshape` | `ink2` (grey) | Class name, Modules, Reload from folders, Version |
| Timetable | `timetable` | `clock` | `appBlue` | Periods, Subjects |
| Calendar | `calendar` | `calendar` | `appRed` | Terms, Non-teaching days |
| — | | | | |
| Apple Intelligence | `intelligence` | `apple.intelligence` | `appBlue` | `IntelligenceSettings()` unchanged (another session owns that file) |
| — | | | | |
| Folders | `folders` | `folder.fill` | `appBlue` | Student folder, Planner folder |
| Privacy | `privacy` | `hand.raised.fill` | `appBlue` | Devotion and subject privacy |
| Year End | `yearend` | `archivebox.fill` | `appAmber` | Archive this year, Import from folder, Start over (last section), Show archive |
| Updates | `updates` | `arrow.down.circle.fill` | `ink2` | Existing `UpdatesSettings` |

Use only existing Theme tokens for tile colours. Glyphs are white on the tile.

## Components (add to Theme.swift or a new SettingsChrome section in SettingsView.swift)

- `SettingsIcon(symbol:tint:size:)`: rounded square (corner radius about 22% of size, `.continuous`), 20 pt in the sidebar, 48 pt in pane headers, white glyph.
- `SettingsPaneHeader(pane:)`: first section of each form. Large tile, pane title in `.title2.bold()`, one-line blurb in `.callout` secondary, centred like System Settings. Blurbs in plain Australian English, for example Timetable: "Periods, subjects and their colours."
- Sidebar row: `Label { Text(title) } icon: { SettingsIcon(...) }`.

## Shell

```swift
NavigationSplitView {
    List(selection: $selection) {
        header card
        Section { general, timetable, calendar }
        Section { intelligence, siri }
        Section { folders, privacy, yearend, updates }
    }
    .searchable(text: $query, placement: .sidebar, prompt: "Search")
    .navigationSplitViewColumnWidth(215)
} detail: {
    pane(for: selection)
}
.toolbar(removing: .sidebarToggle)
.navigationTitle(selection.title)
```

- Search filters sidebar rows by title and a short keyword list per pane (for example Privacy: "devotion quotes private lessons subject share"). With no match show "No results".
- Each pane is its own `struct` (GeneralPane, TimetablePane, CalendarPane, FoldersPane, PrivacyPane, YearEndPane, IntelligenceSettings, SiriSettings, UpdatesSettings) using `.settingsForm()`. Move shared binding helpers into a small helper type or extension so they are not duplicated.
- Split files: keep `SettingsView.swift` for the shell, enum and chrome; put panes in `SettingsPanes.swift`. Folder-synced groups pick the new file up.

## Rules to keep

- No logic changes to folder, import, archive, start over, privacy or rename code. Move views only.
- House look tokens only. Light mode stays forced. Australian English, plain wording, no emoji.
- Destructive Start over keeps its sheet confirmation.
- Add one bullet to `## Unreleased` in Holocron/CHANGELOG.md: "Settings now looks like System Settings, with a sidebar and search. The Data tab is split into Folders, Privacy and Year End, and Siri has its own page."
- Update docs/ARCHITECTURE.md file map and docs mentioning settings tabs.

## Verify

- `xcodebuild -project Holocron.xcodeproj -scheme Holocron -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` succeeds with no new warnings.
- Grep shows no remaining "Settings, then Data" or "Data tab" in Swift, README or docs (except old CHANGELOG sections).
- Run the `ui-design-check` agent on the changed views.
