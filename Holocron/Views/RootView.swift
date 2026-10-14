import SwiftUI
import AppKit

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var narrow = false

    var body: some View {
        @Bindable var m = model
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 290)
        } detail: {
            ZStack(alignment: .bottom) {
                Color.appBG.ignoresSafeArea()
                VStack(spacing: 0) {
                    if !model.folderOK { FolderBanner() }
                    UpdateBanner()
                    DetailRouter()
                }
                if let t = model.toast {
                    Text(t)
                        .font(.system(size: 12.5, weight: .medium))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        .padding(.bottom, 18)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.toast)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { w in
            // Tuck the sidebar away in split screen and bring it back when there is room.
            if w < 820 && !narrow {
                narrow = true
                columns = .detailOnly
            } else if w > 920 && narrow {
                narrow = false
                columns = .all
            }
        }
        .sheet(item: $m.sheet) { s in
            SheetRouter(sheet: s)
                .environment(model)
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $m.showSetup) {
            SetupSheet()
                .environment(model)
                .preferredColorScheme(.light)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsButton()
            }
        }
    }
}

/// The gear in the window toolbar. Opens the Settings window, the same one as Holocron, Settings (Cmd+,).
struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button { openSettings() } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .help("Settings (Cmd+,)")
    }
}

struct DetailRouter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch (model.isEnabled(model.nav) ? model.nav : NavItem.today) {
        case .today: TodayView()
        case .week: WeekView()
        case .classScreen: ClassScreenModule()
        case .term: TermView()
        case .units: UnitsView()
        case .devotion: DevotionView()
        case .students: StudentsView()
        case .quick: QuickLogView()
        case .assess: MarkClassView()
        case .hours: HoursView()
        }
    }
}

struct SheetRouter: View {
    var sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .plan(let d, let p, let edit): PlanSheet(date: d, per: p, startEditing: edit)
        case .change(let d, let p): ChangeSheet(date: d, per: p)
        case .move(let d, let p): MoveSheet(date: d, per: p)
        case .dayType(let d): DayTypeSheet(date: d)
        case .swap(let a, let b): SwapSheet(a: a, b: b)
        case .bump(let t, let s, let i, let plans): BumpSheet(title: t, sub: s, intro: i, plans: plans)
        case .unit(let id): UnitSheet(unitID: id)
        case .pack(let sid): PackSheet(studentID: sid)
        case .quick(let ids): QuickLogSheet(ids: ids)
        case .newStudent: NewStudentSheet()
        }
    }
}

struct FolderBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.appRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("No data folder connected").font(.system(size: 13, weight: .semibold))
                Text(model.folderMessage.isEmpty
                     ? "Nothing you type will be saved until a data folder is connected."
                     : model.folderMessage)
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
            Spacer()
            Button("Set up data folder") { model.showSetup = true }
        }
        .padding(12)
        .background(Color.appRed.opacity(0.1))
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var height: CGFloat = 900

    var body: some View {
        @Bindable var m = model
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("HOLOCRON").font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(Color.appBlue)
                    Text(model.db.className).font(.system(size: 21, weight: .bold))
                }
                WeekBox()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List(selection: Binding<NavItem?>(
                get: { model.nav },
                set: { if let n = $0 { model.nav = n } })) {
                ForEach(model.visibleNav) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)

            Divider()
            // The mini calendar shrinks to one week on shorter windows, and steps aside on very short ones,
            // so every module stays in reach.
            if height > 620 {
                MiniCalendar(forceWeek: height <= 780)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider()
            }
            FolderStatus()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}

struct WeekBox: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let ref = model.cursor
        let t = model.db.termOf(ref)
        VStack(alignment: .leading, spacing: 3) {
            if let t = t, let w = model.db.termWeek(ref) {
                Text("Term \(t.term), \(t.year)").font(.system(size: 11)).foregroundStyle(Color.ink2)
                Text("Week \(w)").font(.system(size: 22, weight: .semibold, design: .rounded))
                if let l = model.db.weekLetter(ref) { WeekBadge(letter: l) }
            } else {
                Text("Outside term").font(.system(size: 11)).foregroundStyle(Color.ink2)
                Text(shortDate(ref)).font(.system(size: 22, weight: .semibold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
    }
}

struct MiniCalendar: View {
    @Environment(AppModel.self) private var model
    /// Set by the sidebar when the window is too short for a whole month.
    var forceWeek = false
    @AppStorage("miniCalMode") private var modeRaw = "week"
    /// Weeks away from the week that holds the selected day. Resets when the selected day changes.
    @State private var weekOffset = 0

    private var showMonth: Bool { modeRaw == "month" && !forceWeek }

    var body: some View {
        let today = todayISO()
        VStack(spacing: 4) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                Spacer()
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
            }
            if !forceWeek {
                Picker("", selection: $modeRaw) {
                    Text("Week").tag("week")
                    Text("Month").tag("month")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .padding(.bottom, 2)
            }
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i])
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.ink3)
                        .frame(maxWidth: .infinity)
                }
            }
            let rows = showMonth ? monthRows() : [weekCells()]
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        dayCell(rows[r][c], today: today)
                    }
                }
            }
        }
        .onChange(of: model.cursor) { weekOffset = 0 }
        .onChange(of: modeRaw) {
            // Opening the month view lands on the month of the day you are looking at.
            if let (y, m, _) = Cal.parts(addDays(mondayOf(model.cursor), 7 * weekOffset)) {
                model.calMonth = Cal.make(y, m, 1)
            }
        }
    }

    private var weekStart: String { addDays(mondayOf(model.cursor), 7 * weekOffset) }

    private var title: String {
        if showMonth {
            let (y, mo, _) = Cal.parts(model.calMonth) ?? (2026, 1, 1)
            return "\(Cal.monthLong[mo - 1]) \(String(y))"
        }
        let first = weekStart
        let last = addDays(first, 6)
        guard let (_, m1, d1) = Cal.parts(first), let (_, m2, d2) = Cal.parts(last) else { return "" }
        return m1 == m2
            ? "\(d1) to \(d2) \(Cal.monthShort[m2 - 1])"
            : "\(d1) \(Cal.monthShort[m1 - 1]) to \(d2) \(Cal.monthShort[m2 - 1])"
    }

    private func weekCells() -> [String?] {
        (0..<7).map { addDays(weekStart, $0) }
    }

    private func monthRows() -> [[String?]] {
        let first = model.calMonth
        let (y, mo, _) = Cal.parts(first) ?? (2026, 1, 1)
        let lead = dayIdx(first)
        let daysInMonth = Cal.civilFromDays(Cal.daysFromCivil(mo == 12 ? y + 1 : y, mo == 12 ? 1 : mo + 1, 1) - 1).2
        var c: [String?] = Array(repeating: nil, count: lead)
        for d in 1...daysInMonth { c.append(Cal.make(y, mo, d)) }
        while c.count % 7 != 0 { c.append(nil) }
        return stride(from: 0, to: c.count, by: 7).map { Array(c[$0..<$0 + 7]) }
    }

    @ViewBuilder
    private func dayCell(_ d: String?, today: String) -> some View {
        if let d = d {
            let school = model.db.isSchoolDay(d)
            let nt = model.db.isNonTeaching(d)
            let isToday = d == today
            let sel = d == model.cursor
            Button {
                model.cursor = d
                model.nav = .today
            } label: {
                Text(String(Cal.parts(d)?.2 ?? 0))
                    .font(.system(size: 11.5, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isToday ? Color.white : (nt ? Color.appRed : (school ? Color.primary : Color.ink3.opacity(0.6))))
                    .frame(width: 24, height: 22)
                    .background(
                        Circle().fill(isToday ? Color.appBlue : (sel ? Color.appBlue.opacity(0.15) : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .help(longDate(d))
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 22)
        }
    }

    private func shift(_ n: Int) {
        if !showMonth { weekOffset += n; return }
        guard let (y, m, _) = Cal.parts(model.calMonth) else { return }
        var ny = y, nm = m + n
        while nm < 1 { nm += 12; ny -= 1 }
        while nm > 12 { nm -= 12; ny += 1 }
        model.calMonth = Cal.make(ny, nm, 1)
    }
}

struct FolderStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(model.folderOK ? Color.appGreen : Color.appRed).frame(width: 7, height: 7)
                Text(model.folderOK ? "Saved in \(model.folderLabel)" : "Not connected")
                    .font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
            if let p = model.folder.plannerURL {
                Text("Planner: \(p.lastPathComponent)").font(.system(size: 11.5)).foregroundStyle(Color.ink3).lineLimit(1)
            }
            Button("Reload from folder") {
                model.flushNow(wait: true)
                model.loadAll()
                model.showToast("Reloaded from folder")
            }
            .frame(maxWidth: .infinity)
            Text("v\(AppModel.appVersion)").font(.system(size: 10.5)).foregroundStyle(Color.ink3)
        }
    }
}

// MARK: - First run and folder setup

struct SetupSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set up Holocron").font(.system(size: 22, weight: .bold))
            Text("Holocron keeps everything as CSV files in a folder you can back up and edit. The usual place is a Holocron folder in your iCloud Drive.")
                .font(.system(size: 13)).foregroundStyle(Color.ink2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Current folder").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink2)
                Text(model.folder.url.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            }
            .card()

            Button {
                model.useFolder(DataFolder.defaultURL(), createIfNeeded: true)
                if model.folderOK { dismiss() }
                else { message = model.folderMessage.isEmpty ? "iCloud Drive could not be opened." : model.folderMessage }
            } label: {
                Label("Use iCloud Drive / Holocron / data", systemImage: "icloud")
            }
            .buttonStyle(.borderedProminent)

            Button {
                chooseFolder(title: "Choose the data folder", create: true) { url in
                    model.useFolder(url, createIfNeeded: false)
                    if model.folderOK { dismiss() }
                }
            } label: {
                Label("Choose a different folder...", systemImage: "folder")
            }

            Button {
                chooseFolder(title: "Choose the folder to import from", create: false) { url in
                    if !model.folder.exists() { model.useFolder(DataFolder.defaultURL(), createIfNeeded: true) }
                    message = model.importData(from: url)
                    if model.folderOK { dismiss() }
                }
            } label: {
                Label("Import my existing planner data...", systemImage: "square.and.arrow.down")
            }
            Text("Pick an existing Holocron data folder. Its CSV files and photos are copied across.")
                .font(.system(size: 12)).foregroundStyle(Color.ink3)

            if !message.isEmpty {
                Text(message).font(.system(size: 12.5)).foregroundStyle(Color.appAmber)
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

func chooseFolder(title: String, create: Bool, then: @escaping (URL) -> Void) {
    let p = NSOpenPanel()
    p.title = title
    p.canChooseFiles = false
    p.canChooseDirectories = true
    p.canCreateDirectories = create
    p.allowsMultipleSelection = false
    if p.runModal() == .OK, let u = p.url { then(u) }
}
