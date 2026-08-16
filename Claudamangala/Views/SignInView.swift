import SwiftUI

struct SignInView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Claudamangala")
                .font(.headline)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

            HStack(spacing: 6) {
                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit(signIn)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(isPasswordVisible ? "Hide password" : "Show password")
            }

            if let error = authViewModel.signInError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: signIn) {
                if authViewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glass)
            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

            Divider().padding(.top, 4)

            Button("Quit Claudamangala") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func signIn() {
        Task { await authViewModel.signIn(email: email, password: password) }
    }
}
