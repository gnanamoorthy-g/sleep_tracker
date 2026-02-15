import SwiftUI

/// Full metrics dashboard view showing all available metrics
struct InsightsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedMetric: MetricType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Quick Summary Header
                    if let readiness = viewModel.readinessMetrics {
                        QuickSummaryHeader(readiness: readiness)
                    }

                    // Metrics Grid
                    PremiumSectionHeader(
                        title: "All Metrics",
                        icon: "chart.bar.doc.horizontal.fill",
                        iconColor: AppTheme.Colors.info
                    )
                    .padding(.horizontal)

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
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Insights")
            .onAppear {
                viewModel.loadData(from: coordinator)
            }
            .refreshable {
                viewModel.loadData(from: coordinator)
            }
            .sheet(item: $selectedMetric) { type in
                MetricDetailView(
                    type: type,
                    value: viewModel.value(for: type) ?? 0,
                    baseline: viewModel.baseline(for: type)
                )
            }
        }
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
    @Published var latestSummary: DailyHRVSummary?
    @Published var baseline7d: Double?
    @Published var biologicalAge: ReadinessEngine.BiologicalAgeResult?
    @Published var illnessFlag: HealthDetectionEngine.IllnessFlag?

    func loadData(from coordinator: AppCoordinator) {
        let summaries = coordinator.summaryRepository.loadAll()
        latestSummary = summaries.last
        baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries)

        guard let latest = summaries.last else { return }
        let historical = Array(summaries.dropLast())

        readinessMetrics = ReadinessEngine.calculateReadiness(
            todaySummary: latest,
            historicalSummaries: historical
        )

        let avgRMSSD = baseline7d ?? latest.rmssd
        let avgRHR = historical.suffix(7).map { $0.minHR }.reduce(0, +) / max(1, Double(historical.suffix(7).count))
        biologicalAge = ReadinessEngine.estimateBiologicalAge(
            chronologicalAge: 30,
            avgRMSSD: avgRMSSD,
            avgRHR: avgRHR > 0 ? avgRHR : latest.minHR
        )

        illnessFlag = HealthDetectionEngine.detectIllness(
            currentSummary: latest,
            historicalSummaries: historical
        )
    }

    func value(for type: MetricType) -> Double? {
        guard let summary = latestSummary else { return nil }

        switch type {
        case .rhr: return summary.minHR
        case .rmssd: return summary.rmssd
        case .sdnn: return summary.sdnn
        case .pnn50: return nil // Not stored in summary
        case .lfHfRatio: return nil // Not stored in summary
        case .hrRecovery: return nil // Would need HRR data
        case .sleepScore: return summary.sleepScore.map { Double($0) }
        case .readiness: return readinessMetrics.map { Double($0.readinessScore) }
        case .illnessRisk: return illnessFlag.map { $0.confidence }
        case .biologicalAge: return biologicalAge.map { Double($0.biologicalAge) }
        case .sympatheticLoad: return nil // Would calculate from LF/HF
        case .hrvRhrRatio: return summary.minHR > 0 ? summary.rmssd / summary.minHR : nil
        case .dfaAlpha1: return nil // Would need DFA calculation
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
