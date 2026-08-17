import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var session: FirebaseSession?
    var authError: String?
    var isLoading = false
    var isRestoringSession = true

    var isSignedIn: Bool { session != nil }

    init() {
        Task { await restoreSessionIfPossible() }
    }

    func signIn(email: String, password: String) async {
        await authenticate(email: email, password: password) {
            try await FirebaseSession.signIn(email: $0, password: $1)
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate(email: email, password: password) {
            try await FirebaseSession.signUp(email: $0, password: $1)
        }
    }

    func signOut() {
        session?.signOut()
        session = nil
    }

    private func authenticate(
        email: String,
        password: String,
        request: (String, String) async throws -> FirebaseSession
    ) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            session = try await request(trimmedEmail, trimmedPassword)
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func restoreSessionIfPossible() async {
        defer { isRestoringSession = false }
        session = try? await FirebaseSession.restore()
    }
}
