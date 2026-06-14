import AppKit
import Foundation

/// Checks for app updates via the GitHub Releases API.
enum UpdateChecker {

    /// Represents the latest release fetched from GitHub.
    struct ReleaseInfo: Sendable, Equatable {
        let version: String
        let htmlURL: URL
        let body: String
        let publishedAt: Date
    }

    private static let repo = "bexonpak/container-gui"
    private static let latestURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    private static let releasesURL = URL(string: "https://github.com/\(repo)/releases")!

    /// Fetches the latest release from GitHub. Returns `nil` on failure / no network.
    static func checkForUpdate() async -> ReleaseInfo? {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ContainerGUI/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let tag = json["tag_name"] as? String,
              let htmlURL = (json["html_url"] as? String).flatMap({ URL(string: $0) }),
              let publishedAt = (json["published_at"] as? String).flatMap({ ISO8601DateFormatter().date(from: $0) })
        else { return nil }

        let body = (json["body"] as? String) ?? ""

        // Strip leading "v" or "v" prefix from tag for comparison
        let remoteVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

        // Compare using semantic versioning
        let current = AppVersion.short
        let isNewer = remoteVersion.compare(current, options: .numeric) == .orderedDescending

        guard isNewer else { return nil }

        return ReleaseInfo(version: remoteVersion, htmlURL: htmlURL, body: body, publishedAt: publishedAt)
    }

    /// Opens the releases page in the browser.
    static func openReleasesPage() {
        NSWorkspace.shared.open(releasesURL)
    }
}
