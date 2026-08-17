import AppKit
import SwiftUI

struct AccountRowView: View {
    let account: ClaudeAccount
    let usage: ClaudeAccountUsage
    let isRefreshing: Bool
    let isRefreshingUsage: Bool
    let isJustApplied: Bool
    let onApply: () -> Void
    let onRefresh: () -> Void
    let onRefreshUsage: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let isPinnedToMenuBar: Bool
    let onToggleMenuBarLimits: () -> Void

    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(account.isExpiringSoon ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)

                Text(account.label)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                ToolbarIconCluster {
                    ToolbarIconButton(
                        systemName: isPinnedToMenuBar ? "eye.fill" : "eye",
                        help: isPinnedToMenuBar
                            ? "Hide limits from the menu bar"
                            : "Show this account's limits in the menu bar"
                    ) {
                        onToggleMenuBarLimits()
                    }
                    ToolbarIconButton(systemName: "square.and.pencil", help: "Edit label and credentials") {
                        onEdit()
                    }
                    ToolbarIconButton(systemName: "minus", help: "Delete account") {
                        onDelete()
                    }
                }
            }

            HStack(spacing: 12) {
                metricBlock(title: "Session", value: account.expiresInDescription)
                metricBlock(title: "Refresh", value: account.lastRefreshStatus)
            }
            .padding(.top, 6)

            if usage.isLoading {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Text("Limits")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    if usage.isStored {
                        Text("saved")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if isRefreshingUsage {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 24, height: 24)
                    } else {
                        ToolbarIconButton(systemName: "arrow.triangle.2.circlepath", help: "Refresh limits") {
                            onRefreshUsage()
                        }
                    }
                }

                UsageMeterBar(
                    label: "5-hour window",
                    value: usage.fiveHourAvailable
                )
                UsageMeterBar(
                    label: "Weekly window",
                    value: usage.weeklyAvailable
                )
            }

            AccountActionButtons(
                isRefreshing: isRefreshing,
                isJustApplied: isJustApplied,
                justCopied: justCopied,
                onRefresh: onRefresh,
                onCopy: copyCredentials,
                onApply: onApply
            )
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.primary.opacity(0.07), .primary.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.vertical, 4)
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
