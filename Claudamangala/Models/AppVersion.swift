import Foundation

struct SemanticVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    static func parse(_ raw: String) -> SemanticVersion? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = withoutPrefix.split(separator: ".", omittingEmptySubsequences: false)
        guard let major = Int(parts.first ?? ""), major >= 0 else { return nil }

        let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
        return SemanticVersion(major: major, minor: minor, patch: patch)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    var displayString: String {
        "\(major).\(minor).\(patch)"
    }
}

enum AppVersion {
    static var current: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? short
        return short == build ? short : "\(short) (\(build))"
    }

    static var currentSemantic: SemanticVersion? {
        SemanticVersion.parse(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}

enum AppReleaseConfig {
    static let githubOwner = "TheGuyDangerous"
    static let githubRepo = "Claudamangala"
    static let dmgNamePrefix = "Claudamangala-"
}
