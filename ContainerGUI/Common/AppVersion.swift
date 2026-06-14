import Foundation

/// Current app version information.
enum AppVersion {
    /// Human-readable version string (e.g. "1.0").
    static let short: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }()

    /// Build number (e.g. "1").
    static let build: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }()

    /// Full display string: "1.0 (1)"
    static var full: String { "\(short) (\(build))" }
}
