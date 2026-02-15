import SwiftUI

/// Full metrics dashboard view showing all available metrics
struct InsightsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedMetric: MetricType?
    @State private var selectedDate: Date = Date()

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

                    // Metrics Grid
                    PremiumSectionHeader(
                        title: "Metrics for \(formattedDate)",
                        icon: "chart.bar.doc.horizontal.fill",
                        iconColor: AppTheme.Colors.info
                    )
                    .padding(.horizontal)

                    if viewModel.selectedSummary != nil {
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
                    value: viewModel.value(for: type) ?? 0,
                    baseline: viewModel.baseline(for: type)
                )
            }
        }
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
    @Published var selectedSummary: DailyHRVSummary?
    @Published var baseline7d: Double?
    @Published var biologicalAge: ReadinessEngine.BiologicalAgeResult?
    @Published var illnessFlag: HealthDetectionEngine.IllnessFlag?

    private var allSummaries: [DailyHRVSummary] = []
    private let calendar = Calendar.current

    /// All dates that have data available
    var availableDates: Set<Date> {
        Set(allSummaries.map { calendar.startOfDay(for: $0.date) })
    }

    /// Check if a specific date has data
    func hasDataForDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return allSummaries.contains { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Load all summaries from repository
    func loadAllData(from coordinator: AppCoordinator) {
        allSummaries = coordinator.summaryRepository.loadAll()
        baseline7d = BaselineEngine.calculate7DayBaseline(from: allSummaries)
    }

    /// Select and load metrics for a specific date
    func selectDate(_ date: Date) {
        let startOfDay = calendar.startOfDay(for: date)

        // Find summary for selected date
        selectedSummary = allSummaries.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }

        guard let selected = selectedSummary else {
            readinessMetrics = nil
            biologicalAge = nil
            illnessFlag = nil
            return
        }

        // Get historical summaries (all summaries before selected date)
        let historical = allSummaries.filter { $0.date < startOfDay }

        // Calculate readiness for selected date
        readinessMetrics = ReadinessEngine.calculateReadiness(
            todaySummary: selected,
            historicalSummaries: historical
        )

        // Calculate biological age
        let avgRMSSD = baseline7d ?? selected.rmssd
        let avgRHR = historical.suffix(7).map { $0.minHR }.reduce(0, +) / max(1, Double(historical.suffix(7).count))
        biologicalAge = ReadinessEngine.estimateBiologicalAge(
            chronologicalAge: 30,
            avgRMSSD: avgRMSSD,
            avgRHR: avgRHR > 0 ? avgRHR : selected.minHR
        )

        // Detect illness indicators
        illnessFlag = HealthDetectionEngine.detectIllness(
            currentSummary: selected,
            historicalSummaries: historical
        )
    }

    func value(for type: MetricType) -> Double? {
        guard let summary = selectedSummary else { return nil }

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
