import Foundation

/// Prevents the menu-bar popover from treating Keychain system UI as a user-dismiss.
@MainActor
enum KeychainAccessGate {
    private(set) static var activeOperations = 0

    static var isPresentingSystemUI: Bool { activeOperations > 0 }

    static func begin() {
        activeOperations += 1
    }

    static func end() {
        activeOperations = max(0, activeOperations - 1)
    }

    static func whileAccessing<T>(_ operation: () async throws -> T) async rethrows -> T {
        begin()
        defer { end() }
        return try await operation()
    }
}
