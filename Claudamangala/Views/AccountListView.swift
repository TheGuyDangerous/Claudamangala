import SwiftUI

private enum AccountPanel: Equatable {
    case list
    case add
    case rename(accountId: String, currentLabel: String)
}

struct AccountListView: View {
    @Bindable var accountsViewModel: AccountsViewModel

    @State private var panel: AccountPanel = .list
    @State private var applyAlertAccount: ClaudeAccount?
    @State private var applyErrorMessage: String?
    @State private var refreshErrorMessage: String?
    @State private var pendingApplyCompletion: ((Bool) -> Void)?

    var body: some View {
        Group {
            switch panel {
            case .list:
                accountList
            case .add:
                AddAccountSheet(accountsViewModel: accountsViewModel) {
                    panel = .list
                }
            case .rename(let accountId, let currentLabel):
                RenameSheet(
                    accountsViewModel: accountsViewModel,
                    accountId: accountId,
                    currentLabel: currentLabel
                ) {
                    panel = .list
                }
            }
        }
        .alert(
            "Switch to '\(applyAlertAccount?.label ?? "")'?",
            isPresented: Binding(
                get: { applyAlertAccount != nil },
                set: { if !$0 { applyAlertAccount = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                pendingApplyCompletion?(false)
                pendingApplyCompletion = nil
            }
            Button("Apply", role: .destructive) {
                performApply()
            }
        } message: {
            Text("This will replace the Claude Code session currently active on this Mac.")
        }
        .alert(
            "Apply Failed",
            isPresented: Binding(
                get: { applyErrorMessage != nil },
                set: { if !$0 { applyErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(applyErrorMessage ?? "")
        }
        .alert(
            "Refresh Failed",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { if !$0 { refreshErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(refreshErrorMessage ?? "")
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claudamangala")
                    .font(.headline)
                Spacer()
                Button {
                    panel = .add
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }

            if accountsViewModel.permissionDenied {
                Text("Access denied — check Firebase Auth configuration.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if accountsViewModel.accounts.isEmpty {
                Text("No accounts yet — click + to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(accountsViewModel.accounts) { account in
                    AccountRowView(
                        account: account,
                        isRefreshing: accountsViewModel.isRefreshing(accountId: account.id),
                        onApply: { completion in
                            applyAlertAccount = account
                            pendingApplyCompletion = completion
                        },
                        onRefresh: {
                            triggerRefresh(for: account)
                        },
                        onRename: {
                            guard let id = account.id else { return }
                            panel = .rename(accountId: id, currentLabel: account.label)
                        }
                    )
                    Divider()
                }
            }

            if let error = accountsViewModel.lastActionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func performApply() {
        guard let account = applyAlertAccount else { return }
        applyAlertAccount = nil
        do {
            try accountsViewModel.applyAccount(account)
            pendingApplyCompletion?(true)
        } catch {
            applyErrorMessage = error.localizedDescription
            pendingApplyCompletion?(false)
        }
        pendingApplyCompletion = nil
    }

    private func triggerRefresh(for account: ClaudeAccount) {
        guard let id = account.id else { return }
        Task {
            do {
                try await accountsViewModel.triggerPipelineRefresh(accountId: id)
            } catch {
                refreshErrorMessage = error.localizedDescription
            }
        }
    }
}
