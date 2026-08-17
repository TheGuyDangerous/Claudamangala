import SwiftUI

private enum AuthMode: String {
    case signIn
    case signUp
}

struct SignInView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var localValidationError: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Claudamangala")
                .font(.headline)

            Text(mode == .signIn ? "Sign in to manage your Claude accounts." : "Create an account to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .textContentType(.username)

            passwordField(
                title: "Password",
                text: $password,
                isVisible: $isPasswordVisible,
                onSubmit: submit
            )

            if mode == .signUp {
                passwordField(
                    title: "Confirm password",
                    text: $confirmPassword,
                    isVisible: $isConfirmPasswordVisible,
                    onSubmit: submit
                )
            }

            if let error = localValidationError ?? authViewModel.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: submit) {
                if authViewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glass)
            .disabled(authViewModel.isLoading || !canSubmit)

            Button {
                switchMode()
            } label: {
                if mode == .signIn {
                    Text("Don't have an account? **Sign up**")
                } else {
                    Text("Already have an account? **Sign in**")
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .disabled(authViewModel.isLoading)

            Divider().padding(.top, 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Text("Quit Claudamangala")
                    Text("⌘Q")
                        .font(.caption.weight(.medium).monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit (⌘Q)")
        }
        .padding(16)
        .frame(width: 300)
    }

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        if mode == .signUp {
            return !confirmPassword.isEmpty
        }
        return true
    }

    @ViewBuilder
    private func passwordField(
        title: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Group {
                if isVisible.wrappedValue {
                    TextField(title, text: text)
                } else {
                    SecureField(title, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .textContentType(mode == .signUp ? .newPassword : .password)
            .onSubmit(onSubmit)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
    }

    private func switchMode() {
        mode = mode == .signIn ? .signUp : .signIn
        localValidationError = nil
        authViewModel.authError = nil
        confirmPassword = ""
    }

    private func submit() {
        localValidationError = nil
        authViewModel.authError = nil

        if mode == .signUp {
            guard password.count >= 6 else {
                localValidationError = "Password must be at least 6 characters."
                return
            }
            guard password == confirmPassword else {
                localValidationError = "Passwords do not match."
                return
            }
        }

        Task {
            switch mode {
            case .signIn:
                await authViewModel.signIn(email: email, password: password)
            case .signUp:
                await authViewModel.signUp(email: email, password: password)
            }
        }
    }
}
