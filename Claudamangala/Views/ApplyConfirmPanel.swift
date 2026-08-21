import SwiftUI

struct ApplyConfirmPanel: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let account: ClaudeAccount
    let onFinished: () -> Void
    let onSuccess: (String) -> Void

    @AppStorage(ApplyDestinationPreferences.destinationKey) private var applyDestinationRaw = ApplyDestination.keychain.rawValue
    @State private var applyError: String?
    @State private var isApplying = false

    private var applyDestination: ApplyDestination {
        ApplyDestination(rawValue: applyDestinationRaw) ?? .keychain
    }

    private var applyDestinationCopy: String {
        switch applyDestination {
        case .keychain:
            return "This will replace the Claude Code session currently stored in the macOS Keychain."
        case .credentialsFile:
            return "This will write ~/.claude/.credentials.json. If that file is missing, it will be created; if it already exists, Apply updates the session inside it."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelBackHeader(title: "Switch Account", onBack: onFinished)

            Text("Switch to \"\(account.label)\"?")
                .font(.body)

            Text(applyDestinationCopy)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let applyError {
                Text(applyError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { onFinished() }
                    .buttonStyle(.plain)
                    .disabled(isApplying)

                Button {
                    apply()
                } label: {
                    if isApplying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Apply")
                    }
                }
                .buttonStyle(.glass)
                .disabled(isApplying)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func apply() {
        guard !isApplying else { return }
        isApplying = true
        applyError = nil

        Task {
            do {
                try await accountsViewModel.applyAccount(account)
                await MainActor.run {
                    onSuccess(account.id ?? account.label)
                    onFinished()
                }
            } catch {
                await MainActor.run {
                    applyError = error.localizedDescription
                    isApplying = false
                }
            }
        }
    }
}
