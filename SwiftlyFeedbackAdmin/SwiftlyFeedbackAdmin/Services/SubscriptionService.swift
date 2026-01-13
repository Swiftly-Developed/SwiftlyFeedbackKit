//
//  SubscriptionService.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 04/01/2026.
//

import Foundation
import RevenueCat

// MARK: - Subscription Tier

/// Represents the user's subscription tier
enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case team = "team"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }

    /// Maximum number of projects allowed (nil = unlimited)
    var maxProjects: Int? {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .team: return nil
        }
    }

    /// Maximum feedback items per project (nil = unlimited)
    var maxFeedbackPerProject: Int? {
        switch self {
        case .free: return 10
        case .pro: return nil
        case .team: return nil
        }
    }

    /// Whether the tier allows inviting team members
    var canInviteMembers: Bool {
        self == .team
    }

    /// Whether the tier has access to integrations (Slack, GitHub, Email)
    var hasIntegrations: Bool {
        self != .free
    }

    /// Whether the tier has advanced analytics (MRR, detailed insights)
    var hasAdvancedAnalytics: Bool {
        self != .free
    }

    /// Whether the tier has configurable statuses
    var hasConfigurableStatuses: Bool {
        self != .free
    }

    /// Check if this tier meets the requirement of another tier
    func meetsRequirement(_ required: SubscriptionTier) -> Bool {
        switch required {
        case .free: return true
        case .pro: return self == .pro || self == .team
        case .team: return self == .team
        }
    }
}

// MARK: - Subscription Service

/// Service responsible for managing subscriptions via RevenueCat.
@MainActor
@Observable
final class SubscriptionService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SubscriptionService()

    // MARK: - Configuration

    /// RevenueCat public API key - Replace with your actual key from RevenueCat dashboard
    static let revenueCatAPIKey = "appl_qwlqUlehsPfFfhvmaWLAqfEKMGs"

    /// Entitlement identifier for Pro tier (must match RevenueCat dashboard)
    static let proEntitlementID = "Swiftly Pro"

    /// Entitlement identifier for Team tier (must match RevenueCat dashboard)
    static let teamEntitlementID = "Swiftly Team"

    /// Product identifiers
    enum ProductID: String, CaseIterable {
        case proMonthly = "swiftlyfeedback.pro.monthly"
        case proYearly = "swiftlyfeedback.pro.yearly"
        case teamMonthly = "swiftlyfeedback.team.monthly"
        case teamYearly = "swiftlyfeedback.team.yearly"
    }

    // MARK: - DEBUG Tier Simulation

    #if DEBUG
    /// DEBUG only: Simulated tier for testing specific tier behaviors
    /// Set via Developer Center. nil = use environment override or actual tier
    /// Stored in SecureStorageManager with "debug" scope.

    /// Backing storage for simulatedTier - @Observable tracks this property
    private var _simulatedTier: SubscriptionTier? = {
        guard let raw: String = SecureStorageManager.shared.get(.simulatedSubscriptionTier) else { return nil }
        return SubscriptionTier(rawValue: raw)
    }()

    var simulatedTier: SubscriptionTier? {
        get { _simulatedTier }
        set {
            _simulatedTier = newValue
            if let tier = newValue {
                SecureStorageManager.shared.set(tier.rawValue, for: .simulatedSubscriptionTier)
            } else {
                SecureStorageManager.shared.remove(.simulatedSubscriptionTier)
            }
            AppLogger.storage.debug("Simulated tier set to: \(newValue?.rawValue ?? "nil")")
        }
    }

    func clearSimulatedTier() {
        simulatedTier = nil
        AppLogger.storage.debug("Simulated tier cleared")
    }
    #endif

    /// Clears the cached server tier (used when resetting purchases in Developer Center)
    func clearServerTier() {
        serverTier = nil
        AppLogger.subscription.debug("Server tier cleared")
    }

    // MARK: - State

    /// Whether the service is currently loading data
    private(set) var isLoading = false

    /// Error message if an operation failed
    private(set) var errorMessage: String?

    /// Whether an error should be shown
    var showError = false

    /// Current customer info from RevenueCat
    private(set) var customerInfo: CustomerInfo?

    /// Available offerings from RevenueCat
    private(set) var offerings: Offerings?

    /// Server-side tier (used when RevenueCat doesn't have an active subscription)
    /// This is populated from the /auth/subscription/sync response
    private(set) var serverTier: SubscriptionTier?

    // MARK: - Computed Properties - Tier

    /// The user's current subscription tier based on RevenueCat entitlements
    /// Falls back to server tier if RevenueCat has no active subscription
    var currentTier: SubscriptionTier {
        // First check RevenueCat entitlements
        if let customerInfo {
            // Check Team first (higher tier)
            if customerInfo.entitlements[Self.teamEntitlementID]?.isActive == true {
                return .team
            }

            // Check for Pro entitlement
            if customerInfo.entitlements[Self.proEntitlementID]?.isActive == true {
                return .pro
            }
        }

        // If RevenueCat has no active subscription, use server tier
        // This handles cases like:
        // - DEBUG builds without App Store receipts
        // - Server-side tier overrides (from Developer Center)
        // - Users who purchased through other means (e.g., promo codes applied server-side)
        if let serverTier {
            return serverTier
        }

        return .free
    }

    /// Effective tier considering simulation (DEBUG only)
    /// Priority: 1. Simulated tier (DEBUG only), 2. Actual RevenueCat tier
    var effectiveTier: SubscriptionTier {
        #if DEBUG
        // If a specific tier is being simulated, use it
        if let simulated = simulatedTier {
            return simulated
        }
        #endif
        // Otherwise use actual RevenueCat tier
        return currentTier
    }

    /// Check if user meets tier requirement (considering environment override)
    func meetsRequirement(_ required: SubscriptionTier) -> Bool {
        effectiveTier.meetsRequirement(required)
    }

    /// Whether the user has an active Team subscription
    var isTeamSubscriber: Bool {
        effectiveTier == .team
    }

    /// Whether the user has an active Pro subscription (or higher)
    var isProSubscriber: Bool {
        effectiveTier == .pro || effectiveTier == .team
    }

    /// Whether the user has any paid subscription
    var isPaidSubscriber: Bool {
        isProSubscriber || isTeamSubscriber
    }

    /// The expiration date of the active subscription
    var subscriptionExpirationDate: Date? {
        customerInfo?.entitlements[Self.proEntitlementID]?.expirationDate
    }

    /// Whether the subscription will renew
    var willRenew: Bool {
        customerInfo?.entitlements[Self.proEntitlementID]?.willRenew ?? false
    }

    /// Display name for the current subscription status
    var subscriptionStatusText: String {
        currentTier.displayName
    }

    // MARK: - Initialization

    private init() {
        AppLogger.subscription.info("SubscriptionService initialized")
    }

    // MARK: - Configuration

    /// Configure the subscription service. Call this once at app launch.
    func configure(userId: UUID? = nil) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
        AppLogger.subscription.info("RevenueCat configured")

        if let userId {
            Task {
                await login(userId: userId)
            }
        }
    }

    // MARK: - Authentication

    /// Login with a user ID (call after user authentication)
    func login(userId: UUID) async {
        AppLogger.subscription.info("Logging in to RevenueCat with user ID: \(userId)")

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId.uuidString)
            self.customerInfo = customerInfo
            AppLogger.subscription.info("RevenueCat login successful, tier: \(currentTier.displayName)")

            // Sync with server
            await syncWithServer()
        } catch {
            AppLogger.subscription.error("RevenueCat login failed: \(error)")
        }
    }

    /// Logout (call after user logout)
    func logout() async {
        AppLogger.subscription.info("Logging out from RevenueCat")

        // Clear server tier on logout
        serverTier = nil

        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            AppLogger.subscription.info("RevenueCat logout successful")
        } catch {
            AppLogger.subscription.error("RevenueCat logout failed: \(error)")
        }
    }

    // MARK: - Data Fetching

    /// Fetch the current customer info
    func fetchCustomerInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.customerInfo()
            AppLogger.subscription.info("Fetched customer info, tier: \(currentTier.displayName)")
        } catch {
            AppLogger.subscription.error("Failed to fetch customer info: \(error)")
            showError(message: error.localizedDescription)
        }
    }

    /// Fetch available offerings
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await Purchases.shared.offerings()
            AppLogger.subscription.info("Fetched offerings: \(offerings?.current?.availablePackages.count ?? 0) packages")
        } catch {
            AppLogger.subscription.error("Failed to fetch offerings: \(error)")
            showError(message: error.localizedDescription)
        }
    }

    // MARK: - Purchases

    /// Purchase a subscription package
    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        AppLogger.subscription.info("Starting purchase for package: \(package.identifier)")

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            // Check if user cancelled the purchase
            if userCancelled {
                AppLogger.subscription.info("Purchase cancelled by user")
                throw SubscriptionError.purchaseCancelled
            }

            self.customerInfo = customerInfo
            AppLogger.subscription.info("Purchase successful, tier: \(currentTier.displayName)")

            // Sync with server after purchase
            await syncWithServer()
        } catch SubscriptionError.purchaseCancelled {
            // Re-throw our own cancellation error
            throw SubscriptionError.purchaseCancelled
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError {
                AppLogger.subscription.info("Purchase cancelled by user (ErrorCode)")
                throw SubscriptionError.purchaseCancelled
            }
            AppLogger.subscription.error("Purchase failed: \(error)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        } catch {
            AppLogger.subscription.error("Purchase failed: \(error)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        AppLogger.subscription.info("Restoring purchases")

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            AppLogger.subscription.info("Purchases restored, tier: \(currentTier.displayName)")

            // Sync with server after restore
            await syncWithServer()
        } catch {
            AppLogger.subscription.error("Restore failed: \(error)")
            throw error
        }
    }

    // MARK: - Server Sync

    /// Response from the subscription sync endpoint
    /// Note: AdminAPIClient uses .convertFromSnakeCase, so property names are auto-converted
    private struct SubscriptionSyncResponse: Codable {
        let tier: SubscriptionTier
        let limits: Limits?

        struct Limits: Codable {
            let canCreateProject: Bool
            let currentProjectCount: Int
            // No CodingKeys needed - AdminAPIClient uses .convertFromSnakeCase
        }
    }

    /// Sync subscription status with the server
    private func syncWithServer() async {
        AppLogger.subscription.info("Syncing subscription with server")

        do {
            // Call the server sync endpoint
            let response: SubscriptionSyncResponse = try await AdminAPIClient.shared.post(
                path: "auth/subscription/sync",
                body: ["revenuecat_app_user_id": Purchases.shared.appUserID],
                requiresAuth: true
            )

            // Store the server's tier
            // This is authoritative when RevenueCat doesn't have an active subscription
            serverTier = response.tier
            AppLogger.subscription.info("Subscription synced with server, server tier: \(response.tier.displayName), effective tier: \(effectiveTier.displayName)")
        } catch {
            AppLogger.subscription.error("Failed to sync subscription with server: \(error)")
            // Don't throw - this is a best-effort sync
        }
    }

    // MARK: - Entitlement Checking

    /// Check if the user has access to a specific entitlement
    func hasEntitlement(_ entitlementId: String) -> Bool {
        customerInfo?.entitlements[entitlementId]?.isActive == true
    }

    /// Check if the user has pro access (Pro or Team tier)
    func hasProAccess() -> Bool {
        isProSubscriber
    }

    /// Check if the user has team access
    func hasTeamAccess() -> Bool {
        isTeamSubscriber
    }

    /// Check if the user's tier meets the required tier
    func hasTierAccess(_ requiredTier: SubscriptionTier) -> Bool {
        currentTier.meetsRequirement(requiredTier)
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case purchaseCancelled
    case noProductsAvailable
    case purchaseFailed(String)
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .noProductsAvailable:
            return "No subscription products are available"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .notImplemented:
            return "Subscriptions are not yet available. Coming soon!"
        }
    }
}
