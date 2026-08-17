import SwiftUI

struct AccountRowContext {
    let account: ClaudeAccount
    let usage: ClaudeAccountUsage
    let isRefreshing: Bool
    let isJustApplied: Bool
    let onApply: () -> Void
    let onRefresh: () -> Void
    let onRename: () -> Void
    let onCopy: () -> Void
    let justCopied: Bool
}

extension UsageLevel {
    var color: Color {
        switch self {
        case .healthy: return .green
        case .low: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }
}

struct UsageMeterBar: View {
    let label: String
    let value: Double?
    let level: UsageLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let value {
                    Text("\(Int(value.rounded()))% left")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(level.color)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(level.color.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat((value ?? 0) / 100))
                }
            }
            .frame(height: 5)
        }
    }
}

struct UsageRing: View {
    let label: String
    let value: Double?
    let level: UsageLevel

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat((value ?? 0) / 100))
                    .stroke(level.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if let value {
                    Text("\(Int(value.rounded()))")
                        .font(.caption.weight(.bold).monospacedDigit())
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct UsageStatChip: View {
    let title: String
    let value: String
    let level: UsageLevel

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(level.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(.primary.opacity(0.06))
        }
    }
}

struct AccountActionButtons: View {
    let isRefreshing: Bool
    let isJustApplied: Bool
    let justCopied: Bool
    let onRefresh: () -> Void
    let onCopy: () -> Void
    let onApply: () -> Void
    var compact = false

    var body: some View {
        liquidGlassCluster {
            HStack(spacing: compact ? 6 : 8) {
                Spacer()

                Button(action: onRefresh) {
                    if isRefreshing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            if !compact { Text("Refreshing…") }
                        }
                    } else if compact {
                        Image(systemName: "arrow.clockwise")
                    } else {
                        Text("Refresh")
                    }
                }
                .buttonStyle(.glass)
                .disabled(isRefreshing)

                Button(action: onCopy) {
                    Text(justCopied ? "Copied ✓" : (compact ? "Copy" : "Copy"))
                }
                .buttonStyle(.glass)
                .disabled(isRefreshing)
                .help("Copy credentials JSON to clipboard")

                Button(action: onApply) {
                    Text(isJustApplied ? "Applied ✓" : "Apply")
                }
                .buttonStyle(.glass)
                .disabled(isRefreshing)
            }
        }
    }
}
