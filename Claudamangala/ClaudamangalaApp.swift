import SwiftUI

@main
struct ClaudamangalaApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var accountsViewModel = AccountsViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(authViewModel: authViewModel, accountsViewModel: accountsViewModel)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.original)
        }
        .menuBarExtraStyle(.window)
    }
}
