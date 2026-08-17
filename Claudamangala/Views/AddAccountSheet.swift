import SwiftUI

struct AddAccountSheet: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let onFinished: () -> Void

    @State private var label = ""
    @State private var docId = ""
    @State private var docIdManuallyEdited = false
    @State private var currentCredentials: ClaudeOAuthCredentials?
    @State private var readError: String?
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelBackHeader(title: "Add Account", onBack: onFinished)

            if let readError {
                Text(readError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let credentials = currentCredentials {
                Text("Found current session, expires \(expiresDescription(credentials.expiresAt)).")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                ProgressView().controlSize(.small)
            }

            TextField("Label (e.g. Personal Account)", text: $label)
                .textFieldStyle(.roundedBorder)
                .onChange(of: label) { _, newValue in
                    if !docIdManuallyEdited {
                        docId = slugify(newValue)
                    }
                }

            TextField("Document ID", text: $docId)
                .textFieldStyle(.roundedBorder)
                .onChange(of: docId) { _, _ in docIdManuallyEdited = true }

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
        .frame(width: 320)
        .task { readCurrentSession() }
    }

    private var canAdd: Bool {
        currentCredentials != nil && !label.isEmpty && !docId.isEmpty && !isSaving
    }

    private func readCurrentSession() {
        do {
            currentCredentials = try KeychainService.readCurrentClaudeCredentials()
        } catch {
            readError = error.localizedDescription
        }
    }

    private func addAccount() {
        guard let credentials = currentCredentials else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await accountsViewModel.addAccount(docId: docId, label: label, credentials: credentials)
                await MainActor.run { onFinished() }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func slugify(_ input: String) -> String {
        let lowered = input.lowercased()
        let slug = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        var result = String(String.UnicodeScalarView(slug.compactMap { char -> Unicode.Scalar? in
            char.unicodeScalars.first
        }))
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func expiresDescription(_ expiresAt: Double) -> String {
        let remainingMs = expiresAt - Date().timeIntervalSince1970 * 1000
        if remainingMs <= 0 { return "already (expired)" }
        let minutes = Int(remainingMs / 60_000)
        if minutes < 60 { return "in \(minutes)m" }
        return "in \(minutes / 60)h \(minutes % 60)m"
    }
}
