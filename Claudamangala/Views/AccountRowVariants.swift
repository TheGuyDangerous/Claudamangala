import SwiftUI

enum AccountRowVariants {
    @ViewBuilder
    static func row(style: AccountUIStyle, context: AccountRowContext) -> some View {
        switch style {
        case .studio:
            StudioAccountRow(context: context)
        case .card:
            CardAccountRow(context: context)
        case .compact:
            CompactAccountRow(context: context)
        case .dashboard:
            DashboardAccountRow(context: context)
        }
    }
}

private struct StudioAccountRow: View {
    let context: AccountRowContext

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.85, green: 0.46, blue: 0.34))
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(context.account.isExpiringSoon ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)

                    Text(context.account.label)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button(action: context.onRename) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Text("\(context.account.expiresInDescription) · \(context.account.lastRefreshStatus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    UsageStatChip(
                        title: "5h",
                        value: context.usage.isLoading ? "…" : context.usage.fiveHourDisplay,
                        level: context.usage.availabilityColor(for: context.usage.fiveHourAvailable)
                    )
                    UsageStatChip(
                        title: "7d",
                        value: context.usage.isLoading ? "…" : context.usage.weeklyDisplay,
                        level: context.usage.availabilityColor(for: context.usage.weeklyAvailable)
                    )
                }

                AccountActionButtons(
                    isRefreshing: context.isRefreshing,
                    isJustApplied: context.isJustApplied,
                    justCopied: context.justCopied,
                    onRefresh: context.onRefresh,
                    onCopy: context.onCopy,
                    onApply: context.onApply
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CardAccountRow: View {
    let context: AccountRowContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.account.label)
                        .font(.headline)
                    Text(context.account.expiresInDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: context.onRename) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                UsageRing(
                    label: "5h left",
                    value: context.usage.fiveHourAvailable,
                    level: context.usage.availabilityColor(for: context.usage.fiveHourAvailable)
                )
                UsageRing(
                    label: "7d left",
                    value: context.usage.weeklyAvailable,
                    level: context.usage.availabilityColor(for: context.usage.weeklyAvailable)
                )
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.account.lastRefreshStatus.capitalized)
                        .font(.caption.weight(.medium))
                }
            }

            AccountActionButtons(
                isRefreshing: context.isRefreshing,
                isJustApplied: context.isJustApplied,
                justCopied: context.justCopied,
                onRefresh: context.onRefresh,
                onCopy: context.onCopy,
                onApply: context.onApply
            )
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.primary.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
        }
        .padding(.vertical, 4)
    }
}

private struct CompactAccountRow: View {
    let context: AccountRowContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(context.account.isExpiringSoon ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)

                Text(context.account.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                if context.usage.isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Text("5h \(context.usage.fiveHourDisplay)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(context.usage.availabilityColor(for: context.usage.fiveHourAvailable).color)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("7d \(context.usage.weeklyDisplay)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(context.usage.availabilityColor(for: context.usage.weeklyAvailable).color)
                }

                Button(action: context.onRename) {
                    Image(systemName: "pencil")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(context.account.expiresInDescription) · \(context.account.lastRefreshStatus)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            AccountActionButtons(
                isRefreshing: context.isRefreshing,
                isJustApplied: context.isJustApplied,
                justCopied: context.justCopied,
                onRefresh: context.onRefresh,
                onCopy: context.onCopy,
                onApply: context.onApply,
                compact: true
            )
        }
        .padding(.vertical, 4)
    }
}

private struct DashboardAccountRow: View {
    let context: AccountRowContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.account.label.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                Spacer()
                Button(action: context.onRename) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                metricBlock(title: "Session", value: context.account.expiresInDescription)
                metricBlock(title: "Refresh", value: context.account.lastRefreshStatus)
            }

            if context.usage.isLoading {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                UsageMeterBar(
                    label: "5-hour window",
                    value: context.usage.fiveHourAvailable,
                    level: context.usage.availabilityColor(for: context.usage.fiveHourAvailable)
                )
                UsageMeterBar(
                    label: "Weekly window",
                    value: context.usage.weeklyAvailable,
                    level: context.usage.availabilityColor(for: context.usage.weeklyAvailable)
                )
            }

            AccountActionButtons(
                isRefreshing: context.isRefreshing,
                isJustApplied: context.isJustApplied,
                justCopied: context.justCopied,
                onRefresh: context.onRefresh,
                onCopy: context.onCopy,
                onApply: context.onApply
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
}
