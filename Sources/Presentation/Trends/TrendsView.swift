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

                    // HRV Trend Chart
                    HRVTrendView(
                        summaries: viewModel.summaries,
                        baseline7d: viewModel.baseline7d,
                        baseline30d: viewModel.baseline30d
                    )

                    // Recovery Trend Chart
                    RecoveryTrendView(summaries: viewModel.summaries)

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
    @Published var summaries: [DailyHRVSummary] = []
    @Published var latestReport: RecoveryIntelligenceEngine.IntelligenceReport?
    @Published var latestScoreComponents: SleepScore?
    @Published var dailyComparisons: [DailyMeasurementComparison] = []

    private let repository = DailyHRVSummaryRepository()
    private let snapshotRepository = HRVSnapshotRepository()
    private let continuousRepository = ContinuousHRVDataRepository()

    var baseline7d: Double? {
        BaselineEngine.calculate7DayBaseline(from: summaries)
    }

    var baseline30d: Double? {
        BaselineEngine.calculate30DayBaseline(from: summaries)
    }

    var latestSummary: DailyHRVSummary? {
        summaries.last
    }

    func loadData() {
        summaries = repository.loadAll()

        // Calculate intelligence report for latest
        if let latest = summaries.last {
            let historical = Array(summaries.dropLast())
            latestReport = RecoveryIntelligenceEngine.analyze(
                todaySummary: latest,
                historicalSummaries: historical
            )

            // Calculate score components
            if let sleepScore = latest.sleepScore {
                let totalMinutes = latest.sleepDurationMinutes
                latestScoreComponents = EnhancedSleepScoreCalculator.calculateDetailedScore(
                    totalSleepMinutes: totalMinutes,
                    deepSleepMinutes: latest.deepSleepMinutes,
                    nightRMSSD: latest.rmssd,
                    baselineRMSSD: baseline7d ?? latest.rmssd,
                    awakenings: 0 // Would need to be passed from session
                )
            }
        }

        // Load daily comparisons
        loadDailyComparisons()
    }

    private func loadDailyComparisons() {
        let calendar = Calendar.current
        var comparisons: [DailyMeasurementComparison] = []

        // Get last 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            // Get continuous data for this day (averaged)
            let continuousData = continuousRepository.loadForDate(date)
            let continuousRMSSD: Double? = continuousData.isEmpty ? nil :
                continuousData.map { $0.averageRMSSD * Double($0.sampleCount) }.reduce(0, +) /
                Double(continuousData.map { $0.sampleCount }.reduce(0, +))

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
