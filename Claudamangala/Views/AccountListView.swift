import SwiftUI

private enum AccountPanel: Equatable {
    case list
    case add
    case rename(accountId: String, currentLabel: String)
    case apply(account: ClaudeAccount)
}

struct AccountListView: View {
    @Bindable var accountsViewModel: AccountsViewModel

    @State private var panel: AccountPanel = .list
    @State private var refreshErrorMessage: String?
    @State private var lastAppliedAccountId: String?

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
            case .apply(let account):
                ApplyConfirmPanel(
                    accountsViewModel: accountsViewModel,
                    account: account,
                    onFinished: { panel = .list },
                    onSuccess: { accountId in
                        lastAppliedAccountId = accountId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if lastAppliedAccountId == accountId {
                                lastAppliedAccountId = nil
                            }
                        }
                    }
                )
            }
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
                        isJustApplied: lastAppliedAccountId == (account.id ?? account.label),
                        onApply: {
                            panel = .apply(account: account)
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
