import SwiftUI
import AppKit
import CryptoKit

/// Checks GitHub Releases for a newer Holocron and can install it.
///
/// Installing downloads the release zip, checks it against the published checksum, unpacks it next to
/// the running app, then quits. A small script waits for Holocron to close, swaps the new app in
/// (keeping the old one until the swap works) and opens it again. Your data lives in its own
/// folders, so an update never touches it.
@Observable
final class Updater {
    struct Info: Equatable {
        var version: String
        var notes: String
        var pageURL: URL
        var zipURL: URL
        var checksumURL: URL?
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case working(String)
        case failed(String)
    }

    var state: State = .idle
    /// The newer release, once one has been found.
    var pending: Info? = nil
    /// Hides the banner until the next launch.
    var bannerDismissed = false
    private(set) var repo: String
    private(set) var autoCheck: Bool
    private(set) var lastChecked: Date?

    /// Set by the app: save everything to disk before quitting for an update.
    @ObservationIgnored var prepareToQuit: () -> Void = {}

    /// Where this copy of Holocron looks for new versions until a different repository is typed in Settings.
    static let defaultRepo = "andrew-snape/holocron-planner"
    static let repoKey = "updateRepo"
    static let autoKey = "updateAutoCheck"
    static let lastKey = "updateLastChecked"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init() {
        let d = UserDefaults.standard
        repo = d.string(forKey: Updater.repoKey) ?? Updater.defaultRepo
        autoCheck = d.object(forKey: Updater.autoKey) as? Bool ?? true
        lastChecked = d.object(forKey: Updater.lastKey) as? Date
    }

    func setRepo(_ s: String) {
        repo = s.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(repo, forKey: Updater.repoKey)
    }

    func setAutoCheck(_ on: Bool) {
        autoCheck = on
        UserDefaults.standard.set(on, forKey: Updater.autoKey)
    }

    var repoIsValid: Bool { ReleasePick.isValidRepo(repo) }

    // MARK: Checking

    /// Called at launch and when the app comes forward. Checks at most every six hours.
    func checkIfDue() {
        guard autoCheck, repoIsValid, pending == nil else { return }
        if let t = lastChecked, Date().timeIntervalSince(t) < 6 * 3600 { return }
        check(userInitiated: false)
    }

    func check(userInitiated: Bool) {
        if case .checking = state { return }
        if case .working = state { return }
        Task { await runCheck(userInitiated: userInitiated) }
    }

    @MainActor
    private func runCheck(userInitiated: Bool) async {
        guard repoIsValid else {
            if userInitiated { state = .failed("Enter your GitHub repository first, for example yourname/holocron-planner.") }
            return
        }
        state = .checking
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("Holocron-Updater", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 {
                state = userInitiated ? .failed("No release found at github.com/\(repo) yet. Check the name, and that the repository is public.") : .idle
                return
            }
            guard code == 200 else {
                state = userInitiated ? .failed("GitHub answered with code \(code). Try again later.") : .idle
                return
            }
            let rel = try GitHubRelease.decode(data)
            lastChecked = Date()
            UserDefaults.standard.set(lastChecked, forKey: Updater.lastKey)

            guard VersionCompare.isNewer(rel.version, than: Updater.currentVersion) else {
                pending = nil
                state = .upToDate
                return
            }
            guard let zip = ReleasePick.zipAsset(rel), let zipURL = URL(string: zip.browserDownloadUrl),
                  ReleasePick.isTrustedDownload(zipURL, repo: repo) else {
                state = userInitiated ? .failed("Version \(rel.version) exists, but it has no Holocron zip attached.") : .idle
                return
            }
            let sumURL = ReleasePick.checksumAsset(for: zip, in: rel)
                .flatMap { URL(string: $0.browserDownloadUrl) }
                .flatMap { ReleasePick.isTrustedDownload($0, repo: repo) ? $0 : nil }
            pending = Info(version: rel.version, notes: rel.body ?? "",
                           pageURL: URL(string: rel.htmlUrl) ?? URL(string: "https://github.com/\(repo)/releases")!,
                           zipURL: zipURL, checksumURL: sumURL)
            bannerDismissed = false
            state = .available
        } catch {
            state = userInitiated ? .failed("Could not reach GitHub. \(error.localizedDescription)") : .idle
        }
    }

    // MARK: Installing

    func install() {
        guard pending != nil else { return }
        if case .working = state { return }
        Task { await runInstall() }
    }

    private struct InstallError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    @MainActor
    private func runInstall() async {
        guard let info = pending else { return }
        let dest = Bundle.main.bundleURL
        let parent = dest.deletingLastPathComponent()
        guard dest.pathExtension == "app", !dest.path.contains("/DerivedData/") else {
            state = .failed("This copy is running from Xcode. Install updates in the copy in your Applications folder.")
            return
        }
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            state = .failed("Holocron cannot change its own folder. Use the download page and drag the new app into Applications.")
            return
        }
        let stage = parent.appendingPathComponent(".Holocron-update-\(UUID().uuidString.prefix(8))", isDirectory: true)
        do {
            state = .working("Downloading version \(info.version)")
            let (tmp, resp) = try await URLSession.shared.download(from: info.zipURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw InstallError(message: "The download did not complete.") }

            if let sumURL = info.checksumURL {
                state = .working("Checking the download")
                let (sumData, _) = try await URLSession.shared.data(from: sumURL)
                guard let want = ReleasePick.parseChecksum(String(decoding: sumData, as: UTF8.self)) else {
                    throw InstallError(message: "The checksum file could not be read.")
                }
                let got = try Updater.sha256(of: tmp)
                guard got == want else { throw InstallError(message: "The download did not match its checksum, so it was not installed.") }
            }

            state = .working("Installing")
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
            try await Updater.run("/usr/bin/ditto", ["-x", "-k", tmp.path, stage.path])
            let found = try FileManager.default.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil)
                .first { $0.pathExtension == "app" }
            guard let newApp = found, let b = Bundle(url: newApp) else { throw InstallError(message: "The download did not contain the app.") }
            guard b.bundleIdentifier == Bundle.main.bundleIdentifier else { throw InstallError(message: "The download is not Holocron.") }
            let v = b.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard VersionCompare.isNewer(v, than: Updater.currentVersion) else { throw InstallError(message: "The download is not newer than this version.") }
            try await Updater.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

            let script = FileManager.default.temporaryDirectory.appendingPathComponent("holocron-update.sh")
            try Updater.swapScript.write(to: script, atomically: true, encoding: .utf8)
            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
            launcher.arguments = ["-c", "nohup /bin/sh \"$0\" \"$@\" >/dev/null 2>&1 &", script.path,
                                  String(ProcessInfo.processInfo.processIdentifier), newApp.path, dest.path, stage.path]
            try launcher.run()
            launcher.waitUntilExit()

            state = .working("Restarting")
            prepareToQuit()
            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: stage)
            state = .failed((error as? InstallError)?.message ?? "The update failed. \(error.localizedDescription)")
        }
    }

    /// Waits for Holocron to quit, then swaps the apps. The old app is kept until the swap has worked.
    /// If anything goes wrong the old app is put back and the new one is shown in Finder.
    private static let swapScript = """
    PID="$1"; NEW="$2"; DEST="$3"; STAGE="$4"
    n=0
    while kill -0 "$PID" 2>/dev/null && [ "$n" -lt 150 ]; do sleep 0.2; n=$((n+1)); done
    BACKUP="$DEST.previous"
    rm -rf "$BACKUP"
    OK=0
    if mv "$DEST" "$BACKUP"; then
      if mv "$NEW" "$DEST"; then
        OK=1
        rm -rf "$BACKUP"
      else
        mv "$BACKUP" "$DEST"
      fi
    fi
    if [ "$OK" = "1" ]; then
      rm -rf "$STAGE"
      xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
    else
      open -R "$NEW"
    fi
    open "$DEST"
    """

    private static func run(_ tool: String, _ args: [String]) async throws {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            let err = Pipe()
            p.standardError = err
            p.standardOutput = Pipe()
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus != 0 {
                throw InstallError(message: "A step of the install failed (\((tool as NSString).lastPathComponent)).")
            }
        }.value
    }

    private static func sha256(of url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let chunk = try h.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func openDownloadPage() {
        let url = pending?.pageURL ?? URL(string: "https://github.com/\(repo)/releases")
        if let u = url { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Views

struct UpdateBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let u = model.updater
        if let info = u.pending, !u.bannerDismissed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.appBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Holocron \(info.version) is available").font(.system(size: 13, weight: .semibold))
                    switch u.state {
                    case .working(let what): Text(what + "...").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    case .failed(let msg): Text(msg).font(.system(size: 12)).foregroundStyle(Color.appRed)
                    default: Text("You have \(Updater.currentVersion). Your data is not touched by an update.")
                        .font(.system(size: 12)).foregroundStyle(Color.ink2)
                    }
                }
                Spacer()
                if case .working = u.state {
                    ProgressView().controlSize(.small)
                } else {
                    Button("What's new") { u.openDownloadPage() }
                    Button("Install and restart") { u.install() }.buttonStyle(.borderedProminent)
                    Button("Not now") { u.bannerDismissed = true }
                }
            }
            .padding(12)
            .background(Color.appBlue.opacity(0.09))
        }
    }
}

struct UpdatesSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let u = model.updater
        Form {
            Section {
                LabeledContent("Installed version") {
                    Text(Updater.currentVersion).font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                LabeledContent("GitHub repository") {
                    TextField(Updater.defaultRepo, text: Binding(get: { u.repo }, set: { u.setRepo($0) }))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 240)
                        .autocorrectionDisabled()
                }
                Toggle("Check for updates when Holocron opens", isOn: Binding(get: { u.autoCheck }, set: { u.setAutoCheck($0) }))
            } header: {
                Text("Updates")
            } footer: {
                Text("Updates come from the releases page of your GitHub repository. Installing quits Holocron, swaps in the new version and opens it again. Your data folders are never changed by an update.")
            }

            Section {
                HStack {
                    Button("Check now") { u.check(userInitiated: true) }
                        .disabled(u.state == .checking)
                    if case .checking = u.state { ProgressView().controlSize(.small) }
                    statusText(u)
                    Spacer()
                    if let info = u.pending {
                        Button("Install \(info.version) and restart") { u.install() }
                            .buttonStyle(.borderedProminent)
                            .disabled({ if case .working = u.state { return true } else { return false } }())
                    }
                }
                if let info = u.pending, !info.notes.isEmpty {
                    Text(info.notes)
                        .font(.callout).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(14)
                }
            }
        }
        .settingsForm()
    }

    @ViewBuilder
    private func statusText(_ u: Updater) -> some View {
        switch u.state {
        case .upToDate: Text("You are up to date.").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        case .available: Text("A new version is ready.").font(.system(size: 12.5)).foregroundStyle(Color.appBlue)
        case .working(let w): Text(w + "...").font(.system(size: 12.5)).foregroundStyle(Color.ink2)
        case .failed(let m): Text(m).font(.system(size: 12.5)).foregroundStyle(Color.appRed)
        default: EmptyView()
        }
    }
}
