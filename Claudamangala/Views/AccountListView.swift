import SwiftUI

private enum AccountPanel: Equatable {
    case list
    case preferences
    case add
    case rename(accountId: String, currentLabel: String)
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

            ScrollView {
                accountListBody
            }
            .frame(maxHeight: 460)

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
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
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
                        onRename: {
                            guard let id = account.id else { return }
                            panel = .rename(accountId: id, currentLabel: account.label)
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
