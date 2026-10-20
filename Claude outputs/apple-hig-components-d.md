# Apple Human Interface Guidelines: Components (Part D)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Text fields, Toggles, Pickers, Segmented controls, Steppers, Progress indicators.

Platform sections for tvOS, watchOS and visionOS are summarised or removed where they do not apply to your projects. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Text fields

A text field is a rectangular area where people enter or edit small, specific pieces of text, such as a name or an email address. For larger amounts of text, use a text view.

### Best practices

- **Show a hint** with placeholder text such as "Email" or "Password" when the field is empty. Placeholder text disappears as people type, so a separate label that describes the field is also useful.
- **Use a secure text field for private data,** such as a password. Always use one when the app asks for sensitive information.
- **Size the field to the expected amount of text.** The size helps people judge how much to enter.
- **Space multiple fields evenly and stack them vertically** where possible, with consistent widths. Each field's label should be easy to match to its field.
- **Make tabbing between fields follow a logical sequence.** The system usually does this automatically, so you rarely need to change it.
- **Validate at the right moment.** For an email address, validate when people leave the field. For a user name or password, validate before they move on.
- **Use a number formatter for numeric data.** It restricts input to numbers and can display decimal places, percentages or currency. Do not assume the presentation, because formats vary with the person's locale.
- **Choose how clipped text behaves.** By default, text beyond the field's edge is clipped. You can instead wrap text by character or word, or truncate it with an ellipsis at the start, middle or end.
- **Consider an expansion tooltip** to show the full text of clipped or truncated content on hover.
- **On iOS, iPadOS, tvOS and visionOS, show the keyboard type that suits the content,** such as a number keyboard for numbers or a URL keyboard for web addresses.
- **Minimise text entry on tvOS and watchOS.** Use buttons or other quicker ways to gather information.

### iOS and iPadOS

- **Show a Clear button** at the trailing end, so people can erase their input in one tap.
- **Use the ends of the field for clarity and function.** Use the leading end to show the field's purpose, and the trailing end for extra features such as a bookmarks button.

### macOS

- **Consider a combo box** when text entry should be paired with a list of choices.

### watchOS

- **Show a text field only when necessary.** A list of options is better where possible.

---

## Toggles

A toggle lets people choose between two opposing states, such as on and off, with a different appearance for each. Styles include switches and checkboxes, which differ by platform. Buttons can also behave like toggles by changing their appearance between states.

### Best practices

- **Use a toggle to manage the state of something,** choosing between two opposing values that affect content or a view. For a choice from a list, use a pop-up button instead.
- **Make clear what the toggle affects.** The surrounding context usually does this. On macOS, a label can describe the state being controlled. A toggle button needs an icon that explains its purpose, and its background should change with its state.
- **Make the visual difference between states obvious.** Add or remove a colour fill, show or hide a background shape, or change a checkmark or dot. Do not rely on colour alone, because not everyone can tell colours apart.

### iOS and iPadOS

- **Use the switch style only in a list row.** The row supplies the context, so no label is needed.
- **Change the switch colour only when necessary.** The default green works well in most cases. If you use the accent colour instead, make sure it contrasts with the off state.
- **Outside a list, use a toggle button rather than a switch.** For example, a filter button in the Phone app is highlighted when active and plain when inactive.
- **Do not add a label that explains a toggle button's purpose.** The icon and the background change should make it clear.

### macOS

- **Switch:** prefer a switch for settings you want to emphasise, such as one that turns on a group of settings. Within a grouped form, a mini switch keeps row heights consistent. For a hierarchy of settings, use a regular switch for the main setting and mini switches for the subordinate ones. Do not replace an existing checkbox with a switch.
- **Checkbox:** a small square that is empty when off, has a checkmark when on, and shows a dash when mixed. Use checkboxes for hierarchies of settings, aligned along the leading edge and indented to show dependencies. Use a mixed state when a parent checkbox controls subordinate checkboxes that differ.
- **Radio buttons:** a small circle, usually in groups of two to five, for mutually exclusive choices. Use checkboxes when people can pick several options. Use a checkbox rather than a single radio button for one on or off setting. If there are more than about five options, use a pop-up button.
- **Keep spacing consistent** when radio buttons sit in a row, measured against the longest label.
- **Use toggles in the window body,** not in the window frame or a toolbar or status bar.

---

## Pickers

A picker displays one or more scrollable lists of distinct values for people to choose from. The values, and their order, depend on the device language.

### Best practices

- **Use a picker for medium to long lists.** For a short list, a pull-down button is lighter. For a very large set, a list or table is better, because a table can include an index that helps people jump to a section.
- **Use predictable, logical order,** such as alphabetical. People can then guess where hidden values are.
- **Show the picker in context,** near the field being edited. It usually appears at the bottom of the window or in a popover, rather than on a separate screen.
- **Use less granularity for minutes** if it helps. The default is 60 values. You can use an interval that divides evenly into 60, such as quarter hours.

### iOS and iPadOS

Date pickers come in four styles:

- **Compact:** a button showing the current value. Tapping it opens a modal calendar-style editor, where people can make several changes before tapping outside to confirm.
- **Inline:** for time, a button that shows wheels; for dates and times, an inline calendar.
- **Wheels:** scrolling wheels that also accept keyboard entry.
- **Automatic:** the system chooses a style for the platform and mode.

Date pickers have four modes: Date, Time, Date and time, and Countdown timer. The countdown timer shows hours and minutes up to 23 hours and 59 minutes, and it is not available in the inline or compact styles.

- **Use the compact style when space is limited.** It shows the value in the app's accent colour.

### macOS

- **Textual** date pickers suit limited space and specific date and time entry.
- **Graphical** date pickers suit browsing days, selecting a range of dates, or a clock-face look.

### tvOS and watchOS

- **tvOS:** pickers are available through SwiftUI.
- **watchOS:** pickers are navigated with the Digital Crown. They can use a wheel style, and date and time pickers are available too. For longer lists, a navigation link shows the picker as a button that opens the full list. People can also scrub through the options with the Digital Crown without opening it.

### visionOS

- No additional considerations.

---

## Segmented controls

A segmented control is a linear set of two or more segments, each of which works like a button. Segments are usually equal in width, and can contain text or images.

A segmented control offers one choice from a set of options. On macOS it can also offer several choices at once, such as combining bold, italic and underline. It can also act as a set of buttons with no selection state, such as Reply, Reply All and Forward in Mail.

### Best practices

- **Use it for closely related choices** that affect an object, a state or a view. In an inspector, it might set attributes for a selection. In a toolbar, it might offer actions for the current view.
- **Use it when grouping matters,** or when the selection state must be clear at a glance. Unlike other button styles, segmented controls keep their grouping at any size.
- **Keep control types consistent.** Do not give segments actions in a control that shows selection, and do not show selection in a control that performs actions.
- **Limit the number of segments.** About five to seven in a wide interface, and about five on iPhone.
- **Keep segments a consistent size,** so the control looks balanced.

### Content

- **Use either text or images in a single control,** not a mix, because mixing them looks disconnected.
- **Use content of similar size** in each segment, since segments are equal in width.
- **Use nouns or noun phrases** in title-style capitalisation for segment labels.

### iOS and iPadOS

- **Use it to switch between closely related subviews.** For example, Calendar's New Event sheet switches between a new event and a new reminder. For separate sections of an app, use a tab bar instead.

### macOS

- **Add introductory text** to clarify the purpose if needed. If the segments use icons, consider a label below each one. Provide a tooltip for each segment.
- **For switching views in the main window area,** use a tab view. A segmented control suits switching views in a toolbar or inspector pane.
- **Consider spring loading** on a Mac with a Magic Trackpad, so people can activate a segment by dragging items over it.

### tvOS

- **Consider a split view instead** on screens that filter content, since it is easier to move between content and filters.
- **Keep other focusable elements away from segmented controls.** A segment becomes selected when focus reaches it, so nearby elements can be picked up by accident.

### visionOS

- When people look at a segmented control that uses icons, a tooltip shows the descriptive text you supply.

### watchOS

- Not supported.

---

## Steppers

A stepper is a two-segment control that people use to increase or decrease a value by a set increment. It does not show a value itself, so it sits next to a field that does.

### Best practices

- **Make the affected value obvious.** People need to know which value they are changing.
- **Pair a stepper with a text field** when large changes are likely or the values vary widely. Steppers suit small changes that take a few taps or clicks. A printing screen, for example, might offer both a stepper and a field for the number of copies.

### macOS

- **Support Shift-click** for large value ranges, so people can change the value by a larger amount, such as ten times the default increment.

### iOS, iPadOS and visionOS

- No additional considerations.

### tvOS and watchOS

- Not supported.

---

## Progress indicators

Progress indicators show that an app is still working while it loads content or performs a lengthy operation. They are transient, appearing only while the operation runs.

There are two types:

- **Determinate:** for a task with a known duration, such as converting a file. A progress bar fills from the leading side to the trailing side. A circular indicator fills clockwise.
- **Indeterminate (activity indicator):** for tasks with no measurable duration, such as loading or syncing complex data. It is usually a spinner. macOS also supports an indeterminate progress bar.

### Best practices

- **Use a determinate indicator when possible.** It helps people decide whether to wait, come back later or stop.
- **Report progress accurately,** and even out the pace. Showing 90 percent in five seconds and the last 10 percent over five minutes makes people doubt the app, and can feel deceptive.
- **Keep the indicator moving.** A stationary indicator suggests a frozen app. If the process stalls, explain the problem and what people can do about it.
- **Switch from indeterminate to determinate** as soon as you can measure the duration.
- **Do not switch between the circular and bar styles.** They differ in shape and size, which disrupts the interface.
- **Add a short, specific description** if it helps. Avoid vague words such as "loading" or "authenticating", which seldom add value.
- **Show the indicator in a consistent location,** so people can find the status of an operation quickly.
- **Let people halt a process** where that is safe, with a Cancel button. If stopping would lose work, such as a partial download, also offer Pause.
- **Warn people when stopping has a cost.** Use an alert that lets them confirm the cancellation or resume.

### iOS and iPadOS

- **Refresh content controls** let people reload a table by dragging it down, such as checking for new mail. The control is hidden until used.
- **Update content automatically as well.** People expect fresh content without having to refresh every time.
- **Add a title only if it adds value.** A title should give useful information about the content, not explain how to refresh.

### macOS

- **Prefer a spinner** for background operations or where space is tight, such as within a text field or beside a button.
- **Do not label a spinner.** It usually appears when people start a process, so a label is seldom needed.

### watchOS

- Progress indicators appear in white over the background by default. You can set a tint colour. Bars and rings fill from left to right and clockwise respectively.

### tvOS and visionOS

- No additional considerations.
