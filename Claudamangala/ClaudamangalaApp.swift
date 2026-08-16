import SwiftUI

@main
struct ClaudamangalaApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var accountsViewModel = AccountsViewModel()

    var body: some Scene {
        MenuBarExtra("Claudamangala", systemImage: "person.badge.key") {
            MenuBarContentView(authViewModel: authViewModel, accountsViewModel: accountsViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
