# Apple Human Interface Guidelines: Components (Part B)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Menus, Toolbars, The menu bar, Context menus, Pop-up buttons, Sidebars.

Platform sections for visionOS, watchOS and tvOS are summarised or removed where they do not apply to your projects. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Menus

A menu reveals its options when people interact with it, which makes it a space-efficient way to present commands. Menu items each represent a command, an option or a state that affects the current selection or context. The guidance on labels and organisation applies to all menus.

Several components include menus for specific uses. A pop-up button or pull-down button reveals options related to its action. A context menu offers a few frequently used actions for the current view. In macOS and iPadOS, the menu bar contains every command in the app.

### Labels

- **Write a clear, succinct label for each item.** Label an action with a verb or verb phrase, such as View, Close or Select.
- **Use title-style capitalisation.** Capitalise every word except articles, coordinating conjunctions and short prepositions, and always capitalise the last word.
- **Remove articles** such as a, an and the from labels to save space. They lengthen the label without adding clarity.
- **Show when an item is unavailable.** Unavailable items usually appear dimmed. If every item is unavailable, keep the menu itself available so people can see what it contains.
- **Add an ellipsis (…) when the action needs more information** before it can finish, usually in another view.
- **Show keyboard shortcuts in an app's menus.** Games rarely show them, because they handle a wider range of input devices.

### Icons

- **Use standard icons for common actions**, such as Share, Print and Search.
- **Use menu icons sparingly and with purpose.** Icons help people find items faster, but leave an item without an icon if you cannot find one that clearly represents it.
- **Be consistent within a group.** Give every item in a group an icon, or none of them.

### Organisation

- **List important or frequently used items first.** People scan a menu from the top.
- **Group logically related items** and separate the groups with a separator. Editing commands such as Copy, Cut and Paste belong together.
- **Keep related commands in one group** even if they differ in importance. Paste and Match Style belong with Copy and Cut.
- **Keep menus a manageable length.** If a menu is long, split it or use a submenu. The exception is a menu of user-generated content, such as Safari's History menu, where scrolling is acceptable.

### Submenus

- **Use submenus sparingly.** Consider one when a repeated term appears in more than two items in a group, such as Sort by Date, Sort by Score and Sort by Time. The submenu can then offer Date, Score and Time under a single Sort by item.
- **Keep submenus to one level** and no more than about five items. Otherwise, make a new menu.
- **Keep a submenu available** even when its items are unavailable, so people can still learn what it contains.
- **Use a submenu rather than indentation.** Indentation does not express relationships clearly in the system.

### Toggled items

- **Use a changeable label** that describes the current state, such as Show Map changing to Hide Map.
- **Add a verb if the label is unclear.** HDR On and HDR Off could be read as states, so Turn HDR On and Turn HDR Off make the action explicit.
- **Show both items if that helps.** For example, Take Account Online and Take Account Offline, with only the relevant one available.
- **Use a checkmark** to show that an attribute is in effect, as in the Format > Font menu.
- **Offer one item that removes several attributes at once,** such as Plain, when people can apply several styles.

### In-game menus

- **Use the platform's default interaction method** for navigating menus. Players expect the same gestures they use elsewhere on the device.
- **Keep menus readable and easy to tap on every platform you support.** Scaling game content to a small screen can make menus too small, so enlarge the tap targets or find another way to show the content.

### iOS and iPadOS

Menus can use one of three layouts:

- **Small:** a row of four icon-only items above the rest of the list. Use it only for closely related actions that appear as a group, such as Bold, Italic, Underline and Strikethrough.
- **Medium:** a row of three items, each with an icon and a short label, above the rest of the list. Use it when three important actions are used often.
- **Large (default):** all items in a list.

### visionOS

- **Show menus near the content they control,** because people need to look at an item before selecting it.
- **Prefer the subtle breakthrough effect** so that a menu over 3D content stays legible. Use the prominent effect only when the menu must stand out, and use none only when the menu can be hidden behind content without harm.

---

## Toolbars

A toolbar gives convenient access to frequently used commands, controls, navigation and search. It is a set of controls arranged horizontally along the top or bottom edge of a view, grouped into logical sections.

A toolbar can hold three kinds of content: the title of the current view, navigation controls (such as Back and Forward) and search fields, and actions (bar items such as buttons and menus). A tab bar, by contrast, is for moving between areas of an app.

### Best practices

- **Choose items deliberately** so people can tell them apart and activate them easily. Decide which items move to an overflow menu as the window narrows.
- **Do not add an overflow menu manually.** macOS and iPadOS add one automatically when items no longer fit. Avoid layouts that overflow by default.
- **Add a More menu for less important actions.** Include as many actions in the toolbar as you can, and add the More menu only if you need it.
- **In macOS and iPadOS, consider letting people customise the toolbar.** This suits apps with many items, or advanced features that not everyone needs.
- **Reduce custom backgrounds and tinted controls.** They can clash with system background effects. Let the content layer shape the toolbar's appearance, and use a scroll edge effect where you need to separate the toolbar from the content.
- **Avoid similar colours on toolbar labels and content backgrounds.** Prefer the default monochromatic appearance if the content is already colourful.
- **Use standard components.** Their corner radii match the bar's corners. If you make a custom component, match the corner radius too.
- **Consider hiding toolbars temporarily** for a distraction-free experience, but only in context, and always offer a reliable way to bring them back. See Going full screen.

### Titles

- **Give each window a useful title** so people know where they are and can tell windows apart. If the title is redundant, you can leave it empty.
- **Do not title windows with the app name.** It says nothing about the content.
- **Keep titles concise,** ideally under about 15 characters, to leave room for other controls.

### Navigation

- **Use the standard Back and Close buttons,** with the standard symbols. Do not use text labels that say Back or Close. A custom version must look and behave the same way, and must be used consistently throughout the app.

### Actions

- **Provide the actions people use most,** or the commands that act on the most important objects in the app.
- **Make each control's meaning clear.** Prefer simple, recognisable symbols to text, except where a symbol does not work well, such as for Edit.
- **Use system symbols without borders.** The section provides the container, and the system handles hover and selection states. Bordered symbols look busy.
- **Use the prominent style for a key action** such as Done or Submit. Use only one primary action, and place it on the trailing side.

### Item groupings

- **Leading edge:** the controls that return to a previous document or show or hide a sidebar, followed by the title, and a document menu with commands such as Duplicate, Rename, Move and Export. Items here cannot be customised, so they remain available.
- **Centre:** common, useful controls. In macOS and iPadOS, people can rearrange these if you allow customisation. Items here collapse into the overflow menu as the window shrinks.
- **Trailing edge:** items that must always stay visible, buttons that open inspectors, an optional search field, the primary action such as Done, and the More menu.

- **Group items by function and frequency of use.**
- **Group navigation and critical actions** (Done, Close, Save) in dedicated, visually distinct sections.
- **Keep the same grouping and placement across platforms.** People then trust that the app behaves consistently.
- **Aim for no more than three groups.**
- **Separate text-labelled buttons from symbol buttons with fixed space.** Otherwise they can look like a single combined control.

### iOS

- **Include only the most important items** in the main toolbar, and put the rest in a More menu.
- **Use a large title** to help people stay oriented. It shrinks as they scroll and returns when they reach the top.

### iPadOS

- **Consider combining a toolbar with a tab bar.** They can share the top of the view, which leaves the full width of the window for content.

### macOS

- **The toolbar sits in the window frame,** below or integrated with the title bar. Window titles can display inline with controls, and toolbar items have no bezel.
- **Make every toolbar item available as a command in the menu bar,** because people can hide or customise the toolbar. You do not need a toolbar item for every menu command.

### watchOS

- **Place toolbar buttons in the top corners or along the bottom.** They stay visible while content scrolls under them.
- **Use a scrolling toolbar button** for an important action that is related to the view but is not its main function. Mail's New Message button is an example.

---

## The menu bar

On a Mac or an iPad, the menu bar at the top of the screen shows the top-level menus for your app. Mac users rely on it to learn what an app does and to find commands, so a consistent menu bar matters. iPad menu bars follow the same order and familiar menu items as the Mac.

### Best practices

- **Support the default system menus and their order.** The system often implements standard items for you. For example, a standard text field gets Edit > Copy automatically.
- **Always show the same set of menu items.** If an action is unavailable, disable it rather than hiding it.
- **Use the standard icons** for common actions such as Copy, Share and Delete.
- **Support the standard keyboard shortcuts** for standard items, such as Copy, Cut, Paste, Save and Print. Define custom shortcuts only when necessary.
- **Prefer short, one-word menu titles.** If a title needs more than one word, use title-style capitalisation.

### Anatomy

Menus appear in this order: the app menu (your app's name), File, Edit, Format, View, any app-specific menus, Window, and Help. On macOS, the Apple menu sits at the leading end and menu bar extras at the trailing end.

### App menu

The app menu covers the app as a whole. The app name appears in bold so people can tell which app is active.

- **About [App Name]:** shows the About window with copyright and version information. Use a short name of 16 characters or fewer, and leave out the version number.
- **Settings…:** opens your settings window, or your app's page in iPadOS Settings. Use it only for app-level settings. Put document-specific settings in the File menu.
- **Optional app-specific items:** custom app-level configuration. Place them after Settings, in the same group.
- **Services (macOS only):** a submenu of system and app services that apply to the current context.
- **Hide [App Name] (macOS only):** hides the app and its windows.
- **Hide Others (macOS only):** hides other apps.
- **Show All (macOS only):** shows all other apps' windows behind yours.
- **Quit [App Name]:** quits the app. Holding Option changes it to Quit and Keep Windows.

Show About first, with a separator after it so it sits alone in its group.

### File menu

The File menu manages the files or documents the app supports. If your app handles no files, you can rename or remove it.

- **New [Item]:** name the item type your app creates, such as Event or Calendar in the Calendar app.
- **Open:** opens the selected item, or shows an interface to choose one. Add an ellipsis if a separate interface appears.
- **Open Recent:** a submenu of recent documents, typically with a Clear Menu item. Show document names rather than file paths, most recent first.
- **Close:** closes the current window or document. Holding Option changes it to Close All. In a tabbed window, Close Tab replaces it. Consider a Close Window item too.
- **Close Tab:** closes the current tab. Holding Option changes it to Close Other Tabs.
- **Close File:** closes the file and all its windows. Consider it if the app can open several views of one file.
- **Save:** saves the document. Save automatically as people work where possible. For a new document, prompt for a name and location. For several formats, offer a pop-up menu in the Save sheet.
- **Save All:** saves every open document.
- **Duplicate:** creates a copy and leaves both open. Holding Option changes it to Save As. Prefer Duplicate to Save As, Export, Copy To or Save To, because those do not show how the new file relates to the original.
- **Rename…:** renames the document.
- **Move To…:** chooses a new location for the document.
- **Export As…:** exports in a format the app does not usually handle. The original stays open and the exported file does not open. Reserve it for that purpose.
- **Revert To:** when autosave is on, lists recent versions and a version browser. The chosen version replaces the current document.
- **Page Setup…:** sets printing parameters that belong to a specific document, such as paper size and orientation. Global options such as the printer name, and frequently changed ones such as copies, belong in the Print panel.
- **Print…:** opens the standard Print panel, which can also save as PDF.

### Edit menu

The Edit menu handles content changes and the Clipboard. It is useful even in apps that are not document-based, because most editing commands apply to any editable content.

- **Find items** belong here only when they search within the current content. Searching for files or objects may fit the File menu better.
- **Undo and Redo:** reverse the previous operation. Name the target where it helps, such as Undo Paste and Match Style, or Undo Typing.
- **Cut, Copy and Paste:** Cut removes the selection and places it on the Clipboard. Copy duplicates it. Paste inserts the Clipboard contents, which stay unchanged, so Paste can be repeated.
- **Paste and Match Style:** pastes and matches the surrounding text style.
- **Delete:** removes the selection without placing it on the Clipboard. Use Delete rather than Erase or Clear, because it matches the Delete key.
- **Select All**
- **Find:** a submenu with Find, Find and Replace, Find Next, Find Previous, Use Selection for Find and Jump to Selection.
- **Spelling and Grammar:** a submenu for checking spelling and grammar.
- **Substitutions:** a submenu for toggling automatic substitutions, such as smart quotes, smart dashes, smart links, data detectors and text replacement.
- **Transformations:** a submenu for Make Uppercase, Make Lowercase and Capitalize.
- **Speech:** a submenu with Start Speaking and Stop Speaking.
- **Start Dictation and Emoji & Symbols:** added automatically by the system at the bottom of the menu.

### Format menu

The Format menu adjusts text formatting. You can leave it out if your app does not support formatted text.

- **Font:** a submenu with Show Fonts, Bold, Italic, Underline, Bigger, Smaller, Show Colors, Copy Style and Paste Style.
- **Text:** a submenu with Align Left, Align Center, Justify, Align Right, Writing Direction, Show Ruler, Copy Ruler and Paste Ruler.

### View menu

The View menu customises the appearance of all windows. Provide one even if you support only some view functions. For example, an app with no tab bar, toolbar or sidebar can still offer Enter Full Screen.

- **Make show and hide titles reflect the current state.** When the toolbar is hidden, show Show Toolbar. When it is visible, show Hide Toolbar.
- **Show/Hide Tab Bar:** toggles the tab bar in a tabbed window.
- **Show All Tabs / Exit Tab Overview:** shows an overview of all open tabs.
- **Show/Hide Toolbar:** toggles the toolbar.
- **Customize Toolbar:** opens toolbar customisation.
- **Show/Hide Sidebar:** toggles the sidebar.
- **Enter/Exit Full Screen:** opens the window full screen in its own space.

The View menu does not manage windows. That job belongs to the Window menu.

### App-specific menus

These sit between the View menu and the Window menu. Safari's History and Bookmarks menus are examples.

- **Provide app-specific menus for custom commands.** People search the menu bar first, especially when they use an app for the first time. Putting commands in the menu bar also makes shortcuts and Full Keyboard Access possible.
- **Reflect the app's hierarchy** where you can. In Mail, Mailbox, Message and Format appear in an order that matches how they relate.
- **Order menus from most to least general or commonly used.**

### Window menu

The Window menu helps people navigate and manage windows. It does not change window appearance or close windows. Those belong to the View and File menus.

- **Provide a Window menu even if the app has one window.** Include Minimize and Zoom so people using Full Keyboard Access can reach them.
- **Consider items to show and hide panels.** The Format menu already lists the font and colour panels, so those are not needed here.
- **Minimize:** minimises the active window to the Dock. Holding Option changes it to Minimize All.
- **Zoom:** toggles between a content-appropriate size and the size people set. Holding Option changes it to Zoom All. Do not use Zoom for full screen, because the View menu does that.
- **Show Previous Tab and Show Next Tab:** for tabbed windows.
- **Move Tab to New Window and Merge All Windows:** for tabbed windows.
- **Enter/Exit Full Screen:** include it here only if the app has no View menu.
- **Bring All to Front:** brings all app windows forward, keeping their layout. Holding Option changes it to Arrange in Front, which tiles them.
- **Open window names:** list open windows alphabetically. Leave out panels and modal views.

### Help menu

The Help menu sits at the trailing end of the menu bar. If you use the Help Book format, macOS adds a search field at its top.

- **Send [App Name] Feedback to Apple:** opens Feedback Assistant.
- **[App Name] Help:** opens your help content in the Help Viewer.
- **Additional items:** separate them from the main help with a separator. Keep the list short, or link to them from within the help.

### Dynamic menu items

A dynamic menu item changes when a modifier key is held, such as Minimize becoming Minimize All with Option.

- **Do not make a dynamic item the only way to do a task.** It is hidden by default, so use it as a shortcut to advanced actions.
- **Use dynamic items mainly in menu bar menus,** not in context or Dock menus, where they are even harder to find.
- **Require only one modifier key.** Two keys at once are awkward while opening a menu.

### iPadOS

- **The menu bar is hidden until revealed** by moving the pointer to the top edge or swiping down. When visible, it shares the status bar's space. It is centred rather than on the leading side, and it does not include menu bar extras, the Apple menu, or app-level items such as About, Services or app visibility.
- **Window controls appear in the menu bar** when the app is full screen.
- **Because the menu bar is often hidden,** make sure every function is reachable through the interface. Dynamic menu items work only with a hardware keyboard, so always offer another route.
- **Reserve YourAppName > Settings for opening your app's page in iPadOS Settings.** Link to any in-app preferences with a separate item beneath it.
- **For tab-style navigation, add each tab to the View menu,** and consider keyboard shortcuts for each.
- **Group items into submenus more often than on the Mac,** because iPad menu rows are larger to make them easier to tap.

### macOS

- **The Apple menu is always first** on the leading side, and you cannot change it.
- **Menu bar extras** sit on the trailing side and show an icon while the app runs, even when it is not frontmost. They are hidden when space is short.
- **Use a symbol for a menu bar extra,** either an SF Symbol or a custom icon in black and clear. The menu bar is 24 pt high.
- **Show a menu rather than a popover** when people click a menu bar extra, unless the function is too complex for a menu.
- **Let people decide whether to show the extra.** Consider offering the choice during setup.
- **Do not rely on the extra being present,** because the system hides and shows extras regularly.
- **Consider a Dock menu** as well. It appears when people Control-click the Dock icon and is always available while the app runs.

---

## Context menus

A context menu gives access to functions directly related to an item, without cluttering the interface. It is hidden by default, so people may not know it is there. It opens with a secondary click (Control-click or a secondary click on a trackpad), or on touch devices with a press and hold.

### Best practices

- **Choose the most likely commands for the current context.** Do not include advanced or rare commands. A Mail message context menu offers Reply and Move, not message editing or filtering.
- **Aim for a small number of items.** A long context menu is hard to scan.
- **Support context menus consistently** throughout the app. If some items have them and others do not, people will think the feature is broken.
- **Always make the same commands available in the main interface too.** In macOS, the menu bar lists every command, including those in context menus.
- **Keep submenus to one level,** with a title that predicts the contents.
- **Hide unavailable items rather than dimming them.** The exceptions on macOS are Cut, Copy and Paste, which may appear dimmed when they do not apply.
- **Put the most used items where people look first.** A menu opens above or below the content, so you may need to reverse the order to match.
- **Do not show keyboard shortcuts in context menus.** The main menus show them.
- **Use no more than about three groups,** with separators between them.
- **Put destructive items last and mark them as destructive** in iOS, iPadOS and visionOS, so the system can show them in red.

### Content

- **Include a title only if it makes the effect clearer.** For example, a title stating the number of selected messages when several are being marked.
- **Use the same icons as the system** for actions such as Copy, Share and Delete, wherever they appear.

### iOS and iPadOS

- **Offer a context menu or an edit menu for an item, but not both.** Both together confuse people and make the system guess their intent.
- **On iPadOS, consider a context menu for creating new objects.** Files uses one in the empty space between files and folders to create a new folder.
- **Provide a preview** of the content near the commands, where it helps. A preview of a Notes or Mail item confirms which item people are acting on.
- **Make the preview match the content's shape,** so its rounded corners do not change during the animation.

### macOS

- On a Mac, a context menu is sometimes called a contextual menu.

### visionOS

- **Prefer a context menu to a panel or inspector** for frequently used functions, to keep the space uncluttered.
- **Keep the context menu no taller than the window,** because window controls sit above and below the window's edges and could be covered.

---

## Pop-up buttons

A pop-up button shows a menu of mutually exclusive options. After people choose an item, the menu closes and the button shows the current selection.

### Best practices

- **Use a pop-up button for a flat list of mutually exclusive options or states** that affects content or the surrounding view.
- **Use a pull-down button instead** if you need to offer a list of actions, allow people to select several items, or include a submenu.
- **Provide a useful default.** Show the default item until people choose one, and make it the choice most people are likely to want.
- **Let people predict the options without opening the button,** with an introductory label or a button label that describes the effect.
- **Use a pop-up button when space is limited** and not every option needs to be visible all the time.
- **Include a Custom option if it helps.** It keeps occasional items out of the main interface. You can add explanatory text below the list.

### iPadOS

- **In a popover or modal view, use a pop-up button instead of a disclosure indicator** when a list item has a small, well-defined set of options. People choose without going to a detail view.

### Platform notes

- **Not supported** in tvOS or watchOS.
- **iOS, macOS and visionOS:** no additional considerations.

---

## Sidebars

A sidebar sits on the leading side of a view and lets people move between areas of the app, or between top-level collections such as folders and playlists.

A sidebar needs a lot of vertical and horizontal space. When space is tight, a compact control such as a tab bar may suit better. Many apps can use a tab bar that converts to a sidebar, so people do not have to choose between them. See Tab bars and Layout.

### Best practices

- **Extend visually rich content beneath the sidebar.** The sidebar can float over content in the Liquid Glass layer. Either let the content scroll horizontally beneath it, or apply a background extension effect, which mirrors the adjacent content so it appears to stretch under the sidebar.
- **Let people customise the sidebar** where possible, so they can order the areas that matter most to them.
- **Use disclosure controls** to group hierarchy when the app has a lot of content, to keep the sidebar manageable.
- **Use familiar symbols** from SF Symbols for sidebar items. If you need a custom icon, make a custom symbol rather than a bitmap.
- **Let people hide the sidebar** using the platform's usual gesture or command. In iPadOS, that is the edge swipe. On a Mac, provide a show/hide button or Show Sidebar and Hide Sidebar commands in the View menu. Do not hide it by default, because that makes it hard to find.
- **Show no more than two levels of hierarchy.** For deeper data, use a split view with a content list between the sidebar and the detail view.
- **If you use two levels, give each group a short, descriptive title,** and leave out unnecessary words.
- **Make sure sidebar icon colours have a clear purpose.** By default, icons use the app's accent colour, and on a Mac they follow the system accent colour that people choose. Use fixed colours sparingly, to show meaning or draw attention, as Mail does with its yellow VIP icon.

### iOS and iPadOS

- **Consider a tab bar first.** It gives content more room and handles many main areas. If you need to show more areas than fit, the tab bar's sidebar style can reach the less used ones.
- **Use the adaptable sidebar tab style** if you want people to switch between a sidebar and a tab bar. It adapts to the platform and to the width of the view.
- **If you are not using SwiftUI,** you can use the sidebar appearance of a collection view list layout.

### macOS

- **Sidebar size** (small, medium or large) controls row height and text size. People can change it in General settings.
- **Consider hiding the sidebar automatically** when the window resizes, to give the content more room.
- **Avoid putting critical information or actions at the bottom** of a sidebar, because people often move windows so the bottom edge is hidden.

### visionOS

- **In a deep hierarchy,** a sidebar within a tab can support secondary navigation. Make sure selecting an item in the sidebar does not change the open tab.

### tvOS and watchOS

- **Not supported** in tvOS or watchOS.
