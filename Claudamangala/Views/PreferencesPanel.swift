import SwiftUI

struct PreferencesPanel: View {
    @AppStorage(UsagePreferences.fetchOnMenuOpenKey) private var fetchOnMenuOpen = false
    @AppStorage(RefreshPreferences.oauthRefreshModeKey) private var oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
    @AppStorage(LaunchPreferences.launchAtLoginKey) private var launchAtLogin = false
    @AppStorage(UpdatePreferences.checkAutomaticallyKey) private var checkForUpdatesAutomatically = true
    @AppStorage(UpdatePreferences.installAutomaticallyKey) private var installUpdatesAutomatically = true
    @Bindable var updateViewModel: UpdateViewModel
    let userEmail: String?
    let onFinished: () -> Void

    @State private var launchAtLoginError: String?

    private var canUseCloudRefresh: Bool {
        RefreshPreferences.canUseCloudRefresh(email: userEmail)
    }

    private var oauthRefreshMode: OAuthRefreshMode {
        RefreshPreferences.oauthRefreshMode(for: userEmail)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PanelBackHeader(title: "Preferences", onBack: onFinished)

                Text("General")
                    .font(.subheadline.weight(.semibold))

                preferenceToggle(
                    title: "Launch at login",
                    subtitle: "Open Claudamangala automatically when you sign in to this Mac.",
                    isOn: $launchAtLogin
                )

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Updates")
                    .font(.subheadline.weight(.semibold))

                Text(updateViewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("Check now") {
                        Task { await updateViewModel.checkForUpdates() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isUpdateActionInProgress)

                    if updateViewModel.pendingUpdate != nil {
                        Button("Install update") {
                            Task { await updateViewModel.downloadAndInstall() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isUpdateActionInProgress)
                    }
                }

                preferenceToggle(
                    title: "Check for updates automatically",
                    subtitle: "Look for a newer GitHub release when Claudamangala opens.",
                    isOn: $checkForUpdatesAutomatically
                )

                preferenceToggle(
                    title: "Install updates automatically",
                    subtitle: "Download and replace the app in Applications, then relaunch. macOS may still ask you to approve the new build once.",
                    isOn: $installUpdatesAutomatically
                )

                Text("Token refresh")
                    .font(.subheadline.weight(.semibold))

                if canUseCloudRefresh {
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
                } else {
                    Text("OAuth tokens refresh locally on this Mac and save straight to Firebase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
            }
            .padding(16)
        }
        .frame(width: 340)
        .frame(maxHeight: 520)
        .onAppear {
            launchAtLogin = LaunchPreferences.isRegisteredWithSystem
            if !canUseCloudRefresh, oauthRefreshModeRaw == OAuthRefreshMode.cloud.rawValue {
                oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
            }
        }
        .onChange(of: launchAtLogin) { _, enabled in
            launchAtLoginError = nil
            do {
                try LaunchPreferences.setLaunchAtLogin(enabled)
            } catch {
                launchAtLogin = LaunchPreferences.isRegisteredWithSystem
                launchAtLoginError = error.localizedDescription
            }
        }
        .onChange(of: checkForUpdatesAutomatically) { _, enabled in
            UpdatePreferences.checkAutomatically = enabled
        }
        .onChange(of: installUpdatesAutomatically) { _, enabled in
            UpdatePreferences.installAutomatically = enabled
        }
    }

    private var isUpdateActionInProgress: Bool {
        switch updateViewModel.status {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
        }
    }

    private func preferenceToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .toggleStyle(.switch)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
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
