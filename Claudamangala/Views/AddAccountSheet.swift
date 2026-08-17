import SwiftUI

private enum CredentialSource: String, CaseIterable, Identifiable {
    case keychain = "Current session"
    case json = "Paste JSON"

    var id: String { rawValue }
}

struct AddAccountSheet: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let onFinished: () -> Void

    @State private var source: CredentialSource = .keychain
    @State private var label = ""
    @State private var jsonText = ""
    @State private var keychainCredentials: ClaudeOAuthCredentials?
    @State private var readError: String?
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelBackHeader(title: "Add Account", onBack: onFinished)

            Picker("Source", selection: $source) {
                ForEach(CredentialSource.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            credentialSourceSection

            TextField("Label (e.g. Personal Account)", text: $label)
                .textFieldStyle(.roundedBorder)

            if !label.isEmpty {
                let slug = AccountDocumentId.slug(from: label)
                if !slug.isEmpty {
                    Text("Document id: \(slug)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
                Button("Add") { addAccount() }
                    .buttonStyle(.glass)
                    .disabled(!canAdd)
            }
        }
        .padding(16)
        .frame(width: 340)
        .task { loadKeychainCredentialsIfNeeded() }
        .onChange(of: source) { _, newSource in
            if newSource == .keychain, keychainCredentials == nil {
                loadKeychainCredentialsIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var credentialSourceSection: some View {
        switch source {
        case .keychain:
            if let readError {
                Text(readError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let credentials = keychainCredentials {
                Text("Found current session, expires \(expiresDescription(credentials.expiresAt)).")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading Keychain…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .json:
            Text("Paste `~/.claude/.credentials.json` or the claudeAiOauth block.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $jsonText)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private var canAdd: Bool {
        guard !label.isEmpty, !isSaving, !AccountDocumentId.slug(from: label).isEmpty else {
            return false
        }
        switch source {
        case .keychain:
            return keychainCredentials != nil
        case .json:
            return parsedJSONCredentials != nil
        }
    }

    private var parsedJSONCredentials: ClaudeOAuthCredentials? {
        try? ClaudeOAuthCredentials.parse(importedJSON: jsonText)
    }

    private func resolvedCredentials() throws -> ClaudeOAuthCredentials {
        switch source {
        case .keychain:
            guard let keychainCredentials else {
                throw KeychainServiceError.itemNotFound
            }
            return keychainCredentials
        case .json:
            return try ClaudeOAuthCredentials.parse(importedJSON: jsonText)
        }
    }

    private func loadKeychainCredentialsIfNeeded() {
        readError = nil
        do {
            keychainCredentials = try KeychainService.readCurrentClaudeCredentials()
        } catch {
            keychainCredentials = nil
            readError = error.localizedDescription
        }
    }

    private func addAccount() {
        isSaving = true
        saveError = nil
        Task {
            do {
                let credentials = try resolvedCredentials()
                try await accountsViewModel.addAccount(label: label, credentials: credentials)
                await MainActor.run { onFinished() }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func expiresDescription(_ expiresAt: Double) -> String {
        let remainingMs = expiresAt - Date().timeIntervalSince1970 * 1000
        if remainingMs <= 0 { return "already (expired)" }
        let minutes = Int(remainingMs / 60_000)
        if minutes < 60 { return "in \(minutes)m" }
        return "in \(minutes / 60)h \(minutes % 60)m"
    }
}
