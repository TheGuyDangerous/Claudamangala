import SwiftUI

@main
struct ClaudamangalaApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var accountsViewModel = AccountsViewModel()
    @State private var updateViewModel = UpdateViewModel()
    @State private var localRefreshScheduler = LocalRefreshScheduler()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                authViewModel: authViewModel,
                accountsViewModel: accountsViewModel,
                updateViewModel: updateViewModel,
                localRefreshScheduler: localRefreshScheduler
            )
            .task {
                await updateViewModel.checkOnLaunchIfNeeded()
            }
        } label: {
            MenuBarStatusLabel(accountsViewModel: accountsViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusLabel: View {
    @Bindable var accountsViewModel: AccountsViewModel

    var body: some View {
        HStack(spacing: 6) {
            if let caption = accountsViewModel.menuBarUsageCaption {
                Text(caption)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }
}
