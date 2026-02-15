import SwiftUI

/// Full metrics dashboard view showing all available metrics
struct InsightsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedMetric: MetricType?
    @State private var selectedDate: Date = Date()
    @State private var showHRRecoveryMeasurement = false
    @State private var showExtendedMeasurement = false
    @State private var pendingAction: MetricAction?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Date Picker
                    DateNavigationHeader(
                        selectedDate: $selectedDate,
                        hasDataForDate: viewModel.hasDataForDate,
                        availableDates: viewModel.availableDates
                    )
                    .padding(.horizontal)

                    // Quick Summary Header
                    if let readiness = viewModel.readinessMetrics {
                        QuickSummaryHeader(readiness: readiness)
                    }

                    // Metrics Grid Header with Data Source
                    HStack {
                        PremiumSectionHeader(
                            title: "Metrics for \(formattedDate)",
                            icon: "chart.bar.doc.horizontal.fill",
                            iconColor: AppTheme.Colors.info
                        )

                        Spacer()

                        if !viewModel.dataSource.isEmpty {
                            Text(viewModel.dataSource)
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.selectedDataPoint != nil {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppTheme.Spacing.md) {
                            ForEach(MetricType.allCases) { type in
                                MetricGridCard(
                                    type: type,
                                    value: viewModel.value(for: type),
                                    baseline: viewModel.baseline(for: type)
                                )
                                .onTapGesture {
                                    selectedMetric = type
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        NoDataForDateView()
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Insights")
            .onAppear {
                viewModel.loadAllData(from: coordinator)
                viewModel.selectDate(selectedDate)
            }
            .onChange(of: selectedDate) { newDate in
                viewModel.selectDate(newDate)
            }
            .refreshable {
                viewModel.loadAllData(from: coordinator)
                viewModel.selectDate(selectedDate)
            }
            .sheet(item: $selectedMetric) { type in
                MetricDetailView(
                    type: type,
                    value: viewModel.value(for: type),
                    baseline: viewModel.baseline(for: type),
                    onActionTapped: { action in
                        handleMetricAction(action)
                    }
                )
            }
            .sheet(isPresented: $showHRRecoveryMeasurement) {
                HRRecoveryMeasurementView { hrRecovery in
                    // Save the HR Recovery measurement
                    saveHRRecovery(hrRecovery)
                }
            }
            .sheet(isPresented: $showExtendedMeasurement) {
                ExtendedHRVMeasurementView { metrics in
                    // Metrics will be saved automatically
                    viewModel.loadAllData(from: coordinator)
                    viewModel.selectDate(selectedDate)
                }
            }
        }
    }

    private func handleMetricAction(_ action: MetricAction) {
        switch action {
        case .takeSnapshot, .takeMorningReadiness:
            // Switch to Monitor tab
            coordinator.selectedTab = .monitor
        case .takeExtendedMeasurement:
            showExtendedMeasurement = true
        case .measureHRRecovery:
            showHRRecoveryMeasurement = true
        case .startSleepTracking:
            // Switch to Monitor tab and start sleep tracking
            coordinator.selectedTab = .monitor
        }
    }

    private func saveHRRecovery(_ hrRecovery: Double) {
        // Save HR Recovery to today's data point
        // This will be persisted through the HR Recovery repository
        viewModel.loadAllData(from: coordinator)
        viewModel.selectDate(selectedDate)
    }

    private var formattedDate: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }
}

// MARK: - Date Navigation Header

struct DateNavigationHeader: View {
    @Binding var selectedDate: Date
    let hasDataForDate: (Date) -> Bool
    let availableDates: Set<Date>

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Previous day button
            Button {
                if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                    selectedDate = newDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Date display with picker
            DatePicker(
                "",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            // Next day button
            Button {
                if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate),
                   newDate <= Date() {
                    selectedDate = newDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoForward ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            }
            .disabled(!canGoForward)

            // Today button
            if !calendar.isDateInToday(selectedDate) {
                Button {
                    selectedDate = Date()
                } label: {
                    Text("Today")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var canGoForward: Bool {
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) else {
            return false
        }
        return nextDate <= Date()
    }
}

// MARK: - No Data View

struct NoDataForDateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)

            Text("No Data for This Day")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("Complete a sleep session or take measurements to see your metrics.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Quick Summary Header

struct QuickSummaryHeader: View {
    let readiness: ReadinessEngine.ReadinessMetrics

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            CircularProgressRing(
                progress: Double(readiness.readinessScore) / 100.0,
                gradient: AppTheme.Gradients.scoreGradient(for: readiness.readinessScore),
                lineWidth: 10,
                size: 100,
                showPercentage: false
            )
            .overlay(
                VStack(spacing: 0) {
                    Text("\(readiness.readinessScore)")
                        .font(AppTheme.Typography.metricMedium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Ready")
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text(readiness.interpretation.emoji)
                    Text(readiness.interpretation.rawValue)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }

                Text(readiness.recommendation)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .premiumCard()
        .padding(.horizontal)
    }
}

// MARK: - Metric Grid Card

struct MetricGridCard: View {
    let type: MetricType
    let value: Double?
    let baseline: Double?

    private var definition: MetricDefinition {
        MetricRegistry.definition(for: type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: definition.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorForValue)

                Spacer()

                if value != nil {
                    Circle()
                        .fill(colorForValue)
                        .frame(width: 8, height: 8)
                }
            }

            Text(definition.label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)

            if let value = value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedValue(value))
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if !definition.unit.isEmpty {
                        Text(definition.unit)
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            } else {
                Text("--")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(colorForValue.opacity(0.2), lineWidth: 1)
        )
    }

    private var colorForValue: Color {
        guard let value = value else { return .gray }
        return definition.colorLogic(value, baseline).color
    }

    private func formattedValue(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Insights ViewModel

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var readinessMetrics: ReadinessEngine.ReadinessMetrics?
    @Published var selectedDataPoint: DailyHRVDataPoint?
    @Published var selectedSummary: DailyHRVSummary?
    @Published var baseline7d: Double?
    @Published var biologicalAge: ReadinessEngine.BiologicalAgeResult?
    @Published var illnessFlag: HealthDetectionEngine.IllnessFlag?
    @Published var dataSource: String = ""

    // Repositories
    private let snapshotRepository = HRVSnapshotRepository()
    private let continuousRepository = ContinuousHRVDataRepository()
    private let sessionRepository = SleepSessionRepository()

    private var allDataPoints: [DailyHRVDataPoint] = []
    private var allSummaries: [DailyHRVSummary] = []
    private let calendar = Calendar.current

    /// All dates that have data available
    var availableDates: Set<Date> {
        Set(allDataPoints.map { calendar.startOfDay(for: $0.date) })
    }

    /// Check if a specific date has data
    func hasDataForDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return allDataPoints.contains { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Load all data from all sources
    func loadAllData(from coordinator: AppCoordinator) {
        allSummaries = coordinator.summaryRepository.loadAll()
        baseline7d = BaselineEngine.calculate7DayBaseline(from: allSummaries)

        // Load daily data points from all sources (last 365 days)
        loadAllDataPoints()
    }

    private func loadAllDataPoints() {
        var dataPoints: [DailyHRVDataPoint] = []
        let sleepSessions = (try? sessionRepository.loadAll()) ?? []

        // Get last 365 days
        for dayOffset in (0..<365).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            // Get snapshots for this day
            let snapshots = snapshotRepository.loadForDate(date)
            let morningReadiness = snapshots.first { $0.measurementMode == .morningReadiness }

            // Get sleep session that ended on this day
            let sleepSession = sleepSessions.first { session in
                guard let endTime = session.endTime else { return false }
                return endTime >= startOfDay && endTime < endOfDay
            }

            var dataPoint: DailyHRVDataPoint?

            // Priority 1: Sleep session + optional morning readiness
            if let session = sleepSession {
                let summary = SleepSummaryCalculator.calculate(from: session)
                dataPoint = DailyHRVDataPoint.fromSleepSession(
                    session,
                    summary: summary,
                    morningReadiness: morningReadiness
                )
            }
            // Priority 2: Morning readiness alone
            else if let morning = morningReadiness {
                dataPoint = DailyHRVDataPoint.fromMorningReadiness(morning)
            }
            // Priority 3: Continuous monitoring data
            else {
                let continuousData = continuousRepository.loadForDate(date)
                if !continuousData.isEmpty {
                    dataPoint = DailyHRVDataPoint.fromContinuousData(continuousData)
                }
            }
            // Priority 4: Quick snapshots
            if dataPoint == nil {
                let quickSnapshots = snapshots.filter { $0.measurementMode == .snapshot }
                if !quickSnapshots.isEmpty {
                    dataPoint = DailyHRVDataPoint.fromSnapshots(quickSnapshots)
                }
            }

            // If no data point yet, try to create from extended metrics
            if dataPoint == nil {
                let extendedRepo = ExtendedHRVMetricsRepository()
                if let extendedMetrics = extendedRepo.load(for: date) {
                    var point = DailyHRVDataPoint(
                        date: extendedMetrics.timestamp,
                        rmssd: extendedMetrics.time.rmssd,
                        sdnn: extendedMetrics.time.sdnn,
                        averageHR: 60, // Default, will be overwritten if available
                        source: .snapshot,
                        hasMorningReadiness: false,
                        hasSleepData: false
                    )
                    // Set all time domain metrics
                    point.pnn50 = extendedMetrics.time.pnn50
                    point.lfHfRatio = extendedMetrics.freq?.lfHfRatio
                    point.dfaAlpha1 = extendedMetrics.dfaAlpha1
                    dataPoint = point
                }
            }

            if var point = dataPoint {
                // Enrich with extended HRV metrics (LF/HF, DFA Alpha1, pNN50, SDNN)
                let extendedRepo = ExtendedHRVMetricsRepository()
                if let extendedMetrics = extendedRepo.load(for: date) {
                    // Always update frequency domain metrics
                    point.lfHfRatio = extendedMetrics.freq?.lfHfRatio
                    point.dfaAlpha1 = extendedMetrics.dfaAlpha1

                    // Update time domain metrics if not already set
                    if point.sdnn == nil {
                        point.sdnn = extendedMetrics.time.sdnn
                    }
                    if point.pnn50 == nil {
                        point.pnn50 = extendedMetrics.time.pnn50
                    }
                }

                // Enrich with HR Recovery
                let hrRecoveryRepo = HRRecoveryRepository()
                if let hrRecovery = hrRecoveryRepo.loadForDate(date) {
                    point.hrRecovery = hrRecovery.hrRecovery
                }

                dataPoints.append(point)
            }
        }

        // Sort by date and enrich with baselines
        dataPoints.sort { $0.date < $1.date }

        var enrichedPoints: [DailyHRVDataPoint] = []
        for (index, point) in dataPoints.enumerated() {
            let historical = Array(dataPoints.prefix(index))
            let enriched = point.withBaselines(from: historical)
            enrichedPoints.append(enriched)
        }

        allDataPoints = enrichedPoints
    }

    /// Select and load metrics for a specific date
    func selectDate(_ date: Date) {
        let startOfDay = calendar.startOfDay(for: date)

        // Find data point for selected date
        selectedDataPoint = allDataPoints.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }

        // Also find summary if available (for sleep-specific metrics)
        selectedSummary = allSummaries.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }

        guard let dataPoint = selectedDataPoint else {
            readinessMetrics = nil
            biologicalAge = nil
            illnessFlag = nil
            dataSource = ""
            return
        }

        dataSource = dataPoint.source.rawValue

        // Create a temporary summary for intelligence engines
        let tempSummary = DailyHRVSummary(
            date: dataPoint.date,
            meanHR: dataPoint.averageHR,
            minHR: dataPoint.averageHR - 10,
            maxHR: dataPoint.averageHR + 20,
            rmssd: dataPoint.rmssd,
            sdnn: dataPoint.sdnn ?? 0,
            sleepDurationMinutes: dataPoint.sleepDurationMinutes ?? 0,
            deepSleepMinutes: dataPoint.deepSleepMinutes ?? 0,
            lightSleepMinutes: dataPoint.lightSleepMinutes ?? 0,
            remSleepMinutes: dataPoint.remSleepMinutes ?? 0,
            awakeMinutes: dataPoint.awakeMinutes ?? 0,
            baseline7d: dataPoint.baseline7d,
            baseline30d: dataPoint.baseline30d,
            zScore: dataPoint.zScore,
            recoveryScore: dataPoint.recoveryScore,
            sleepScore: dataPoint.sleepScore
        )

        // Get historical summaries
        let historical = allSummaries.filter { $0.date < startOfDay }

        // Calculate readiness
        readinessMetrics = ReadinessEngine.calculateReadiness(
            todaySummary: tempSummary,
            historicalSummaries: historical
        )

        // Calculate biological age
        let avgRMSSD = baseline7d ?? dataPoint.rmssd
        let avgRHR = historical.suffix(7).map { $0.minHR }.reduce(0, +) / max(1, Double(historical.suffix(7).count))
        biologicalAge = ReadinessEngine.estimateBiologicalAge(
            chronologicalAge: 30,
            avgRMSSD: avgRMSSD,
            avgRHR: avgRHR > 0 ? avgRHR : dataPoint.averageHR
        )

        // Detect illness indicators
        illnessFlag = HealthDetectionEngine.detectIllness(
            currentSummary: tempSummary,
            historicalSummaries: historical
        )
    }

    func value(for type: MetricType) -> Double? {
        guard let dataPoint = selectedDataPoint else { return nil }

        switch type {
        case .rhr: return dataPoint.averageHR - 10 // Estimate resting HR
        case .rmssd: return dataPoint.rmssd
        case .sdnn: return dataPoint.sdnn
        case .pnn50: return dataPoint.pnn50
        case .lfHfRatio: return dataPoint.lfHfRatio
        case .hrRecovery: return dataPoint.hrRecovery
        case .sleepScore: return dataPoint.sleepScore.map { Double($0) }
        case .readiness: return readinessMetrics.map { Double($0.readinessScore) }
        case .illnessRisk: return illnessFlag.map { $0.confidence }
        case .biologicalAge: return biologicalAge.map { Double($0.biologicalAge) }
        case .sympatheticLoad: return dataPoint.sympatheticLoad
        case .hrvRhrRatio:
            let rhr = dataPoint.averageHR - 10
            return rhr > 0 ? dataPoint.rmssd / rhr : nil
        case .dfaAlpha1: return dataPoint.dfaAlpha1
        }
    }

    func baseline(for type: MetricType) -> Double? {
        switch type {
        case .rmssd: return baseline7d
        case .biologicalAge: return 30 // Chronological age
        default: return nil
        }
    }
}
