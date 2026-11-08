import SwiftUI
import AppKit

// MARK: - Settings

/// Settings forms sit on Holocron's grey background, with white rows like the rest of the app.
extension View {
    func settingsForm() -> some View {
        self.formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBG)
            .listRowBackground(Color.cardBG)
    }
}

/// One page of Settings. The raw values are stored in the `settingsTab` default, so keep them stable.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, timetable, calendar, intelligence, folders, privacy, yearend, updates
    var id: String { rawValue }

    /// Reads a stored value. The old Data tab is now Folders, and anything unknown opens General.
    init(stored: String) {
        if stored == "data" { self = .folders }
        else { self = SettingsTab(rawValue: stored) ?? .general }
    }

    var title: String {
        switch self {
        case .general: return "General"
        case .timetable: return "Timetable"
        case .calendar: return "Calendar"
        case .intelligence: return "Apple Intelligence"
        case .folders: return "Folders"
        case .privacy: return "Privacy"
        case .yearend: return "Year End"
        case .updates: return "Updates"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .timetable: return "clock"
        case .calendar: return "calendar"
        case .intelligence: return "apple.intelligence"
        case .folders: return "folder.fill"
        case .privacy: return "hand.raised.fill"
        case .yearend: return "archivebox.fill"
        case .updates: return "arrow.down.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .general, .updates: return .ink2
        case .timetable, .intelligence, .folders, .privacy: return .appBlue
        case .calendar: return .appRed
        case .yearend: return .appAmber
        }
    }
    var blurb: String {
        switch self {
        case .general: return "Your class name, which screens are on, and reloading."
        case .timetable: return "Periods, subjects and their colours."
        case .calendar: return "Term dates and days with no teaching."
        case .intelligence: return "Suggestions, report comments, Siri and Shortcuts, all on this Mac."
        case .folders: return "Where your student and planner files live."
        case .privacy: return "What stays with you when the planner is shared."
        case .yearend: return "Archive the year, import a copy or begin again."
        case .updates: return "Check for a newer version of Holocron."
        }
    }
    /// Extra words the sidebar search matches, beyond the title.
    var keywords: String {
        switch self {
        case .general: return "class name modules screens switch off reload version"
        case .timetable: return "periods bell times subjects colour release rename"
        case .calendar: return "terms dates weeks non-teaching holiday pupil free"
        case .intelligence: return "ai suggestions report comments rules ilp drafts model siri names spotlight shortcuts voice dictate"
        case .folders: return "student folder planner folder shared icloud finder change"
        case .privacy: return "devotion quotes private lessons subject share"
        case .yearend: return "archive import start over clear begin again new year"
        case .updates: return "update version install check release"
        }
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return q.split(separator: " ").allSatisfy { word in
            title.localizedCaseInsensitiveContains(word) || keywords.localizedCaseInsensitiveContains(word)
        }
    }
}

// MARK: - Chrome

/// A coloured rounded square with a white symbol, as in System Settings.
struct SettingsIcon: View {
    var symbol: String
    var tint: Color
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.55, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// The large tile, title and one-line blurb at the top of a pane.
struct SettingsPaneTitle: View {
    var pane: SettingsTab

    var body: some View {
        VStack(spacing: 6) {
            SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 48)
            Text(pane.title).font(.title2.bold())
            Text(pane.blurb).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The first section of a form pane.
struct SettingsPaneHeader: View {
    var pane: SettingsTab

    var body: some View {
        Section {
            SettingsPaneTitle(pane: pane)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Shell

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("settingsTab") private var tabRaw = SettingsTab.general.rawValue
    @State private var query = ""

    private var tab: SettingsTab { SettingsTab(stored: tabRaw) }

    private static let groups: [[SettingsTab]] = [
        [.general, .timetable, .calendar],
        [.intelligence],
        [.folders, .privacy, .yearend, .updates],
    ]

    var body: some View {
        let selection = Binding<SettingsTab?>(get: { tab }, set: { if let t = $0 { tabRaw = t.rawValue } })
        let visible = Self.groups.map { $0.filter { $0.matches(query) } }
        NavigationSplitView {
            List(selection: selection) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    headerCard
                }
                ForEach(visible.indices, id: \.self) { g in
                    if !visible[g].isEmpty {
                        Section {
                            ForEach(visible[g]) { t in
                                Label { Text(t.title) } icon: { SettingsIcon(symbol: t.symbol, tint: t.tint) }
                                    .tag(t)
                            }
                        }
                    }
                }
                if visible.allSatisfy({ $0.isEmpty }) {
                    Text("No results").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: "Search")
            .navigationSplitViewColumnWidth(215)
        } detail: {
            pane(for: tab)
        }
        .toolbar(removing: .sidebarToggle)
        .navigationTitle(tab.title)
    }

    /// The app icon, class name and version. Choosing it opens General.
    private var headerCard: some View {
        Button { tabRaw = SettingsTab.general.rawValue } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.db.className).font(.headline).lineLimit(1)
                    Text("Holocron \(Updater.currentVersion)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.db.className), Holocron \(Updater.currentVersion). Opens General.")
    }

    @ViewBuilder
    private func pane(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralPane()
        case .timetable: TimetablePane()
        case .calendar: CalendarPane()
        case .intelligence: IntelligenceSettings()
        case .folders: FoldersPane()
        case .privacy: PrivacyPane()
        case .yearend: YearEndPane()
        case .updates: UpdatesSettings()
        }
    }
}
