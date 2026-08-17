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
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
