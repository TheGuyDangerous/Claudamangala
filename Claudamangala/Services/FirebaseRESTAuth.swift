import Foundation

/// Email/password auth via Firebase Identity Toolkit REST API.
/// Avoids Firebase Auth SDK keychain access, which fails on unsigned macOS builds (error 17995).
@MainActor
final class FirebaseSession {
    private(set) var email: String
    private(set) var idToken: String
    private(set) var refreshToken: String
    private var expiresAt: Date

    private static let storageKey = "com.sannidhya.claude.firebaseSession"

    private init(email: String, idToken: String, refreshToken: String, expiresIn: TimeInterval) {
        self.email = email
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.expiresAt = Date().addingTimeInterval(expiresIn)
    }

    // MARK: - Public API

    static func signIn(email: String, password: String) async throws -> FirebaseSession {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "returnSecureToken": true,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let idToken = json?["idToken"] as? String,
            let refreshToken = json?["refreshToken"] as? String,
            let expiresIn = Self.parseExpiresIn(json?["expiresIn"])
        else {
            throw FirebaseRESTError.unexpectedResponse
        }

        let session = FirebaseSession(
            email: email,
            idToken: idToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )
        session.persist()
        return session
    }

    static func restore() async throws -> FirebaseSession? {
        guard
            let stored = UserDefaults.standard.dictionary(forKey: storageKey),
            let email = stored["email"] as? String,
            let refreshToken = stored["refreshToken"] as? String
        else {
            return nil
        }

        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 400 {
            clearStoredSession()
            return nil
        }
        try Self.throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let idToken = json?["id_token"] as? String,
            let newRefresh = json?["refresh_token"] as? String,
            let expiresIn = Self.parseExpiresIn(json?["expires_in"])
        else {
            clearStoredSession()
            return nil
        }

        let session = FirebaseSession(
            email: email,
            idToken: idToken,
            refreshToken: newRefresh,
            expiresIn: expiresIn
        )
        session.persist()
        return session
    }

    func validIDToken() async throws -> String {
        if Date() < expiresAt.addingTimeInterval(-60) {
            return idToken
        }
        try await refresh()
        return idToken
    }

    func signOut() {
        Self.clearStoredSession()
    }

    // MARK: - Private

    private func refresh() async throws {
        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let newIDToken = json?["id_token"] as? String,
            let newRefresh = json?["refresh_token"] as? String,
            let expiresIn = Self.parseExpiresIn(json?["expires_in"])
        else {
            throw FirebaseRESTError.unexpectedResponse
        }

        idToken = newIDToken
        refreshToken = newRefresh
        expiresAt = Date().addingTimeInterval(expiresIn)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set([
            "email": email,
            "refreshToken": refreshToken,
        ], forKey: Self.storageKey)
    }

    private static func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func parseExpiresIn(_ value: Any?) -> TimeInterval? {
        if let seconds = value as? TimeInterval { return seconds }
        if let seconds = value as? Int { return TimeInterval(seconds) }
        if let string = value as? String, let seconds = TimeInterval(string) { return seconds }
        return nil
    }

    private static func throwIfHTTPError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FirebaseRESTError.network
        }
        guard (200 ... 299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw FirebaseRESTError.server(message)
            }
            throw FirebaseRESTError.http(http.statusCode)
        }
    }
}

enum FirebaseRESTError: LocalizedError {
    case network
    case http(Int)
    case server(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .network:
            return "No internet connection."
        case .http(401), .http(400):
            return "Incorrect email or password."
        case .http(let code):
            return "Sign-in failed (HTTP \(code))."
        case .server(let message):
            switch message {
            case "INVALID_PASSWORD", "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS":
                return "Incorrect email or password."
            case "USER_DISABLED":
                return "This account has been disabled."
            default:
                return "Sign-in failed. Please try again."
            }
        case .unexpectedResponse:
            return "Sign-in failed. Please try again."
        }
    }
}
