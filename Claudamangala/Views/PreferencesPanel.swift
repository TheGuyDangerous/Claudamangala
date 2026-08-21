import SwiftUI

struct PreferencesPanel: View {
    @AppStorage(UsagePreferences.fetchOnMenuOpenKey) private var fetchOnMenuOpen = false
    @AppStorage(ApplyDestinationPreferences.destinationKey) private var applyDestinationRaw = ApplyDestination.keychain.rawValue
    @AppStorage(RefreshPreferences.oauthRefreshModeKey) private var oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
    @AppStorage(LaunchPreferences.launchAtLoginKey) private var launchAtLogin = false
    @AppStorage(UpdatePreferences.checkAutomaticallyKey) private var checkForUpdatesAutomatically = true
    @AppStorage(UpdatePreferences.installAutomaticallyKey) private var installUpdatesAutomatically = true
    @AppStorage(LocalRefreshSchedulePreferences.scheduleKey) private var localRefreshScheduleRaw = LocalRefreshSchedule.off.rawValue
    @Bindable var updateViewModel: UpdateViewModel
    @Bindable var accountsViewModel: AccountsViewModel
    let localRefreshScheduler: LocalRefreshScheduler
    let onFinished: () -> Void

    @State private var launchAtLoginError: String?

    private var canUseCloudRefresh: Bool {
        accountsViewModel.canUseCloudRefresh
    }

    private var applyDestination: ApplyDestination {
        ApplyDestination(rawValue: applyDestinationRaw) ?? .keychain
    }

    private var oauthRefreshMode: OAuthRefreshMode {
        OAuthRefreshMode(rawValue: oauthRefreshModeRaw) ?? .local
    }

    private var oauthRefreshModeSubtitle: String {
        switch oauthRefreshMode {
        case .local:
            return "Refresh tokens on this Mac and write straight to Firebase."
        case .cloud:
            return "Trigger the GitHub Actions pipeline and wait for Firebase to update."
        }
    }

    private var localRefreshSchedule: LocalRefreshSchedule {
        LocalRefreshSchedule(rawValue: localRefreshScheduleRaw) ?? .off
    }

    private func localRefreshScheduleSubtitle(for schedule: LocalRefreshSchedule) -> String {
        switch schedule {
        case .off:
            return "Only refresh when you tap Refresh on an account."
        case .every1Hour, .every2Hours, .every4Hours, .every6Hours:
            return "Runs automatically while this Mac is awake and Claudamangala is open."
        }
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

                Text("Apply")
                    .font(.subheadline.weight(.semibold))

                Text("Choose where the Apply button writes the selected Claude Code session on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    preferenceOption(
                        title: "macOS Keychain",
                        subtitle: "Default. Replaces the Claude Code-credentials Keychain item Claude Code reads on this Mac.",
                        isSelected: applyDestination == .keychain
                    ) {
                        applyDestinationRaw = ApplyDestination.keychain.rawValue
                    }

                    preferenceOption(
                        title: ".claude folder",
                        subtitle: "Write ~/.claude/.credentials.json. Creates the folder and file if they are missing; if the file already exists, Apply updates claudeAiOauth inside it and leaves other keys (like MCP tokens) alone.",
                        isSelected: applyDestination == .credentialsFile
                    ) {
                        applyDestinationRaw = ApplyDestination.credentialsFile.rawValue
                    }
                }

                Text("Token refresh")
                    .font(.subheadline.weight(.semibold))

                if canUseCloudRefresh {
                    Text("Choose how manual Refresh updates OAuth tokens in Firebase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manual refresh")
                                .font(.body.weight(.medium))
                            Text(oauthRefreshModeSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Picker("Manual refresh", selection: $oauthRefreshModeRaw) {
                            ForEach(OAuthRefreshMode.allCases, id: \.rawValue) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            }
                    }
                } else {
                    Text("OAuth tokens refresh locally on this Mac and save straight to Firebase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                automaticLocalRefreshSection

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
        .frame(minHeight: 480, maxHeight: 520)
        .onAppear {
            launchAtLogin = LaunchPreferences.isRegisteredWithSystem
            if !canUseCloudRefresh, oauthRefreshModeRaw == OAuthRefreshMode.cloud.rawValue {
                oauthRefreshModeRaw = OAuthRefreshMode.local.rawValue
            }
            Task { await accountsViewModel.refreshCloudRefreshAccess() }
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
        .onChange(of: localRefreshScheduleRaw) { _, _ in
            if localRefreshSchedule == .off {
                LocalRefreshSchedulePreferences.lastRunAt = nil
            }
            localRefreshScheduler.reschedule()
        }
    }

    private var automaticLocalRefreshSection: some View {
        Group {
            Text("Automatic local refresh")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)

            Text(automaticLocalRefreshDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interval")
                        .font(.body.weight(.medium))
                    Text(localRefreshScheduleSubtitle(for: localRefreshSchedule))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Picker("Interval", selection: $localRefreshScheduleRaw) {
                    ForEach(LocalRefreshSchedule.allCases) { schedule in
                        Text(schedule.title).tag(schedule.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
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
    }

    private var automaticLocalRefreshDescription: String {
        if canUseCloudRefresh {
            return "While Claudamangala is running on this Mac, refresh every account locally on a schedule. This is separate from the GitHub Actions cron and from the manual Refresh mode above."
        }
        return "While Claudamangala is running, refresh every account on a schedule and write back to Firebase. Enable Launch at login to keep this going in the background."
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .scaleEffect(0.88)
                .frame(width: 32, height: 18)
        }
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
