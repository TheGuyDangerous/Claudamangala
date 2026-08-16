import SwiftUI

struct MenuBarContentView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var accountsViewModel: AccountsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if authViewModel.isSignedIn {
                AccountListView(accountsViewModel: accountsViewModel)
                    .padding(16)
                    .frame(width: 400)

                Divider()

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
        .id(authViewModel.isSignedIn)
        .background(Color(red: 0.14, green: 0.14, blue: 0.15))
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn, let session = authViewModel.session {
                accountsViewModel.startListening(session: session)
            } else {
                accountsViewModel.stopListening()
            }
        }
        .onAppear {
            if authViewModel.isSignedIn, let session = authViewModel.session {
                accountsViewModel.startListening(session: session)
            }
        }
    }
}
