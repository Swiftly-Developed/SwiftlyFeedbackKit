import Testing
@testable import SwiftlyFeedbackAdmin

@Suite("SecureStorageManager Tests")
struct SecureStorageManagerTests {

    @Test("Can store and retrieve string values")
    @MainActor
    func testStringStorage() async {
        let storage = SecureStorageManager.shared
        storage.set("test-value", for: .authToken)
        let retrieved: String? = storage.get(.authToken)
        #expect(retrieved == "test-value")
        storage.remove(.authToken)
    }

    @Test("Can store and retrieve boolean values")
    @MainActor
    func testBoolStorage() async {
        let storage = SecureStorageManager.shared
        storage.set(true, for: .hasCompletedOnboarding)
        let retrieved: Bool? = storage.get(.hasCompletedOnboarding)
        #expect(retrieved == true)
        storage.remove(.hasCompletedOnboarding)
    }

    @Test("Environment scoping isolates data")
    @MainActor
    func testEnvironmentScoping() async {
        let storage = SecureStorageManager.shared

        // Save in production
        storage.setEnvironment(.production)
        storage.set("prod-token", for: .authToken)

        // Save in development
        storage.setEnvironment(.development)
        storage.set("dev-token", for: .authToken)

        // Verify isolation
        storage.setEnvironment(.production)
        #expect(storage.get(.authToken) as String? == "prod-token")

        storage.setEnvironment(.development)
        #expect(storage.get(.authToken) as String? == "dev-token")

        // Cleanup
        storage.clearEnvironment(.production)
        storage.clearEnvironment(.development)
    }

    @Test("Global keys are not environment-scoped")
    @MainActor
    func testGlobalKeys() async {
        let storage = SecureStorageManager.shared

        storage.setEnvironment(.production)
        storage.set("production", for: .selectedEnvironment)

        storage.setEnvironment(.development)
        let value: String? = storage.get(.selectedEnvironment)

        #expect(value == "production")
        storage.remove(.selectedEnvironment)
    }

    @Test("Clear environment only affects that environment")
    @MainActor
    func testClearEnvironment() async {
        let storage = SecureStorageManager.shared

        // Set data in both environments
        storage.setEnvironment(.production)
        storage.set(true, for: .hasCompletedOnboarding)

        storage.setEnvironment(.development)
        storage.set(true, for: .hasCompletedOnboarding)

        // Clear development
        storage.clearEnvironment(.development)

        // Verify production is intact
        storage.setEnvironment(.production)
        #expect(storage.get(.hasCompletedOnboarding) as Bool? == true)

        // Verify development is cleared
        storage.setEnvironment(.development)
        #expect(storage.get(.hasCompletedOnboarding) as Bool? == nil)

        // Cleanup
        storage.clearEnvironment(.production)
    }

    @Test("Remove deletes value")
    @MainActor
    func testRemove() async {
        let storage = SecureStorageManager.shared
        storage.set("to-be-deleted", for: .authToken)
        #expect(storage.exists(.authToken) == true)
        storage.remove(.authToken)
        #expect(storage.exists(.authToken) == false)
    }
}
