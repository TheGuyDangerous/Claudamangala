import Foundation

enum ClaudeCredentialsFileService {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent(".credentials.json")
    }

    static func writeCredentials(_ credentials: ClaudeOAuthCredentials) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try writeCredentialsSync(credentials)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func writeCredentialsSync(_ credentials: ClaudeOAuthCredentials) throws {
        let fm = FileManager.default
        let url = fileURL
        let directory = url.deletingLastPathComponent()

        if !fm.fileExists(atPath: directory.path) {
            do {
                try fm.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch {
                throw ClaudeCredentialsFileServiceError.writeFailed(error.localizedDescription)
            }
        }

        let oauthData: Data
        do {
            oauthData = try JSONEncoder().encode(credentials)
        } catch {
            throw ClaudeCredentialsFileServiceError.malformedCredentials
        }

        guard let oauthDict = try JSONSerialization.jsonObject(with: oauthData) as? [String: Any] else {
            throw ClaudeCredentialsFileServiceError.malformedCredentials
        }

        var root: [String: Any] = [:]
        if fm.fileExists(atPath: url.path),
           let existingData = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]
        {
            root = existing
        }
        root["claudeAiOauth"] = oauthDict

        let output: Data
        do {
            output = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            try output.write(to: url, options: [.atomic])
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw ClaudeCredentialsFileServiceError.writeFailed(error.localizedDescription)
        }
    }
}

enum ClaudeCredentialsFileServiceError: Error, LocalizedError {
    case malformedCredentials
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .malformedCredentials:
            return "Could not encode Claude credentials for ~/.claude/.credentials.json."
        case .writeFailed(let message):
            return "Could not write ~/.claude/.credentials.json: \(message)"
        }
    }
}
