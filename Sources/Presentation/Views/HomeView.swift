import SwiftUI

/// Home dashboard view showing today's summary and quick actions
struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Connection Status Card
                    ConnectionStatusCard()
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1 : 0)

                    // Recovery Status (if available)
                    if let report = viewModel.latestReport {
                        RecoveryStatusCard(report: report)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.05), value: showContent)
                    }

                    // Morning Readiness Status
                    MorningReadinessCard(viewModel: viewModel)
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1 : 0)
                        .animation(AppTheme.Animation.spring.delay(0.1), value: showContent)

                    // Daily HRV Comparison
                    if let comparison = viewModel.dailyHRVComparison, comparison.hasData {
                        DailyHRVComparisonCard(comparison: comparison)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.15), value: showContent)
                    }

                    // Last Night's Sleep Summary
                    if let lastSession = viewModel.lastNightsSleep {
                        LastNightSleepCard(session: lastSession, summary: viewModel.lastNightsSummary)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.2), value: showContent)
                    }

                    // Health Alerts (Illness/Overtraining)
                    if let illnessFlag = viewModel.illnessFlag, illnessFlag.isAlert {
                        HealthAlertCard(illnessFlag: illnessFlag, overtrainingFlag: nil)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.25), value: showContent)
                    }

                    if let overtrainingFlag = viewModel.overtrainingFlag, overtrainingFlag.isAlert {
                        HealthAlertCard(illnessFlag: nil, overtrainingFlag: overtrainingFlag)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.3), value: showContent)
                    }

                    // Training Readiness
                    if let readiness = viewModel.readinessMetrics {
                        TrainingReadinessCard(readiness: readiness)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.35), value: showContent)
                    }

                    // ANS/Hormonal State
                    if let ansState = viewModel.hormonalState {
                        ANSStateCard(inference: ansState)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.4), value: showContent)
                    }

                    // Biological Age
                    if let bioAge = viewModel.biologicalAge {
                        BiologicalAgeCard(result: bioAge)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.45), value: showContent)
                    }

                    // Performance Recommendations
                    if let report = viewModel.performanceReport, !report.recommendations.isEmpty {
                        PerformanceRecommendationsCard(report: report)
                            .offset(y: showContent ? 0 : 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(AppTheme.Animation.spring.delay(0.5), value: showContent)
                    }

                    // Quick Stats
                    QuickStatsCard(viewModel: viewModel)
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1 : 0)
                        .animation(AppTheme.Animation.spring.delay(0.55), value: showContent)

                    // Quick Actions
                    QuickActionsCard()
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1 : 0)
                        .animation(AppTheme.Animation.spring.delay(0.6), value: showContent)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Sleep Tracker")
            .onAppear {
                viewModel.loadData(from: coordinator)
                withAnimation(AppTheme.Animation.spring) {
                    showContent = true
                }
            }
            .refreshable {
                viewModel.loadData(from: coordinator)
            }
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Status indicator with glow
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .scaleEffect(isPulsing && isConnecting ? 1.2 : 1)
                    .opacity(isPulsing && isConnecting ? 0.5 : 1)

                Image(systemName: statusIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(statusColor.gradient)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(coordinator.bleManager.connectionState.rawValue)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                if let device = coordinator.bleManager.connectedPeripheral {
                    Text(device.name)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if coordinator.bleManager.connectionState == .connected {
                VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                    PremiumSignalStrength(bars: signalBars)

                    Text(coordinator.bleManager.connectionHealth.signalStrength.rawValue)
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .premiumCard()
        .onAppear {
            if isConnecting {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private var isConnecting: Bool {
        switch coordinator.bleManager.connectionState {
        case .connecting, .reconnecting, .scanning, .scanningForKnownDevice:
            return true
        default:
            return false
        }
    }

    private var statusIcon: String {
        switch coordinator.bleManager.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting, .reconnecting, .scanningForKnownDevice: return "antenna.radiowaves.left.and.right"
        case .scanning: return "magnifyingglass"
        case .disconnected: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch coordinator.bleManager.connectionState {
        case .connected: return AppTheme.Colors.success
        case .connecting, .reconnecting, .scanning, .scanningForKnownDevice: return AppTheme.Colors.warning
        case .disconnected: return AppTheme.Colors.danger
        }
    }

    private var signalBars: Int {
        switch coordinator.bleManager.connectionHealth.signalStrength {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak, .unknown: return 1
        }
    }
}

// MARK: - Morning Readiness Card

struct MorningReadinessCard: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(
                title: "Morning Readiness",
                icon: "sun.horizon.fill",
                iconColor: .orange
            )

            if viewModel.hasMorningReadinessToday {
                if let snapshot = viewModel.todaysMorningReadiness {
                    HStack {
                        // Readiness score ring
                        if let comparison = snapshot.comparedTo7DayBaseline {
                            CircularProgressRing(
                                progress: min(comparison / 100.0, 1.2),
                                gradient: AppTheme.Gradients.scoreGradient(for: Int(comparison)),
                                lineWidth: 8,
                                size: 80,
                                showPercentage: false
                            )
                            .overlay(
                                VStack(spacing: 0) {
                                    Text("\(Int(comparison))")
                                        .font(AppTheme.Typography.title2)
                                        .fontWeight(.bold)
                                    Text("%")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                            )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: AppTheme.Spacing.sm) {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                Text("Completed")
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundColor(AppTheme.Colors.success)
                            }

                            Text("RMSSD: \(String(format: "%.1f", snapshot.rmssd)) ms")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    Text("Take your morning readiness check to see how recovered you are today")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Button {
                        coordinator.startMorningReadiness()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start 3-min Check")
                        }
                    }
                    .primaryStyle()
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Last Night Sleep Card

struct LastNightSleepCard: View {
    let session: SleepSession
    let summary: SleepSummary?
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(
                    title: "Last Night",
                    icon: "moon.zzz.fill",
                    iconColor: AppTheme.Colors.deepSleep
                )

                if let summary = summary {
                    CircularProgressRing(
                        progress: Double(summary.sleepScore) / 100.0,
                        gradient: AppTheme.Gradients.scoreGradient(for: summary.sleepScore),
                        lineWidth: 6,
                        size: 56,
                        showPercentage: false
                    )
                    .overlay(
                        Text("\(summary.sleepScore)")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    )
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                PremiumStatItem(
                    label: "Duration",
                    value: formatDuration(session.duration),
                    icon: "clock.fill",
                    color: AppTheme.Colors.info
                )

                if let summary = summary {
                    PremiumStatItem(
                        label: "Deep Sleep",
                        value: "\(Int(summary.deepSleepPercentage))%",
                        icon: "powersleep",
                        color: AppTheme.Colors.deepSleep
                    )

                    PremiumStatItem(
                        label: "Avg HR",
                        value: "\(Int(summary.averageHR))",
                        icon: "heart.fill",
                        color: AppTheme.Colors.danger
                    )
                }
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .premiumCard()
        .onAppear {
            withAnimation(AppTheme.Animation.spring.delay(0.2)) {
                appeared = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Premium Stat Item

struct PremiumStatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color.gradient)
            }

            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(label)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Stats Card

struct QuickStatsCard: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(
                title: "7-Day Averages",
                icon: "chart.bar.fill",
                iconColor: AppTheme.Colors.info
            )

            HStack(spacing: AppTheme.Spacing.sm) {
                if let baseline = viewModel.baseline7d {
                    PremiumStatItem(
                        label: "RMSSD",
                        value: String(format: "%.0f", baseline),
                        icon: "waveform.path.ecg",
                        color: .purple
                    )
                }

                PremiumStatItem(
                    label: "Sleep Score",
                    value: viewModel.avgSleepScore.map { "\($0)" } ?? "--",
                    icon: "star.fill",
                    color: AppTheme.Colors.warning
                )

                PremiumStatItem(
                    label: "Stress Events",
                    value: "\(viewModel.weeklyStressCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: viewModel.weeklyStressCount > 5 ? AppTheme.Colors.danger : AppTheme.Colors.success
                )
            }
        }
        .premiumCard()
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(
                title: "Quick Actions",
                icon: "bolt.fill",
                iconColor: AppTheme.Colors.warning
            )

            HStack(spacing: AppTheme.Spacing.md) {
                QuickActionButton(
                    title: "Snapshot",
                    icon: "camera.metering.spot",
                    gradient: AppTheme.Gradients.calm
                ) {
                    coordinator.navigateTo(.monitor)
                }

                QuickActionButton(
                    title: "View Trends",
                    icon: "chart.line.uptrend.xyaxis",
                    gradient: AppTheme.Gradients.primary
                ) {
                    coordinator.navigateTo(.history)
                }
            }
        }
        .premiumCard()
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Stat Item (Legacy support)

struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        PremiumStatItem(
            label: label,
            value: value,
            icon: icon,
            color: AppTheme.Colors.info
        )
    }
}

// MARK: - Daily HRV Comparison Card

struct DailyHRVComparisonCard: View {
    let comparison: DailyHRVComparison

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(
                    title: "Today's HRV",
                    icon: "chart.bar.fill",
                    iconColor: .purple
                )

                if let baseline = comparison.baseline7d {
                    Text("Baseline: \(String(format: "%.0f", baseline)) ms")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xxs)
                        .background(Capsule().fill(Color.gray.opacity(0.1)))
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                HRVMeasurementColumn(
                    title: "Morning",
                    icon: "sun.horizon.fill",
                    color: .orange,
                    summary: comparison.morningReadiness
                )

                HRVMeasurementColumn(
                    title: "Continuous",
                    icon: "infinity",
                    color: AppTheme.Colors.success,
                    summary: comparison.continuous
                )

                HRVMeasurementColumn(
                    title: "Snapshots",
                    icon: "camera.metering.spot",
                    color: AppTheme.Colors.info,
                    summary: comparison.snapshots
                )
            }
        }
        .premiumCard()
    }
}

struct HRVMeasurementColumn: View {
    let title: String
    let icon: String
    let color: Color
    let summary: MeasurementSummary?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color.gradient)
            }

            if let summary = summary {
                Text(String(format: "%.0f", summary.rmssd))
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("ms")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)

                if let comparison = summary.comparedToBaseline {
                    HStack(spacing: 2) {
                        Image(systemName: comparison >= 100 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(Int(comparison))%")
                            .font(AppTheme.Typography.caption2)
                    }
                    .foregroundColor(comparisonColor(comparison))
                    .padding(.horizontal, AppTheme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(comparisonColor(comparison).opacity(0.12)))
                }

                if summary.sampleCount > 1 {
                    Text("(\(summary.sampleCount))")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            } else {
                Text("--")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }

            Text(title)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(summary != nil ? color.opacity(0.05) : Color.clear)
        )
    }

    private func comparisonColor(_ value: Double) -> Color {
        switch value {
        case 105...: return AppTheme.Colors.success
        case 95..<105: return AppTheme.Colors.info
        case 85..<95: return AppTheme.Colors.warning
        default: return AppTheme.Colors.danger
        }
    }
}

// MARK: - Health Alert Card

struct HealthAlertCard: View {
    let illnessFlag: HealthDetectionEngine.IllnessFlag?
    let overtrainingFlag: HealthDetectionEngine.OvertrainingFlag?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let illness = illnessFlag {
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.danger.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "cross.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.danger.gradient)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("Possible Illness Detected")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.danger)

                        Text("\(Int(illness.confidence))% confidence")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }

                Text(illness.recommendation)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                // Indicators
                if !illness.indicators.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        ForEach(illness.indicators, id: \.name) { indicator in
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Circle()
                                    .fill(AppTheme.Colors.danger)
                                    .frame(width: 6, height: 6)
                                Text("\(indicator.name): \(String(format: "%.0f", indicator.deviation))% deviation")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                }
            }

            if let overtraining = overtrainingFlag {
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.warning.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.warning.gradient)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(overtraining.status.rawValue)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.warning)

                        Text("\(overtraining.consecutiveDays) consecutive days")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }

                Text(overtraining.recommendation)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .premiumCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(illnessFlag != nil ? AppTheme.Colors.danger.opacity(0.3) : AppTheme.Colors.warning.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Training Readiness Card

struct TrainingReadinessCard: View {
    let readiness: ReadinessEngine.ReadinessMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(
                    title: "Training Readiness",
                    icon: "figure.run",
                    iconColor: readinessColor
                )

                Spacer()

                CircularProgressRing(
                    progress: Double(readiness.readinessScore) / 100.0,
                    gradient: AppTheme.Gradients.scoreGradient(for: readiness.readinessScore),
                    lineWidth: 6,
                    size: 56,
                    showPercentage: false
                )
                .overlay(
                    Text("\(readiness.readinessScore)")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
            }

            HStack(spacing: AppTheme.Spacing.xs) {
                Text(readiness.interpretation.emoji)
                    .font(.system(size: 20))
                Text(readiness.interpretation.rawValue)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(readinessColor)
            }

            Text(readiness.recommendation)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)

            // Component breakdown
            HStack(spacing: AppTheme.Spacing.sm) {
                ReadinessComponentItem(label: "HRV", value: Int(readiness.hrvZScore), icon: "waveform.path.ecg")
                ReadinessComponentItem(label: "RHR", value: Int(readiness.rhrDeviation), icon: "heart.fill")
                ReadinessComponentItem(label: "Sleep", value: Int(readiness.sleepScore), icon: "moon.zzz.fill")
                ReadinessComponentItem(label: "HRR", value: Int(readiness.hrrScore), icon: "arrow.down.heart.fill")
            }
        }
        .premiumCard()
    }

    private var readinessColor: Color {
        switch readiness.interpretation {
        case .optimal: return AppTheme.Colors.success
        case .good: return AppTheme.Colors.info
        case .moderate: return AppTheme.Colors.warning
        case .low, .veryLow: return AppTheme.Colors.danger
        }
    }
}

struct ReadinessComponentItem: View {
    let label: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(componentColor)

            Text("\(value)")
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(componentColor)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(componentColor.opacity(0.08))
        )
    }

    private var componentColor: Color {
        switch value {
        case 80...: return AppTheme.Colors.success
        case 60..<80: return AppTheme.Colors.info
        case 40..<60: return AppTheme.Colors.warning
        default: return AppTheme.Colors.danger
        }
    }
}

// MARK: - ANS State Card

struct ANSStateCard: View {
    let inference: HormonalInferenceEngine.HormonalInference

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(
                    title: "Autonomic State",
                    icon: "brain.head.profile",
                    iconColor: stateColor
                )

                Spacer()

                Text(inference.primaryState.emoji)
                    .font(.system(size: 32))
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Text(inference.primaryState.rawValue)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(stateColor)

                Spacer()

                Text("\(Int(inference.confidence))% confidence")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
            }

            Text(inference.description)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)

            // Recommendations
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                ForEach(inference.recommendations.prefix(2), id: \.self) { rec in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(stateColor)
                        Text(rec)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }

            // HRV/RHR levels
            HStack(spacing: AppTheme.Spacing.lg) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(hrvLevelColor)
                        .frame(width: 8, height: 8)
                    Text("HRV: \(inference.hrvLevel.rawValue)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(rhrLevelColor)
                        .frame(width: 8, height: 8)
                    Text("RHR: \(inference.rhrLevel.rawValue)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                if let lfhf = inference.lfHfRatio {
                    Text("LF/HF: \(String(format: "%.1f", lfhf))")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }

            Text(inference.disclaimer)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .italic()
        }
        .premiumCard()
    }

    private var stateColor: Color {
        switch inference.primaryState {
        case .parasympatheticOptimized, .recoveryMode: return AppTheme.Colors.success
        case .balanced: return AppTheme.Colors.info
        case .sympatheticDominant, .fightOrFlight: return AppTheme.Colors.warning
        case .chronicStressPattern: return AppTheme.Colors.danger
        }
    }

    private var hrvLevelColor: Color {
        switch inference.hrvLevel {
        case .high: return AppTheme.Colors.success
        case .normal: return AppTheme.Colors.info
        case .low: return AppTheme.Colors.danger
        }
    }

    private var rhrLevelColor: Color {
        switch inference.rhrLevel {
        case .low: return AppTheme.Colors.success
        case .normal: return AppTheme.Colors.info
        case .elevated: return AppTheme.Colors.danger
        }
    }
}

// MARK: - Biological Age Card

struct BiologicalAgeCard: View {
    let result: ReadinessEngine.BiologicalAgeResult

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(
                title: "Biological Age",
                icon: "calendar.badge.clock",
                iconColor: ageColor
            )

            HStack(alignment: .center, spacing: AppTheme.Spacing.lg) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(result.biologicalAge)")
                        .font(AppTheme.Typography.metricLarge)
                        .foregroundColor(ageColor)
                    Text("years")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: result.ageDifference > 0 ? "arrow.down" : "arrow.up")
                            .foregroundColor(result.ageDifference > 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                        Text("\(abs(result.ageDifference)) years \(result.ageDifference > 0 ? "younger" : "older")")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(result.ageDifference > 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                    }

                    Text("\(result.percentile)th percentile for your age")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()
            }

            Text(result.interpretation)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)

            // Component percentiles
            HStack(spacing: AppTheme.Spacing.sm) {
                PercentileBar(label: "HRV", percentile: Int(result.components.rmssdPercentile))
                PercentileBar(label: "RHR", percentile: Int(result.components.rhrPercentile))
                PercentileBar(label: "HRR", percentile: Int(result.components.hrrPercentile))
            }
        }
        .premiumCard()
    }

    private var ageColor: Color {
        if result.ageDifference >= 5 {
            return AppTheme.Colors.success
        } else if result.ageDifference >= 0 {
            return AppTheme.Colors.info
        } else {
            return AppTheme.Colors.warning
        }
    }
}

struct PercentileBar: View {
    let label: String
    let percentile: Int

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(percentileColor.gradient)
                        .frame(width: geo.size.width * CGFloat(percentile) / 100, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Spacer()
                Text("\(percentile)%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(percentileColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var percentileColor: Color {
        switch percentile {
        case 75...: return AppTheme.Colors.success
        case 50..<75: return AppTheme.Colors.info
        case 25..<50: return AppTheme.Colors.warning
        default: return AppTheme.Colors.danger
        }
    }
}

// MARK: - Performance Recommendations Card

struct PerformanceRecommendationsCard: View {
    let report: PerformanceOptimizationEngine.OptimizationReport
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(
                    title: "Recommendations",
                    icon: "lightbulb.fill",
                    iconColor: statusColor
                )

                Spacer()

                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(report.overallStatus.emoji)
                    Text(report.overallStatus.rawValue)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(Capsule().fill(statusColor.opacity(0.12)))
            }

            Text(report.summary)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)

            // Show recommendations
            let visibleRecs = isExpanded ? report.recommendations : Array(report.recommendations.prefix(2))
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(visibleRecs) { rec in
                    RecommendationRow(recommendation: rec)
                }
            }

            if report.recommendations.count > 2 {
                Button {
                    withAnimation(AppTheme.Animation.quick) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show Less" : "Show \(report.recommendations.count - 2) More")
                            .font(AppTheme.Typography.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.info)
                }
            }
        }
        .premiumCard()
    }

    private var statusColor: Color {
        switch report.overallStatus {
        case .optimal: return AppTheme.Colors.success
        case .good: return AppTheme.Colors.info
        case .needsAttention: return AppTheme.Colors.warning
        case .critical: return AppTheme.Colors.danger
        }
    }
}

struct RecommendationRow: View {
    let recommendation: PerformanceOptimizationEngine.Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(priorityColor.opacity(0.12))
                    .frame(width: 28, height: 28)

                Image(systemName: typeIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(priorityColor)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text(recommendation.title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    Text(recommendation.priority.emoji)
                        .font(.system(size: 10))
                }

                Text(recommendation.action)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(priorityColor.opacity(0.05))
        )
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return AppTheme.Colors.danger
        case .medium: return AppTheme.Colors.warning
        case .low: return AppTheme.Colors.success
        }
    }

    private var typeIcon: String {
        switch recommendation.type {
        case .training: return "figure.run"
        case .recovery: return "bed.double.fill"
        case .nutrition: return "fork.knife"
        case .sleep: return "moon.zzz.fill"
        case .stress: return "brain.head.profile"
        }
    }
}
