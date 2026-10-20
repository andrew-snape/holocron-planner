# Apple Human Interface Guidelines: Components (Part E)

Source: https://developer.apple.com/design/human-interface-guidelines/
Copyright 2026 Apple Inc. All rights reserved.

Pages in this part: Charts (and Charting data), Image views, Text views, Web views.

Platform sections for visionOS, watchOS and tvOS are summarised or removed where they do not apply to your projects. Dashes in quoted guidance have been replaced with punctuation to match house style.

---

## Charts

An effective chart highlights a few key pieces of information in a dataset, so people can gain insight and make decisions. Examples include a weather forecast's effect on plans, stock performance over time, or fitness progress.

### Anatomy

- **Mark:** a visual representation of a data value. The main types are bar, line and point.
- **Plot area:** the region that contains the marks.
- **Scale:** maps data values (numbers, dates or categories) to visual properties such as position, height or colour.
- **Axes:** frames of reference for the marks, usually one horizontal and one vertical.
- **Ticks and grid lines:** reference points along an axis, which help people estimate values.
- **Labels, accessibility labels, titles, subtitles and annotations:** descriptive content that gives context.
- **Legend:** explains properties that are not position, such as colour or shape used to show categories.

### Marks

- **Bar marks** compare categories or show parts of a whole. Over time, they work well when each value is a sum, such as daily steps.
- **Line marks** show change over time, and the slope reveals the trend.
- **Point marks** show individual values, relationships between two properties, outliers and clusters.
- **Combine mark types** when it adds clarity, such as points on a line to highlight individual readings.

### Axes

- **Use a fixed range** when the minimum and maximum are meaningful for every possible value, such as 0% to 100% battery charge.
- **Use a dynamic range** when values vary widely and you want the marks to fill the plot area.
- **Choose the lower bound by mark type.** Bar charts usually work well starting at zero, so people can compare heights. A heart rate chart may need a higher lower bound, or differences between readings disappear.
- **Use familiar tick sequences,** such as 0, 5, 10, rather than less common intervals such as 1, 6, 11.
- **Match grid line density to the task.** Too many grid lines distract, and too few make values hard to estimate. If people inspect individual points, use fewer grid lines and lighter labels so the data stays prominent.

### Descriptive content

- **Describe the chart's purpose before people view it.** Informative titles and labels matter especially for VoiceOver users and people with some cognitive disabilities.
- **Summarise the main message** so people grasp the key point at a glance, without reading the detail.

### Best practices

- **Highlight important information,** and keep the chart simple. If there is a lot of data, let people reveal more detail gradually, such as different levels of detail or subsets of data.
- **Prefer common chart types** such as bar and line charts, because people already know how to read them. For a novel chart, help people learn how to read it, for example by animating its parts in turn.
- **Look at the data from several levels** (totals and averages, subsets, individual values) to find details that enrich the chart.
- **Add descriptive text** such as titles, subtitles and annotations to emphasise key information and takeaways.
- **Match chart size to its function.** It should be large enough to read details and support the interaction you want, or small for a glanceable summary or a preview.
- **Keep charts consistent** across an app, and deviate only to highlight a real difference. For several charts showing the same data, keep the same type, colours and annotations so people see that the data is unchanged.
- **Make every chart accessible,** with accessibility labels for values and components, and interactive elements people can use.
- **Keep the data prominent.** Descriptions and axes should give context without competing with the marks.
- **In compact layouts, maximise the plot area width.** Keep vertical axis labels short, and move units into the title where you can.
- **Let people interact with the data,** but never require interaction to reveal critical information. A Stocks-style line chart with a draggable indicator is an example.
- **Make marks easy to target.** Small marks are hard to hit, so let the whole plot area respond to a drag or scrub.
- **Support keyboard and Switch Control navigation** in interactive charts. Use a logical path, such as moving along the X axis, or move between subsets for very large datasets.
- **Make important changes noticeable.** Animate changes, but also flag them in other ways so VoiceOver users and people who turn off animations know about them.
- **Align the chart** with surrounding content. A common approach is to keep the leading edge aligned and place grid line labels on the trailing side.

### Colour

- **Do not rely on colour alone.** Add shapes or patterns, such as a circle and a diamond for two series.
- **Separate adjacent colour areas,** such as stacked segments, with a narrow gap.

### Accessibility

- **Swift Charts provides defaults:** Audio Graphs and an accessibility element for each mark or group of marks.
- **Customise Audio Graphs** with a chart title and a summary, so VoiceOver speaks the purpose and main features. Without Audio Graphs, describe the chart type, what each axis represents and the axis bounds.
- **Choose the label granularity by purpose.** Describe every mark when people need individual values, such as a step count for each day. Summarise groups of marks when the purpose is the overall shape, such as elevation over a route.
- **Write labels that describe what the values mean,** with the date or place that gives them context. Avoid subjective words such as "rapidly" or "almost", and use actual values.
- **Write clear formats.** "June 6" is clearer than "6/6", and "60 minutes" is clearer than "60m".
- **Describe what details represent, not how they look.** Name the series, but do not describe its colour.
- **Be consistent** about which axis you mention first.
- **Hide visible axis and tick labels from assistive technologies,** because VoiceOver users get the values from the accessibility labels and Audio Graphs.

### watchOS

- Avoid complex chart interactions. Show information people can take in at a glance, and support simple interactions. If the app also runs on another platform, use that version for more detail.

---

## Image views

An image view displays a single image, or an animated sequence of images, on a transparent or opaque background. It can stretch, scale, size to fit or pin the image. Image views are usually not interactive.

### Best practices

- **Use an image view when the view's main purpose is to show an image.** If the image must be clickable, use a button that displays the image, rather than adding button behaviour to an image view.
- **Use a symbol or interface icon for icons.** SF Symbols is a large library of vector symbols that can take colour and opacity. Symbols and interface icons can also use the accent colours people choose.
- **Take care when overlaying text on images.** Overlaid text can lose clarity. Ensure good contrast, and consider a text shadow or a background layer.
- **Use a consistent size for images in an animation.** Prescaled images avoid work at runtime, and performance is better when all images share a size and shape.

### Content

- Image views can display PNG, JPEG and PDF, among other formats. See Images.

### macOS

- **For an editable image, use an image well.** It supports copying, pasting, dragging and clearing with the Delete key.
- **For a clickable image, use an image button.** It contains an image or icon and triggers an app action.

### visionOS

- Image views can display 2D and stereoscopic images, and spatial photos. With RealityKit, you can display images outside image views next to 3D content, or create a spatial scene from a 2D image.

### tvOS

- Many tvOS images combine layers with transparency to create depth. See Layered images.

### iOS, iPadOS and watchOS

- **watchOS:** use SwiftUI for animations where you can. Otherwise you can animate a sequence of images in an image element with WatchKit.
- **iOS and iPadOS:** no additional considerations.

---

## Text views

A text view displays multiline, styled text that can optionally be editable. It can be any height, and it scrolls when its content overflows. By default, text is aligned to the leading edge and uses the system label colour. On iOS, iPadOS and visionOS, an editable text view shows the keyboard when selected.

### Best practices

- **Use a text view for long, editable or specially formatted text.** For a short amount of text, use a label, or a text field if it is editable.
- **Keep text legible.** You can use several fonts, colours and alignments, but readability comes first. Adopt Dynamic Type, and test with accessibility options such as bold text.
- **Make useful text selectable,** such as an error message, serial number or IP address, so people can copy it.

### iOS and iPadOS

- **Show the keyboard type that suits the content** when editing.

### tvOS

- Text input is minimal on tvOS, so editable text uses text fields instead of text views.

### macOS, visionOS and watchOS

- No additional considerations.

---

## Web views

A web view loads and displays web content, such as embedded HTML or a website, inside your app. For example, Mail uses one to show the HTML of a message.

### Best practices

- **Support back and forward navigation** when people are likely to visit several pages. A web view does not provide these by default, so supply the controls yourself.
- **Do not build a web browser.** A web view is fine for briefly showing a website without leaving your app. Safari is how people browse the web, and copying its features is unnecessary.

### Platform notes

- **iOS, iPadOS, macOS and visionOS:** no additional considerations.
- **tvOS and watchOS:** not supported.

---

## Notes for this project

For Holocron, a chart of hours by term or by DOTTL type would be a Charts case. Use a bar chart with a zero baseline so the hours can be compared, use a consistent colour per DOTTL type with shape or label support, and make the plot readable at phone width.
