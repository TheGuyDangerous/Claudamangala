import SwiftUI

struct MenuBarContentView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var accountsViewModel: AccountsViewModel
    @Bindable var updateViewModel: UpdateViewModel
    let localRefreshScheduler: LocalRefreshScheduler

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
                .frame(width: 300)
            } else if authViewModel.isSignedIn {
                AccountListView(
                    accountsViewModel: accountsViewModel,
                    updateViewModel: updateViewModel,
                    localRefreshScheduler: localRefreshScheduler
                )
                    .padding(16)
                    .frame(width: 340)

                MinimalDivider()
                    .padding(.top, 2)

                HStack {
                    Button {
                        authViewModel.signOut()
                    } label: {
                        footerActionLabel("Sign Out", shortcut: "⌘S")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Sign Out (⌘S)")

                    Spacer()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        footerActionLabel("Quit", shortcut: "⌘Q")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
                    .help("Quit (⌘Q)")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 12)
            } else {
                SignInView(authViewModel: authViewModel)
            }
        }
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn, let session = authViewModel.session {
                accountsViewModel.startListening(session: session)
                accountsViewModel.menuDidOpen()
                localRefreshScheduler.start(accountsViewModel: accountsViewModel)
            } else {
                localRefreshScheduler.stop()
                accountsViewModel.stopListening()
            }
        }
        .onChange(of: authViewModel.isRestoringSession) { _, isRestoring in
            guard !isRestoring, authViewModel.isSignedIn, let session = authViewModel.session else { return }
            accountsViewModel.startListening(session: session)
            accountsViewModel.menuDidOpen()
            localRefreshScheduler.start(accountsViewModel: accountsViewModel)
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

    private func footerActionLabel(_ title: String, shortcut: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text(shortcut)
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(.tertiary)
        }
    }
}
