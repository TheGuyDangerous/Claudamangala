import Foundation

@MainActor
final class LocalRefreshScheduler {
    private weak var accountsViewModel: AccountsViewModel?
    private var timerTask: Task<Void, Never>?

    func start(accountsViewModel: AccountsViewModel) {
        self.accountsViewModel = accountsViewModel
        reschedule()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        accountsViewModel = nil
    }

    func reschedule() {
        timerTask?.cancel()
        timerTask = nil

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
        guard let accountsViewModel else { return }
        guard LocalRefreshSchedulePreferences.schedule.interval != nil else { return }

        LocalRefreshSchedulePreferences.lastRunAt = Date()
        await accountsViewModel.refreshAllAccountsLocally()
    }
}
