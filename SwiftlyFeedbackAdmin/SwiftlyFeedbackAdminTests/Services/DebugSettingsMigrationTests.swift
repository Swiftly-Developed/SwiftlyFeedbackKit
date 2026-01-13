import Testing
@testable import SwiftlyFeedbackAdmin

#if DEBUG
@Suite("Debug Settings Migration Tests")
struct DebugSettingsMigrationTests {

    @Test("Simulated tier persists to SecureStorageManager")
    @MainActor
    func testSimulatedTierPersistence() async {
        let subscription = SubscriptionService.shared
        let storage = SecureStorageManager.shared

        // Set simulated tier
        subscription.simulatedTier = .pro

        // Verify persisted
        let retrieved: String? = storage.get(.simulatedSubscriptionTier)
        #expect(retrieved == "pro")

        // Clear
        subscription.clearSimulatedTier()
        #expect(subscription.simulatedTier == nil)

        // Verify removed from storage
        let afterClear: String? = storage.get(.simulatedSubscriptionTier)
        #expect(afterClear == nil)
    }

    @Test("Debug settings use debug scope")
    @MainActor
    func testDebugScope() async {
        let storage = SecureStorageManager.shared

        // Set a debug setting
        storage.set("team", for: .simulatedSubscriptionTier)

        // Verify it uses debug scope (not environment)
        let keys = storage.listAllKeys()
        #expect(keys.contains("debug.simulatedSubscriptionTier"))

        // Should NOT have environment-scoped key
        #expect(!keys.contains("production.simulatedSubscriptionTier"))
        #expect(!keys.contains("development.simulatedSubscriptionTier"))

        // Cleanup
        storage.remove(.simulatedSubscriptionTier)
    }

    @Test("Clear debug settings removes all debug keys")
    @MainActor
    func testClearDebugSettings() async {
        let storage = SecureStorageManager.shared

        // Set debug setting
        storage.set("pro", for: .simulatedSubscriptionTier)

        // Verify it exists
        #expect(storage.exists(.simulatedSubscriptionTier))

        // Clear debug settings
        storage.clearDebugSettings()

        // Verify removed
        #expect(!storage.exists(.simulatedSubscriptionTier))
    }
}
#endif
