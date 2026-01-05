import SwiftUI
import Charts

// MARK: - Events Dashboard View

struct EventsDashboardView: View {
    @Bindable var projectViewModel: ProjectViewModel
    @State private var eventViewModel = ViewEventViewModel()
    @State private var showCustomPeriodSheet = false
    @State private var customPeriodValue: Int = 14
    @State private var customPeriodUnit: ViewEventViewModel.TimePeriodUnit = .days

    /// Uses the shared project filter from ProjectViewModel
    private var selectedProject: ProjectListItem? {
        get { projectViewModel.selectedFilterProject }
        nonmutating set { projectViewModel.selectedFilterProject = newValue }
    }

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    var body: some View {
        dashboardContent
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    projectPicker
                }

                ToolbarItem(placement: .primaryAction) {
                    timePeriodMenu
                }

                ToolbarItem(placement: .primaryAction) {
                    sortMenu
                }
            }
            .searchable(text: $eventViewModel.searchText, prompt: "Search events...")
            .task(id: TaskIdentifier(projectId: selectedProject?.id, timePeriod: eventViewModel.timePeriod)) {
                AppLogger.view.info("EventsDashboardView: .task fired for project: \(selectedProject?.name ?? "All Projects"), period: \(eventViewModel.timePeriod.displayName)")
                // Load events for the current selected project (nil = all projects)
                await eventViewModel.loadEvents(projectId: selectedProject?.id)
            }
            #if os(iOS)
            .refreshable {
                AppLogger.view.info("EventsDashboardView: Pull to refresh triggered")
                await eventViewModel.loadEvents(projectId: selectedProject?.id)
            }
            #endif
            .alert("Error", isPresented: $eventViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(eventViewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showCustomPeriodSheet) {
                customPeriodSheet
            }
            .onAppear {
                AppLogger.view.info("EventsDashboardView: onAppear - selectedProject: \(self.selectedProject?.name ?? "nil"), projects count: \(self.projectViewModel.projects.count)")
            }
    }

    /// Hashable identifier for .task(id:) that includes both project and time period
    private struct TaskIdentifier: Hashable {
        let projectId: UUID?
        let timePeriod: ViewEventViewModel.TimePeriod
    }

    // MARK: - Project Picker

    private var projectPicker: some View {
        Menu {
            Button {
                selectedProject = nil
            } label: {
                HStack {
                    Text("All Projects")
                    if selectedProject == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !projectViewModel.projects.isEmpty {
                Divider()

                ForEach(projectViewModel.projects) { project in
                    Button {
                        selectedProject = project
                    } label: {
                        HStack {
                            Text(project.name)
                            if project.isArchived {
                                Image(systemName: "archivebox")
                            }
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let project = selectedProject {
                    ProjectIconView(
                        name: project.name,
                        isArchived: project.isArchived,
                        colorIndex: project.colorIndex,
                        size: 24
                    )
                    Text(project.name)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                    Text("All Projects")
                        .fontWeight(.medium)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(ViewEventViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    eventViewModel.sortOrder = order
                } label: {
                    HStack {
                        Label(order.rawValue, systemImage: order.icon)
                        if eventViewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Time Period Menu

    private var timePeriodMenu: some View {
        Menu {
            Section("Presets") {
                ForEach(ViewEventViewModel.TimePeriod.presets, id: \.self) { period in
                    Button {
                        eventViewModel.timePeriod = period
                    } label: {
                        HStack {
                            Text(period.displayName)
                            if eventViewModel.timePeriod == period {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                showCustomPeriodSheet = true
            } label: {
                Label("Custom...", systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(eventViewModel.timePeriod.shortName, systemImage: "calendar")
        }
    }

    // MARK: - Custom Period Sheet

    private var customPeriodSheet: some View {
        #if os(macOS)
        macOSCustomPeriodSheet
        #else
        iOSCustomPeriodSheet
        #endif
    }

    #if os(iOS)
    private var iOSCustomPeriodSheet: some View {
        NavigationStack {
            Form {
                // Quick presets for easy selection
                Section {
                    ForEach([7, 14, 30, 60, 90], id: \.self) { days in
                        Button {
                            customPeriodValue = days
                            customPeriodUnit = .days
                        } label: {
                            HStack {
                                Text("Last \(days) days")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if customPeriodUnit == .days && customPeriodValue == days {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Quick Select")
                }

                // Custom input section
                Section {
                    Stepper(value: $customPeriodValue, in: 1...365) {
                        HStack {
                            Text("Last")
                            Text("\(customPeriodValue)")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 30)
                        }
                    }

                    Picker("Unit", selection: $customPeriodUnit) {
                        ForEach(ViewEventViewModel.TimePeriodUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Custom Range")
                } footer: {
                    let totalDays = customPeriodUnit.toDays(customPeriodValue)
                    if totalDays > 365 {
                        Label("Maximum is 365 days. Will be clamped.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Showing data for the last \(totalDays) days")
                    }
                }
            }
            .navigationTitle("Time Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomPeriodSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyCustomPeriod()
                    }
                    .fontWeight(.semibold)
                    .disabled(customPeriodValue < 1)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    #endif

    #if os(macOS)
    private var macOSCustomPeriodSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Time Period")
                    .font(.headline)
                Spacer()
                Button {
                    showCustomPeriodSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Quick presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Select")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach([7, 14, 30, 60, 90], id: \.self) { days in
                            Button {
                                customPeriodValue = days
                                customPeriodUnit = .days
                            } label: {
                                Text("\(days)d")
                                    .frame(minWidth: 40)
                            }
                            .buttonStyle(.bordered)
                            .tint(customPeriodUnit == .days && customPeriodValue == days ? .blue : .secondary)
                        }
                    }
                }

                Divider()

                // Custom input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Range")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Text("Last")
                            .foregroundStyle(.secondary)

                        TextField("", value: $customPeriodValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)

                        Picker("", selection: $customPeriodUnit) {
                            ForEach(ViewEventViewModel.TimePeriodUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .frame(width: 100)

                        Stepper("", value: $customPeriodValue, in: 1...365)
                            .labelsHidden()
                    }

                    // Summary
                    let totalDays = customPeriodUnit.toDays(customPeriodValue)
                    HStack {
                        if totalDays > 365 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Maximum is 365 days")
                                .foregroundStyle(.orange)
                        } else {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            Text("Total: \(totalDays) days")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()

            Divider()

            // Footer buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    showCustomPeriodSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    applyCustomPeriod()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(customPeriodValue < 1)
            }
            .padding()
        }
        .frame(width: 380, height: 340)
    }
    #endif

    private func applyCustomPeriod() {
        if customPeriodUnit.toDays(customPeriodValue) > 365 {
            eventViewModel.timePeriod = .year
        } else {
            eventViewModel.timePeriod = .custom(value: customPeriodValue, unit: customPeriodUnit)
        }
        showCustomPeriodSheet = false
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        if eventViewModel.isLoading && eventViewModel.overview == nil {
            ProgressView("Loading events...")
        } else if eventViewModel.overview == nil || eventViewModel.overview?.totalEvents == 0 {
            emptyEventsView
        } else if eventViewModel.filteredEvents.isEmpty && !eventViewModel.searchText.isEmpty {
            noResultsView
        } else {
            eventsListContent
        }
    }

    // MARK: - Events List Content

    private var eventsListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Section
                if let overview = eventViewModel.overview {
                    EventStatsView(overview: overview)
                }

                // Daily Chart Section
                if let overview = eventViewModel.overview, !overview.dailyStats.isEmpty {
                    DailyEventsChartView(dailyStats: overview.dailyStats, periodLabel: eventViewModel.timePeriod.displayName)
                }

                // Event Breakdown Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Breakdown (\(eventViewModel.filteredEvents.count))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(eventViewModel.filteredEvents, id: \.eventName) { eventStats in
                            EventStatsRowView(eventStats: eventStats)
                            if eventStats.eventName != eventViewModel.filteredEvents.last?.eventName {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }

                // Recent Events Section
                if let overview = eventViewModel.overview, !overview.recentEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Events")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(overview.recentEvents) { event in
                                RecentEventRowView(event: event)
                                if event.id != overview.recentEvents.last?.id {
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                }
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 800, alignment: .center)
            #endif
        }
        #if os(macOS)
        .frame(maxWidth: .infinity)
        #endif
        .background(groupedBackgroundColor)
    }

    // MARK: - Empty States

    private var emptyEventsView: some View {
        ContentUnavailableView {
            Label("No Events", systemImage: "chart.bar.xaxis")
        } description: {
            Text("No events have been tracked for this project yet.")
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No events match your search.")
        } actions: {
            Button("Clear Search") {
                eventViewModel.searchText = ""
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Event Stats View

struct EventStatsView: View {
    let overview: ViewEventsOverview

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(minimum: 140, maximum: 180)),
        GridItem(.flexible(minimum: 140, maximum: 180)),
        GridItem(.flexible(minimum: 140, maximum: 180))
    ]
    #else
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: 180)),
        GridItem(.flexible(minimum: 100, maximum: 180))
    ]
    #endif

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            EventStatCard(
                icon: "chart.bar.fill",
                iconColor: .blue,
                title: "Total Events",
                value: "\(overview.totalEvents)"
            )

            EventStatCard(
                icon: "person.2.fill",
                iconColor: .green,
                title: "Unique Users",
                value: "\(overview.uniqueUsers)"
            )

            EventStatCard(
                icon: "list.bullet",
                iconColor: .purple,
                title: "Event Types",
                value: "\(overview.eventBreakdown.count)"
            )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Event Stat Card

struct EventStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Event Stats Row View

struct EventStatsRowView: View {
    let eventStats: ViewEventStats

    private var eventIcon: String {
        switch eventStats.eventName {
        case "feedback_list": return "list.bullet.rectangle"
        case "feedback_detail": return "doc.text"
        case "submit_feedback": return "square.and.pencil"
        default: return "chart.bar"
        }
    }

    private var eventColor: Color {
        switch eventStats.eventName {
        case "feedback_list": return .blue
        case "feedback_detail": return .purple
        case "submit_feedback": return .green
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Event Icon
            Image(systemName: eventIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(eventColor, in: RoundedRectangle(cornerRadius: 8))

            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                Text(eventStats.eventName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(eventStats.totalCount)", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(eventStats.uniqueUsers)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Count Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(eventStats.totalCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Event Row View

struct RecentEventRowView: View {
    let event: ViewEvent

    private var eventIcon: String {
        switch event.eventName {
        case "feedback_list": return "list.bullet.rectangle"
        case "feedback_detail": return "doc.text"
        case "submit_feedback": return "square.and.pencil"
        default: return "chart.bar"
        }
    }

    private var eventColor: Color {
        switch event.eventName {
        case "feedback_list": return .blue
        case "feedback_detail": return .purple
        case "submit_feedback": return .green
        default: return .orange
        }
    }

    private var userTypeColor: Color {
        switch event.userType {
        case .iCloud: return .blue
        case .local: return .gray
        case .custom: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Event Icon
            Image(systemName: eventIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(eventColor, in: RoundedRectangle(cornerRadius: 8))

            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.eventName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let properties = event.properties, !properties.isEmpty {
                        Text("(\(properties.count) props)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: event.userType.icon)
                        .font(.caption2)
                        .foregroundStyle(userTypeColor)

                    Text(event.displayUserId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timestamp
            if let createdAt = event.createdAt {
                Text(createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Daily Events Chart View

struct DailyEventsChartView: View {
    let dailyStats: [DailyEventStats]
    var periodLabel: String = "Last 30 Days"
    @State private var selectedDay: DailyEventStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events Over Time")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 8) {
                Chart(dailyStats) { day in
                    BarMark(
                        x: .value("Date", day.parsedDate ?? Date()),
                        y: .value("Events", day.totalCount)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)

                // Summary stats
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(dailyStats.reduce(0) { $0 + $1.totalCount })")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Avg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let avg = dailyStats.isEmpty ? 0 : dailyStats.reduce(0) { $0 + $1.totalCount } / dailyStats.count
                        Text("\(avg)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peak Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let peak = dailyStats.max(by: { $0.totalCount < $1.totalCount }) {
                            Text("\(peak.totalCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else {
                            Text("-")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Preview

#Preview("Events Dashboard") {
    NavigationStack {
        EventsDashboardView(projectViewModel: ProjectViewModel())
    }
}
