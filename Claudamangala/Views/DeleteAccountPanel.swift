import SwiftUI

struct DeleteAccountPanel: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let account: ClaudeAccount
    let onFinished: () -> Void

    @State private var deleteError: String?
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelBackHeader(title: "Delete Account", onBack: onFinished)

            Text("Delete \"\(account.label)\"?")
                .font(.body)

            Text("This removes the account from Firebase. It does not sign you out of Claude Code on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let deleteError {
                Text(deleteError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { onFinished() }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                Button(role: .destructive) {
                    deleteAccount()
                } label: {
                    if isDeleting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Delete")
                    }
                }
                .buttonStyle(.glass)
                .disabled(isDeleting)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func deleteAccount() {
        guard let accountId = account.id else {
            deleteError = "This account has no document id."
            return
        }
        guard !isDeleting else { return }

        isDeleting = true
        deleteError = nil

        Task {
            do {
                try await accountsViewModel.deleteAccount(accountId: accountId)
                await MainActor.run { onFinished() }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                    isDeleting = false
                }
            }
        }
    }
}
