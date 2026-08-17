import Foundation

@MainActor
final class LocalRefreshScheduler {
    private weak var accountsViewModel: AccountsViewModel?
    private var timerTask: Task<Void, Never>?
    private var signedInEmail: String?

    func start(accountsViewModel: AccountsViewModel, email: String?) {
        self.accountsViewModel = accountsViewModel
        signedInEmail = email
        reschedule(email: email)
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        accountsViewModel = nil
        signedInEmail = nil
    }

    func reschedule(email: String?) {
        signedInEmail = email
        timerTask?.cancel()
        timerTask = nil

        guard !RefreshPreferences.canUseCloudRefresh(email: email) else { return }
        guard let interval = LocalRefreshSchedulePreferences.schedule.interval else { return }
        guard accountsViewModel != nil else { return }

        timerTask = Task { [weak self] in
            await self?.waitUntilNextRun(interval: interval)
            while !Task.isCancelled {
                await self?.runScheduledRefresh()
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func waitUntilNextRun(interval: TimeInterval) async {
        guard let lastRun = LocalRefreshSchedulePreferences.lastRunAt else { return }

        let elapsed = Date().timeIntervalSince(lastRun)
        guard elapsed < interval else {
            await runScheduledRefresh()
            return
        }

        let remaining = interval - elapsed
        try? await Task.sleep(for: .seconds(remaining))
    }

    private func runScheduledRefresh() async {
        guard !RefreshPreferences.canUseCloudRefresh(email: signedInEmail) else { return }
        guard let accountsViewModel else { return }
        guard LocalRefreshSchedulePreferences.schedule.interval != nil else { return }

        LocalRefreshSchedulePreferences.lastRunAt = Date()
        await accountsViewModel.refreshAllAccountsLocally()
    }
}
