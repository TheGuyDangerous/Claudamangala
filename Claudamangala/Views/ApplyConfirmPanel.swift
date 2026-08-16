import SwiftUI

struct ApplyConfirmPanel: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let account: ClaudeAccount
    let onFinished: () -> Void
    let onSuccess: (String) -> Void

    @State private var applyError: String?
    @State private var isApplying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    onFinished()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Switch Account")
                    .font(.headline)
            }

            Text("Switch to \"\(account.label)\"?")
                .font(.body)

            Text("This will replace the Claude Code session currently active on this Mac.")
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
        isApplying = true
        applyError = nil
        do {
            try accountsViewModel.applyAccount(account)
            onSuccess(account.id ?? account.label)
            onFinished()
        } catch {
            applyError = error.localizedDescription
            isApplying = false
        }
    }
}
