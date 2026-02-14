import SwiftUI

struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Recovery Status Card
                    if let report = viewModel.latestReport {
                        RecoveryStatusCard(report: report)
                    }

                    // Daily Measurement Comparison (Continuous vs Morning Readiness vs Snapshots)
                    DailyMeasurementComparisonView(viewModel: viewModel)

                    // HRV Trend Chart (from all sources)
                    HRVTrendView(
                        dataPoints: viewModel.dailyHRVDataPoints,
                        baseline7d: viewModel.baseline7d,
                        baseline30d: viewModel.baseline30d
                    )

                    // Recovery Trend Chart (from all sources)
                    RecoveryTrendView(dataPoints: viewModel.dailyHRVDataPoints)

                    // Sleep Trend Chart (sleep sessions only)
                    SleepTrendView(dataPoints: viewModel.dailyHRVDataPoints.filter { $0.hasSleepData })

                    // Latest Sleep Score Breakdown
                    if let latest = viewModel.latestSummary,
                       let sleepScore = latest.sleepScore {
                        SleepScoreBreakdownView(
                            durationScore: viewModel.latestScoreComponents?.durationComponent ?? 0,
                            deepScore: viewModel.latestScoreComponents?.deepComponent ?? 0,
                            hrvScore: viewModel.latestScoreComponents?.hrvComponent ?? 0,
                            continuityScore: viewModel.latestScoreComponents?.continuityComponent ?? 0
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
            .onAppear {
                viewModel.loadData()
            }
            .refreshable {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Daily Measurement Comparison View

struct DailyMeasurementComparisonView: View {
    @ObservedObject var viewModel: TrendsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily HRV Comparison")
                .font(.headline)

            Text("Compare RMSSD across measurement types")
                .font(.caption)
                .foregroundColor(.secondary)

            // Show last 7 days comparison
            ForEach(viewModel.dailyComparisons.prefix(7), id: \.date) { comparison in
                DailyComparisonRow(comparison: comparison)
            }

            if viewModel.dailyComparisons.isEmpty {
                Text("No data available yet. Start taking measurements!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DailyComparisonRow: View {
    let comparison: DailyMeasurementComparison

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(dateFormatter.string(from: comparison.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            HStack(spacing: 12) {
                // Continuous (averaged)
                MeasurementTypeIndicator(
                    icon: "infinity",
                    label: "Continuous",
                    value: comparison.continuousRMSSD,
                    color: .green
                )

                // Morning Readiness
                MeasurementTypeIndicator(
                    icon: "sun.horizon.fill",
                    label: "Morning",
                    value: comparison.morningReadinessRMSSD,
                    color: .orange
                )

                // Snapshots (averaged)
                MeasurementTypeIndicator(
                    icon: "camera.metering.spot",
                    label: "Snapshots",
                    value: comparison.snapshotsRMSSD,
                    color: .blue
                )
            }
        }
        .padding(.vertical, 8)
    }
}

struct MeasurementTypeIndicator: View {
    let icon: String
    let label: String
    let value: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(value.map { String(format: "%.0f", $0) } ?? "--")
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(value != nil ? 0.1 : 0.05))
        .cornerRadius(8)
    }
}

// MARK: - Recovery Status Card

struct RecoveryStatusCard: View {
    let report: RecoveryIntelligenceEngine.IntelligenceReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recovery Status")
                    .font(.headline)

                Spacer()

                Text(report.primaryState.emoji)
                    .font(.title2)
            }

            HStack(spacing: 16) {
                // Primary State
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.primaryState.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(colorForState(report.primaryState))

                    if let zScore = report.zScore {
                        Text("Z-Score: \(String(format: "%.2f", zScore))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Metrics
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Stress Index:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", report.stressIndex))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    if report.recoveryDebt > 10 {
                        HStack(spacing: 4) {
                            Text("Recovery Debt:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f", report.recoveryDebt))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            // Recommendation
            if let recommendation = report.recommendations.first {
                Text(recommendation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Alert states
            if !report.secondaryStates.isEmpty {
                HStack(spacing: 8) {
                    ForEach(report.secondaryStates, id: \.rawValue) { state in
                        Text(state.emoji + " " + state.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(report.isAlert ? Color.red.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(report.isAlert ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }

    private func colorForState(_ state: RecoveryIntelligenceEngine.RecoveryState) -> Color {
        switch state {
        case .parasympatheticDominant, .elevated:
            return .green
        case .normal:
            return .blue
        case .sympatheticDominant:
            return .yellow
        case .recoveryDebt:
            return .orange
        case .overreachingRisk, .cnsFatigue:
            return .red
        }
    }
}

// MARK: - Daily Measurement Comparison Model

struct DailyMeasurementComparison {
    let date: Date
    let continuousRMSSD: Double?
    let morningReadinessRMSSD: Double?
    let snapshotsRMSSD: Double?
}

// MARK: - Trends ViewModel

@MainActor
final class TrendsViewModel: ObservableObject {
    // Legacy summaries (from sleep sessions only)
    @Published var summaries: [DailyHRVSummary] = []

    // New: Daily HRV data points from all sources
    @Published var dailyHRVDataPoints: [DailyHRVDataPoint] = []

    @Published var latestReport: RecoveryIntelligenceEngine.IntelligenceReport?
    @Published var latestScoreComponents: SleepScore?
    @Published var dailyComparisons: [DailyMeasurementComparison] = []

    private let repository = DailyHRVSummaryRepository()
    private let snapshotRepository = HRVSnapshotRepository()
    private let continuousRepository = ContinuousHRVDataRepository()
    private let sessionRepository = SleepSessionRepository()

    var baseline7d: Double? {
        guard !dailyHRVDataPoints.isEmpty else { return nil }
        let last7 = dailyHRVDataPoints.suffix(7)
        return last7.map { $0.rmssd }.reduce(0, +) / Double(last7.count)
    }

    var baseline30d: Double? {
        guard !dailyHRVDataPoints.isEmpty else { return nil }
        let last30 = dailyHRVDataPoints.suffix(30)
        return last30.map { $0.rmssd }.reduce(0, +) / Double(last30.count)
    }

    var latestSummary: DailyHRVSummary? {
        summaries.last
    }

    var latestDataPoint: DailyHRVDataPoint? {
        dailyHRVDataPoints.last
    }

    func loadData() {
        // Load legacy summaries (still used for sleep-specific views)
        summaries = repository.loadAll()

        // Load new daily HRV data points from all sources
        loadDailyHRVDataPoints()

        // Calculate intelligence report from latest data point
        if let latest = dailyHRVDataPoints.last {
            let historical = Array(dailyHRVDataPoints.dropLast())
            latestReport = createIntelligenceReport(from: latest, historical: historical)
        }

        // Calculate score components from sleep data if available
        if let latest = summaries.last, latest.sleepScore != nil {
            latestScoreComponents = EnhancedSleepScoreCalculator.calculateDetailedScore(
                totalSleepMinutes: latest.sleepDurationMinutes,
                deepSleepMinutes: latest.deepSleepMinutes,
                nightRMSSD: latest.rmssd,
                baselineRMSSD: baseline7d ?? latest.rmssd,
                awakenings: 0
            )
        }

        // Load daily comparisons
        loadDailyComparisons()
    }

    private func loadDailyHRVDataPoints() {
        let calendar = Calendar.current
        var dataPoints: [DailyHRVDataPoint] = []

        // Load sleep sessions
        let sleepSessions = (try? sessionRepository.loadAll()) ?? []

        // Get last 365 days (1 year) to support all time range options
        for dayOffset in (0..<365).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            // Get morning readiness for this day
            let snapshots = snapshotRepository.loadForDate(date)
            let morningReadiness = snapshots.first { $0.measurementMode == .morningReadiness }

            // Get sleep session that ended on this day (previous night's sleep)
            let sleepSession = sleepSessions.first { session in
                guard let endTime = session.endTime else { return false }
                return endTime >= startOfDay && endTime < endOfDay
            }

            var dataPoint: DailyHRVDataPoint?

            // Priority 1: Sleep session + optional morning readiness (combined)
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

            if let point = dataPoint {
                dataPoints.append(point)
            }
        }

        // Sort by date and enrich with baselines
        dataPoints.sort { $0.date < $1.date }

        // Enrich each point with baselines calculated from prior points
        var enrichedPoints: [DailyHRVDataPoint] = []
        for (index, point) in dataPoints.enumerated() {
            let historical = Array(dataPoints.prefix(index))
            let enriched = point.withBaselines(from: historical)
            enrichedPoints.append(enriched)
        }

        dailyHRVDataPoints = enrichedPoints
    }

    private func createIntelligenceReport(
        from latest: DailyHRVDataPoint,
        historical: [DailyHRVDataPoint]
    ) -> RecoveryIntelligenceEngine.IntelligenceReport? {
        // Create a temporary DailyHRVSummary for the intelligence engine
        let tempSummary = DailyHRVSummary(
            date: latest.date,
            meanHR: latest.averageHR,
            minHR: latest.averageHR - 10,
            maxHR: latest.averageHR + 20,
            rmssd: latest.rmssd,
            sdnn: latest.sdnn ?? 0,
            sleepDurationMinutes: latest.sleepDurationMinutes ?? 0,
            deepSleepMinutes: latest.deepSleepMinutes ?? 0,
            lightSleepMinutes: latest.lightSleepMinutes ?? 0,
            remSleepMinutes: latest.remSleepMinutes ?? 0,
            awakeMinutes: latest.awakeMinutes ?? 0,
            baseline7d: latest.baseline7d,
            baseline30d: latest.baseline30d,
            zScore: latest.zScore,
            recoveryScore: latest.recoveryScore,
            sleepScore: latest.sleepScore
        )

        let historicalSummaries = historical.map { point in
            DailyHRVSummary(
                date: point.date,
                meanHR: point.averageHR,
                minHR: point.averageHR - 10,
                maxHR: point.averageHR + 20,
                rmssd: point.rmssd,
                sdnn: point.sdnn ?? 0,
                sleepDurationMinutes: point.sleepDurationMinutes ?? 0,
                deepSleepMinutes: point.deepSleepMinutes ?? 0,
                lightSleepMinutes: point.lightSleepMinutes ?? 0,
                remSleepMinutes: point.remSleepMinutes ?? 0,
                awakeMinutes: point.awakeMinutes ?? 0,
                baseline7d: point.baseline7d,
                baseline30d: point.baseline30d,
                zScore: point.zScore,
                recoveryScore: point.recoveryScore,
                sleepScore: point.sleepScore
            )
        }

        return RecoveryIntelligenceEngine.analyze(
            todaySummary: tempSummary,
            historicalSummaries: historicalSummaries
        )
    }

    private func loadDailyComparisons() {
        let calendar = Calendar.current
        var comparisons: [DailyMeasurementComparison] = []

        // Get last 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            // Get continuous data for this day (averaged)
            let continuousData = continuousRepository.loadForDate(date)
            let totalSamples = continuousData.map { $0.sampleCount }.reduce(0, +)
            let continuousRMSSD: Double? = totalSamples == 0 ? nil :
                continuousData.map { $0.averageRMSSD * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)

            // Get snapshots for this day
            let snapshots = snapshotRepository.loadForDate(date)

            // Morning readiness RMSSD
            let morningReadiness = snapshots.first { $0.measurementMode == .morningReadiness }
            let morningRMSSD = morningReadiness?.rmssd

            // Quick snapshots averaged
            let quickSnapshots = snapshots.filter { $0.measurementMode == .snapshot }
            let snapshotsRMSSD: Double? = quickSnapshots.isEmpty ? nil :
                quickSnapshots.map { $0.rmssd }.reduce(0, +) / Double(quickSnapshots.count)

            let comparison = DailyMeasurementComparison(
                date: date,
                continuousRMSSD: continuousRMSSD,
                morningReadinessRMSSD: morningRMSSD,
                snapshotsRMSSD: snapshotsRMSSD
            )

            comparisons.append(comparison)
        }

        dailyComparisons = comparisons
    }
}
