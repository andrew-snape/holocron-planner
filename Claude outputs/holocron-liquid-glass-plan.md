# Holocron: Liquid Glass and theme update plan

A plan to move Holocron's look to the macOS 26 and 27 Liquid Glass design, and to tidy the theme so the change happens in one place. Nothing here has been built yet.

## Summary

- Liquid Glass belongs to the **control and navigation layer** only: sidebar, toolbar, sheets, popovers, floating controls. Holocron's content (lesson cards, the week grid, notes, the Class screen) stays solid and readable.
- Most of the work is **removing custom chrome** so the system can draw glass, not adding glass. The biggest win is moving each screen's own row of buttons (Last Week, This Week, Print, filter) into the window toolbar.
- The theme moves from loose values to **tokens** (colours, corner radii, type sizes) in `Theme.swift`, so later changes are one-line edits.
- **Light mode only stays.** Dark mode is not part of this plan (CLAUDE.md rule). See the open decisions.
- Six phases (the seventh, accent themes, was dropped), each with its own release bullet. About two to three weeks of work in total. Decisions are recorded near the end.

## What Apple says (from the HIG notes and WWDC)

Taken from `apple-hig-foundations.md`, `apple-hig-components-b.md` and `apple-hig-components-c.md` in this folder, plus WWDC25 and WWDC26.

| Guidance | What it means for Holocron |
|---|---|
| Liquid Glass is a separate layer for controls and navigation that floats above content | Sidebar, toolbar, sheets and the toast use glass. Cards, grid and notes do not. |
| Do not use Liquid Glass in the content layer. Use standard materials there | No `.glassEffect()` on cards, lesson blocks or the week grid. |
| Use it sparingly. System components pick it up automatically | Prefer system toolbars, buttons and sidebars over hand-drawn ones. |
| Regular glass for text-heavy parts; clear glass only over rich backgrounds | Use regular everywhere. Holocron has no photo or video backgrounds that justify clear. |
| Apply colour to glass sparingly, colour the background of the primary action, not its text | One prominent (blue) action per toolbar at most. |
| Reduce custom backgrounds and tinted controls in toolbars | Remove custom bar backgrounds; let the scroll edge effect separate toolbar from content. |
| Extend rich content under the sidebar (background extension effect) | Optional for Week and Class screen. Not needed for list screens. |
| Every toolbar item must also be in the menu bar | Anything moved to the toolbar gets a menu command (most already exist). |
| Sheets: Cancel on the leading edge of the top bar, Done on the trailing edge | `SheetFrame` header becomes a system toolbar. |
| Even a single-appearance app should supply light and dark variants for glass | Glass reads colour from what is behind it. With light forced, keep content light so glass stays light. Revisit only if dark mode is ever wanted. |

**macOS 27 refinements (WWDC26).** Apple kept Liquid Glass and refined it: a system slider for glass opacity, a uniform window corner radius across apps, sidebars that reach the window edge, and sidebar icons back in colour. Standard SwiftUI components pick these up with no code change. The lesson for Holocron: **the more system components it uses, the more it gets for free each year.** Custom chrome has to be redone by hand.

## Where Holocron is now

Measured on `main` at 1.14. Deployment target macOS 26.0, built on Xcode 26 and 27.

| Area | Now | Liquid Glass gap |
|---|---|---|
| Window | `NavigationSplitView`, detail painted `Color.appBG` grey | Fine. The sidebar already gets glass from the system. |
| Sidebar | System `List(.sidebar)` plus custom header (HOLOCRON, class name, WeekBox), MiniCalendar, FolderStatus | Mostly right. Check the custom header sits well on glass. |
| Toolbar | One item (Settings gear) | Screen controls live in the content as plain buttons, not in the toolbar. |
| Page titles | `PageHeader` and hand-made 26 to 28 pt titles inside the scroll view | Duplicates the window title. On 26 the toolbar shows the title. |
| Cards | `.card()` used 32 times: white, 14 pt radius, shadow, hairline | Content layer, keep. Update radius to the new token and drop the shadow. |
| Colours | 11 tokens in `Theme.swift`, but 42 `Color.white`, 22 `Color.black.opacity`, 40 `background(Color…)` scattered | Needs tokens so content surfaces change in one place. |
| Corner radii | 63 literal `cornerRadius` values | Needs 3 or 4 radius tokens. |
| Type | 414 `.font(.system(size:))` calls | Needs a small type scale. |
| Buttons | 39 `.borderedProminent`, 20 `.plain` | System restyles these already. Toolbar ones become `.glass` / `.glassProminent`. |
| Toast | Capsule on `.regularMaterial` with a shadow | A floating control, a good fit for `.glassEffect()`. |
| Sheets | `SheetFrame` with its own title row and xmark button, 14 sheets | System sheet toolbar gives glass, Cancel/Done placement and Esc/Return for free. |
| Settings | `.formStyle(.grouped)` with background overridden to `appBG` and rows to white | Remove the overrides; the system grouped form already looks right on 26. |
| Glass APIs used | None (`glassEffect`, `GlassEffectContainer`, `ToolbarSpacer`, `backgroundExtensionEffect`: 0) | Expected; most should come from system components. |

## Design direction

1. **Content is paper, chrome is glass.** Lesson blocks, notes, results and the Class screen are things a teacher reads, often from across a room. They stay solid, high contrast and white. Everything you press to move around or act floats on glass.
2. **Subject colour stays in the content.** `Tone` tints and bars are the main colour in the app. Glass controls above them stay monochrome so the two do not fight (HIG: avoid similar colours on toolbar labels and content).
3. **Fewer surfaces.** Drop the grey `appBG` page plus white card plus shadow stack where a single white page reads better (Today, Units, Students detail). Keep cards where grouping helps (Today's periods, Import results).
4. **Concentric corners.** Inner shapes follow the window's corner. Use `ConcentricRectangle` / `containerShape` where a card sits close to the window edge; otherwise use the radius tokens.
5. **Class screen is a projector surface.** No glass over subject blocks, no translucency, controls tucked into a glass bar that can hide.

## The theme rework (tokens)

Keep everything in `Holocron/Views/Theme.swift`, as now. Names stay short and match the existing ones so the diff is readable.

### Colours

| Token | Use | Change |
|---|---|---|
| `appBG` | Window content background | Keep the name. Try `Color(nsColor: .windowBackgroundColor)` against the current grey; pick by eye on a real Mac. |
| `cardBG` | Card and page surfaces | Keep white. |
| `fieldBG` (new) | Text box fill (`NoteBox`, inline editors) | Replaces 42 scattered `Color.white`. |
| `fieldStroke` (new) | Text box border | Replaces `Color.black.opacity(0.14)`. |
| `fill` (new) | Quiet fills (chips off, empty notes, avatar circle) | Replaces `Color.black.opacity(0.03 to 0.08)`. |
| `hairline`, `ink2`, `ink3` | As now | Check `ink2` at 4.5:1 on `appBG` once the background is chosen. |
| `appBlue`, `appGreen`, `appAmber`, `appRed`, `weekB`, `weekBBG` | As now | `appBlue` becomes the app accent (`AccentColor` in the asset catalog) so system controls and glass tint match it. |

### Shape, space and type

```swift
enum Radius { static let card: CGFloat = 16; static let field: CGFloat = 10; static let chip: CGFloat = 8; static let block: CGFloat = 10 }
enum Space  { static let page: CGFloat = 24; static let card: CGFloat = 14; static let gap: CGFloat = 12 }
extension Font {
    static let pageTitle = Font.system(size: 26, weight: .bold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let body13 = Font.system(size: 13)
    static let caption12 = Font.system(size: 12)
    static let label11 = Font.system(size: 11, weight: .semibold)
}
```

Exact values are a starting point. The rule is: new and touched code uses tokens; the 414 font calls move over screen by screen, not in one sweep.

### "Change of themes"

Two readings, both possible:

- **A. One new house look** (this plan, chosen). Liquid Glass chrome, cleaner content, same colours.
- **B. A choice of accent theme** in Settings, General (for example Blue, Teal, Purple, Graphite). Once colours are tokens this is small: the accent token reads from a setting and every system control and glass tint follows. It is a per-Mac preference, so store it in `UserDefaults` (like `settingsTab`), not in `settings.csv`, which travels with the student folder.

A was chosen, so B (phase 7) is not planned. Tokens keep it a small job if it is ever wanted.

## Phases

Each phase: its own branch from `main`, build on Xcode 26 and 27, run `ui-design-check`, take before and after screenshots of every screen it touches, add a `## Unreleased` bullet to `CHANGELOG.md`. None of this touches file reading or writing, so `code-reviewer` is only needed if a phase strays into `Core`.

### Phase 1. Tokens, no visible change (S to M)

- Add the colour, radius, space and font tokens to `Theme.swift`.
- Replace literal colours and radii in `Theme.swift` and `Sheets.swift` first, then the rest of `Views`, keeping values identical so nothing moves on screen.
- Set `AccentColor` in `Assets.xcassets` to `appBlue`. Moved to phase 2: it changes the colour of every system control and overrides the Mac's own accent setting, so it is a visible change.
- Done when a grep for `Color.white`, `Color.black.opacity` and `cornerRadius: <number>` in `Views` returns only `Theme.swift` and `PrintWeek.swift` (print stays as it is), apart from the 2 pt bar in Students.
- Status: done on 8 Nov 2026. Values are unchanged, except that faint fills of 0.025 to 0.045 now share one value (0.03), and two strokes and a legend swatch moved to the nearest token. None of these are visible. Card shadows and the toast shadow stay until phases 3 and 5.

### Phase 2. Window, toolbar and titles (M)

The biggest visible change.

- Each screen sets `.navigationTitle` and, on macOS, `.navigationSubtitle` (for example "Term 4 Week 5" and "10 Nov to 14 Nov, Week B").
- Move each screen's control row into `.toolbar`:
  - **Week:** Last Week / This Week / Next Week as one group, the subject filter, then Print as a menu. Use `ToolbarSpacer` between groups.
  - **Today:** previous and next day, Today, Copy Day.
  - **Term, Units, Devotion, Students, Hours, Assess:** their Add / Import / filter controls.
  - **Settings gear** stays trailing, alone (`sharedBackgroundVisibility(.hidden)` if it looks crowded).
- `PageHeader` shrinks to an optional in-content line (or goes) because the toolbar now shows the title. Keep the type for the one or two screens that need an in-page heading.
- Remove the grey fill behind the toolbar so the system scroll edge effect does the separation (`.scrollEdgeEffectStyle(.soft, for: .top)` where content runs under it).
- Every toolbar item has a menu bar command (Go menu already covers navigation; add Previous Week / Next Week / This Week under a View or Go section with Cmd+[ and Cmd+]).
- Narrow windows (the 820 pt sidebar rule in `RootView`): check toolbar items collapse into the overflow menu cleanly at 520 pt.

### Phase 3. Content surfaces (M)

- `CardStyle`: radius to `Radius.card`, drop the shadow, keep the hairline. Try a borderless version on screens where the card is the whole page.
- `NoteBox`, `LineField`, inline editors: use `fieldBG` and `fieldStroke`.
- Week grid: keep its white panel, use `Radius.card`, and check lesson block corners nest inside it.
- Empty notes, chips and the avatar circle: use `fill`.
- Move to plain white pages (decision 2). Start with Today, Units and Students detail, keep cards only where grouping helps, and confirm with before and after screenshots before doing the rest.

### Phase 4. Sheets (M)

- `SheetFrame` keeps its API (`title`, `subtitle`, `width`, `dirty`, `discardMessage`) so the 14 callers do not change.
- Inside, swap the hand-made title row for a `NavigationStack` with `.navigationTitle` and a toolbar: Cancel (`.cancellationAction`, leading) and the sheet's primary button (`.confirmationAction`, trailing, prominent). The system draws these on glass.
- Keep the discard confirmation exactly as it is when `dirty` is true. This is the one place in the plan where behaviour could regress, so test Esc, Cancel and clicking outside on a dirty sheet.
- Sheets whose primary button is currently in the body (several in `Sheets.swift`) need a `confirmation` slot on `SheetFrame`. Move them one at a time.

### Phase 5. Floating controls and small glass (S)

- Toast in `RootView`: replace `.regularMaterial` and the shadow with `.glassEffect(.regular, in: .capsule)`.
- Class screen: put its controls (timer, next slide, hide names, close) in a floating glass bar at the bottom using `GlassEffectContainer` so the buttons blend as one shape. The bar fades after a few seconds of no mouse movement and returns on hover. The projected content underneath stays solid.
- Update banner and folder banner: keep as content-layer banners (they are messages, not controls), using tokens.
- Do not add glass anywhere else without a reason written in the PR.

### Phase 6. Sidebar and Settings (S)

- Sidebar: remove any background the custom header adds, check `WeekBox` and `MiniCalendar` on the glass sidebar with the macOS 27 opacity slider at both ends. Give each module its own icon colour (decision 6): add a `tint` to `NavItem` and apply it to the sidebar `Label` icon. Keep the colours distinct from subject colours and check them against the selected row highlight.
- Settings: in `settingsForm()` drop `.scrollContentBackground(.hidden)`, the `appBG` background and the white row background, and let the grouped form draw itself. Check it still matches the redesign in `settings-redesign-plan.md`.
- Help window: same treatment as the main window (toolbar title, no custom bar).

### Phase 7. Accent themes (not planned, decision 1)

- Settings, General: "Accent colour" picker with four or five choices and a preview swatch.
- Stored in `UserDefaults` under `appearance_accent`. Applied with `.tint()` at the scene root.
- Subject colours, Week B purple and status colours (green, amber, red) do not change with the accent.

## Testing checklist (every phase)

- Build: the Release command in CLAUDE.md on Xcode 26, and a Debug build on Xcode 27. Glass APIs are macOS 26, so no `#available` checks are needed unless a macOS 27-only API is used; then guard it.
- Look at every screen at 1280 x 860 and at 520 x 480.
- System Settings, Accessibility, Display: **Reduce transparency** on, **Increase contrast** on. Glass must fall back to solid and text must stay readable.
- macOS 27: the Liquid Glass opacity slider at both ends.
- Class screen on a projector or a second display at a distance.
- Print Week and Save Week as PDF: output unchanged.
- Keyboard: Return and Esc in every sheet touched, toolbar reachable with Full Keyboard Access.
- `ui-design-check` agent, then fix what it finds before merging.

## Risks

| Risk | Mitigation |
|---|---|
| Glass on a bright white page looks washed out | Regular glass only; keep content light and simple; test with the opacity slider. |
| Toolbar too crowded on narrow windows | Group items, rely on overflow, keep one prominent action. |
| `SheetFrame` change breaks the unsaved-changes guard | Keep the guard code untouched; test dirty sheets by hand in phase 4. |
| macOS 27 changes how glass renders again | Prefer system components so updates arrive free; keep custom glass to the toast and Class screen bar. |
| A big visual change unsettles daily use | Ship phases across a few releases, with plain changelog bullets. |
| API names drift between SDKs | Check each modifier against the Xcode 26 SDK before use; CI builds on both. |

## Suggested order and size

| Step | Phase | Size | Release |
|---|---|---|---|
| 1 | 1 Tokens | S to M | Can ship silently |
| 2 | 2 Toolbar and titles | M | 1.15 headline |
| 3 | 3 Content surfaces | M | 1.15 |
| 4 | 5 Toast and Class screen bar | S | 1.15 |
| 5 | 4 Sheets | M | 1.16 |
| 6 | 6 Sidebar and Settings | S | 1.16 |
| 7 | 7 Accent themes | S | Not planned |

## Decisions (8 Nov 2026)

| # | Question | Decision |
|---|---|---|
| 1 | Theme meaning | One new house look. No accent colour choice, so phase 7 is dropped. |
| 2 | Page background | Plain white pages, leaning that way. Confirm with before and after screenshots in phase 3. |
| 3 | Page titles | Yes. The title moves to the window toolbar, and the big in-page titles go. |
| 4 | Class screen controls | Auto-hiding glass bar. |
| 5 | Dark mode | Still parked. Light mode only stays. |
| 6 | Sidebar icon colour | Coloured per module. |

## API reference (macOS 26 SwiftUI)

Verify each against the SDK before use.

| API | Where it would be used |
|---|---|
| `.glassEffect(_:in:)`, `Glass.regular`, `.interactive()`, `.tint(_:)` | Toast, Class screen bar |
| `GlassEffectContainer(spacing:)`, `.glassEffectID(_:in:)` | Class screen bar grouping and morphing |
| `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` | Floating custom buttons only; toolbar buttons get glass automatically |
| `ToolbarSpacer(.fixed)` / `ToolbarSpacer(.flexible)` | Grouping toolbar items |
| `.sharedBackgroundVisibility(.hidden)` | Standing a toolbar item apart from its group |
| `.scrollEdgeEffectStyle(_:for:)` | Content running under the toolbar |
| `.backgroundExtensionEffect()` | Optional, Week grid or Class screen under the sidebar |
| `ConcentricRectangle`, `.containerShape(_:)` | Cards near the window corner |
| `.navigationSubtitle(_:)` | Week and term line under the window title |
| `.toolbar(removing:)` | Already used in Settings |

## Sources

- HIG notes in this folder: `apple-hig-foundations.md` (Materials, Liquid Glass colour), `apple-hig-components-b.md` (Toolbars, Sidebars, menu bar), `apple-hig-components-c.md` (Sheets, Search).
- WWDC25 session 323, Build a SwiftUI app with the new design: https://wwdcnotes.com/documentation/wwdc25-323-build-a-swiftui-app-with-the-new-design/
- WWDC26 SwiftUI changes: https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
- macOS 27 Liquid Glass refinements: https://www.neowin.net/news/apple-finally-brings-the-slider-for-liquid-glass-and-many-other-changes/ and https://siliconangle.com/2026/06/08/apple-refines-liquid-glass-design-expands-child-safety-tools-wwdc/
