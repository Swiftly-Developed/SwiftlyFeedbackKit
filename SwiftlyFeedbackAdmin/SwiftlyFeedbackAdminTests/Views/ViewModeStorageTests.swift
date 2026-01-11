import Testing
@testable import SwiftlyFeedbackAdmin

@Suite("View Mode Storage Tests")
struct ViewModeStorageTests {

    @Test("Feedback view mode is environment-scoped")
    @MainActor
    func testFeedbackViewModeScoping() async {
        let storage = SecureStorageManager.shared

        // Set in production
        storage.setEnvironment(.production)
        storage.set("kanban", for: .feedbackViewMode)

        // Set in development
        storage.setEnvironment(.development)
        storage.set("list", for: .feedbackViewMode)

        // Verify isolation
        storage.setEnvironment(.production)
        #expect(storage.get(.feedbackViewMode) as String? == "kanban")

        storage.setEnvironment(.development)
        #expect(storage.get(.feedbackViewMode) as String? == "list")

        // Cleanup
        storage.remove(.feedbackViewMode)
        storage.setEnvironment(.production)
        storage.remove(.feedbackViewMode)
    }

    @Test("Dashboard view mode persists")
    @MainActor
    func testDashboardViewModePersistence() async {
        let storage = SecureStorageManager.shared

        storage.set("kanban", for: .dashboardViewMode)
        let retrieved: String? = storage.get(.dashboardViewMode)

        #expect(retrieved == "kanban")

        storage.remove(.dashboardViewMode)
    }

    @Test("Project view mode defaults correctly")
    @MainActor
    func testProjectViewModeDefault() async {
        let storage = SecureStorageManager.shared

        // Remove any existing value
        storage.remove(.projectViewMode)

        // Should return nil (no default in storage)
        let retrieved: String? = storage.get(.projectViewMode)
        #expect(retrieved == nil)

        // View should use its own default ("list")
    }

    @Test("All view mode keys are environment-scoped")
    @MainActor
    func testViewModeKeysAreEnvironmentScoped() async {
        #expect(StorageKey.feedbackViewMode.isEnvironmentScoped == true)
        #expect(StorageKey.dashboardViewMode.isEnvironmentScoped == true)
        #expect(StorageKey.projectViewMode.isEnvironmentScoped == true)
    }

    @Test("View mode values survive environment switch")
    @MainActor
    func testViewModesSurviveEnvironmentSwitch() async {
        let storage = SecureStorageManager.shared

        // Set view modes in production
        storage.setEnvironment(.production)
        storage.set("list", for: .feedbackViewMode)
        storage.set("kanban", for: .dashboardViewMode)
        storage.set("grid", for: .projectViewMode)

        // Switch to development and set different values
        storage.setEnvironment(.development)
        storage.set("kanban", for: .feedbackViewMode)
        storage.set("list", for: .dashboardViewMode)
        storage.set("list", for: .projectViewMode)

        // Switch back to production and verify original values
        storage.setEnvironment(.production)
        #expect(storage.get(.feedbackViewMode) as String? == "list")
        #expect(storage.get(.dashboardViewMode) as String? == "kanban")
        #expect(storage.get(.projectViewMode) as String? == "grid")

        // Verify development values
        storage.setEnvironment(.development)
        #expect(storage.get(.feedbackViewMode) as String? == "kanban")
        #expect(storage.get(.dashboardViewMode) as String? == "list")
        #expect(storage.get(.projectViewMode) as String? == "list")

        // Cleanup
        storage.remove(.feedbackViewMode)
        storage.remove(.dashboardViewMode)
        storage.remove(.projectViewMode)
        storage.setEnvironment(.production)
        storage.remove(.feedbackViewMode)
        storage.remove(.dashboardViewMode)
        storage.remove(.projectViewMode)
    }
}
