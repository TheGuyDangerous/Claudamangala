import Foundation
import Observation

@MainActor
@Observable
final class UpdateViewModel {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(AppUpdateInfo)
        case downloading
        case installing
        case failed(String)
    }

    private(set) var status: Status = .idle
    private let service = UpdateService()

    var currentVersion: String { AppVersion.current }

    var statusMessage: String {
        switch status {
        case .idle:
            return "Version \(currentVersion)"
        case .checking:
            return "Checking for updates…"
        case .upToDate:
            return "You're on the latest version (\(currentVersion))."
        case .updateAvailable(let update):
            return "Update available: \(update.version.displayString)"
        case .downloading:
            return "Downloading update…"
        case .installing:
            return "Installing update…"
        case .failed(let message):
            return message
        }
    }

    var pendingUpdate: AppUpdateInfo? {
        if case .updateAvailable(let update) = status { return update }
        return nil
    }

    func checkOnLaunchIfNeeded() async {
        LaunchPreferences.applyStoredPreferenceIfNeeded()
        guard UpdatePreferences.checkAutomatically else { return }
        await checkForUpdates(installIfAvailable: UpdatePreferences.installAutomatically)
    }

    func checkForUpdates(installIfAvailable: Bool = false) async {
        status = .checking

        do {
            if let update = try await service.fetchLatestUpdate() {
                status = .updateAvailable(update)
                if installIfAvailable {
                    await downloadAndInstall(update)
                }
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func downloadAndInstall(_ update: AppUpdateInfo? = nil) async {
        let target = update ?? pendingUpdate
        guard let target else { return }

        status = .downloading

        do {
            let dmgURL = try await service.downloadUpdate(target)
            status = .installing
            try await service.installUpdate(from: dmgURL)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
