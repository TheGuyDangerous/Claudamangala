import AppKit
import SwiftUI

struct AccountRowView: View {
    let account: ClaudeAccount
    let isRefreshing: Bool
    let isJustApplied: Bool
    let onApply: () -> Void
    let onRefresh: () -> Void
    let onRename: () -> Void

    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(account.isExpiringSoon ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)

                Text(account.label)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Button {
                    onRename()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Rename")
            }

            Text("\(account.expiresInDescription) · \(account.lastRefreshStatus)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            liquidGlassCluster {
                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        onRefresh()
                    } label: {
                        if isRefreshing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text("Refreshing…")
                            }
                        } else {
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(isRefreshing)

                    Button {
                        copyCredentials()
                    } label: {
                        Text(justCopied ? "Copied ✓" : "Copy")
                    }
                    .buttonStyle(.glass)
                    .disabled(isRefreshing)
                    .help("Copy credentials JSON to clipboard")

                    Button {
                        onApply()
                    } label: {
                        Text(isJustApplied ? "Applied ✓" : "Apply")
                    }
                    .buttonStyle(.glass)
                    .disabled(isRefreshing)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func copyCredentials() {
        do {
            let json = try account.credentialsClipboardJSON()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                justCopied = false
            }
        } catch {}
    }
}
