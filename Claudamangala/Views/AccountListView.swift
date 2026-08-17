import SwiftUI

private enum AccountPanel: Equatable {
    case list
    case add
    case rename(accountId: String, currentLabel: String)
    case apply(account: ClaudeAccount)
}

struct AccountListView: View {
    @Bindable var accountsViewModel: AccountsViewModel

    @AppStorage("accountUIStyle") private var storedStyle = AccountUIStyle.studio.rawValue
    @AppStorage("accountUIStyleChosen") private var styleChosen = false

    @State private var panel: AccountPanel = .list
    @State private var refreshErrorMessage: String?
    @State private var lastAppliedAccountId: String?
    @State private var previewIndex = 0
    @State private var browsingStyles = false

    private var activeStyle: AccountUIStyle {
        AccountUIStyle(rawValue: storedStyle) ?? .studio
    }

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
        .onAppear {
            if let index = AccountUIStyle.allCases.firstIndex(of: activeStyle) {
                previewIndex = index
            }
            browsingStyles = !styleChosen
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claudamangala")
                    .font(.headline)
                Spacer()
                if styleChosen {
                    Button {
                        browsingStyles = true
                    } label: {
                        Image(systemName: "paintbrush")
                    }
                    .buttonStyle(.plain)
                    .help("Browse UI styles")
                }
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
            } else if browsingStyles || !styleChosen {
                UIStyleCarousel(previewIndex: $previewIndex) {
                    storedStyle = AccountUIStyle.allCases[previewIndex].rawValue
                    styleChosen = true
                    browsingStyles = false
                } content: { style in
                    accountsBody(style: style)
                }
            } else {
                accountsBody(style: activeStyle)
            }

            if let error = accountsViewModel.lastActionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func accountsBody(style: AccountUIStyle) -> some View {
        ForEach(accountsViewModel.accounts.indices, id: \.self) { index in
            let account = accountsViewModel.accounts[index]
            AccountRowView(
                style: style,
                account: account,
                usage: accountsViewModel.usage(for: account),
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
            if index < accountsViewModel.accounts.count - 1 {
                Divider()
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
