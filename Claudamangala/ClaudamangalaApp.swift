import SwiftUI

@main
struct ClaudamangalaApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var accountsViewModel = AccountsViewModel()
    @State private var updateViewModel = UpdateViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                authViewModel: authViewModel,
                accountsViewModel: accountsViewModel,
                updateViewModel: updateViewModel
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
