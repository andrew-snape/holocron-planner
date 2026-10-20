import SwiftUI
import AppKit

// MARK: - Topics

/// The pages of the Help window. The Help menu opens the window on one of these.
enum HelpTopic: String, CaseIterable, Identifiable {
    case start, using, data, ai, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: return "Getting started"
        case .using: return "Using Holocron"
        case .data: return "Loading data"
        case .ai: return "Entering data with AI"
        case .shortcuts: return "Keyboard shortcuts"
        }
    }

    /// The wording used in the Help menu.
    var menuTitle: String {
        switch self {
        case .start: return "Getting Started"
        case .using: return "Using Holocron"
        case .data: return "Loading Data and CSV Files"
        case .ai: return "Entering Data with an AI Assistant"
        case .shortcuts: return "Keyboard Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .start: return "flag"
        case .using: return "book"
        case .data: return "folder"
        case .ai: return "sparkles"
        case .shortcuts: return "command"
        }
    }

    static let storageKey = "helpTopic"

    /// Remembers the page so the Help window opens on it. The window reads this with @AppStorage.
    func select() { UserDefaults.standard.set(rawValue, forKey: HelpTopic.storageKey) }
}

// MARK: - Actions shared by the menu and the window

enum HelpActions {
    static let repoURL = URL(string: "https://github.com/andrew-snape/holocron-planner")!

    /// Opens a folder in Finder. Beeps when the folder is not there.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard DataFolder.isDirectory(url) else { NSSound.beep(); return false }
        return NSWorkspace.shared.open(url)
    }

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

// MARK: - Menu bar

/// Replaces the standard Help menu.
struct HelpCommands: Commands {
    var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private func show(_ topic: HelpTopic) {
        topic.select()
        openWindow(id: "help")
    }

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Holocron Help") { show(.start) }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            Divider()
            ForEach([HelpTopic.using, .data, .ai, .shortcuts]) { t in
                Button(t.menuTitle) { show(t) }
            }
            Divider()
            if model.folder.plannerURL == nil {
                Button("Open Data Folder") { HelpActions.open(model.folder.url) }
                    .disabled(!model.folder.studentExists)
            } else {
                Button("Open Student Folder") { HelpActions.open(model.folder.url) }
                    .disabled(!model.folder.studentExists)
                Button("Open Planner Folder") {
                    if let p = model.folder.plannerURL { HelpActions.open(p) }
                }
                .disabled(!model.folder.plannerExists)
            }
            Button("Copy CSV Guide for AI") {
                model.copyText(CSVGuide.text, toast: "CSV guide copied. Paste it into your AI chat.")
            }
            Divider()
            Button("Holocron on GitHub...") { NSWorkspace.shared.open(HelpActions.repoURL) }
        }
    }
}

// MARK: - Window

struct HelpView: View {
    @AppStorage(HelpTopic.storageKey) private var topicRaw = HelpTopic.start.rawValue
    @State private var columns: NavigationSplitViewVisibility = .all

    private var topic: HelpTopic { HelpTopic(rawValue: topicRaw) ?? .start }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            VStack(spacing: 0) {
                Text("HELP")
                    .font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(Color.appBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                // Same pattern as the main sidebar: a List bound to the selection, so the
                // highlight always follows the page, including pages opened from the Help menu.
                List(selection: Binding<HelpTopic?>(
                    get: { HelpTopic(rawValue: topicRaw) ?? .start },
                    set: { if let t = $0 { topicRaw = t.rawValue } })) {
                    ForEach(HelpTopic.allCases) { t in
                        Label(t.title, systemImage: t.symbol)
                            .tag(t)
                    }
                }
                .listStyle(.sidebar)
                HelpOpenFolderButtons()
                    .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 290)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HelpBody(topic: topic)
                }
                .padding(28)
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(topicRaw)
            .background(Color.appBG)
        }
        .frame(minWidth: 740, minHeight: 520)
    }
}

// MARK: - Building blocks for the pages

struct HelpTitle: View {
    var text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(size: 26, weight: .bold)).padding(.bottom, 2)
    }
}

struct HelpHeading: View {
    var text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(size: 16, weight: .semibold)).padding(.top, 12)
    }
}

/// Help text with **bold**, *italic* and `code` marks turned into styling. Read straight from the
/// string, so the text is never looked up as a localisation key.
private func helpText(_ markdown: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return Text((try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown))
}

/// A paragraph. Supports **bold** and `code` in the text.
struct HelpPara: View {
    var text: String
    var secondary = false
    init(_ t: String, secondary: Bool = false) { text = t; self.secondary = secondary }
    var body: some View {
        helpText(text)
            .font(.system(size: 13.5))
            .foregroundStyle(secondary ? Color.ink2 : Color.primary.opacity(0.88))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct HelpBullets: View {
    var items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, t in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle().fill(Color.appBlue).frame(width: 5, height: 5).offset(y: -1.5)
                    helpText(t)
                        .font(.system(size: 13.5)).foregroundStyle(Color.primary.opacity(0.88))
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct HelpSteps: View {
    var items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, t in
                HStack(alignment: .top, spacing: 11) {
                    Text(String(i + 1))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.appBlue))
                    helpText(t)
                        .font(.system(size: 13.5)).foregroundStyle(Color.primary.opacity(0.88))
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }
}

struct HelpCallout: View {
    enum Kind { case info, care }
    var kind: Kind = .info
    var title: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind == .info ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(kind == .info ? Color.appBlue : Color.appAmber)
                .padding(.top, 1)
                .accessibilityLabel(kind == .info ? "Note" : "Caution")
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                helpText(text)
                    .font(.system(size: 13)).foregroundStyle(Color.primary.opacity(0.85))
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background((kind == .info ? Color.appBlue : Color.appAmber).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Text you can select, with a Copy button.
struct HelpCode: View {
    var text: String
    var copyLabel = "Copy"
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copied" : copyLabel) {
                HelpActions.copy(text)
                flash($copied)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A button that jumps to another Help page.
struct HelpTopicLink: View {
    var topic: HelpTopic
    var body: some View {
        Button { topic.select() } label: {
            Label(topic.title, systemImage: topic.symbol)
        }
    }
}

struct HelpKeyRow: View {
    var keys: String
    var action: String
    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .padding(.vertical, 3).padding(.horizontal, 9)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(width: 170, alignment: .leading)
            Text(action).font(.system(size: 13.5))
            Spacer(minLength: 0)
        }
    }
}

/// Open Data Folder buttons, shown at the bottom of the Help sidebar on every page.
/// With a separate planner folder there is one button for each folder.
struct HelpOpenFolderButtons: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            if let planner = model.folder.plannerURL {
                button("Open Student Folder", url: model.folder.url)
                button("Open Planner Folder", url: planner)
            } else {
                button("Open Data Folder", url: model.folder.url)
            }
        }
    }

    private func button(_ title: String, url: URL) -> some View {
        Button { HelpActions.open(url) } label: {
            Label(title, systemImage: "folder")
                .frame(maxWidth: .infinity)
        }
        .disabled(!DataFolder.isDirectory(url))
    }
}
