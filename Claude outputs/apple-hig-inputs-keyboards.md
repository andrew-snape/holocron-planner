# Apple Human Interface Guidelines: Inputs (Keyboards)

Source: https://developer.apple.com/design/human-interface-guidelines/keyboards
Copyright 2026 Apple Inc. All rights reserved.

This file covers the Keyboards page. The full standard shortcuts table on Apple's page is long, so this file keeps the shortcuts most relevant to Mac apps and a web or Mac design context. The complete table is on Apple's page.

Platform sections for visionOS are summarised. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Discussion

A physical keyboard is an essential input device for entering text, playing games and controlling apps. People can connect one to any device except Apple Watch. Mac users use a keyboard all the time, and iPad users often do too. Many people prefer a physical keyboard over a virtual one when they enter a lot of text.

A keyboard shortcut is a combination of a primary key and one or more modifier keys (Control, Option, Shift and Command) that maps to a command. In a game, a shortcut is called a key binding and often uses a single key.

Apple defines standard shortcuts that work across the system and most apps, so people can carry their knowledge from one app to another. Apps may define custom shortcuts for the commands people use most. Games usually define custom key bindings.

---

## Best practices

- **Support Full Keyboard Access where possible.** It is available on iOS, iPadOS, macOS and visionOS. It lets people navigate and activate windows, menus, controls and system features using only the keyboard. Turn it on in the Accessibility settings to test your app.
- **On iPadOS, do not build keyboard navigation for controls** such as buttons, segmented controls and switches. Keyboard navigation works for text fields, text views and sidebars. Let people use Full Keyboard Access to reach and activate controls instead.
- **Respect standard shortcuts.** People expect them to work everywhere. For a frequently used custom action, create a new shortcut rather than repurposing a standard one that means something else.

---

## Standard keyboard shortcuts

Repurpose a standard shortcut only when its action does not make sense in your app. For example, an app with no text editing has no need for Command-I Italic, so Command-I could be used for Get Info instead.

The table below keeps the shortcuts most useful to Mac apps. Apple's page has the full list.

| Shortcut | Action |
|---|---|
| Command-Space | Show or hide Spotlight search |
| Control-Command-Space | Show the Special Characters window |
| Tab, Shift-Tab | Move forward or backward through controls |
| Command-Tab, Shift-Command-Tab | Move forward or backward through open apps, by recent use |
| Control-Tab | Move to the next group of controls in a dialog, or the next table cell |
| Escape | Cancel the current action or process |
| Option-Command-Escape | Open the Force Quit dialog |
| Command-Grave accent | Activate the next window of the frontmost app |
| Shift-Command-Grave accent | Activate the previous window of the frontmost app |
| Control-Command-F | Enter full screen |
| Option-Command-D | Show or hide the Dock |
| Option-Command-T | Show or hide a toolbar |
| Command-A | Select all items, or all characters in a text field |
| Command-B | Bold the selected text, or toggle bold |
| Command-C | Copy the selection |
| Command-E | Use the selection for a find operation |
| Command-F | Open a Find window |
| Command-G, Shift-Command-G | Find the next or previous occurrence |
| Command-H | Hide the windows of the current app |
| Option-Command-H | Hide the windows of all other apps |
| Command-I | Italicise the selected text, or toggle italic |
| Option-Command-I | Display an inspector window |
| Command-J | Scroll to the selection |
| Command-M | Minimise the active window to the Dock |
| Option-Command-M | Minimise all windows of the active app |
| Command-N | Open a new document |
| Command-O | Open a document |
| Command-P | Print |
| Shift-Command-P | Page Setup |
| Command-Q | Quit the app |
| Command-S | Save |
| Shift-Command-S | Duplicate, or Save As |
| Command-T | Show the Fonts window |
| Command-U | Underline the selected text, or toggle underline |
| Command-V | Paste |
| Option-Shift-Command-V | Paste and match the style of the surrounding text |
| Command-W | Close the active window |
| Shift-Command-W | Close the file and its windows |
| Option-Command-W | Close all windows in the app |
| Command-X | Cut |
| Command-Z | Undo |
| Shift-Command-Z | Redo, where Undo and Redo are separate commands |
| Command-Comma | Open the app's settings window |
| Command-Period | Cancel an operation |
| Command-Question mark | Open the app's Help menu |
| Command-Hyphen | Decrease the size of the selection |
| Shift-Command-Equal sign | Increase the size of the selection |
| Command-Left bracket | Left-align the selection |
| Command-Right bracket | Right-align the selection |
| Command-Pipe | Centre-align the selection |
| Command-Semicolon | Find misspelled words in the document |
| Shift-Command-3 | Capture the screen to a file |
| Control-Shift-Command-3 | Capture the screen to the Clipboard |
| Shift-Command-4 | Capture a selection to a file |
| Control-Shift-Command-4 | Capture a selection to the Clipboard |

Notes:

- Command-Comma opens settings, so an app's Settings should use it.
- Command-Period cancels an operation, which pairs well with a Cancel button.
- The system uses Control-based shortcuts for focus movement and screenshots, so avoid building your own on Control.

---

## Custom keyboard shortcuts

- **Define custom shortcuts only for the most frequently used commands.** Too many make an app hard to learn.
- **Use modifier keys the way people expect.** Command while dragging moves items as a group. Shift while resizing keeps the aspect ratio. Holding an arrow key moves the selection by the smallest unit the app defines.

### Modifier keys

- **Command:** the main modifier for custom shortcuts.
- **Shift:** a secondary modifier that complements a related shortcut.
- **Option:** use sparingly, for less common commands or power features.
- **Control:** avoid it. The system uses Control in many system features and shortcuts, such as moving focus and taking screenshots.

Some keyboard layouts need modifiers to make certain characters, so avoid extra modifiers with characters that are not on every keyboard. If you must use a modifier other than Command, use it only with alphabetic keys.

- **List modifiers in this order:** Control, Option, Shift, Command.
- **Do not add Shift to a shortcut for a two-character key.** Write the upper character instead. The Help shortcut is Command-Question mark, not Shift-Command-Slash.
- **Let the system localise and mirror shortcuts.** It adjusts the keys to the connected keyboard, and mirrors shortcuts in right-to-left layouts.
- **Do not add a modifier to an existing shortcut for an unrelated command.** Shift-Command-Z is confusing as anything other than redo, because people expect Command-Z to undo.

---

## Platform notes

- **iOS, iPadOS, macOS and tvOS:** no additional considerations.
- **watchOS:** not supported.
- **visionOS:** holding Command on a connected keyboard shows the app's shortcuts, grouped into system categories such as File, Edit and View. Each shortcut title must make sense on its own, because submenu titles are not shown. Expect a virtual keyboard overlay that offers typing suggestions when a physical keyboard is connected.

---

## Notes for this project

For Holocron on macOS, follow the Mac pattern. Add Command-N for a new event or lesson, Command-F to find a student or lesson, Command-Comma for settings, Command-W to close windows, and Command-Z and Shift-Command-Z for undo and redo. Keep Escape as the cancel key in sheets and dialogs.
