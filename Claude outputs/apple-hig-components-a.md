# Apple Human Interface Guidelines: Components (Part A)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Lists and tables, Split views, Tab views, Labels, Boxes, Buttons.

Platform sections for visionOS, watchOS and tvOS are summarised where they do not apply to your projects. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Lists and tables

Lists and tables present data in one or more columns of rows. They can show grouped or hierarchical data and support selecting, adding, deleting and reordering. Many apps use lists to show an overall information hierarchy, and productivity apps use multicolumn tables with sortable columns.

### Best practices

- **Prefer displaying text in a list or table.** The row format suits text that is easy to scan. If items vary widely in size, or you need to show many images, consider a collection instead.
- **Let people edit a table when it makes sense.** People appreciate reordering even if they cannot add or remove items. On iOS and iPadOS, people must enter an edit mode before they can select table items.
- **Give feedback when people select a row.** A table used to navigate a hierarchy keeps the selected row highlighted to show the path. A table of options often highlights a row briefly and adds a checkmark to show the selection.

### Content

- **Keep item text succinct.** Short text reduces truncation and wrapping. If each item holds a lot of text, list only the titles and let people open a detail view.
- **Preserve readability of clipped text.** In a narrow table, a middle ellipsis keeps both the start and the end of an item recognisable.
- **Use descriptive column headings in a multicolumn table.** Use nouns or short noun phrases in title-style capitalisation, with no ending punctuation. A single-column table without a heading needs a label or header that explains its context.

### Style

- **Choose a table or list style that suits your data and platform.** Grouped styles use headers, footers and extra space to separate groups. macOS offers a bordered style with alternating row backgrounds for large tables.
- **Choose a row style that fits the information.** For example, a small image at the leading edge followed by a short label. Several platforms provide built-in row layouts for this.

### macOS

- **When it adds value, let people click a column heading to sort.** Clicking the heading of a column that is already sorted reverses the direction.
- **Let people resize columns.** Data widths vary, and people want to reveal clipped content.
- **Consider alternating row colours in a wide multicolumn table.** Alternating colours help people track values across columns.
- **Use an outline view for hierarchical data.** An outline view looks like a table but includes disclosure triangles for nested levels, such as folders and the items inside them.

### iOS, iPadOS and visionOS

- **Use an info button only to reveal more information about a row.** An info button does not support drilling into a hierarchy. For that, use a disclosure indicator (a chevron).
- **Avoid an index in a table with trailing controls.** An index runs along the trailing edge and competes with disclosure indicators, making both harder to use.

### tvOS and watchOS

- **tvOS:** Check that images near a table still look right, because a focused row enlarges and its corners round. Do not add your own corner masks.
- **watchOS:** Limit the number of rows, and provide a way to see more when a list is long. Keep detail views short if you want people to swipe vertically between them.

---

## Split views

A split view manages the presentation of multiple adjacent panes. Each pane can hold tables, collections, images or custom views.

### Discussion

Typically, a split view shows several levels of the app's hierarchy at once. Selecting an item in the primary pane shows its contents in the secondary pane, and an optional tertiary pane can show further detail. The most common use is a sidebar for navigation. Less often, panes supplement the main view, such as the slide navigator, presenter notes and inspector in Keynote on macOS.

### Best practices

- **Persistently highlight the current selection** in each pane that leads to a detail view. This keeps people oriented.
- **Consider letting people drag and drop content between panes.** This moves content from one part of the app to another. See Drag and drop.

### iOS and iPadOS

- **Prefer a split view in a regular, not compact, environment.** Multiple panes need horizontal space. On an iPhone in portrait, panes wrap or truncate and become hard to use.
- **iPadOS can use two panes (like Mail) or three (like Keynote).** Windows resize fluidly, so check the layout at narrow, compact and intermediate widths. Make sure people can move between panes logically. See Layout.

### macOS

- **Panes can be vertical, horizontal or both,** with dividers that people drag to resize.
- **Set reasonable minimum and maximum pane sizes.** If a pane gets too small, the divider seems to vanish and becomes hard to grab.
- **Consider letting people hide a pane.** In Keynote, people can hide the navigator and presenter notes to focus on editing.
- **Provide more than one way to reveal a hidden pane.** For example, a toolbar button and a menu command with a keyboard shortcut.
- **Prefer the thin divider style.** It is one point wide, which leaves the most room for content. Use a thicker divider only when both sides hold strong linear content that makes a thin divider hard to see.

### tvOS, visionOS and watchOS

- **tvOS:** A split view works well for filtering. Choose between a one-third and two-thirds layout, or half and half. Show one title above the whole split view. Centre it when the secondary pane holds a collection, and place it above the primary view when the secondary pane holds a single main view.
- **visionOS:** Prefer a split view to a new window for supplementary information, because new windows can confuse navigation. For a small request or a simple task, use a sheet.
- **watchOS:** The split view shows either the list or one detail view at full screen. Show the most relevant detail first. If there are several detail pages, place them in a vertical tab view so people can scroll between them with the Digital Crown.

---

## Tab views

A tab view presents multiple mutually exclusive panes of content in the same area. People switch between panes with a tabbed control.

### Best practices

- **Use a tab view for closely related content.** Tabs give a strong sense of enclosure, so people expect each pane to relate to the others.
- **Keep each pane self-contained.** Controls in a pane should affect only that pane.
- **Label each tab with what its pane contains.** Use nouns or short noun phrases in title-style capitalisation. A short verb phrase can work in some contexts.
- **Avoid a pop-up button to switch tabs.** A tabbed control needs one click and shows every choice at once. A pop-up needs two clicks and hides its choices. A pop-up can be reasonable when there are too many panes to show as tabs.
- **Avoid more than six tabs.** Beyond six, the interface gets crowded. Consider a pop-up menu of views instead.

### Anatomy

The tabbed control sits on the top edge of the content area. You can hide it when the app switches panes programmatically. The content area can be borderless, bezelled or bordered with a line. In general, inset the tab view with a margin of window-body area on all sides, which leaves room for related controls. Extending a tab view to the window edges is unusual.

### Platform notes

- **iOS and iPadOS:** Tab views are not supported. Use a segmented control for similar behaviour.
- **tvOS and visionOS:** Not supported.
- **watchOS:** Tab views use page controls.

---

## Labels

A label is a static piece of text that people can read and often copy, but not edit.

### Discussion

Labels display text throughout the interface, in buttons, menu items and views. They help people understand the current context and what they can do next. A label inside a button generally says what the button does, such as Edit, Cancel or Send. Within a list, a label describes each item, often with a symbol or image. Within a view, a label can introduce a control or describe an action.

### Best practices

- **Use a label for a small amount of text people do not need to edit.** For small editable text, use a text field. For large text, optionally editable, use a text view.
- **Prefer system fonts.** Labels support Dynamic Type by default. If you change the style or use a custom font, keep the text legible.
- **Use system label colours to show relative importance.** There are four.

| System colour | Example usage | macOS equivalent |
|---|---|---|
| Label | Primary information | labelColor |
| Secondary label | A subheading or supplemental text | secondaryLabelColor |
| Tertiary label | Text describing an unavailable item or behaviour | tertiaryLabelColor |
| Quaternary label | Watermark text | quaternaryLabelColor |

- **Make useful label text selectable.** If a label holds information such as an error message, a location or an IP address, let people select and copy it.

### macOS

To display uneditable text in a label, make a text field non-editable (developer note: the isEditable property of NSTextField).

### watchOS

Date and timer text components adapt automatically to the available space and update without extra work from your app. Consider using them in complications.

---

## Boxes

A box creates a visually distinct group of logically related information and components. By default, a box uses a visible border or background colour to separate its contents from the rest of the interface. It can also include a title.

### Best practices

- **Keep a box relatively small** compared with its containing view. As a box approaches the size of the window, it stops separating its contents well and can crowd other content.
- **Use padding and alignment for subgroups.** A box's border is a strong visual element, and nested boxes make an interface feel busy and cramped.

### Content

- **Provide a succinct title if it helps.** A title explains why the contents are related, and helps VoiceOver users predict what they will hear.
- **Write a brief phrase for the title.** Use sentence-style capitalisation and no ending punctuation. In a settings pane, end the title with a colon.

### Platform notes

- **iOS and iPadOS:** Boxes use the secondary and tertiary background colours by default.
- **macOS:** The box title sits above the box by default.
- **visionOS:** No additional considerations.
- **tvOS and watchOS:** Not supported.

---

## Buttons

A button initiates an instantaneous action. It combines three attributes to communicate its function: a **style** (size, colour and shape), **content** (a symbol, a text label or both) and a **role** (its system-defined meaning, which can also affect appearance). Related components include toggles, pop-up buttons and segmented controls.

### Best practices

- **Make buttons easy to use.** Leave enough space around a button so people can tell it apart from nearby content. As a general rule, a button needs a hit region of at least 44 x 44 pt (60 x 60 pt in visionOS), whether people use a fingertip, a pointer, their eyes or a remote.
- **Always include a press state for a custom button.** Without one, a button can feel unresponsive.

### Style

- **Use a prominent style for the most likely action in a view.** The system applies the accent colour to its background. Keep prominent buttons to one or two per view, because too many increase the effort of choosing.
- **Use style, not size, to pick out the preferred option.** Buttons of the same size signal a coherent set of choices. To highlight the preferred option, give it a more prominent style.
- **Avoid similar colours on button labels and content-layer backgrounds.** If the content is already bright and colourful, prefer the default monochromatic button labels. See Liquid Glass colour in the Color guidance.

### Content

- **Make sure each button clearly communicates its purpose.** Use a symbol, a text label or both.
- **Show tooltips where they help.** In macOS and visionOS, a tooltip appears after the pointer or gaze rests on a button. See Offering help.
- **Use familiar icons for familiar actions.** For example, the share symbol for sharing. Check the standard icons list.
- **Use text when a short label is clearer than an icon.** Use title-style capitalisation and, where it helps, start with a verb, such as "Add to Cart".

### Role

A system button can have one of four roles:

- **Normal:** no specific meaning.
- **Primary:** the default button, which people are most likely to choose. It uses the app's accent colour and responds to the Return key.
- **Cancel:** cancels the current action.
- **Destructive:** can result in data loss. Uses the system red colour.

- **Assign the primary role to the most likely choice.** In temporary views such as sheets, alerts and editable views, this lets people press Return to confirm, and the view can close automatically.
- **Do not assign the primary role to a destructive action,** even if it is the most likely choice. Visual prominence makes people press it without reading, so keep nondestructive actions as primary.

### iOS and iPadOS

- **Show an activity indicator for actions that do not complete instantly.** Keep the label visible and change it to describe the progress, such as "Checking out" becoming "Checking out...". The indicator replaces the image while it runs.

### macOS button types

**Push buttons** are the standard type. They can show text, a symbol, an image or a combination, can be the default button, and can be tinted.

- Use a flexible-height push button only for tall or multi-line content. Otherwise use a standard push button.
- Add a trailing ellipsis to the title when the button opens another window, view or app.
- Consider spring loading. On a Magic Trackpad, people can drag selected items over a button and force click it without dropping the items.

**Square buttons** (also called gradient buttons) start an action related to a view, such as adding or removing table rows.

- They contain symbols, not text, and can behave as push buttons, toggles or pop-up buttons.
- Place them within or beneath the view they affect, not in the window frame or a toolbar. Use toolbar items for toolbars.
- Prefer SF Symbols. Do not add labels that introduce them, because their purpose is clear from context.

**Help buttons** are circular buttons containing a question mark. They open app-specific help.

- Use the system-provided help button so people recognise it.
- Where possible, open the help topic for the current context. If none applies, open the top level of the help documentation.
- Include no more than one help button per window.
- Place it in a consistent position. In a dialog with dismissal buttons, put it in the lower corner opposite them, vertically aligned. In a dialog without them, or in a settings window or pane, put it in the lower-left or lower-right corner.
- Keep it within a view, not in the toolbar or status bar, and do not add text that introduces it.

**Image buttons** show an image, symbol or icon within a view. They can behave as push buttons, toggles or pop-up buttons.

- Keep them in a view, not in the window frame. Use a toolbar item if you need one in a toolbar.
- Include about 10 pixels of padding between the image and the button edge, so clicks register even when they miss the image itself. Avoid the system border.
- If you need a label, place it below the button.

### visionOS

- Buttons include a visible background and play a sound on interaction, because visionOS does not play haptics.
- Standard shapes: a circle for icon-only buttons, a capsule for text-only or icon-and-text buttons, and a rounded rectangle for text-only buttons in a stack.
- Avoid a custom button with a white background and black text, because the system reserves that look for the toggled state.
- Keep button centres at least 60 pt apart, and add 4 pt of padding around buttons 60 pt or larger so the hover effect does not overlap.
- In a vertical stack, prefer rounded rectangles. In a horizontal row, prefer capsules.

### watchOS

- Inline buttons use the capsule shape and gain a material effect for legibility.
- Place corner buttons in a toolbar. The system moves the time and title to make room.
- Make primary actions full width, which is easier to tap. If two buttons share a row, give them the same height, with images or short titles.
- Use the same height for stacked one- and two-line text buttons.
