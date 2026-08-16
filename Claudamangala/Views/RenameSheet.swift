import SwiftUI

struct RenameSheet: View {
    @Bindable var accountsViewModel: AccountsViewModel
    let accountId: String
    let onFinished: () -> Void

    @State private var newLabel: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        accountsViewModel: AccountsViewModel,
        accountId: String,
        currentLabel: String,
        onFinished: @escaping () -> Void
    ) {
        self.accountsViewModel = accountsViewModel
        self.accountId = accountId
        self.onFinished = onFinished
        _newLabel = State(initialValue: currentLabel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    onFinished()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Rename Account")
                    .font(.headline)
            }

            TextField("Label", text: $newLabel)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

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
                    .disabled(newLabel.isEmpty || isSaving)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func save() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil
        Task {
            await accountsViewModel.rename(accountId: accountId, newLabel: trimmed)
            await MainActor.run {
                isSaving = false
                onFinished()
            }
        }
    }
}
