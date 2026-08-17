import SwiftUI

struct PreferencesPanel: View {
    @AppStorage(UsagePreferences.fetchOnMenuOpenKey) private var fetchOnMenuOpen = false
    @AppStorage(RefreshPreferences.oauthRefreshModeKey) private var oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
    let onFinished: () -> Void

    private var oauthRefreshMode: OAuthRefreshMode {
        OAuthRefreshMode(rawValue: oauthRefreshModeRaw) ?? .local
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelBackHeader(title: "Preferences", onBack: onFinished)

            Text("Token refresh")
                .font(.subheadline.weight(.semibold))

            Text("Choose how Refresh updates OAuth tokens in Firebase.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                preferenceOption(
                    title: "Local refresh",
                    subtitle: "Refresh tokens on this Mac and write straight to Firebase. Usually finishes in a few seconds.",
                    isSelected: oauthRefreshMode == .local
                ) {
                    oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
                }

                preferenceOption(
                    title: "Cloud refresh",
                    subtitle: "Trigger the GitHub Actions pipeline and wait for it to update Firebase. Slower, but uses the same path as scheduled refreshes.",
                    isSelected: oauthRefreshMode == .cloud
                ) {
                    oauthRefreshModeRaw = OAuthRefreshMode.cloud.rawValue
                }
            }

            Text("Usage limits")
                .font(.subheadline.weight(.semibold))

            Text("Choose when Claudamangala calls the Anthropic usage API. Saved limits are always loaded from Firebase when you open the menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                preferenceOption(
                    title: "Show saved limits only",
                    subtitle: "Load the last saved 5-hour and weekly values from Firebase. Tap ↻ on an account to fetch fresh limits and save them.",
                    isSelected: !fetchOnMenuOpen
                ) {
                    fetchOnMenuOpen = false
                }

                preferenceOption(
                    title: "Refresh limits on menu open",
                    subtitle: "Also call the usage API every time you open the menu bar popup, then save the result to Firebase.",
                    isSelected: fetchOnMenuOpen
                ) {
                    fetchOnMenuOpen = true
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 340)
    }

    private func preferenceOption(
        title: String,
        subtitle: String,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button {
            onSelect()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isSelected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.primary.opacity(0.2) : Color.primary.opacity(0.08),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
