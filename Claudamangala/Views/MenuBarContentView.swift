import SwiftUI

struct MenuBarContentView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var accountsViewModel: AccountsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if authViewModel.isRestoringSession {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Restoring session…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(width: 280)
            } else if authViewModel.isSignedIn {
                AccountListView(accountsViewModel: accountsViewModel)
                    .padding(16)
                    .frame(width: 340)

                if accountsViewModel.accounts.count > 1 {
                    Divider()
                }

                HStack {
                    Button("Sign Out") { authViewModel.signOut() }
                        .buttonStyle(.plain)
                        .font(.caption)
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
                .padding(12)
            } else {
                SignInView(authViewModel: authViewModel)
            }
        }
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn, let session = authViewModel.session {
                accountsViewModel.startListening(session: session)
                accountsViewModel.menuDidOpen()
            } else {
                accountsViewModel.stopListening()
            }
        }
        .onChange(of: authViewModel.isRestoringSession) { _, isRestoring in
            guard !isRestoring, authViewModel.isSignedIn, let session = authViewModel.session else { return }
            accountsViewModel.startListening(session: session)
            accountsViewModel.menuDidOpen()
        }
        .onMenuBarWindowLifecycle(
            onOpen: {
                guard authViewModel.isSignedIn, let session = authViewModel.session else { return }
                accountsViewModel.startListening(session: session)
                accountsViewModel.menuDidOpen()
            },
            onClose: {
                accountsViewModel.menuDidClose()
            }
        )
    }
}
