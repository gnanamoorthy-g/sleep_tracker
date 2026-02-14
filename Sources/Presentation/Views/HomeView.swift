import SwiftUI

/// Home dashboard view showing today's summary and quick actions
struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection Status Card
                    ConnectionStatusCard()

                    // Recovery Status (if available)
                    if let report = viewModel.latestReport {
                        RecoveryStatusCard(report: report)
                    }

                    // Morning Readiness Status
                    MorningReadinessCard(viewModel: viewModel)

                    // Daily HRV Comparison
                    if let comparison = viewModel.dailyHRVComparison, comparison.hasData {
                        DailyHRVComparisonCard(comparison: comparison)
                    }

                    // Last Night's Sleep Summary
                    if let lastSession = viewModel.lastNightsSleep {
                        LastNightSleepCard(session: lastSession, summary: viewModel.lastNightsSummary)
                    }

                    // Quick Stats
                    QuickStatsCard(viewModel: viewModel)

                    // Quick Actions
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("Sleep Tracker")
            .onAppear {
                viewModel.loadData(from: coordinator)
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

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(coordinator.bleManager.connectionState.rawValue)
                    .font(.headline)

                if let device = coordinator.bleManager.connectedPeripheral {
                    Text(device.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if coordinator.bleManager.connectionState == .connected {
                // Signal strength
                HStack(spacing: 4) {
                    Image(systemName: coordinator.bleManager.connectionHealth.signalStrength.systemImageName)
                        .foregroundColor(signalColor)
                    Text(coordinator.bleManager.connectionHealth.signalStrength.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
        case .connected: return .green
        case .connecting, .reconnecting, .scanning, .scanningForKnownDevice: return .orange
        case .disconnected: return .red
        }
    }

    private var signalColor: Color {
        switch coordinator.bleManager.connectionHealth.signalStrength {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .weak, .unknown: return .red
        }
    }
}

// MARK: - Morning Readiness Card

struct MorningReadinessCard: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.horizon.fill")
                    .foregroundColor(.orange)
                Text("Morning Readiness")
                    .font(.headline)
                Spacer()
            }

            if viewModel.hasMorningReadinessToday {
                if let snapshot = viewModel.todaysMorningReadiness {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Completed")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Text("RMSSD: \(String(format: "%.1f", snapshot.rmssd)) ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let comparison = snapshot.comparedTo7DayBaseline {
                            Text("\(Int(comparison))% of baseline")
                                .font(.subheadline)
                                .foregroundColor(comparison >= 100 ? .green : .orange)
                        }
                    }
                }
            } else {
                Button {
                    coordinator.startMorningReadiness()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start 3-min Check")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Last Night Sleep Card

struct LastNightSleepCard: View {
    let session: SleepSession
    let summary: SleepSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
                Text("Last Night")
                    .font(.headline)
                Spacer()

                if let summary = summary {
                    Text("\(summary.sleepScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(summary.sleepScore))
                }
            }

            HStack(spacing: 16) {
                StatItem(
                    label: "Duration",
                    value: formatDuration(session.duration),
                    icon: "clock"
                )

                if let summary = summary {
                    StatItem(
                        label: "Deep",
                        value: "\(Int(summary.deepSleepPercentage))%",
                        icon: "powersleep"
                    )

                    StatItem(
                        label: "Avg HR",
                        value: "\(Int(summary.averageHR))",
                        icon: "heart"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Quick Stats Card

struct QuickStatsCard: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Averages")
                .font(.headline)

            HStack(spacing: 16) {
                if let baseline = viewModel.baseline7d {
                    StatItem(
                        label: "RMSSD",
                        value: String(format: "%.0f", baseline),
                        icon: "waveform.path.ecg"
                    )
                }

                StatItem(
                    label: "Sleep Score",
                    value: viewModel.avgSleepScore.map { "\($0)" } ?? "--",
                    icon: "star"
                )

                StatItem(
                    label: "Stress Events",
                    value: "\(viewModel.weeklyStressCount)",
                    icon: "exclamationmark.triangle"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Snapshot",
                    icon: "camera.metering.spot",
                    color: .blue
                ) {
                    // Navigate to monitor tab - user starts snapshot manually there
                    coordinator.navigateTo(.monitor)
                }

                QuickActionButton(
                    title: "View Trends",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                ) {
                    coordinator.navigateTo(.history)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Daily HRV Comparison Card

struct DailyHRVComparisonCard: View {
    let comparison: DailyHRVComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Today's HRV")
                    .font(.headline)
                Spacer()
                if let baseline = comparison.baseline7d {
                    Text("Baseline: \(String(format: "%.0f", baseline)) ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                // Morning Readiness
                HRVMeasurementColumn(
                    title: "Morning",
                    icon: "sun.horizon.fill",
                    color: .orange,
                    summary: comparison.morningReadiness
                )

                // Continuous
                HRVMeasurementColumn(
                    title: "Continuous",
                    icon: "infinity",
                    color: .green,
                    summary: comparison.continuous
                )

                // Snapshots
                HRVMeasurementColumn(
                    title: "Snapshots",
                    icon: "camera.metering.spot",
                    color: .blue,
                    summary: comparison.snapshots
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HRVMeasurementColumn: View {
    let title: String
    let icon: String
    let color: Color
    let summary: MeasurementSummary?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            if let summary = summary {
                Text(String(format: "%.0f", summary.rmssd))
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("ms")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Baseline comparison
                if let comparison = summary.comparedToBaseline {
                    HStack(spacing: 2) {
                        Image(systemName: comparison >= 100 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text("\(Int(comparison))%")
                            .font(.caption2)
                    }
                    .foregroundColor(comparisonColor(comparison))
                }

                // Sample count for continuous/snapshots
                if summary.sampleCount > 1 {
                    Text("(\(summary.sampleCount) samples)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonColor(_ value: Double) -> Color {
        switch value {
        case 105...: return .green
        case 95..<105: return .blue
        case 85..<95: return .orange
        default: return .red
        }
    }
}
