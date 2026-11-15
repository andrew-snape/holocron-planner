import Foundation
import Observation

// MARK: - Welcome board data
//
// needs.csv, docs.csv and prompts.csv live in the student folder (they are not planner tables). A linked
// document stays where the teacher keeps it: only its path and a bookmark are saved, and unlinking it
// never touches the file.

extension Database {
    // MARK: Subject icons

    /// The SF Symbol for a subject or block: the one chosen in subjects.csv, else one worked out from the name.
    func icon(forSubject name: String) -> String {
        let chosen = subjectInfo(name).icon
        if !chosen.isEmpty { return chosen }
        let g = BoardIcons.guess(name)
        return g.isEmpty ? "book.closed" : g
    }

    /// Saves the icon chosen for a subject. Empty goes back to the one worked out from the name.
    func setSubjectIcon(_ name: String, _ icon: String) {
        update(.subjects, where: { $0.s("subject") == name }) { $0["icon"] = icon }
        touch(.subjects)
    }

    // MARK: What you need today

    func needs(on date: String) -> [Row] {
        rows(.needs).filter { $0.s("date") == date && !$0.s("item").isEmpty }
    }

    /// Adds an item to a day's list. A blank item, or one already on the list, is ignored.
    func addNeed(_ item: String, on date: String) {
        let t = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !needs(on: date).contains(where: { $0.s("item").caseInsensitiveCompare(t) == .orderedSame }) else { return }
        append(.needs, ["id": uid(), "date": date, "item": t])
        touch(.needs)
    }

    func removeNeed(id: String) {
        remove(.needs, where: { $0.s("id") == id })
        touch(.needs)
    }

    /// The items on the most recent earlier day with a list.
    func lastNeeds(before date: String) -> [String] {
        NeedsList.lastList(before: date, in: rows(.needs))
    }

    /// Copies the last list onto a day. Returns how many items were added.
    @discardableResult
    func copyLastNeeds(to date: String) -> Int {
        let before = needs(on: date).count
        for item in lastNeeds(before: date) { addNeed(item, on: date) }
        return needs(on: date).count - before
    }

    // MARK: Documents for today

    func docs(on date: String) -> [Row] {
        rows(.docs).filter { $0.s("date") == date && !$0.s("path").isEmpty }
    }

    /// Links a file to a day. The file is not copied. A file already linked to the day is skipped.
    func addDoc(_ url: URL, on date: String) {
        let path = url.standardizedFileURL.path
        guard !docs(on: date).contains(where: { $0.s("path") == path }) else { return }
        let mark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil))?.base64EncodedString() ?? ""
        append(.docs, ["id": uid(), "date": date, "title": url.deletingPathExtension().lastPathComponent, "path": path, "bookmark": mark])
        touch(.docs)
    }

    /// Takes the link off the day. The file itself is left alone.
    func removeDoc(id: String) {
        remove(.docs, where: { $0.s("id") == id })
        touch(.docs)
    }

    /// Where a linked file is now. The bookmark finds a file that has been moved or renamed, and the saved
    /// path is brought up to date when it has. Nil when the file cannot be found.
    func locateDoc(_ row: Row) -> URL? {
        let fm = FileManager.default
        if let data = Data(base64Encoded: row.s("bookmark")), !data.isEmpty {
            var stale = false
            // Never mounts a network drive or asks anything, so a click cannot hang. A file in the Bin counts as gone.
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
               fm.fileExists(atPath: url.path), !Self.isInTrash(url) {
                let path = url.standardizedFileURL.path
                if path != row.s("path") || stale {
                    let id = row.s("id")
                    let mark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil))?.base64EncodedString() ?? row.s("bookmark")
                    update(.docs, where: { $0.s("id") == id }) { $0["path"] = path; $0["bookmark"] = mark }
                    touch(.docs)
                }
                return url
            }
        }
        let path = row.s("path")
        return fm.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    static func isInTrash(_ url: URL) -> Bool {
        var rel: FileManager.URLRelationship = .other
        if (try? FileManager.default.getRelationship(&rel, of: .trashDirectory, in: .userDomainMask, toItemAt: url)) != nil,
           rel == .contains { return true }
        return url.path.contains("/.Trash/")
    }

    /// The iCloud placeholder (`.name.icloud`) for a file that is in iCloud but not downloaded to this Mac.
    static func cloudPlaceholder(_ path: String) -> URL {
        let u = URL(fileURLWithPath: path)
        return u.deletingLastPathComponent().appendingPathComponent("." + u.lastPathComponent + ".icloud")
    }

    /// True when the file is in iCloud but not on this Mac yet. Asks iCloud to download it.
    func downloadDocFromCloud(_ row: Row) -> Bool {
        let path = row.s("path")
        guard FileManager.default.fileExists(atPath: Self.cloudPlaceholder(path).path) else { return false }
        try? FileManager.default.startDownloadingUbiquitousItem(at: URL(fileURLWithPath: path))
        return true
    }

    /// Paths of linked files that are not on this Mac (an iCloud placeholder counts as there). Checked off the
    /// main thread, so a slow network drive cannot stall the screen.
    static func missingDocPaths(_ paths: [String]) async -> Set<String> {
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            return Set(paths.filter { !fm.fileExists(atPath: $0) && !fm.fileExists(atPath: cloudPlaceholder($0).path) })
        }.value
    }

    // MARK: Question prompts

    var prompts: [String] {
        rows(.prompts).map { $0.s("prompt").trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Replaces the prompt list with the lines typed in the prompts sheet. A line that was already there keeps its id.
    func setPrompts(_ lines: [String]) {
        var ids: [String: String] = [:]
        for r in rows(.prompts) where ids[r.s("prompt")] == nil { ids[r.s("prompt")] = r.s("id") }
        let clean = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        // Each id is used once, so a question typed twice gets a new id the second time.
        setRows(.prompts, clean.map { line -> Row in
            ["id": ids.removeValue(forKey: line) ?? uid(), "prompt": line]
        })
        touch(.prompts)
    }

    // MARK: Weather settings

    static let weatherPlaceKey = "weather_place"
    static let weatherLatKey = "weather_lat"
    static let weatherLonKey = "weather_lon"

    /// The town, latitude and longitude for the forecast, or nil when none is set (the weather is then off).
    var weatherPlace: WeatherPlace? {
        guard let name = setting(Self.weatherPlaceKey), !name.isEmpty,
              let lat = Double(setting(Self.weatherLatKey) ?? ""), let lon = Double(setting(Self.weatherLonKey) ?? "") else { return nil }
        return WeatherPlace(name: name, region: "", latitude: lat, longitude: lon)
    }

    func setWeatherPlace(_ p: WeatherPlace?) {
        setSetting(Self.weatherPlaceKey, p?.name ?? "")
        setSetting(Self.weatherLatKey, p.map { String(format: "%.4f", $0.latitude) } ?? "")
        setSetting(Self.weatherLonKey, p.map { String(format: "%.4f", $0.longitude) } ?? "")
    }
}

// MARK: - Forecast in memory

/// The forecast for the Welcome board. Shared by the main window and the projector window, kept in memory
/// only, and fetched at most every 30 minutes while a board is showing. A failed fetch keeps the last
/// forecast and says nothing; the board shows "Weather not available" only when there is none.
@Observable
final class BoardWeather {
    private(set) var days: [WeatherDay] = []
    private(set) var failed = false
    @ObservationIgnored private var fetchedAt: Date?
    @ObservationIgnored private var fetchedFor = ""
    /// The place the board wants now. A fetch for any other place is thrown away when it comes back.
    @ObservationIgnored private var wanted = ""
    /// The fetch under way, shared by every board asking for the same place.
    @ObservationIgnored private var inFlight: (key: String, task: Task<[WeatherDay], Never>)?

    private static func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("Holocron", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        return req
    }

    /// The forecast, or no days when the fetch failed or was cancelled.
    private static func fetch(_ url: URL) async -> [WeatherDay] {
        guard let (data, resp) = try? await URLSession.shared.data(for: request(url)),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return WeatherService.parseForecast(data)
    }

    /// Fetches the forecast for a place when there is none yet, the place changed, or it is over 30 minutes old.
    @MainActor
    func refresh(_ place: WeatherPlace?) async {
        guard let p = place else {
            inFlight?.task.cancel()
            inFlight = nil
            days = []; failed = false; fetchedFor = ""; wanted = ""
            return
        }
        let key = String(format: "%.2f,%.2f", p.latitude, p.longitude)
        wanted = key
        if key == fetchedFor, let at = fetchedAt, Date().timeIntervalSince(at) < 30 * 60, !days.isEmpty { return }
        guard let url = WeatherService.forecastURL(latitude: p.latitude, longitude: p.longitude),
              url.host == WeatherService.forecastHost, url.scheme == "https" else { return }
        if key != fetchedFor { days = []; failed = false }
        let task: Task<[WeatherDay], Never>
        if let f = inFlight, f.key == key {
            task = f.task
        } else {
            inFlight?.task.cancel()
            task = Task { await BoardWeather.fetch(url) }
            inFlight = (key, task)
        }
        let got = await task.value
        if inFlight?.key == key { inFlight = nil }
        // The town changed while this was on its way: keep nothing from it.
        guard wanted == key else { return }
        if got.isEmpty { failed = days.isEmpty; return }
        days = got
        failed = false
        fetchedAt = Date()
        fetchedFor = key
    }

    /// Looks up a town by name. Nil when nothing is found or there is no connection.
    static func findPlace(_ name: String) async -> WeatherPlace? {
        guard let url = WeatherService.placeURL(name), url.host == WeatherService.placeHost, url.scheme == "https",
              let (data, resp) = try? await URLSession.shared.data(for: request(url)),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return WeatherService.parsePlace(data)
    }
}
