# Apple Human Interface Guidelines: Components (Part C)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Tab bars, Search fields, Sheets, Popovers, Alerts, Windows.

Platform sections for tvOS, watchOS and visionOS are summarised or removed where they do not apply to your projects. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Tab bars

A tab bar lets people navigate between the top-level sections of an app. It helps people see what kinds of information or functions the app offers, and lets them switch sections while keeping each section's navigation state.

### Best practices

- **Use a tab bar for navigation, not for actions.** Controls that act on the current view belong in a toolbar.
- **Keep the tab bar visible** as people move between sections, so they always know where they are. The exception is a modal view, which is temporary and self-contained.
- **Use only as many tabs as the app needs.** Fewer tabs are easier to navigate. For a complex structure, consider a sidebar, or a tab bar that adapts to a sidebar.
- **Avoid overflow tabs.** On iOS and iPadOS, when space runs out the last tab becomes a More tab, which hides content and makes it harder to reach. Limit cases where this can happen.
- **Do not disable or hide tab bar buttons** when their content is unavailable. Changing the bar makes the app feel unstable. If a section is empty, explain why.
- **Include a label for each tab,** preferably a single word.
- **Use SF Symbols for tab icons.** They adapt to regular and compact layouts. In compact views the icon sits above the label, and in regular views they sit side by side. Prefer filled symbols for consistency with the platform.
- **Use a badge only for critical information.** A badge is a red oval with a number or exclamation mark. Reserve badges for what needs attention, so they keep their impact. See Notifications.
- **Avoid similar colours on tab labels and content backgrounds.** Prefer a monochromatic appearance if the content is colourful.

### iOS

- The tab bar floats above the content, on a Liquid Glass background that lets content show through.
- For a tab bar with an attached accessory, such as the MiniPlayer in Music, you can minimise the bar as people scroll down, so the accessory sits inline with it.
- A search tab can sit at the trailing end. See Search fields.

### iPadOS

- The tab bar sits near the top of the screen. You can keep it as a fixed bar, or add a button that converts it to a sidebar.
- If you only need a sidebar, use a split view rather than a tab view.
- **Prefer a tab bar for navigation.** For a more complex app, let people convert the tab bar to a sidebar so they can reach more navigation options.
- **Let people customise the tab bar** in apps with many sections. Keep the default list to five or fewer, so the layout stays consistent between compact and regular sizes.

### macOS

- No additional considerations.

### tvOS

- The tab bar can be styled with a background tint or image, a custom font, and tints for selected and unselected items, and it can include icons such as settings and search.
- By default the bar is translucent, with only the selected tab opaque. Its height and top position are fixed by the system.
- Truncation fades the items that do not fit.
- By default, people can scroll the tab bar off screen when the current tab shows a single main view. If the screen has a split view, the bar stays pinned.
- In a live-viewing app, order tabs as live content first, then recorded content, then other content.

### visionOS

- The tab bar is always vertical, fixed to the window's leading side. It expands when people look at it, and it can briefly cover content behind it when expanded.
- Supply both a symbol and a short text label for each tab. The symbol is always visible, and the label appears when people look at the bar.
- If the hierarchy is deep, a sidebar inside a tab can provide secondary navigation. Make sure selecting a sidebar item does not change the open tab.

### watchOS

- Not supported.

---

## Search fields

A search field lets people search a collection of content by typing terms. It is an editable text field with a search icon, a Clear button and placeholder text. It can also use a scope bar and tokens to filter the search.

### Best practices

- **Use placeholder text to say what can be searched,** especially when the search covers a particular type of content.
- **Start searching as people type** where possible. Results that refine as the text becomes more specific feel more responsive.
- **Show suggested search terms,** such as recent searches before typing begins, or predictive suggestions as people type.
- **Put the most relevant results first,** and consider grouping them into categories.
- **Let people filter results** with a scope bar in the results area.

### Scope bars and tokens

- A **scope bar** is a control that filters or changes the scope of a search. Use it for clearly defined categories. Default to the broader scope, so people have context before they narrow it.
- A **token** is a visual form of a search term that people can select and edit as one item. It filters any other terms. Use tokens for common search terms or items, such as a contact or a type of attachment.
- **Pair tokens with search suggestions,** because people may not know which tokens exist.

### iOS

Search can be placed in three main positions:

- **As a tab in the tab bar.** A standard search tab opens a landing page with a search field at the top, which suits apps with rich content to explore. A button-style search tab opens straight into the keyboard, which suits quick searches that return people to their previous tab.
- **In a toolbar,** at the top or bottom of the screen. At the bottom, search can be an expanded field or a button, and it animates into a field above the keyboard. Place it at the bottom when search is a priority. Place it at the top when covering the bottom content would interfere with a main function.
- **Inline with content,** when the position next to the content strengthens the link between them. An inline field sits above the list it searches, and can be pinned to the top toolbar when scrolling. This suits filtering within a single view.

### iPadOS and macOS

- Keep the search experience as consistent as possible across iPad and Mac.
- **Put a search field on the trailing side of the toolbar** for many common uses, especially in split views that search across several columns, such as Mail or Notes.
- **Place search at the top of the sidebar** when it filters the sidebar, such as Settings does.
- **Use a sidebar or tab item for search** when discovery needs its own area, with suggestions, categories or rich content, such as Music or TV.
- **Consider focusing the field** when people open a dedicated search area. On iPad, leave it unfocused if only the virtual keyboard is available, so the keyboard does not cover the view unexpectedly.
- **Account for window resizing.** On iPad, search should stay available where it is most useful in compact layouts. Notes and Mail place search above the content list when they narrow.

### tvOS

- Use a search screen with a keyboard input area, a scope bar and results beneath the keyboard.
- Provide popular and context-specific suggestions, including recent searches, because people do not like typing with a remote.

### watchOS

- Tapping the search field opens a full-screen text input. The app returns to the search field only after people tap Cancel or Search.

### visionOS

- No additional considerations.

---

## Sheets

A sheet helps people complete a scoped task closely related to their current context. It can request specific information, such as a file to attach or a location to save to, or present a simple task that people can finish before returning to the parent view.

### Anatomy

- On macOS, tvOS, visionOS and watchOS, a sheet is always modal. It blocks interaction with the parent view until dismissed.
- On iOS and iPadOS, a sheet can be modal or nonmodal. A nonmodal sheet lets people change the parent view while it stays open, such as the format sheet in Notes.
- **Cancel (or Close)** dismisses without saving. It is common in most sheets.
- **Done** dismisses after completing the task or saving changes.
- **Back** moves to a previous step in a multistep flow or to a parent view. It does not dismiss the sheet.

### Best practices

- **Consider alternatives for complex or long flows.** On iOS and iPadOS, a full-screen modal suits video, photos, camera or multistep editing. On a Mac, a new window or full screen may suit better. A self-contained task such as editing a document often works well in a separate window.
- **Show only one sheet at a time from the main interface.** If a sheet leads to another sheet, close the first one before showing the second. You can show the first again afterwards.
- **Use a nonmodal view for supplementary items** that affect the main task. On visionOS, use a split view. On macOS, use a panel. On iOS and iPadOS, use a nonmodal sheet.
- **Always pair Done with Cancel.** Done on its own implies that completing the task is the only way out, which can feel restrictive or misleading.
- **Avoid showing Cancel, Done and Back together.**

### iOS and iPadOS

- For a single-view sheet, put Cancel on the leading edge of the top toolbar, and Done on the trailing edge.
- In a multistep flow, the buttons change by step. The first step shows Cancel. Later steps show Back. The final step shows Done.
- **Detents** are the heights at which a resizable sheet rests. The system provides large (fully expanded) and medium (about half height). You can add custom detents.
- **Consider the medium detent on iPhone** for progressive disclosure, such as a share sheet showing the most relevant items first. Skip it when the content needs full height, such as a compose sheet.
- **Include a grabber in a resizable sheet.** It shows that the sheet can be dragged, and works with VoiceOver.
- **Support swiping to dismiss.** If there are unsaved changes, confirm with an action sheet before dismissing.
- **On iPadOS, prefer the form or page sheet styles.** They use a default size, centre the content and provide a consistent look.

### macOS

- A sheet is a card with rounded corners that floats over its parent window, which is dimmed while the sheet is open.
- **Use a reasonable default size.** People do not usually expect to resize sheets, although supporting resizing is helpful when people need more room.
- **Let people use other windows** while a sheet is open. Bring the parent window forward, and let people reach the app's other windows.
- **Use a panel instead** when people need to repeat input and see results each time, such as a find and replace panel.

### visionOS

- A sheet floats in front of its parent window and dims it.
- Avoid a sheet that rises from the bottom edge of the window. Centre it in the field of view.
- Use a default size that keeps the person's context. Avoid covering most of the window, but consider letting people resize it.

### watchOS

- A sheet is a full-screen view that slides over the current content. The system blurs and desaturates what sits behind it.
- **Use a sheet only when the task needs a custom title or custom content.** For important information or a set of choices, use an alert or an action sheet.
- **Keep sheet interactions brief.** Do not use a sheet to navigate content.
- **If you change the default label, use an SF Symbol.** A text label in the top-leading corner that looks like a page title confuses people about how to dismiss the sheet.

### tvOS

- No additional considerations.

---

## Popovers

A popover is a transient view that appears above other content when people click or tap a control or interactive area.

### Best practices

- **Use a popover for a small amount of information or functionality,** such as a few related tasks. It disappears after people interact with it, so keep it focused.
- **Use a popover when you need more room temporarily.** It keeps the interface tidy compared with a permanent sidebar or panel.
- **Point the arrow as directly as possible** at the element that revealed the popover. Ideally, the popover should not cover that element or any content people need while using it.
- **Use a Close button only where it adds clarity,** such as to show whether changes are saved. Otherwise, a popover closes when people click outside it or pick an item. If several selections are possible, keep it open until people dismiss it.
- **Save work when a nonmodal popover closes automatically.** Discard changes only when people press an explicit Cancel.
- **Show only one popover at a time.** Never show a popover from another popover. Close the open one first.
- **Show nothing over a popover** except an alert.
- **Let people switch popovers with one click or tap** where possible, especially when several bar buttons each open one.
- **Keep the popover no bigger than its contents.** The system can adjust its size to fit.
- **Animate size changes** between condensed and expanded views, so the change does not look like a new popover.
- **Avoid the word "popover" in help.** Refer to the task or the selection instead.
- **Do not use a popover for a warning.** People can miss it or dismiss it by accident. Use an alert.

### iOS and iPadOS

- **Avoid popovers in compact views.** Adjust the layout to the size class instead. Reserve popovers for wide views, and use a full-screen sheet in compact views.

### macOS

- A popover can be detached into a separate panel when people drag it, so they can keep it visible while working elsewhere.
- **Consider letting people detach a popover,** and keep the panel's appearance close to the original so people keep their context.

### visionOS, tvOS and watchOS

- Not supported in tvOS or watchOS. visionOS has no additional considerations.

---

## Alerts

An alert gives people critical information they need right away. It is a modal view that interrupts the current task.

### Best practices

- **Use alerts sparingly.** Each alert should carry only essential information and useful actions.
- **Do not use an alert merely to inform.** If the information is not actionable, show it in context instead. For example, Mail shows an indicator when the server is unavailable, and people can choose to learn more.
- **Do not alert people about common, undoable actions,** even destructive ones such as deleting an email. Use an alert for an uncommon destructive action that cannot be undone, in case it was done by accident.
- **Do not show an alert at launch.** If the app needs to share important information at startup, make it discoverable in another way. For a network problem, show cached or placeholder data with a quiet label.

### Content

- **Use a direct, neutral, approachable tone.** Do not be oblique or accusatory, and do not hide the seriousness of the problem.
- **Write a clear title** that describes what happened, the context and why, without being verbose. Avoid titles such as "Error" or "Error 329347 occurred". Keep titles to two lines at most. Use sentence case with full punctuation for complete sentences. For a fragment, use title case with no ending punctuation.
- **Add informative text only if it adds value.** Keep it short, with complete sentences.
- **Do not explain the buttons** if the text and titles are clear.
- **Include a text field only when you need input** to resolve the situation, such as a password.
- Alerts have a title, optional informative text and up to three buttons.
- On iOS, iPadOS, macOS and visionOS, an alert can include a text field. macOS and visionOS can also include an icon and an accessory view.

### Buttons

- **Use short, logical titles,** usually one or two words that describe the result, such as View All, Reply or Ignore. In purely informational alerts, OK is acceptable. Use Cancel for the button that cancels the action. Avoid Yes and No.
- **Avoid OK as the default title** unless the alert is purely informational. A specific title such as Erase, Convert, Clear or Delete is clearer.
- **Place buttons where people expect.** The most likely choice goes on the trailing side of a row, or at the top of a stack. The default button goes on the trailing side or at the top. Cancel usually goes on the leading side of a row or at the bottom of a stack.
- **Use the destructive style** for a button that performs a destructive action people did not deliberately choose. If people deliberately chose a destructive action such as Empty Trash, the alert's confirm button need not be destructive styled, because it matches their intent.
- **Include a Cancel button whenever there is a destructive action,** so people have a safe way out. Do not make Cancel the default button. If you want people to read the alert rather than press Return, do not make any button the default. A single-button alert that is also the default should use Done, not Cancel.
- **Provide quick ways to cancel.** Escape or Command-Period works on iOS, iPadOS, macOS and visionOS with an attached keyboard. Menu on the remote works on tvOS. Exiting to the Home Screen also works on iOS and iPadOS.

### iOS and iPadOS

- **Use an action sheet, not an alert,** when people need to choose between options related to an intentional action. For example, cancelling an email draft might offer Delete Draft, Save Draft or Keep Editing.
- **Avoid alerts that scroll.** Keep titles short and messages brief.

### macOS

- macOS shows your app icon in alerts by default. You can supply another icon or symbol.
- You can set up repeating alerts that let people suppress future occurrences, add an accessory view, or add a Help button.
- **Use the caution symbol sparingly.** Use it only when extra attention is really needed, such as before an action that may cause unexpected data loss. Do not use it for simple saves or emptying the trash.

### visionOS

- In the Shared Space, an alert appears in front of the app's window. If the person moves the window, the alert stays anchored to it.
- In a Full Space, the alert is centred in the person's field of view.
- An accessory view in a visionOS alert can be at most 154 pt high, with a 16 pt corner radius.

### tvOS and watchOS

- No additional considerations.

---

## Windows

A window presents the views and components of your app. On iPadOS, macOS and visionOS, windows define the visual boundaries of content, separate it from the rest of the system, and enable multitasking within and between apps. Windows include system elements such as frames and controls that let people open, close, resize and move them.

There are two kinds of window:

- A **primary** window presents the app's main navigation and content.
- An **auxiliary** window presents one specific task or area. It does not navigate to other parts of the app, and it usually has a button to close it when the task is done.

### Best practices

- **Make windows adapt fluidly to different sizes,** so they work with multitasking. See Layout and Multitasking.
- **Choose the right moment to open a new window.** It helps people multitask or keep context, as Mail does when composing. Too many windows create clutter, so avoid opening them by default.
- **Offer a way to open content in a new window** through a context menu or the File menu, so people can choose.
- **Do not build custom window UI.** People recognise system windows. A custom frame or control that does not match the system look and behaviour makes the app feel broken.
- **Use the word "window"** in user-facing text. Terms such as "scene" will confuse people.

### iPadOS

- **Full screen:** windows fill the screen, and people switch between them with the app switcher.
- **Windowed:** people can resize windows freely, have several open at once, and move them. The system remembers size and position, even after the app closes.
- **Keep window controls clear of toolbar items.** In windowed mode, controls appear at the leading edge of the toolbar and can hide buttons placed there. Move leading buttons inward when the controls appear.
- **Consider letting people open content in a new window** with a gesture, such as a pinch on a Notes item.
- If people only need to view one file, you can present it without a custom window, but you still must support multiple windows in the app.

### macOS

- People run several apps at once, move and resize windows, and switch between them often.
- **Window anatomy:** a window has a frame, which holds the window controls and an optional toolbar, and a body area. People move a window by its frame and resize it by its edges. A bottom bar is rare.
- **Main window:** the frontmost window of an app. There is only one main window per app.
- **Key window:** the active window, which accepts input. There is only one key window on screen at a time. A panel can be key while the main window stays main.
- **Inactive window:** a window that is not in the foreground. Inactive windows lose vibrancy and look subdued.
- **Use system appearances for custom windows.** System components update automatically when the state changes. Custom implementations must handle this themselves.
- **Avoid critical information or actions in a bottom bar,** because people often move windows so the bottom edge is hidden. A bottom bar suits small, related information, such as the item count in Finder's status bar.

### visionOS

- **Window:** an upright plane with a glass background, a close button, window bar and resize controls. It can include a Share button, tab bar, toolbar and ornaments.
- **Volume:** displays 2D or 3D content that people view from any angle. Its close button and window bar turn to face the viewer.
- **Prefer a window** for familiar, UI-centred interfaces. **Prefer a volume** for rich 3D content.
- **Keep the glass background.** Removing it reduces legibility, and an opaque background makes the window feel heavy.
- **Choose a sensible initial size.** The default is 1280 x 720 pt. Avoid large empty areas, and let the content's shape guide the initial shape.
- **Set minimum and maximum sizes** so the layout works at every size.
- **Keep 3D depth in a window shallow.** The system clips 3D content that extends too far from the window's surface. Use a volume for greater depth.
- **Place 2D content in a volume so it looks right from several angles.** Use an attachment to pin 2D content to 3D areas.
- **Use dynamic scaling in general.** Fixed scaling is for content that represents a real-world object, such as a product in a retail app.
- **Use the default baseplate glow** to show the edges of a volume, unless the content fills it or you have a custom baseplate.
- **Consider one ornament** for high-value content in a volume, placed away from the toolbar or tab bar.
- **Choose the alignment that suits the interaction.** A volume that stays level suits content that people rarely touch. A volume that tilts towards the viewer suits interactive content.

### tvOS, watchOS and iOS

- Not supported.
