import SwiftUI

private enum AccountListLayout {
    /// Fixed scroll viewport — ScrollView collapses without an explicit height in menu-bar windows.
    static let scrollHeight: CGFloat = 480
}

private enum AccountPanel: Equatable {
    case list
    case preferences
    case add
    case edit(account: ClaudeAccount)
    case delete(account: ClaudeAccount)
    case apply(account: ClaudeAccount)
}

struct AccountListView: View {
    @Bindable var accountsViewModel: AccountsViewModel
    @Bindable var updateViewModel: UpdateViewModel
    let localRefreshScheduler: LocalRefreshScheduler

    @State private var panel: AccountPanel = .list
    @State private var lastAppliedAccountId: String?

    var body: some View {
        Group {
            switch panel {
            case .list:
                accountList
            case .preferences:
                PreferencesPanel(
                    updateViewModel: updateViewModel,
                    accountsViewModel: accountsViewModel,
                    localRefreshScheduler: localRefreshScheduler
                ) {
                    panel = .list
                }
            case .add:
                AddAccountSheet(accountsViewModel: accountsViewModel) {
                    panel = .list
                }
            case .edit(let account):
                EditAccountSheet(
                    accountsViewModel: accountsViewModel,
                    account: account
                ) {
                    panel = .list
                }
            case .delete(let account):
                DeleteAccountPanel(
                    accountsViewModel: accountsViewModel,
                    account: account
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
        .onChange(of: accountsViewModel.menuDismissToken) { _, _ in
            panel = .list
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claudamangala")
                    .font(.headline)
                Spacer()
                Button {
                    panel = .preferences
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Preferences")
                Button {
                    panel = .add
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: true) {
                accountListBody
            }
            .frame(height: AccountListLayout.scrollHeight)

            if let error = accountsViewModel.lastActionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var accountListBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if accountsViewModel.permissionDenied {
                Text("Firestore access denied — ask the project owner to publish the rules from firestore.rules.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if accountsViewModel.isLoadingAccounts && accountsViewModel.accounts.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading accounts…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if accountsViewModel.accounts.isEmpty {
                Text("No accounts yet — click + to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: AccountListLayout.scrollHeight - 16, alignment: .topLeading)
                    .padding(.vertical, 8)
            } else {
                ForEach(accountsViewModel.accounts, id: \.listId) { account in
                    AccountRowView(
                        account: account,
                        usage: accountsViewModel.usage(for: account),
                        isRefreshing: accountsViewModel.isRefreshing(accountId: account.id),
                        isRefreshingUsage: accountsViewModel.isRefreshingUsage(accountId: account.id),
                        isJustApplied: lastAppliedAccountId == (account.id ?? account.label),
                        onApply: {
                            panel = .apply(account: account)
                        },
                        onRefresh: {
                            triggerRefresh(for: account)
                        },
                        onRefreshUsage: {
                            accountsViewModel.refreshUsage(for: account)
                        },
                        onEdit: {
                            panel = .edit(account: account)
                        },
                        onDelete: {
                            panel = .delete(account: account)
                        }
                    )
                    if account.listId != accountsViewModel.accounts.last?.listId {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func triggerRefresh(for account: ClaudeAccount) {
        guard let id = account.id else { return }
        Task { @MainActor in
            do {
                accountsViewModel.lastActionError = nil
                try await accountsViewModel.triggerRefresh(accountId: id)
            } catch {
                accountsViewModel.lastActionError = error.localizedDescription
            }
        }
    }
}
