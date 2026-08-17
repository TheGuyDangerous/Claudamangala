import AppKit
import SwiftUI

struct AccountRowView: View {
    let style: AccountUIStyle
    let account: ClaudeAccount
    let usage: ClaudeAccountUsage
    let isRefreshing: Bool
    let isJustApplied: Bool
    let onApply: () -> Void
    let onRefresh: () -> Void
    let onRename: () -> Void

    @State private var justCopied = false

    var body: some View {
        AccountRowVariants.row(
            style: style,
            context: AccountRowContext(
                account: account,
                usage: usage,
                isRefreshing: isRefreshing,
                isJustApplied: isJustApplied,
                onApply: onApply,
                onRefresh: onRefresh,
                onRename: onRename,
                onCopy: copyCredentials,
                justCopied: justCopied
            )
        )
    }

    private func copyCredentials() {
        do {
            let json = try account.credentialsClipboardJSON()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                justCopied = false
            }
        } catch {}
    }
}
