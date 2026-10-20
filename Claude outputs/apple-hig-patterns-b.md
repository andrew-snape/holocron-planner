# Apple Human Interface Guidelines: Patterns (Part B)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Launching, Loading, Multitasking, Offering help, Settings, Undo and redo.

Platform sections for visionOS, watchOS and tvOS are trimmed where they do not apply to your projects.

---

## Launching

Launching is the period from when someone opens your app to when its first screen is ready. A streamlined launch helps people start using the app straight away, ideally within a couple of seconds.

### Best practices

- **Launch instantly.** People want to start interacting right away.
- **Provide a launch screen where the platform requires one.** On iOS, iPadOS and tvOS the system shows your launch screen as soon as the app starts, then replaces it with your first screen. macOS, visionOS and watchOS do not require one.
- **If you need a splash screen, show it at the start of onboarding,** or as soon as launching completes if you have no onboarding. A splash screen can carry branding and other information.
- **Restore the previous state on restart.** People should not have to retrace their steps. Scroll views to the last position, and reopen windows in the state and place they were left.

### Launch screens

These do not apply to macOS, visionOS or watchOS.

- **Downplay the launch screen.** It is not onboarding, a splash screen or a place for artistic expression. Its only job is to make your app feel quick to start.
- **Make it nearly identical to your first screen.** Different elements cause a visible flash. If your app shows a solid colour first, the launch screen should show only that colour. Match the device orientation and appearance mode.
- **Avoid text on the launch screen.** Its content does not change, so any text would not be localised.
- **Do not advertise.** Avoid an "About" look or logos unless they are a fixed part of your first screen.

### Platform notes

- **iOS and iPadOS.** Launch in the device's current orientation if your app supports both orientations. If it supports one orientation only, launch in that orientation and let people rotate if needed. Landscape-only interfaces must respond correctly whichever way the device is turned.
- **tvOS.** Launch screens are static. For live-viewing apps, consider starting playback after a few seconds of inactivity.
- **visionOS.** Consider launching into the Shared Space even if the app is fully immersive, so people can choose when to enter the immersive experience.

---

## Loading

The best loading experience finishes before people notice it.

### Best practices

- **Show something as soon as possible.** A blank screen can look like a fault. Show placeholder text, graphics or animation, and replace them as content arrives.
- **Let people do other things while content loads.** Load in the background so they can keep using other actions. A game might load the next level while players read hints or open a menu.
- **If loading is unavoidably long, give people something to look at.** Show hints, tips or new features. Estimate the remaining time as accurately as you can, so the placeholder neither runs out nor repeats.
- **Download large assets in the background** to improve installation and launch times. The Background Assets framework can schedule downloads, such as game level packs or 3D models, for after installation, during updates or at other quiet times.

### Showing progress

- **Show clearly that content is loading, and how long it might take.** Use a determinate progress indicator when you know the duration, and an indeterminate one when you do not. See Progress indicators.
- **In games, consider a custom loading view** that matches the game's style, instead of a standard indicator.

### watchOS

- Avoid loading indicators where you can. People expect quick interactions. If content needs a second or two, a loading indicator is better than a blank screen.

---

## Multitasking

Multitasking lets people switch quickly between apps and carry out tasks in each. People expect it on their devices, and an app that does not allow it can seem broken. With rare exceptions, such as some games and Vision Pro apps in a Full Space, every app should work well with multitasking.

Because you cannot know when people will switch away, always be ready to save and restore their context.

### Best practices

- **Pause activities that need attention when people switch away.** A game or media app should not let people miss anything. When they return, let them carry on as if they had never left.
- **Respond to audio interruptions smoothly.**
  - For primary interruptions, such as a phone call or a playlist started by Siri, pause indefinitely.
  - For shorter interruptions, such as GPS directions, lower the volume or pause briefly, then resume when the interruption ends.
- **Finish user-started tasks in the background.** If someone starts a download or video processing, it should finish even if they leave the app.
- **Use notifications sparingly.** Notify people when an important, time-sensitive task finishes and they may need to act. Do not notify them about routine tasks. Let them check those when they return.

### Platform notes

- **iOS.** Multitasking includes Picture in Picture, so a video or FaceTime call can float above another app.
- **iPadOS.** People can use full-screen apps, or windowed apps that they can resize and arrange. Apps can also have several windows open at once. Picture in Picture works in both modes. Apps do not control the multitasking configuration and are not told which one people chose, so the layout must adapt gracefully to different sizes. See Layout and Windows.
- **macOS.** Multitasking is the default, because people run several apps and move between windows. Window shadows and states show which window is active.
- **tvOS.** People can browse while watching in Picture in Picture, where supported.
- **visionOS.** Several apps run in the Shared Space. Only one window is active at a time. Do not change window edges, because the system uses a feathered mask to show which window is inactive. Do not pause video when people look away, and expect audio to duck when your app is not the Now Playing app.

---

## Offering help

Help is most useful when it is contextual and short. The most effective experiences need little help, but you can add it where people need it.

### Best practices

- **Match help to the task.** Use an inline view for simple one- or two-step tasks. Offer a tutorial for complex or multistep goals. Relate help to what people are doing right now, and make it easy to dismiss.
- **Use language and images that fit the context and platform.** Do not show a game controller in a tvOS remote context. Do not tell people to click on iPhone or tap on a Mac.
- **Keep help inclusive.** See Inclusion.
- **Do not explain standard controls.** Describe what the specific action does in your app. For a unique control, show it with animation or graphics rather than long text.

### Tips

A tip is a small, temporary view that briefly shows how to use a feature. TipKit is the developer framework for them.

- **Choose the right tip type.** A popover tip preserves the content flow. An inline tip keeps surrounding information visible. An annotation-style tip points to a specific element. A hint-style tip is not tied to one element.
- **Use tips for simple features.** If a feature needs more than three actions, a tip is probably the wrong tool.
- **Keep tips short and actionable.** One or two sentences, in direct language. Avoid promotional content, or content that is unrelated to what the person is doing.
- **Set eligibility rules.** Do not show a tip for a feature someone has already used. Limit how often tips appear, for example once every 24 hours.
- **Use a symbol if people associate one with the feature,** and prefer the filled variant. Do not repeat the same image in the tip and in the interface it points to.
- **Use buttons to lead people somewhere,** such as the settings where they can adjust a feature, or a setup flow.

### macOS and visionOS: tooltips

A tooltip, called a help tag in user documentation, is a small view that describes a control when the pointer rests on it (on a Mac) or when someone looks at it (in visionOS).

- **Describe only the control the person is pointing at.**
- **Say what the control does,** ideally starting with a verb, such as "Restore default settings".
- **Do not repeat the control's name** in its tooltip.
- **Be brief.** Aim for about 60 to 75 characters at most, and remember that translation changes length. Sentence fragments without articles work well.
- **Use sentence case.** Omit the final full stop unless your style requires it.
- **Consider context-sensitive tooltips** that change with the control's state.

---

## Settings

Settings let people customise the experience. Most of the time, people just want the app to work, so default settings matter most.

### Best practices

- **Choose defaults that suit the most people.** For example, a game can set graphics quality for the device it runs on, rather than asking players after launch.
- **Offer as few settings as you can.** Too many make the app feel less approachable and make each setting harder to find.
- **Use the conventions people expect.** On a Mac, Command-Comma opens settings. In a game, players often use Escape.
- **Do not ask for information you can detect.** A game can detect a connected controller. An app can detect whether Dark Mode is on.
- **Do not duplicate systemwide settings.** Accessibility, scrolling behaviour and authentication belong in the system Settings app. Copies in your app confuse people and suggest that systemwide choices may not apply.

### Where settings go

- **General, rarely changed options go in your settings area.** This is for things like window configuration, saving behaviour or account options.
- **Task-specific options belong in the task.** For example, showing or hiding parts of a view, reordering items or filtering a list should happen on the screen they affect. A separate settings area disconnects them from their context.
- **System Settings is for the rarest options.** If you add settings there, offer a button in your interface that opens them directly.

### macOS

- **Put the Settings item in the App menu.** Do not add settings buttons to the toolbar, because they take room from frequently used commands. Document-level options go in the File menu.
- **Use a settings window that opens with Command-Comma.** Dim its minimise and maximise buttons, since it is quick to reopen and sized to its content.
- **Use a fixed toolbar** that always shows which pane is active. Buttons switch between panes of related settings.
- **Update the window title** to match the visible pane. With a single pane, use "App Name Settings".
- **Restore the last pane** the person used when the window reopens.

### watchOS

- Apps do not add settings to the Settings app on Apple Watch. Offer a few essential options at the bottom of the main view, or use a More menu.

---

## Undo and redo

Undo and redo let people reverse recent actions, so they can explore and experiment safely. People often undo several times until something changes, so each step must be predictable and visible.

### Best practices

- **Help people predict the result.** Describe what will be undone, for example with menu labels such as "Undo Typing" or "Redo Bold".
- **Show the result of every undo and redo.** If the change is off screen, scroll to it. Otherwise people may think nothing happened and repeat the action.
- **Let people undo many times.** Do not limit the count without good reason. People expect to undo everything back to a logical point, such as opening or saving a document.
- **Consider reverting a batch at once.** Related incremental changes, such as adjusting one property many times, can be undone together. Some apps also offer "revert to saved".
- **Add visible undo and redo buttons only if needed.** People expect the system methods: the Edit menu on a Mac, keyboard shortcuts, or a shake on iPhone. If you add buttons, use the standard symbols in a toolbar.

### iOS and iPadOS

- **Do not redefine standard gestures.** Three-finger swipe and shake already mean undo and redo.
- **Describe the operation briefly.** The alert title already starts with "Undo " or "Redo ". Add a word or two after it, such as "Undo Name" or "Redo Address Change".

### macOS

- **Put Undo and Redo at the top of the Edit menu.** Support the standard shortcuts: Command-Z for undo and Shift-Command-Z for redo.

---

## Resources

- Layout, Windows, Progress indicators, Onboarding, Feedback, Managing notifications, Playing audio and Inclusion pages on Apple's HIG site.
