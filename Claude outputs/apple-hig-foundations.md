# Apple Human Interface Guidelines: Foundations (Part 1)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Scope: this file covers the Foundations pages that apply to your Holocron planner, your website and your macOS apps. Platform-specific sections for visionOS, watchOS and tvOS have been left out, and large reference tables have been summarised. Where Apple's text is quoted it is kept close to the original.

Status: Part 1 of Foundations. Still to come: Right to left, SF Symbols, Spatial layout, Typography, Writing.

---

## Accessibility

Accessible user interfaces empower everyone to have a great experience with your app or game.

An accessible interface is:

- **Intuitive.** It uses familiar and consistent interactions that make tasks straightforward to perform.
- **Perceivable.** It does not rely on any single method to convey information. People can access and interact with content whether they use sight, hearing, speech or touch.
- **Adaptable.** It adapts to how people want to use their device, whether by supporting system accessibility features or letting people personalise settings.

Audit the accessibility of your interface as you design. Use the Accessibility Inspector in Xcode to highlight issues and to see how your app presents itself to people using system accessibility features.

### Vision

- **Support larger text sizes.** Ideally let people enlarge text by at least 200 percent. Do this either with custom UI or by adopting Dynamic Type, the systemwide text size setting. (See Typography.)
- **Use recommended defaults for custom type sizes.** Default and minimum sizes: iOS and iPadOS 17 pt default, 11 pt minimum; macOS 13 pt default, 10 pt minimum.
- **Font weight affects readability.** If you use a thin custom font, go larger than the recommended sizes.
- **Meet colour contrast minimums.** The Accessibility Inspector uses WCAG Level AA values:
  - Text up to 17 pt, any weight: 4.5:1
  - 18 pt text, any weight: 3:1
  - Any size, bold: 3:1

  If your app does not meet this by default, provide a higher-contrast colour scheme when Increase Contrast is on. Check both light and dark appearances.
- **Prefer system-defined colours.** They have accessible variants that adapt when people change colour preferences.
- **Do not rely on colour alone.** Red-green and blue-orange pairings are hard for many colour-blind people. Add shapes, icons or labels alongside colour. Consider letting people customise chart colours.
- **Describe your interface for VoiceOver.** Every control and piece of content needs a meaningful label. (See VoiceOver.)

### Hearing

- **Support text-based ways to enjoy audio and video.**
  - Captions give the textual equivalent of audible information, synchronised with the media.
  - Subtitles show live on-screen dialogue in the preferred language.
  - Audio descriptions narrate important visual information between pauses in the main audio.
  - Transcripts give a full text version of video or audio, covering both audible and visual content.
- **Use haptics in addition to audio cues.** Pair a success chime or error sound with matching haptics.
- **Augment audio cues with visual cues.** This matters most where important content happens off screen.

### Mobility

- **Offer sufficiently sized controls.** Default and minimum control sizes: iOS and iPadOS 44 x 44 pt default, 28 x 28 pt minimum; macOS 28 x 28 pt default, 20 x 20 pt minimum.
- **Spacing matters as much as size.** Around elements with a bezel, add about 12 pt of padding. Around elements without a bezel, add about 24 pt around the visible edges.
- **Support simple gestures for common interactions.** Avoid custom multi-finger and multi-hand gestures.
- **Offer alternatives to gestures.** If a swipe dismisses or deletes something, also provide a button so people can tap or use an assistive device.
- **Support Voice Control.** Label interface elements clearly so people can operate the app by speaking.
- **Integrate with Siri and Shortcuts** so people can perform tasks by voice alone.
- **Support mobility-related assistive technologies** such as VoiceOver, AssistiveTouch, Full Keyboard Access, Pointer Control and Switch Control. Test with them.

### Speech

- **Let people use the keyboard alone.** Support Full Keyboard Access. Avoid overriding system keyboard shortcuts.
- **Support Switch Control.** People can select, tap, type and draw using separate hardware or sounds.

### Cognitive

- **Keep actions simple and intuitive.** Prefer system gestures and behaviours people already know over custom gestures.
- **Minimise time-boxed elements.** Views that auto-dismiss on a timer are hard for some people. Prefer dismissal through an explicit action.
- **Consider difficulty options in games.** For example, reduce the criteria for completing a level, adjust reaction time, or enable control assistance.
- **Let people control audio and video playback.** Avoid autoplay without visible start and stop controls. Consider a global opt-out.
- **Allow people to opt out of flashing lights.** If your app plays video, respond to the Dim Flashing Lights setting.
- **Be cautious with fast-moving and blinking animation.** When Reduce Motion is on, reduce automatic and repetitive animation, including zooming, scaling and peripheral motion. Good practice includes:
  - Tightening animation springs to reduce bounce
  - Tracking animations directly with the person's gestures
  - Avoiding animating depth changes on the z-axis
  - Replacing x, y and z transitions with fades
  - Avoiding animating into and out of blurs
- **Optimise for Assistive Access (iOS and iPadOS).** Identify core functionality, remove non-critical workflows, break multi-step workflows into one interaction per screen, and ask for confirmation twice before any action that is hard to undo, such as deleting a file.

---

## App icons

A unique, memorable icon expresses your app's purpose and personality and helps people recognise it at a glance.

Your icon appears on the Home Screen and in search results, notifications, System Settings and share sheets. It should convey your identity clearly and consistently across all Apple platforms.

### Layer design

- Layers give you the most control. Import foreground layers into Icon Composer (included with Xcode) to define the background, place layers, apply specular highlights and refraction, set dark, mono and tinted variants, and export.
- The system applies Liquid Glass attributes, including specular highlights, refraction and translucency. These adapt to icon size.
- **Prefer clearly defined edges** in foreground layers. Avoid soft or feathered edges.
- **Vary opacity** across foreground layers to add depth.
- **Design a background that stands out** and emphasises the foreground. Gradients should respond well to system lighting. Background layers should be full-bleed and opaque if imported.
- **Prefer vector graphics** (SVG or PDF) for layers. Outline artwork and convert text to outlines. Use PNG for mesh gradients and raster artwork.

### Icon shape

- On iOS, iPadOS and macOS, icons are square. The system applies the rounded mask.
- **Produce square, unmasked layers.** Do not pre-mask them. Pre-masking hurts specular highlights and makes edges jagged.
- **Keep primary content centred** so nothing is truncated when the system adjusts corners.

### Design

- **Embrace simplicity.** Find one core concept and express it with the fewest shapes possible. A simple background such as a solid colour or gradient is usually enough.
- **Provide a consistent design across all platforms** your app supports.
- **Consider filled, overlapping shapes** to create depth.
- **Include text only when essential.** Text in icons does not localise or support accessibility. Do not add words such as "Play" or "New".
- **Prefer illustrations to photos.** Do not replicate standard UI components or use app screenshots.
- **Do not use replicas of Apple hardware.**

### Visual effects

- **Let the system handle effects.** Do not add specular highlights, drop shadows, bevels, blurs or glows. Custom effects are static, while the system's are dynamic.
- If you do use custom effects, test them carefully in Icon Composer or on a device.
- **Group layers** where it makes sense so effects apply to the group.

### Appearances (iOS, iPadOS and macOS)

People can choose default, dark, clear or tinted app icons. You can design variants for each. The system generates any you do not provide.

- **Keep core features consistent across appearances.** Do not swap elements in and out between variants.
- **Design dark and tinted icons** that sit comfortably beside system icons and widgets. Dark icons are more subdued, and clear and tinted icons more so.
- **Use your light icon as the basis for the dark one.** Avoid excessively bright images. Coloured backgrounds usually give the most contrast in dark icons.
- **Alternate icons** (iOS and iPadOS) must stay closely related to your content and must not be mistaken for another app. They need their own dark, clear and tinted variants and are subject to App Review.

### Specifications

| Platform | Layout size | Style |
|---|---|---|
| iOS, iPadOS, macOS | 1024 x 1024 px | Layered |

Colour spaces: sRGB, Gray Gamma 2.2, and Display P3 (wide colour on iOS, iPadOS, macOS).

---

## Branding

Apps express their brand identity in ways that make them instantly recognisable while feeling at home on the platform and giving people a consistent experience.

- **Use your brand's voice and tone** in all written text, for example through plain words, simple sentences and occasional exclamation marks or emoji.
- **Apply your accent colour judiciously.** Using brand colour too broadly overwhelms the interface. Use it for primary actions and status indicators, such as unread badges or the selected tab. Consider moving brand colour into the content layer, where it scrolls beneath Liquid Glass controls.
- **Consider a custom font for headlines** if your brand depends on one. Ensure it stays legible at all sizes and supports Bold Text and Dynamic Type. Use system fonts for body copy and captions.
- **Express your brand with familiar components.** If you customise a component, keep its sizing, placement and behaviour familiar for the platform.
- **Let branding defer to content.** Do not give screen space to an element that only displays a logo.
- **Use standard patterns consistently.** Place UI in expected locations, use standard symbols for common actions, and rely on established navigation and modality conventions.
- **Do not repeat your logo throughout the app** unless it is essential for context.
- **Do not use the launch screen for branding.** It disappears too quickly to convey anything. A welcome or onboarding screen is a better place.
- **Follow Apple's trademark guidelines.** Apple trademarks must not appear in your app name or images.

---

## Color

Judicious use of colour can enhance communication, evoke your brand, provide visual continuity, communicate status and feedback, and help people understand information.

The system defines colours that look good on various backgrounds and appearance modes, and adapt to vibrancy and accessibility settings. Using system colours makes your experience feel at home on the device. You can also use custom colours to express your app's personality.

### Best practices

- **Do not use the same colour to mean different things.** If brand colour marks a borderless button as interactive, do not use a similar colour for non-interactive text.
- **Make all colours work in light, dark and increased contrast.** Prefer system colours, which already define these variants. For custom colours, supply light and dark variants, plus an increased-contrast option for each with significantly more differentiation. Even a single-appearance app should supply both light and dark variants to support Liquid Glass.
- **Test under a range of lighting conditions.** Colours look darker and more muted in bright light, and more saturated in dim light.
- **Test on different displays.** Check your colours on P3 and sRGB profiles. Changing the profile is available in System Settings > Displays.
- **Consider how artwork and translucency affect nearby colours.** Colours can look different behind a translucent element such as a toolbar.
- **If people choose colours in your app, use system colour pickers** where available. People can then save colour sets they can reuse in any app.

### Inclusive colour

- **Do not rely on colour alone** to differentiate objects, indicate interactivity or communicate essential information. Use text labels, glyph shapes or other alternatives.
- **Avoid colours that make content hard to perceive.** Insufficient contrast makes icons and text blend into the background.
- **Consider how colours are perceived in other cultures.** Red signals danger in some cultures and good fortune in others. Charts are a good example: a rising stock line may be green in one locale and red in another.

### System colours

- **Do not hard-code system colour values.** Values can change between releases. Use the APIs, such as SwiftUI's `Color`, to apply them.
- **Use dynamic system colours as intended.** Each is defined by purpose, not appearance. Do not use the separator colour as a text colour, or the secondary label colour as a background.

### Liquid Glass colour

- Liquid Glass has no inherent colour. It takes on colour from the content behind it. You can apply colour to some Liquid Glass elements, for example to emphasise a primary call to action.
- **Apply colour sparingly to Liquid Glass.** Reserve it for elements that need emphasis, such as status indicators or primary actions. To emphasise a primary action, colour the background, not the symbol or text.
- **Do not colour the backgrounds of many controls** in the same toolbar. Only the primary one should be coloured.
- **Avoid similar colours in control labels over colourful backgrounds.** Prefer a monochromatic toolbar or tab bar, or an accent colour with sufficient differentiation.
- **Keep the default state of the content layer legible.** Colourful content may scroll under controls, but its resting state should remain clear.

### Colour management

- A colour space (for example sRGB or Display P3) is a range of colours. A colour profile describes that space numerically. An image embeds its profile so the device can reproduce its colours correctly.
- **Apply colour profiles to your images.** sRGB is accurate on most displays.
- **Use wide colour** where it adds value. P3 offers richer colours on compatible displays. Use Display P3 at 16 bits per channel and export PNG.
- **Provide colour-space-specific variants** where needed, using the asset catalogue in Xcode. Two close P3 colours can be hard to tell apart on sRGB displays, and P3 gradients can clip.

### macOS colours

macOS provides dynamic system colours for text, backgrounds, separators, controls, selection and focus. Key examples:

- **Label colours** (label, secondary label, tertiary label, quaternary label) for text at each level of hierarchy.
- **Background colours** (window background, control background, alternating content background, under-page background) for surfaces at each level.
- **Control colours** (control, control text, unavailable control text, selected control) for interactive elements.
- **Keyboard focus indicator colour** for the focus ring shown during keyboard navigation.
- **Separator and grid colours** for dividers and table gridlines.
- **Selection colours** (selected content background, unemphasised selected content background, selected text background) for selection in key and non-key windows.

**App accent colours.** From macOS 11, you can specify an accent colour to customise buttons, selection highlighting and sidebar icons. The system applies your accent colour when people leave the accent colour setting at multicolour. If they choose another colour, that choice replaces yours, except for fixed-colour sidebar icons, which keep their colour because it carries meaning.

### iOS and iPadOS colours

- **Background colours** come in system and grouped sets, each with primary, secondary and tertiary variants. Use the grouped set for grouped table views and the system set otherwise. Primary is for the overall view, secondary for grouping within it, and tertiary for grouping within secondary elements.
- **Foreground colours** include label, secondary label, tertiary label, quaternary label, placeholder text, separator, opaque separator and link.

---

## Dark Mode

Dark Mode is a systemwide appearance setting that uses a dark colour palette for a comfortable viewing experience in low light. On iOS, iPadOS, macOS and tvOS, people often choose it as their default and expect apps to respect it.

### Best practices

- **Do not offer an app-specific appearance setting.** It forces people to adjust two settings, and they may think your app is broken when it ignores the system choice.
- **Make your app look good in both modes.** People can choose Auto, which switches with the time of day, potentially while your app is running.
- **Test legibility in both modes**, including with Increase Contrast and Reduce Transparency, on their own and together. Dark text on a dark background can become hard to read.
- **Consider a permanently dark appearance only in rare cases,** such as an immersive media viewer that should let the UI recede.

### Dark Mode colours

- Dark Mode uses dimmer backgrounds and brighter foregrounds. Not every colour is a simple inversion of its light counterpart.
- **Use semantic colours** that adapt automatically, such as the label and control colours. For custom colours, add a colour set to the asset catalogue with both light and dim variants. Avoid hard-coded values that do not adapt.
- **Aim for sufficient contrast in all appearances.** At minimum, keep the contrast ratio at 4.5:1. For custom foreground and background colours, aim for 7:1, especially with small text.
- **Soften white backgrounds in images.** A pure white background can glow in a dark interface. Darken it slightly.

### Icons and images

- **Use SF Symbols wherever possible.** They adapt automatically to Dark Mode.
- **Design separate interface icons for light and dark** if necessary. A full moon icon may need an outline on a light background but not on a dark one. A black droplet may need a white border on dark.
- **Make full-colour images work in both appearances.** Use one asset if it works in both. Otherwise create separate light and dark assets, combined in an asset catalogue.

### Text

- **Use the system label colours** (primary, secondary, tertiary and quaternary). They adapt to light and dark.
- **Use system views for text fields and text views.** They handle legibility on any background, including vibrancy.

### iOS and iPadOS

- The system uses **base** and **elevated** background colour sets. Base colours are dimmer and make background interfaces recede. Elevated colours are brighter and make foreground interfaces advance.
- **Prefer the system background colours.** The background changes from base to elevated automatically for popovers, sheets and multitasking. Custom backgrounds can break these visual distinctions.

### macOS

- If people choose the graphite accent colour, windows pick up colour from the desktop picture. This is called **desktop tinting**.
- **Include some transparency in custom component backgrounds** where it makes sense, so they blend with desktop tinting. Only add transparency to a component that has a visible background or bezel, and only in a neutral state. Avoid transparency in coloured states, because the colour can shift as the window background changes.

---

## Icons

An effective icon is a graphic asset that expresses a single concept in a way people instantly understand.

Interface icons (also called glyphs) are simpler than app icons. They use streamlined shapes and touches of colour. You can design your own or use SF Symbols, either as they are or customised. Both use black and clear colours to define their shapes, and the system applies colour to the black areas.

### Best practices

- **Create a recognisable, highly simplified design.** Use familiar visual metaphors directly related to the action or content.
- **Keep interface icons visually consistent** in size, level of detail, stroke weight and perspective. Adjust dimensions where visual weight differs.
- **Match the weight of icons and adjacent text** unless you want to emphasise one.
- **Add padding for optical alignment** when geometric centring looks unbalanced, for example on an asymmetric download arrow.
- **Provide a selected-state version only if necessary.** System toolbars, tab bars and buttons update selected states automatically.
- **Use inclusive images.** Prefer gender-neutral human figures. Avoid images that are hard to recognise across cultures or languages.
- **Include text only when essential.** A character that represents text formatting is a direct way to communicate. Localise any characters you display. For text passages, use an abstract representation and a flipped version for right-to-left.
- **Use a vector format (PDF or SVG) for custom interface icons.** The system scales vectors for high-resolution displays. PNG requires multiple versions.
- **Provide alternative text labels** for custom icons. They are not visible but let VoiceOver describe them.
- **Avoid replicas of Apple hardware.** Use only the images in Apple Design Resources, or the SF Symbols that represent Apple products.

### Standard icons

Use these SF Symbols for common actions in menus, toolbars and buttons. Symbol names are given as used in SF Symbols.

**Editing**

| Action | Symbol |
|---|---|
| Cut | scissors |
| Copy | document.on.document |
| Paste | document.on.clipboard |
| Done | checkmark |
| Save | (same as Done) |
| Cancel | xmark |
| Close | (same as Cancel) |
| Delete | trash |
| Undo | arrow.uturn.backward |
| Redo | arrow.uturn.forward |
| Compose | square.and.pencil |
| Duplicate | plus.square.on.square |
| Rename | pencil |
| Move to / Folder | folder |
| Attach | paperclip |
| Add | plus |
| More | ellipsis |

**Selection**

| Action | Symbol |
|---|---|
| Select | checkmark.circle |
| Deselect / Close | xmark |
| Delete | trash |

**Text formatting**

| Action | Symbol |
|---|---|
| Superscript | textformat.superscript |
| Subscript | textformat.subscript |
| Bold | bold |
| Italic | italic |
| Underline | underline |
| Align left | text.alignleft |
| Centre | text.aligncenter |
| Justified | text.justify |
| Align right | text.alignright |

**Search**

| Action | Symbol |
|---|---|
| Search | magnifyingglass |
| Find | text.page.badge.magnifyingglass |
| Filter | line.3.horizontal.decrease |

**Sharing and exporting**

| Action | Symbol |
|---|---|
| Share / Export | square.and.arrow.up |
| Print | printer |

**Users and accounts**

| Action | Symbol |
|---|---|
| Account / User / Profile | person.crop.circle |

**Ratings**

| Action | Symbol |
|---|---|
| Dislike | hand.thumbsdown |
| Like | hand.thumbsup |

**Layer ordering**

| Action | Symbol |
|---|---|
| Bring to front | square.3.layers.3d.top.filled |
| Send to back | square.3.layers.3d.bottom.filled |
| Bring forward | square.2.layers.3d.top.filled |
| Send backward | square.2.layers.3d.bottom.filled |

**Other**

| Action | Symbol |
|---|---|
| Alarm | alarm |
| Archive | archivebox |
| Calendar | calendar |

### macOS document icons

- If your app has a custom document type, create a **document icon**. Traditionally it is a sheet of paper with a folded top-right corner. If you do not supply one, macOS composites your app icon and the file extension onto a generated icon.
- You can combine a **background fill**, a **centre image** and **text**. The system layers, masks and composites them onto the folded-corner shape.
- **Keep the design simple** with uncomplicated shapes and a reduced palette. It must remain recognisable at 16 x 16 px.
- **A single expressive background fill** can communicate a document type well on its own.
- **Reduce detail in small sizes.** Fine lines blur at small sizes, so use fewer, thicker lines and remove them entirely at 16 x 16.
- **Avoid important content in the top-right corner** of the background fill, which the system masks.
- **Provide background fills** at 512, 256, 128, 32 and 16 px (with @2x versions).
- **Centre images** measure half the canvas size. Keep most of the image within a margin of about 10 percent of the canvas.
- **Specify a short term** if the file extension is unfamiliar, for example "scene" rather than "scn". Keep it short enough to read at small sizes.

---

## Images

Different devices display images at different resolutions. A **point** is an abstract unit that keeps content consistent across displays. A point maps to a varying number of pixels depending on the display.

A **scale factor** describes pixel density. A scale factor of 1 (@1x) is one pixel per point. @2x and @3x describe higher-density displays, which need more pixels.

- **Provide high-resolution assets for every bitmap image,** for every device you support. Name files with @1x, @2x or @3x.
- **Use these scale factors:** iPadOS and watchOS @2x; iOS @2x and @3x; macOS and tvOS @1x and @2x.
- **Design at the lowest resolution and scale up.** Position control points on whole values so they align cleanly at 1x, because 2x and 3x are multiples of 1x.

### Formats

| Image type | Format |
|---|---|
| Bitmap or raster work | De-interlaced PNG |
| PNG that does not need full 24-bit colour | 8-bit colour palette |
| Photos | JPEG (optimised) or HEIC |
| Flat icons, interface icons and other flat artwork that must scale | PDF or SVG |

### Best practices

- **Include a colour profile** with each image.
- **Always test images on a range of actual devices.** An image that looks good in design can pixelate, stretch or compress on other devices.

---

## Inclusion

Inclusive apps put people first by prioritising respectful communication and presenting content and functionality in ways everyone can access and understand.

Designing an inclusive app is iterative. Be prepared to examine your assumptions about how other people think and feel.

### Inclusive by design

Investigate people's goals and perspectives, and use empathy to understand how different people might respond to your content. A word or image may be incomprehensible, or carry a meaning you do not intend, from some perspectives.

Perspectives come from shared human characteristics, including:

- Age
- Gender and gender identity
- Race and ethnicity
- Sexuality
- Physical and cognitive attributes
- Permanent, temporary and situational disabilities
- Language and culture
- Religion
- Education
- Political or philosophical opinions
- Social and economic context

An inoffensive app is not necessarily an inclusive one. Focus on welcoming everyone, not only on removing offensive content.

### Welcoming language

- **Consider tone from different perspectives.** An academic tone can suggest the app is only for highly educated people. Be clear, direct and respectful.
- **Use "you" and "your".** Referring to people as "the user" or "the player" feels distant. Reserve "we" and "our" for your company or software, because they can otherwise suggest a personal relationship that may feel condescending.
- **Define specialised or technical terms** the first time you use them, and make definitions easy to look up. Plain language is easier to read and to translate.
- **Replace colloquial expressions** with plain language. Some phrases have exclusionary origins, and many are hard to translate.
- **Consider carefully before including humour.** It is subjective and hard to translate, and it can confuse, irritate or offend.

### Approachability

An approachable app does not require particular skills or knowledge before use, and gives people a clear path to deepen their understanding.

- Present a clear, straightforward interface that fits in with the platform.
- Build in ways to learn the app. Consider onboarding that is step-by-step for newcomers but lets others skip ahead.

### Gender identity

- **Avoid unnecessary gender references.** For example, "Subscribers can post recipes to your shared folder" is better than "You can let a subscriber post his or her recipes to your shared folder". The gender-neutral wording also localises better.
- **Avoid gender in avatars, emoji and characters.** Give people tools to customise them.
- **Use nongendered human images** for generic people. SF Symbols includes many.
- **If you must collect gender,** offer inclusive options such as nonbinary, self-identify and decline to state. Consider letting people specify their pronouns.

### People and settings

- **Show a range of human characteristics and activities** in images and copy. A fitness app might show exercises demonstrated by people of different backgrounds, body types, ages and abilities.
- **Avoid stereotypical depictions** of occupations or behaviours, such as only male doctors or female nurses.
- **Review the settings and objects you show.** Showing high affluence can seem out of touch. Prefer familiar and relatable places, homes, activities and items.

### Avoiding stereotypes

Everyone holds biases, often unconsciously. Inclusive design means becoming aware of yours.

- Do not assume a narrow definition of family, relationships or lifestyle.
- Security questions based on culture-specific or capability-specific experiences exclude people who did not share that experience. Use universal alternatives such as "What's your favourite activity?" or "What was the name of your first friend?"

### Accessibility

- **Support Apple's accessibility features**, such as VoiceOver, Display Accommodations, closed captioning, Switch Control and Speak Screen.
- **Do not assume a disability would stop someone wanting to use your app.** Assumptions like this narrow your audience.
- **Remember that disability is a spectrum,** and that everyone experiences temporary and situational disabilities at some point.
- **Avoid images and language that exclude people with disabilities.** Include them when showing a variety of people, and avoid using disability to express a negative quality.
- **Use people-first language** when writing about people with disabilities. Describe accomplishments and goals before mentioning a disability. Find out how a specific person or community self-identifies.
- **Prioritise simplicity and perceivability.** Prefer familiar, consistent interactions that everyone can perceive through sight, hearing or touch.

### Languages

- **Prepare for internationalisation** (handling languages and regions beyond your own), then provide translated text and resources for each locale.
- Inclusive writing, avoiding gendered language and stereotypes, prepares your app for localisation.
- **Use SF Symbols for glyphs** to streamline localisation. It includes left-to-right and right-to-left variants.
- **Check colour meanings in each locale.** White signals grief in some places and purity in others. Make sure colour choices communicate the same thing in every version.

---

## Materials

A material is a visual effect that creates depth, layering and hierarchy between foreground and background elements. Colour passes from background through to foreground, which helps people keep a sense of place.

Apple platforms have two kinds of material: **Liquid Glass**, for controls and navigation, and **standard materials**, for differentiation within the content layer.

### Liquid Glass

Liquid Glass forms a distinct functional layer for controls and navigation, such as tab bars and sidebars, floating above the content layer. Content can scroll and peek through beneath these elements, while controls stay legible.

- **Do not use Liquid Glass in the content layer.** Use standard materials for content-layer elements such as app backgrounds. The exception is transient interactive controls like sliders and toggles, which take on a Liquid Glass appearance while a person activates them.
- **Use Liquid Glass effects sparingly.** System components pick up the material automatically. Apply it to custom controls only to the most important functional elements, because overuse distracts from the content.
- **Use the clear variant only over visually rich backgrounds.** Use the regular variant when background content could harm legibility, or for components with significant text, such as alerts, sidebars and popovers. Most system components use regular.
- **For clear Liquid Glass, add a dimming layer if needed.** If the content beneath is bright, add a dark dimming layer at 35 percent opacity. If the content is dark enough, or if AVKit playback controls provide their own dimming, no layer is needed.
- For colour on Liquid Glass, see the Color page.

### Standard materials

Use standard materials and effects, such as blur, vibrancy and blending modes, to give structure to the content beneath Liquid Glass.

- **Choose materials by semantic meaning and recommended usage,** not by the colour they impart. System settings can change their appearance.
- **Use vibrant colours on top of materials** for legibility. A non-vibrant symbol can disappear against a translucent background.
- **Consider contrast and separation.** Thicker materials are more opaque and give better contrast for fine text. Thinner materials stay translucent and remind people of the content behind.

### iOS and iPadOS

- Four standard materials (ultra-thin, thin, regular and thick) are available for content-layer structure, in addition to Liquid Glass.
- Vibrant colours for labels, fills and separators are designed for each material. Labels and fills have several levels of vibrancy, from the default with the highest contrast down to quaternary with the lowest.
- **Avoid quaternary labels on thin and ultra-thin materials,** because contrast is too low.

### macOS

- macOS provides several standard materials with designated purposes, plus vibrant versions of all system colours.
- **Choose when to allow vibrancy** in custom views and controls. Test in a variety of contexts.
- **Choose a background blending mode:** behind window or within window.

---

## Privacy

Privacy is paramount. Be transparent about the privacy-related data and resources you require, and protect the data people allow you to access.

People use their devices in personal ways and expect apps to help them preserve their privacy. When you submit an app, you must describe your privacy practices and the privacy-relevant data you collect. The App Store shows this on your product page, and people use it to decide whether to download.

### Best practices

- **Request access only to data you actually need.** Asking for too much, or asking before someone is interested in a feature, erodes trust. Make permission requests as specific as possible.
- **Be transparent about how you collect and use data.** Respect choices such as Hide My Email and Mail Privacy Protection. Understand your obligations around app tracking.
- **Process data on the device where possible,** for example with the Neural Engine and custom Core ML models. This avoids risky round trips to a server.
- **Use system privacy protections and security practices.** For example, CloudKit provides encryption and key management for additional data types.

### Requesting permission

You must request permission to access personal data (location, health, financial, contacts and other identifying information), user-generated content (email, messages, calendar, photos, audio and video), protected resources (Bluetooth, home automation, Wi-Fi and local networks), device capabilities (camera and microphone), and the advertising identifier used for tracking.

- **Request permission only when your app clearly needs access.** Ideally wait until a person uses the feature that requires it.
- **Avoid requesting permission at launch** unless the app cannot function without it.
- **Write clear purpose strings.** Use a brief, complete sentence that is straightforward and specific. Use sentence case, avoid passive voice, and end with a full stop. For example, "The app records during the night to detect snoring sounds." is good. "Microphone access is needed for a better experience." is poor, because it is passive and vague. "Turn on microphone access." is poor, because it is imperative and gives no reason.

### Pre-alert screens

- **Include only one button,** and make it clear that it opens the system alert. Use a term such as "Continue" or "Next". Do not use "Allow", because that could push people to tap the alert's Allow button without meaning to.
- **Do not add other actions** such as Close or Cancel, unless a legal consent requires them.

### Tracking requests

- **Never show a custom screen that could confuse or mislead** before the system tracking alert. Prohibited designs include offering incentives, imitating the request, showing an image of the alert and annotating it. Such screens lead to App Review rejection.
- A consent screen that complies with local privacy law, shown before or after the alert, is allowed.

### Location button

- In iOS, iPadOS and watchOS, Core Location provides a **location button** so people can grant temporary, one-time access to their location at the moment a task needs it.
- The first time, the system displays an explanatory alert. After that, a tap gives one-time permission without reconfirmation.
- **Consider the location button** for lightweight sharing, such as attaching a location to a post or finding a nearby store.
- **You can customise** the title (for example "Current Location"), the glyph (filled or outlined), background and title colours, and corner radius. You cannot change other visual attributes.
- The system checks for problems such as low contrast. If the button is consistently flagged, it will not give your app location access, so keep the button legible and make sure its text fits at all accessibility sizes and in translation.

### Protecting data

- **Avoid relying on passwords alone.** Use passkeys where possible. If you must use passwords, add two-factor authentication. Use biometric authentication (Face ID, Optic ID or Touch ID) to protect apps people keep logged in.
- **Store sensitive information in a keychain.**
- **Never store passwords or secure content in plain-text files,** even with file permissions.
- **Avoid inventing custom authentication schemes.** Prefer passkeys, Sign in with Apple and password autofill.

### macOS

- **Sign your app with a valid Developer ID** if you distribute outside the Mac App Store.
- **Use app sandboxing.** It protects people's data and is required for all Mac App Store apps.
- **Avoid assuming who is signed in,** because fast user switching means several people may use the same Mac.

---

## Resources

- Apple Design Resources: https://developer.apple.com/design/resources/
- Accessibility Inspector, Icon Composer and SF Symbols, available from Apple's developer tools.
