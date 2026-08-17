import AppKit
import Foundation

struct AppUpdateInfo: Equatable {
    let tagName: String
    let version: SemanticVersion
    let downloadURL: URL
    let releaseNotesURL: URL?
}

enum UpdateServiceError: LocalizedError {
    case invalidResponse
    case noReleaseAsset
    case downloadFailed
    case mountFailed
    case appBundleMissing
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not read the latest release from GitHub."
        case .noReleaseAsset:
            return "The latest release has no DMG download."
        case .downloadFailed:
            return "Could not download the update."
        case .mountFailed:
            return "Could not open the update disk image."
        case .appBundleMissing:
            return "The update disk image did not contain Claudamangala.app."
        case .installFailed(let detail):
            return "Could not install the update (\(detail))."
        }
    }
}

struct UpdateService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatestUpdate() async throws -> AppUpdateInfo? {
        guard let current = AppVersion.currentSemantic else { return nil }

        let url = URL(
            string: "https://api.github.com/repos/\(AppReleaseConfig.githubOwner)/\(AppReleaseConfig.githubRepo)/releases/latest"
        )!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Claudamangala/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw UpdateServiceError.invalidResponse
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tagName = json["tag_name"] as? String,
            let version = SemanticVersion.parse(tagName),
            version > current,
            let assets = json["assets"] as? [[String: Any]]
        else {
            return nil
        }

        let expectedName = "\(AppReleaseConfig.dmgNamePrefix)\(tagName).dmg"
        guard
            let asset = assets.first(where: { ($0["name"] as? String) == expectedName }),
            let downloadString = asset["browser_download_url"] as? String,
            let downloadURL = URL(string: downloadString)
        else {
            throw UpdateServiceError.noReleaseAsset
        }

        let releaseNotesURL = (json["html_url"] as? String).flatMap(URL.init(string:))
        return AppUpdateInfo(
            tagName: tagName,
            version: version,
            downloadURL: downloadURL,
            releaseNotesURL: releaseNotesURL
        )
    }

    func downloadUpdate(_ update: AppUpdateInfo) async throws -> URL {
        let (temporaryURL, response) = try await session.download(from: update.downloadURL)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw UpdateServiceError.downloadFailed
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Claudamangala-\(update.tagName).dmg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    func installUpdate(from dmgURL: URL) async throws {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("Claudamangala-mount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        try runProcess(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", dmgURL.path, "-nobrowse", "-quiet", "-mountpoint", mountPoint.path]
        )

        defer {
            _ = try? runProcess(
                executable: "/usr/bin/hdiutil",
                arguments: ["detach", mountPoint.path, "-quiet"]
            )
        }

        let sourceApp = mountPoint.appendingPathComponent("Claudamangala.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceApp.path) else {
            throw UpdateServiceError.appBundleMissing
        }

        let stagingApp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Claudamangala-update-\(UUID().uuidString).app", isDirectory: true)
        try? FileManager.default.removeItem(at: stagingApp)
        try FileManager.default.copyItem(at: sourceApp, to: stagingApp)

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudamangala-install-update-\(UUID().uuidString).sh")
        let script = """
        #!/bin/bash
        set -euo pipefail
        sleep 2
        rm -rf "/Applications/Claudamangala.app"
        /usr/bin/ditto "\(stagingApp.path)" "/Applications/Claudamangala.app"
        /usr/bin/open "/Applications/Claudamangala.app"
        rm -f "\(scriptURL.path)"
        rm -rf "\(stagingApp.path)"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/bash")
        installer.arguments = [scriptURL.path]
        try installer.run()

        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
    }

    @discardableResult
    private func runProcess(executable: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateServiceError.installFailed("exit \(process.terminationStatus)")
        }
        return process.terminationStatus
    }
}
