import SwiftUI

struct EditAccountSheet: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let account: ClaudeAccount
    let onFinished: () -> Void

    @State private var label: String
    @State private var jsonText: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        accountsViewModel: AccountsViewModel,
        account: ClaudeAccount,
        onFinished: @escaping () -> Void
    ) {
        self.accountsViewModel = accountsViewModel
        self.account = account
        self.onFinished = onFinished
        _label = State(initialValue: account.label)
        _jsonText = State(
            initialValue: (try? account.credentialsClipboardJSON()) ?? ""
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelBackHeader(title: "Edit Account", onBack: onFinished)

                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                if let accountId = account.id {
                    Text("Document id: \(accountId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("Credentials JSON")
                    .font(.subheadline.weight(.semibold))

                Text("Edit the saved OAuth tokens or paste a fresh export from Claude Code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $jsonText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160, maxHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    Button("Reset to saved") {
                        resetJSONToSaved()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)

                    Button("Read current session") {
                        loadKeychainCredentials()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                if parsedCredentials == nil, !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("JSON must include accessToken, refreshToken, expiresAt, and scopes.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let saveError {
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { onFinished() }
                        .buttonStyle(.plain)
                    Button("Save") { save() }
                        .buttonStyle(.glass)
                        .disabled(!canSave)
                }
            }
            .padding(16)
        }
        .frame(width: 340)
        .frame(minHeight: 360, maxHeight: 460)
    }

    private var parsedCredentials: ClaudeOAuthCredentials? {
        try? ClaudeOAuthCredentials.parse(importedJSON: jsonText)
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedLabel.isEmpty && parsedCredentials != nil
    }

    private func resetJSONToSaved() {
        saveError = nil
        jsonText = (try? account.credentialsClipboardJSON()) ?? ""
    }

    private func loadKeychainCredentials() {
        saveError = nil
        Task {
            do {
                let credentials = try await KeychainService.readCurrentClaudeCredentials()
                let wrapper: [String: Any] = [
                    "claudeAiOauth": [
                        "accessToken": credentials.accessToken,
                        "refreshToken": credentials.refreshToken,
                        "expiresAt": credentials.expiresAt,
                        "scopes": credentials.scopes,
                    ],
                ]
                let data = try JSONSerialization.data(
                    withJSONObject: wrapper,
                    options: [.prettyPrinted, .sortedKeys]
                )
                guard let text = String(data: data, encoding: .utf8) else { return }
                await MainActor.run {
                    jsonText = text
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func save() {
        guard let accountId = account.id else {
            saveError = "This account has no document id."
            return
        }
        guard !isSaving else { return }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return }

        let credentials: ClaudeOAuthCredentials
        do {
            credentials = try ClaudeOAuthCredentials.parse(importedJSON: jsonText)
        } catch {
            saveError = error.localizedDescription
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                try await accountsViewModel.updateAccount(
                    accountId: accountId,
                    label: trimmedLabel,
                    credentials: credentials
                )
                await MainActor.run { onFinished() }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
