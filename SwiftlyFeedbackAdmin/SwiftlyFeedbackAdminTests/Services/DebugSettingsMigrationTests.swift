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

    @Test("Environment override flag persists to SecureStorageManager")
    @MainActor
    func testEnvironmentOverrideFlagPersistence() async {
        let subscription = SubscriptionService.shared
        let storage = SecureStorageManager.shared

        // Enable
        subscription.disableEnvironmentOverrideForTesting = true

        // Verify stored
        let stored: Bool? = storage.get(.disableEnvironmentOverride)
        #expect(stored == true)

        // Disable
        subscription.disableEnvironmentOverrideForTesting = false

        // Verify updated
        let updated: Bool? = storage.get(.disableEnvironmentOverride)
        #expect(updated == false)
    }

    @Test("TestFlight simulation persists to SecureStorageManager")
    @MainActor
    func testTestFlightSimulationPersistence() async {
        let storage = SecureStorageManager.shared

        // Enable
        BuildEnvironment.simulateTestFlight = true

        // Force storage update by waiting for Task
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify storage
        let stored: Bool? = storage.get(.simulateTestFlight)
        #expect(stored == true)

        // Verify cached value
        #expect(BuildEnvironment.simulateTestFlight == true)

        // Disable
        BuildEnvironment.simulateTestFlight = false

        // Force storage update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify cleared
        let afterDisable: Bool? = storage.get(.simulateTestFlight)
        #expect(afterDisable == false)
        #expect(BuildEnvironment.simulateTestFlight == false)
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

        // Set all debug settings
        storage.set("pro", for: .simulatedSubscriptionTier)
        storage.set(true, for: .disableEnvironmentOverride)
        storage.set(true, for: .simulateTestFlight)

        // Verify they exist
        #expect(storage.exists(.simulatedSubscriptionTier))
        #expect(storage.exists(.disableEnvironmentOverride))
        #expect(storage.exists(.simulateTestFlight))

        // Clear debug settings
        storage.clearDebugSettings()

        // Verify all removed
        #expect(!storage.exists(.simulatedSubscriptionTier))
        #expect(!storage.exists(.disableEnvironmentOverride))
        #expect(!storage.exists(.simulateTestFlight))
    }

    @Test("Debug settings initialization loads from storage")
    @MainActor
    func testInitializeDebugSettings() async {
        let storage = SecureStorageManager.shared

        // Set value in storage
        storage.set(true, for: .simulateTestFlight)

        // Initialize (this would normally be called at app launch)
        BuildEnvironment.initializeDebugSettings()

        // Verify cached value was updated
        #expect(BuildEnvironment.simulateTestFlight == true)

        // Cleanup
        BuildEnvironment.simulateTestFlight = false
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
}
#endif
