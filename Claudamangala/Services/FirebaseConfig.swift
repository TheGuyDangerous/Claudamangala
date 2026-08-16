import Foundation

enum FirebaseConfig {
    private static let plist: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("GoogleService-Info.plist is missing from the app bundle.")
        }
        return dict
    }()

    static var apiKey: String {
        guard let key = plist["API_KEY"] as? String else {
            fatalError("GoogleService-Info.plist is missing API_KEY.")
        }
        return key
    }

    static var projectId: String {
        guard let id = plist["PROJECT_ID"] as? String else {
            fatalError("GoogleService-Info.plist is missing PROJECT_ID.")
        }
        return id
    }
}
