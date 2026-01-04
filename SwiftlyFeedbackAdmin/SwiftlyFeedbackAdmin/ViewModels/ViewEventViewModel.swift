import Foundation
import SwiftUI

@MainActor
@Observable
final class ViewEventViewModel {
    var overview: ViewEventsOverview?
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var searchText = ""
    var sortOrder: SortOrder = .totalCount

    enum SortOrder: String, CaseIterable {
        case totalCount = "Total Count"
        case uniqueUsers = "Unique Users"
        case eventName = "Event Name"

        var icon: String {
            switch self {
            case .totalCount: return "number"
            case .uniqueUsers: return "person.2"
            case .eventName: return "textformat"
            }
        }
    }

    private var currentProjectId: UUID?

    var filteredEvents: [ViewEventStats] {
        guard let overview = overview else { return [] }
        var result = overview.eventBreakdown

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { event in
                event.eventName.localizedCaseInsensitiveContains(searchText)
            }
            AppLogger.viewModel.debug("ViewEventViewModel: Filtered to \(result.count) events with search '\(self.searchText)'")
        }

        // Apply sort
        switch sortOrder {
        case .totalCount:
            result.sort { $0.totalCount > $1.totalCount }
        case .uniqueUsers:
            result.sort { $0.uniqueUsers > $1.uniqueUsers }
        case .eventName:
            result.sort { $0.eventName < $1.eventName }
        }

        return result
    }

    func loadEvents(projectId: UUID? = nil) async {
        AppLogger.viewModel.info("ViewEventViewModel: loadEvents called for projectId: \(projectId?.uuidString ?? "all")")

        guard !isLoading else {
            AppLogger.viewModel.warning("ViewEventViewModel: loadEvents skipped - already loading")
            return
        }

        currentProjectId = projectId
        isLoading = true
        AppLogger.viewModel.debug("ViewEventViewModel: Starting to load events...")

        do {
            AppLogger.viewModel.info("ViewEventViewModel: Fetching event stats...")

            let loadedOverview: ViewEventsOverview
            if let projectId = projectId {
                loadedOverview = try await AdminAPIClient.shared.getViewEventStats(projectId: projectId)
            } else {
                loadedOverview = try await AdminAPIClient.shared.getAllViewEventStats()
            }

            AppLogger.viewModel.info("ViewEventViewModel: Successfully loaded overview - totalEvents: \(loadedOverview.totalEvents), uniqueUsers: \(loadedOverview.uniqueUsers)")
            AppLogger.viewModel.info("ViewEventViewModel: Event breakdown count: \(loadedOverview.eventBreakdown.count)")

            overview = loadedOverview

            // Log first few events for debugging
            for (index, event) in loadedOverview.eventBreakdown.prefix(3).enumerated() {
                AppLogger.viewModel.debug("ViewEventViewModel: Event[\(index)] - name: \(event.eventName), count: \(event.totalCount), users: \(event.uniqueUsers)")
            }

        } catch let error as APIError {
            AppLogger.viewModel.error("ViewEventViewModel: APIError - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            AppLogger.viewModel.error("ViewEventViewModel: Unknown error - \(error.localizedDescription)")
            AppLogger.viewModel.error("ViewEventViewModel: Error type: \(type(of: error))")
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
        AppLogger.viewModel.debug("ViewEventViewModel: loadEvents completed, isLoading = false")
    }

    func refreshEvents() async {
        AppLogger.viewModel.info("ViewEventViewModel: refreshEvents called")
        await loadEvents(projectId: currentProjectId)
    }
}
