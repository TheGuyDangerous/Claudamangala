import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var session: FirebaseSession?
    var signInError: String?
    var isLoading = false
    var isRestoringSession = true

    var isSignedIn: Bool { session != nil }

    init() {
        Task { await restoreSessionIfPossible() }
    }

    func signIn(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        signInError = nil
        defer { isLoading = false }

        do {
            session = try await FirebaseSession.signIn(email: trimmedEmail, password: trimmedPassword)
        } catch {
            signInError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        session?.signOut()
        session = nil
    }

    private func restoreSessionIfPossible() async {
        defer { isRestoringSession = false }
        session = try? await FirebaseSession.restore()
    }
}
