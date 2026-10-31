import Foundation

/// App version derived from the bundle.
///
/// Versions are date-based. Apple requires `CFBundleShortVersionString` to be
/// dot-separated integers, so the date ships as `2026.8.9` and is rendered here
/// as `2026-08-09`. Multiple builds on the same date are distinguished by the
/// build number, which `fastlane beta` resets to 1 whenever the date rolls over:
/// the second build of a day displays as `2026-08-09.2`.
enum AppVersion {
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    /// Human-readable version, e.g. `2026-08-09` or `2026-08-09.2`.
    static var display: String {
        let version = marketingVersion
        guard let date = formattedDate(from: version) else { return version }
        guard let build = Int(build), build > 1 else { return date }
        return "\(date).\(build)"
    }

    /// Turns `2026.8.9` into `2026-08-09`. Returns nil for anything that isn't
    /// a three-part numeric date (e.g. a legacy `1.0.0` version).
    private static func formattedDate(from version: String) -> String? {
        let parts = version.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]), year >= 2000,
              let month = Int(parts[1]), (1...12).contains(month),
              let day = Int(parts[2]), (1...31).contains(day)
        else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
