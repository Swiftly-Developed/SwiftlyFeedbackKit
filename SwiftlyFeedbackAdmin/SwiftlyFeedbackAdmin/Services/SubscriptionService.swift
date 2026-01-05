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
        self == .team
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

/// Service responsible for managing subscriptions via RevenueCat
@MainActor
@Observable
final class SubscriptionService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SubscriptionService()

    // MARK: - Configuration

    /// RevenueCat API key - Test key for development
    private static let apiKey = "test_CaMVmhckOrEFFnqAueegthNaqSm"

    /// Entitlement identifiers
    static let proEntitlementID = "Swiftly Pro"
    static let teamEntitlementID = "Swiftly Team"

    /// Product identifiers
    enum ProductID: String, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        case monthlyTeam = "monthlyTeam"
        case yearlyTeam = "yearlyTeam"
    }

    // MARK: - Published State

    /// Current customer info from RevenueCat
    private(set) var customerInfo: CustomerInfo?

    /// Current offering containing available packages
    private(set) var currentOffering: Offering?

    /// Whether the service is currently loading data
    private(set) var isLoading = false

    /// Error message if an operation failed
    private(set) var errorMessage: String?

    /// Whether an error should be shown
    var showError = false

    // MARK: - Computed Properties - Tier

    /// The user's current subscription tier
    var currentTier: SubscriptionTier {
        if isTeamSubscriber {
            return .team
        } else if isProSubscriber {
            return .pro
        }
        return .free
    }

    /// Whether the user has an active Team subscription
    var isTeamSubscriber: Bool {
        customerInfo?.entitlements[Self.teamEntitlementID]?.isActive == true
    }

    /// Whether the user has an active Pro subscription (or higher)
    var isProSubscriber: Bool {
        customerInfo?.entitlements[Self.proEntitlementID]?.isActive == true || isTeamSubscriber
    }

    /// Whether the user has any paid subscription
    var isPaidSubscriber: Bool {
        isProSubscriber || isTeamSubscriber
    }

    /// The active entitlement info (Team takes priority over Pro)
    var activeEntitlement: EntitlementInfo? {
        customerInfo?.entitlements[Self.teamEntitlementID] ?? customerInfo?.entitlements[Self.proEntitlementID]
    }

    /// The expiration date of the active subscription
    var subscriptionExpirationDate: Date? {
        activeEntitlement?.expirationDate
    }

    /// Whether the subscription will renew
    var willRenew: Bool {
        activeEntitlement?.willRenew ?? false
    }

    /// The product identifier of the active subscription
    var activeProductIdentifier: String? {
        activeEntitlement?.productIdentifier
    }

    /// Display name for the current subscription status
    var subscriptionStatusText: String {
        switch currentTier {
        case .free:
            return "Free"
        case .pro:
            if let productId = activeProductIdentifier {
                if productId.contains("yearly") || productId == ProductID.yearly.rawValue {
                    return "Pro (Yearly)"
                }
            }
            return "Pro (Monthly)"
        case .team:
            if let productId = activeProductIdentifier {
                if productId.contains("yearly") || productId == ProductID.yearlyTeam.rawValue {
                    return "Team (Yearly)"
                }
            }
            return "Team (Monthly)"
        }
    }

    // MARK: - Computed Properties - Packages

    /// Monthly Pro package from current offering
    var monthlyPackage: Package? {
        currentOffering?.monthly ?? currentOffering?.package(identifier: ProductID.monthly.rawValue)
    }

    /// Yearly Pro package from current offering
    var yearlyPackage: Package? {
        currentOffering?.annual ?? currentOffering?.package(identifier: ProductID.yearly.rawValue)
    }

    /// Monthly Team package from current offering
    var monthlyTeamPackage: Package? {
        currentOffering?.package(identifier: ProductID.monthlyTeam.rawValue)
    }

    /// Yearly Team package from current offering
    var yearlyTeamPackage: Package? {
        currentOffering?.package(identifier: ProductID.yearlyTeam.rawValue)
    }

    /// All available packages
    var availablePackages: [Package] {
        currentOffering?.availablePackages ?? []
    }

    /// Pro tier packages only
    var proPackages: [Package] {
        [monthlyPackage, yearlyPackage].compactMap { $0 }
    }

    /// Team tier packages only
    var teamPackages: [Package] {
        [monthlyTeamPackage, yearlyTeamPackage].compactMap { $0 }
    }

    // MARK: - Initialization

    private init() {
        AppLogger.subscription.info("SubscriptionService initialized")
    }

    // MARK: - Configuration

    /// Configure RevenueCat SDK. Call this once at app launch.
    /// - Parameter userId: Optional user ID to identify the user. Pass nil for anonymous users.
    func configure(userId: UUID? = nil) {
        AppLogger.subscription.info("🔧 Configuring RevenueCat SDK...")

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        if let userId = userId {
            Purchases.configure(withAPIKey: Self.apiKey, appUserID: userId.uuidString)
            AppLogger.subscription.info("✅ RevenueCat configured with user ID: \(userId.uuidString)")
        } else {
            Purchases.configure(withAPIKey: Self.apiKey)
            AppLogger.subscription.info("✅ RevenueCat configured with anonymous user")
        }

        // Set delegate to receive customer info updates
        Purchases.shared.delegate = self

        // Fetch initial data
        Task {
            await loadInitialData()
        }
    }

    /// Login to RevenueCat with a user ID (call after user authentication)
    /// - Parameter userId: The user's UUID
    func login(userId: UUID) async {
        AppLogger.subscription.info("🔐 Logging in to RevenueCat with user ID: \(userId.uuidString)")

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId.uuidString)
            self.customerInfo = customerInfo
            AppLogger.subscription.info("✅ RevenueCat login successful - Pro: \(self.isProSubscriber)")
        } catch {
            AppLogger.subscription.error("❌ RevenueCat login failed: \(error.localizedDescription)")
            showError(message: "Failed to sync subscription status")
        }
    }

    /// Logout from RevenueCat (call after user logout)
    func logout() async {
        AppLogger.subscription.info("🚪 Logging out from RevenueCat")

        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            AppLogger.subscription.info("✅ RevenueCat logout successful")
        } catch {
            AppLogger.subscription.error("❌ RevenueCat logout failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Data Loading

    /// Load initial subscription data (customer info and offerings)
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCustomerInfo() }
            group.addTask { await self.fetchOfferings() }
        }
    }

    /// Fetch the current customer info
    func fetchCustomerInfo() async {
        AppLogger.subscription.info("📊 Fetching customer info...")

        do {
            customerInfo = try await Purchases.shared.customerInfo()
            AppLogger.subscription.info("✅ Customer info fetched - Pro: \(self.isProSubscriber)")
        } catch {
            AppLogger.subscription.error("❌ Failed to fetch customer info: \(error.localizedDescription)")
        }
    }

    /// Fetch available offerings
    func fetchOfferings() async {
        AppLogger.subscription.info("📦 Fetching offerings...")
        isLoading = true

        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current

            if let offering = currentOffering {
                AppLogger.subscription.info("✅ Offerings fetched - \(offering.availablePackages.count) packages available")
                for package in offering.availablePackages {
                    AppLogger.subscription.debug("  📦 \(package.identifier): \(package.localizedPriceString)")
                }
            } else {
                AppLogger.subscription.warning("⚠️ No current offering available")
            }
        } catch {
            AppLogger.subscription.error("❌ Failed to fetch offerings: \(error.localizedDescription)")
            showError(message: "Failed to load subscription options")
        }

        isLoading = false
    }

    // MARK: - Purchase Operations

    /// Purchase a package
    /// - Parameter package: The package to purchase
    /// - Returns: The updated customer info after purchase
    @discardableResult
    func purchase(package: Package) async throws -> CustomerInfo {
        AppLogger.subscription.info("💳 Purchasing package: \(package.identifier)")
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo

            if result.userCancelled {
                AppLogger.subscription.info("⚠️ Purchase cancelled by user")
                throw SubscriptionError.purchaseCancelled
            }

            AppLogger.subscription.info("✅ Purchase successful - Pro: \(self.isProSubscriber)")
            return result.customerInfo
        } catch let error as SubscriptionError {
            throw error
        } catch {
            AppLogger.subscription.error("❌ Purchase failed: \(error.localizedDescription)")
            showError(message: "Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Restore previous purchases
    /// - Returns: The updated customer info after restoration
    @discardableResult
    func restorePurchases() async throws -> CustomerInfo {
        AppLogger.subscription.info("🔄 Restoring purchases...")
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            AppLogger.subscription.info("✅ Purchases restored - Pro: \(self.isProSubscriber)")
            return customerInfo!
        } catch {
            AppLogger.subscription.error("❌ Restore failed: \(error.localizedDescription)")
            showError(message: "Failed to restore purchases: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Entitlement Checking

    /// Check if the user has access to a specific entitlement
    /// - Parameter entitlementId: The entitlement identifier to check
    /// - Returns: Whether the user has an active entitlement
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

// MARK: - PurchasesDelegate

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            AppLogger.subscription.info("📬 Received customer info update - Tier: \(self.currentTier.displayName)")
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case purchaseCancelled
    case noProductsAvailable
    case purchaseFailed(String)

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .noProductsAvailable:
            return "No subscription products are available"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        }
    }
}
