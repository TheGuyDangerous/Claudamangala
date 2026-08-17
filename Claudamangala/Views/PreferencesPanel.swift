import SwiftUI

struct PreferencesPanel: View {
    @AppStorage(UsagePreferences.fetchOnMenuOpenKey) private var fetchOnMenuOpen = false
    let onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    onFinished()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Preferences")
                    .font(.headline)
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
        .frame(width: 320)
    }

    private func preferenceOption(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
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
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : .primary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.35) : .primary.opacity(0.08),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
