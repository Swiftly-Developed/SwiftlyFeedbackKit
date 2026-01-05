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
    var timePeriod: TimePeriod = .month

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

    enum TimePeriodUnit: String, CaseIterable {
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        case years = "Years"

        var icon: String {
            switch self {
            case .days: return "calendar.day.timeline.left"
            case .weeks: return "calendar"
            case .months: return "calendar.badge.clock"
            case .years: return "calendar.circle"
            }
        }

        func toDays(_ value: Int) -> Int {
            switch self {
            case .days: return value
            case .weeks: return value * 7
            case .months: return value * 30
            case .years: return value * 365
            }
        }
    }

    enum TimePeriod: Equatable, Hashable {
        case week       // 7 days
        case month      // 30 days
        case quarter    // 90 days
        case year       // 365 days
        case custom(value: Int, unit: TimePeriodUnit)

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .custom(let value, let unit): return unit.toDays(value)
            }
        }

        var displayName: String {
            switch self {
            case .week: return "Last 7 Days"
            case .month: return "Last 30 Days"
            case .quarter: return "Last 90 Days"
            case .year: return "Last Year"
            case .custom(let value, let unit):
                return "Last \(value) \(unit.rawValue)"
            }
        }

        var shortName: String {
            switch self {
            case .week: return "7d"
            case .month: return "30d"
            case .quarter: return "90d"
            case .year: return "1y"
            case .custom(let value, let unit):
                switch unit {
                case .days: return "\(value)d"
                case .weeks: return "\(value)w"
                case .months: return "\(value)m"
                case .years: return "\(value)y"
                }
            }
        }

        static var presets: [TimePeriod] {
            [.week, .month, .quarter, .year]
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
        AppLogger.viewModel.info("ViewEventViewModel: loadEvents called for projectId: \(projectId?.uuidString ?? "all"), days: \(timePeriod.days)")

        guard !isLoading else {
            AppLogger.viewModel.warning("ViewEventViewModel: loadEvents skipped - already loading")
            return
        }

        currentProjectId = projectId
        isLoading = true
        AppLogger.viewModel.debug("ViewEventViewModel: Starting to load events...")

        do {
            AppLogger.viewModel.info("ViewEventViewModel: Fetching event stats for \(timePeriod.days) days...")

            let loadedOverview: ViewEventsOverview
            if let projectId = projectId {
                loadedOverview = try await AdminAPIClient.shared.getViewEventStats(projectId: projectId, days: timePeriod.days)
            } else {
                loadedOverview = try await AdminAPIClient.shared.getAllViewEventStats(days: timePeriod.days)
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
