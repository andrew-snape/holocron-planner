import Foundation

// Everything about updates that needs no AppKit, so it can be tested on its own:
// comparing versions, reading GitHub's release JSON, and choosing the right download.

enum VersionCompare {
    /// "1.10.0" is newer than "1.9". A leading "v" is ignored, missing parts count as 0, and any
    /// suffix such as "-beta" is ignored.
    static func parts(_ s: String) -> [Int] {
        return stripV(s).split(separator: ".").map { piece in
            Int(piece.prefix(while: { $0.isNumber })) ?? 0
        }
    }

    /// The version text without spaces or a leading "v".
    static func stripV(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        return t
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        var name: String
        var browserDownloadUrl: String
        var size: Int?
    }

    var tagName: String
    var name: String?
    var body: String?
    var htmlUrl: String
    var draft: Bool?
    var prerelease: Bool?
    var assets: [Asset]

    var version: String { VersionCompare.stripV(tagName) }

    static func decode(_ data: Data) throws -> GitHubRelease {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(GitHubRelease.self, from: data)
    }
}

enum ReleasePick {
    /// "owner/name", the way GitHub spells a repository.
    static func isValidRepo(_ s: String) -> Bool {
        let p = s.split(separator: "/", omittingEmptySubsequences: false)
        guard p.count == 2 else { return false }
        let ok = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        return p.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy { ok.contains($0) } }
    }

    /// Only ever download from the repository's own release files on github.com.
    static func isTrustedDownload(_ url: URL, repo: String) -> Bool {
        guard url.scheme == "https", url.host?.lowercased() == "github.com" else { return false }
        return url.path.lowercased().hasPrefix("/" + repo.lowercased() + "/releases/download/")
    }

    /// The app zip: a .zip with "holocron" in its name, preferring one that says "mac".
    static func zipAsset(_ r: GitHubRelease) -> GitHubRelease.Asset? {
        let zips = r.assets.filter { $0.name.lowercased().hasSuffix(".zip") && $0.name.lowercased().contains("holocron") }
        return zips.first { $0.name.lowercased().contains("mac") } ?? zips.first
    }

    /// A "<zip name>.sha256" file published next to the zip.
    static func checksumAsset(for zip: GitHubRelease.Asset, in r: GitHubRelease) -> GitHubRelease.Asset? {
        r.assets.first { $0.name.lowercased() == zip.name.lowercased() + ".sha256" }
    }

    /// Accepts "<64 hex characters>" or "<64 hex characters>  filename" (what `shasum` prints).
    static func parseChecksum(_ text: String) -> String? {
        guard let first = text.split(whereSeparator: { $0.isWhitespace }).first else { return nil }
        let h = first.lowercased()
        return h.count == 64 && h.allSatisfy({ $0.isHexDigit }) ? h : nil
    }
}
