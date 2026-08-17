import SwiftUI

struct UsageMeterBar: View {
    let label: String
    let value: Double?

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
                        .foregroundStyle(.primary)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.1))
                    Capsule()
                        .fill(.primary.opacity(0.55))
                        .frame(width: geo.size.width * CGFloat((value ?? 0) / 100))
                }
            }
            .frame(height: 5)
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

    var body: some View {
        liquidGlassCluster {
            HStack(spacing: 8) {
                Spacer()

                Button(action: onRefresh) {
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

                Button(action: onCopy) {
                    Text(justCopied ? "Copied ✓" : "Copy")
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
