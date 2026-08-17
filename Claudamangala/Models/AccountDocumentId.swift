import Foundation

enum AccountDocumentId {
    /// Kebab-case Firestore document id derived from the account label.
    static func slug(from label: String) -> String {
        let lowered = label.lowercased()
        let slug = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        var result = String(slug)
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
