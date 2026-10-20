# Apple Human Interface Guidelines: Patterns (Part A)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Charting data, Drag and drop, Entering data, Feedback, File management, Going full screen.

Platform sections for visionOS, watchOS and tvOS are trimmed where they do not apply to your projects.

---

## Charting data

Presenting data in a chart can communicate information with clarity and appeal. Charts convey complex information without requiring people to read and interpret a lot of text, and they give you room to express the personality of your app.

A chart can be a simple glanceable graphic or a rich, interactive centrepiece. Use charts for data-driven tasks such as:

- Analysing trends from historical or predicted values
- Showing the current state of a process, system or quantity that changes over time
- Comparing items, or the same item at different times, across categories

Not every dataset needs a chart. If people only need the data and do not need to analyse it, a list or table they can scroll, search and sort may serve better.

### Best practices

- **Use a chart to highlight important information about a dataset.** Charts draw attention, so make clear what people can learn from them.
- **Keep charts simple.** Too much data makes a chart overwhelming and hides the relationships you want to show. If there is a lot of data or functionality, reveal it gradually, for example through levels of detail or subsets of data. For an interactive chart, you can offer several versions, each with a little more functionality than the last, to teach people how to use it.
- **Make every chart accessible.** Provide accessibility labels that describe chart values and components, and accessibility elements that help people interact with the chart.

### Designing effective charts

- **Prefer common chart types** such as bar and line charts. People already know how to read them.
- **If a chart presents data in a novel way, teach people how to read it.** For example, Activity animates each ring individually to show how it maps to a metric.
- **Look at the data from several levels.** A macro view can show totals or averages. A mid-level view can reveal useful subsets. Individual points can draw attention to specific items.
- **Add descriptive text.** Titles, subtitles, annotations and a short headline or summary help people grasp the key message at a glance. Descriptive text does not replace accessibility labels.
- **Match the size of the chart to its job.** It must be large enough for labels and annotations, and roomy enough for any interaction. A small chart works well as a glanceable snapshot of a larger one.
- **Be consistent across charts.** If charts serve a similar purpose, use a similar type and style. Vary them only to highlight meaningful differences.
- **Keep continuity across charts that share data.** When people move from a summary to a detailed view of the same data, keep the chart type, colours, annotations and layout consistent so the relationship is clear.

---

## Drag and drop

Drag and drop lets people move or duplicate selected content, such as photos or text, by dragging the selection from a source to a destination. The source and destination can be in the same container, in different containers, or in different apps.

Dropping content within the same container usually moves it. Dropping into a different container usually copies it. Dragging between apps always copies.

People drag in different ways on each platform: pinching and holding in visionOS, touch or a pointer on iOS and iPadOS, a pointer or VoiceOver on macOS, and Universal Control between Mac and iPad.

### Best practices

- **Support drag and drop throughout your app** where it makes sense. System text fields and text views give you built-in support.
- **Offer alternatives.** Some people cannot drag easily. Provide menu commands to copy and move items. On iOS and iPadOS, use accessibility APIs so assistive technologies can identify sources and destinations.
- **Decide when a drop moves or copies.** Use the behaviour people expect. A move makes sense within one container, and a copy makes sense between containers. Avoid defaults that could cause frustration or data loss.
- **Support multi-item drag** where it makes sense. People can select several items and drag them as a group. On iPadOS, people can add more items to a drag already in progress.
- **Let people undo a drop.** If a drop cannot be undone, ask for confirmation first. Where possible, provide another way to reverse the result.
- **Offer multiple versions of dragged content,** ordered from highest to lowest fidelity. For example, offer a vector PDF, then a lossless PNG with transparency, then a lossy JPEG. The destination picks the best one it accepts.
- **Consider spring loading.** Dragging content over a button or segmented control can activate it. Calendar uses this to move events between date segments.

### Feedback

Drag and drop is dynamic, so give clear, continuous feedback throughout.

- **Show a drag image** as soon as people drag a selection about three points. A translucent image is helpful because it distinguishes the drag from the original and lets people see destinations as they pass over.
- **Modify the drag image if it adds clarity.** For example, a photo's drag image can expand to show its default size in a document. Drag flocking can group multiple items. Avoid changes that are constant or radical, because they distract.
- **Show whether a destination accepts the content.** Show an insertion point or highlight only when the destination can accept the item. Show no feedback, or an explicit "not allowed" image such as `circle.slash`, when it cannot. Remove feedback when the content moves away. When there are several possible destinations, show one at a time.
- **Give feedback on invalid or failed drops.** The item can return to its source, or it can scale up and fade out, as if it evaporated.

### Accepting drops

- **Scroll the destination when necessary.** Content in a scrolling container should scroll as the dragged item nears the edge. System text views do this by default.
- **Pick the richest version you can accept.** If an app offers a native chart object and an image of it, and your app supports charts, take the native object. Otherwise take the image.
- **Extract only the relevant part.** When a contact is dropped into an email recipient field, show the name and address, not the full contact card.
- **Check for the Option key at drop time** on a physical keyboard. Holding Option during a drag within one container turns the move into a copy.
- **Show feedback while content transfers.** Use a progress indicator for longer transfers. In lists, tables and collections, show a placeholder at the drop location so people can find the content when it arrives.
- **Show feedback when a drop starts a task,** such as printing, and keep people informed of progress.
- **Style dropped text sensibly.** If source and destination support the same text styles, keep the original font and size. Otherwise apply the destination's style.
- **Keep the selection state after a drop.** The dropped content should stay selected in the destination so people can act on it right away. Deselect or remove the selection in the source as appropriate.

### Platform notes

- **iOS and iPadOS.** People can add items to a drag in progress and drop them together. Support multiple simultaneous drops.
- **macOS.** Consider letting people drag content to the Finder in a format your app can reopen later, such as an `.ics` file for an event. Text dragged to the Finder appears as a clipping, which is separate from the Clipboard. People can drag from an inactive window without first activating it. They can drag an unselected item without losing an existing background selection. A badge can show how many items are being dragged. Change the pointer to indicate the outcome, such as copy, drag link, disappearing item or operation not allowed.
- **visionOS.** When people drop content into empty space, your app can open a window that handles it, such as a browser for a URL.

---

## Entering data

When you need information from people, make it easy to provide and hard to get wrong. Entering information is tedious regardless of the input method, so:

- Gather as much information as possible in advance, so people supply less.
- Support every available input method, so people can choose what suits them.

### Best practices

- **Get information from the system where you can.** Do not ask for data you can read from settings, or get with permission, such as location or calendar.
- **Be clear about the data you need.** Use a prompt inside the field, such as "username@company.com", or an introductory label, such as "Email". Prefill sensible defaults where you can, to reduce decisions and speed entry.
- **Use a secure text field for sensitive data,** so input is obscured as it is typed.
- **Never prefill a password field.** Ask people to type it, or use biometric or keychain authentication.
- **Offer choices instead of typing where possible.** Pickers, menus and other selection controls are often faster than typing, even with a keyboard.
- **Support drag and drop and paste** for data entry. It makes your app feel integrated with the rest of the system.
- **Validate values as people type.** People get frustrated when they must return and fix mistakes in a long form. Show a problem as soon as you detect it. For numbers, use a number formatter so the field accepts only numeric values, and format the display as needed, such as decimal places, percentage or currency.
- **Make it clear what must be completed before proceeding.** If a Next or Continue button follows required fields, enable it only once those fields are filled in.

### macOS

- **Use an expansion tooltip** to show the full text of a clipped or truncated field when the pointer rests on it. This helps people see everything they entered when a field is too small to display it.

---

## Feedback

Feedback helps people know what is happening, discover what to do next, understand the results of their actions and avoid mistakes.

Feedback can communicate:

- The current status of something
- The success or failure of an important task or action
- A warning about an action with negative consequences
- An opportunity to correct a mistake or problem

The most effective feedback matches its delivery to its significance. Status information is often best shown passively, so people can check it when they want. A warning about possible data loss needs to interrupt.

### Best practices

- **Make all feedback accessible.** Use more than one channel where you can: colour, text, sound and haptics. People can then receive the feedback whether they have silenced their device, looked away or use VoiceOver.
- **Integrate status feedback into the interface.** Show status near the items it describes, so people do not have to leave their context. Mail, for example, shows the number of unread messages in the mailbox toolbar.
- **Use alerts for critical information,** ideally with an action people can take. Alerts interrupt, so use them sparingly and only for important information.
- **Warn before unexpected, irreversible data loss.** Do not warn when data loss is the expected result. The Finder does not warn every time someone moves a file to the Trash, because that is the expected result.
- **Confirm significant completed actions** when it helps, such as a successful payment. Reserve confirmations for important actions. People expect success, so they mainly need to know when something fails.
- **Explain when a command cannot be carried out.** For example, if directions are requested without a destination, say so and explain why.

### watchOS

- Avoid indeterminate progress indicators in watchOS apps, because they make people feel they must keep watching. Reassure people that they will get a notification when the process completes.

---

## File management

Document-based apps, such as Pages, Keynote, Photos and Preview, help people create, edit and save documents. They also offer ways to browse for content to open.

People also expect to browse files without opening an app. On a Mac they use the Finder. On iPhone, iPad and Apple Vision Pro they use the Files app.

### Creating and opening files

- **Use menus and keyboard shortcuts** for New and Open. On iPadOS, these appear in the Command-key shortcut sheet. On macOS, they appear in the File menu. Also include an Add (+) button so people can create a document without a keyboard.
- **If you build a custom file browser, respect the file system people know.** Open to the most relevant location, such as a Documents or iCloud folder, or the last place used. Let people browse the rest of the file system too.

### Saving work

- **Preserve work automatically.** Avoid making people save explicitly. Save periodically while editing, and when a file is closed or the app is left.
- **Hide file extensions by default,** but let people show them. Reflect the current choice in every save and open interface.

### Quick Look

Quick Look previews files your app handles. Some previews are interactive, for example playing audio, marking up a photo, or rotating a 3D file.

- **Use a Quick Look viewer** so people can preview files your app cannot open, without leaving the app.
- **Consider a Quick Look generator** if your app creates custom file types. It lets the Finder, Files and Spotlight show previews of your documents.

### iOS and iPadOS

- **Document launcher (iOS 18 and iPadOS 18 and later).** Document-based apps can use the system launcher, a full-screen view with three parts: a title card with two app-specific buttons, a background with optional accessory images, and a sheet with a file browser and optional controls.
  - Assign the primary button to the most important action, usually creating a new document. The secondary button can offer more options.
  - Use a background clearly distinct from the accessories and title card. A solid colour, gradient or pattern works. Avoid complex images that distract.
  - Place accessories carefully, so the app name and both buttons stay clearly visible. Test across the sizes and orientations you support.
  - Use animation sparingly. Gentle, repeating motion that subtly highlights content works best.
- **File provider app extension.** If your app shares files with others, a file provider extension gives a custom interface for importing, exporting, opening and moving documents.
  - Show only documents that suit the current context. A PDF editor loading the extension should list PDFs only.
  - When exporting or moving, let people choose a destination in your directory hierarchy, and allow new subfolders.
  - Avoid a custom top toolbar. The extension already sits in a modal view with a toolbar.

### macOS

- **Use the default file browser** unless you have an important reason not to. People know the Finder and document-based apps well.
- **Make a custom open interface convenient.** Offer "open recent" alongside "open", filters, and multi-select where it makes sense. You can rename the Open button to fit the task, such as Insert.
- **Provide a save interface** that lets people change the name, format and location. Default to a logical folder. If you support several formats, let people choose one.
- **Extend the Save dialog where useful.** An accessory view can add options. For example, the Mail save dialog includes an option to include attachments.
- **Finder Sync extensions.** If your app syncs local and remote files, a Finder Sync extension can show sync badges, add contextual menu items and add toolbar buttons for global actions.
- **Help people avoid losing work if autosave is off.** When people turn off autosaving, show unsaved changes with a dot on the close button and next to the document name in the Window menu. Present a save dialog when they close the document, quit, log out or restart. When autosave is on, do not show the dot, because it implies action is needed. You can append "Edited" to the title bar, but remove it as soon as autosave runs or the work is saved.

---

## Going full screen

iPhone, iPad and Mac offer full-screen modes that expand a window to fill the screen, hiding system controls for a distraction-free environment. Apple TV and Apple Watch do not need this, because apps already fill the screen. Vision Pro uses window expansion and immersive experiences instead.

### Best practices

- **Offer full screen when it fits the experience.** It suits games, media such as videos and slideshows, and in-depth tasks that benefit from focus.
- **Adjust the layout in full screen if needed, but do not resize the window programmatically.** Keep essential content prominent and use the extra space well. Keep adjustments subtle, so the transition is not jarring.
- **Keep essential controls available.** A full-screen media experience needs playback controls that are always available or easy to reveal.
- **Keep the Dock accessible** on iPadOS and macOS, except in games. Games can avoid accidental Dock reveals: iPadOS can ignore the first swipe from the bottom edge, and macOS can hide the Dock.
- **Help people resume.** When they leave, pause a game or slideshow so nothing is missed.
- **Let people choose when to exit.** Do not end full screen automatically when a game or film finishes or when people switch away.
- **Hide toolbars and navigation when content is the focus,** such as full-screen photos or reading. Let people bring them back with a familiar gesture, such as tapping, swiping down or moving the cursor to the top of the screen. Keep controls visible when they are needed for navigation or tasks.

### iOS and iPadOS

- By default, the Home Screen indicator hides shortly after switching to a full-screen app, and reappears when people touch the bottom of the screen, so one swipe exits. Keep this default where you can. If accidental exits happen, you can require two swipes.

### macOS

- **Use the system full-screen support.** It handles the camera housing at the top of some Mac screens and other edge cases.
- **In games, do not change the display mode** when entering full screen. People expect control over their display, and changing it does not help performance.
- **Let people choose when to enter full screen.** Use the window's Enter Full Screen button, the View menu item or Control-Command-F. Avoid a custom menu of window modes. In a game, a custom toggle can turn full screen on and off.

---

## Resources

- Layout, Multitasking, Windows, The menu bar, Toolbars, Printing, Motion, Feedback and Alerts pages on Apple's HIG site.
