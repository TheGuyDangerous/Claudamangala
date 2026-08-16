import Foundation

enum PipelineConfigLoader {
    /// Prefer bundled `PipelineConfig.plist` (gitignored). Fall back to Firestore
    /// when rules allow reading `app_config/pipeline`.
    static func load(firestore: FirestoreRESTService? = nil) async throws -> PipelineConfig {
        if let bundled = loadFromBundle() {
            return bundled
        }
        if let firestore {
            return try await firestore.fetchPipelineConfig()
        }
        throw PipelineTriggerError.configMissing
    }

    private static func loadFromBundle() -> PipelineConfig? {
        guard let url = Bundle.main.url(forResource: "PipelineConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        guard
            let githubOwner = plist["githubOwner"] as? String,
            let githubRepo = plist["githubRepo"] as? String,
            let workflowFile = plist["workflowFile"] as? String,
            let defaultBranch = plist["defaultBranch"] as? String,
            let dispatchToken = plist["dispatchToken"] as? String,
            let dispatchSecret = plist["dispatchSecret"] as? String
        else { return nil }

        return PipelineConfig(
            githubOwner: githubOwner,
            githubRepo: githubRepo,
            workflowFile: workflowFile,
            defaultBranch: defaultBranch,
            dispatchToken: dispatchToken,
            dispatchSecret: dispatchSecret
        )
    }
}
