//
//  AppConfiguration.swift
//  SwiftlyFeedbackAdmin
//
//  Global configuration manager for environment and server URL management
//

import Foundation

/// Environment configuration options
enum AppEnvironment: String, Codable, CaseIterable {
    case development
    case staging
    case production

    var displayName: String {
        switch self {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }

    var baseURL: String {
        switch self {
        case .development:
            return "https://feedbackkit-dev-3d08c4624108.herokuapp.com"
        case .staging:
            return "https://feedbackkit-testflight-2e08ccf13bc4.herokuapp.com"
        case .production:
            return "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com"
        }
    }

    /// Local development URL for testing against localhost
    var localURL: String {
        "http://localhost:8080"
    }
}

/// Global configuration manager for app-wide settings
@MainActor
@Observable
final class AppConfiguration {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = AppConfiguration()

    private let userDefaults: UserDefaults
    private let environmentKey = "com.swiftlyfeedback.admin.environment"

    /// Toggle for using localhost instead of remote URLs (useful for local backend testing)
    var useLocalhost: Bool {
        didSet {
            userDefaults.set(useLocalhost, forKey: "com.swiftlyfeedback.admin.useLocalhost")
        }
    }

    /// Current environment setting
    var environment: AppEnvironment {
        didSet {
            #if DEBUG
            // In DEBUG mode, allow changing environment and save it
            userDefaults.set(environment.rawValue, forKey: environmentKey)
            #else
            // In RELEASE mode (TestFlight or Production)
            if BuildEnvironment.isTestFlight {
                // TestFlight: Allow staging or production (for testing)
                if environment == .development {
                    print("⚠️ Development not allowed in TestFlight - switching to Staging")
                    environment = .staging
                } else {
                    userDefaults.set(environment.rawValue, forKey: environmentKey)
                }
            } else {
                // Production (App Store): Lock to production only
                if environment != .production {
                    print("⚠️ Production builds must use Production environment")
                    environment = .production
                }
            }
            #endif
        }
    }

    /// Current base URL based on environment and localhost setting
    var baseURL: String {
        useLocalhost ? environment.localURL : environment.baseURL
    }

    /// Current API v1 base URL (baseURL + /api/v1)
    var apiV1URL: String {
        baseURL + "/api/v1"
    }

    /// Convenience property for checking if in development mode
    var isDevelopmentMode: Bool {
        environment == .development
    }

    /// Convenience property for checking if in staging mode
    var isStagingMode: Bool {
        environment == .staging
    }

    /// Convenience property for checking if in production mode
    var isProductionMode: Bool {
        environment == .production
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load saved localhost preference
        self.useLocalhost = userDefaults.bool(forKey: "com.swiftlyfeedback.admin.useLocalhost")

        #if DEBUG
        // DEBUG mode: Load saved environment or default to development
        if let savedEnv = userDefaults.string(forKey: environmentKey),
           let env = AppEnvironment(rawValue: savedEnv) {
            self.environment = env
        } else {
            self.environment = .development
        }

        // Override with launch arguments for testing
        if CommandLine.arguments.contains("--dev-mode") {
            self.environment = .development
        } else if CommandLine.arguments.contains("--staging-mode") {
            self.environment = .staging
        } else if CommandLine.arguments.contains("--prod-mode") {
            self.environment = .production
        }

        // Override for localhost testing
        if CommandLine.arguments.contains("--localhost") {
            self.useLocalhost = true
        }
        #else
        // RELEASE mode: Behavior depends on build type
        if BuildEnvironment.isTestFlight {
            // TestFlight: Load saved staging/production or default to staging
            if let savedEnv = userDefaults.string(forKey: environmentKey),
               let env = AppEnvironment(rawValue: savedEnv),
               (env == .staging || env == .production) {
                self.environment = env
            } else {
                self.environment = .staging
            }
        } else {
            // Production (App Store): Always use production
            self.environment = .production
        }
        #endif

        #if DEBUG
        print("🔧 App Configuration Initialized")
        print("📍 Environment: \(environment.displayName)")
        print("🌐 Base URL: \(baseURL)")
        print("🏠 Using Localhost: \(useLocalhost)")
        #endif
    }
}

// MARK: - Convenient Global Access
extension AppConfiguration {
    /// Quick access to base URL
    static var baseURL: String {
        shared.baseURL
    }

    /// Quick access to API v1 URL
    static var apiV1URL: String {
        shared.apiV1URL
    }

    /// Quick access to current environment
    static var currentEnvironment: AppEnvironment {
        shared.environment
    }

    /// Quick access to development mode status
    static var isDevelopmentMode: Bool {
        shared.isDevelopmentMode
    }

    /// Quick access to staging mode status
    static var isStagingMode: Bool {
        shared.isStagingMode
    }

    /// Quick access to production mode status
    static var isProductionMode: Bool {
        shared.isProductionMode
    }
}

// MARK: - URL Building
extension AppConfiguration {
    /// Safely construct a URL from the base URL and path
    /// - Parameter path: The path to append (should start with /)
    /// - Returns: A valid URL or nil if construction fails
    func url(path: String) -> URL? {
        let urlString = baseURL + path
        return URL(string: urlString)
    }

    /// Static convenience method for URL construction
    /// - Parameter path: The path to append (should start with /)
    /// - Returns: A valid URL or nil if construction fails
    static func url(path: String) -> URL? {
        shared.url(path: path)
    }
}

// MARK: - Environment Switching
extension AppConfiguration {
    /// Switch to a different environment
    /// - Parameter environment: The target environment
    /// - Note: TestFlight allows staging/production, Production builds lock to production only
    func switchTo(_ environment: AppEnvironment) {
        #if DEBUG
        self.environment = environment
        print("🔄 Switched to \(environment.displayName) environment")
        print("🌐 New Base URL: \(baseURL)")
        #else
        if BuildEnvironment.isTestFlight {
            // TestFlight: Allow staging or production
            if environment == .development {
                print("⚠️ Development not allowed in TestFlight - using Staging")
                self.environment = .staging
            } else {
                self.environment = environment
                print("🔄 Switched to \(environment.displayName) environment")
                print("🌐 New Base URL: \(baseURL)")
            }
        } else {
            // Production: Always lock to production
            print("⚠️ Environment switching disabled in Production builds - locked to Production")
            self.environment = .production
        }
        #endif
    }

    /// Reset to default environment
    /// - Note: DEBUG → Development, TestFlight → Staging, Production → Production
    func resetToDefault() {
        #if DEBUG
        switchTo(.development)
        #else
        if BuildEnvironment.isTestFlight {
            switchTo(.staging)
        } else {
            switchTo(.production)
        }
        #endif
    }

    /// Check if environment switching is allowed
    var canSwitchEnvironment: Bool {
        #if DEBUG
        return true
        #else
        // TestFlight can switch between staging/production, Production is locked
        return BuildEnvironment.isTestFlight
        #endif
    }
}
