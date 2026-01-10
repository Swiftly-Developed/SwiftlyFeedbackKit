import Vapor

enum EnvironmentType: String {
    case development
    case staging
    case production
    case local

    var name: String { rawValue }
}

final class AppEnvironment: Sendable {
    static let shared = AppEnvironment()

    let type: EnvironmentType
    let serverURL: String

    private init() {
        // Read APP_ENV from environment variable
        if let appEnv = Environment.get("APP_ENV") {
            switch appEnv.lowercased() {
            case "development":
                self.type = .development
                self.serverURL = "https://api.feedbackkit.dev.swiftly-developed.com"
            case "staging":
                self.type = .staging
                self.serverURL = "https://api.feedbackkit.testflight.swiftly-developed.com"
            case "production":
                self.type = .production
                self.serverURL = "https://api.feedbackkit.prod.swiftly-developed.com"
            default:
                self.type = .local
                self.serverURL = "http://localhost:8080"
            }
        } else {
            // Default to local for development
            self.type = .local
            self.serverURL = "http://localhost:8080"
        }
    }

    var isDevelopment: Bool { type == .development }
    var isStaging: Bool { type == .staging }
    var isProduction: Bool { type == .production }
    var isLocal: Bool { type == .local }
}
