import SwiftUI

/// History view showing sleep sessions, snapshots, and trends
struct HistoryView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("Sleep").tag(0)
                    Text("Snapshots").tag(1)
                    Text("Trends").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedSegment {
                case 0: SleepSessionsListView(viewModel: viewModel)
                case 1: SnapshotsListView(viewModel: viewModel)
                case 2: TrendsView()
                default: EmptyView()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("History")
            .onAppear { viewModel.loadData(from: coordinator) }
        }
    }
}

// MARK: - Sleep Sessions List

struct SleepSessionsListView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        if viewModel.sleepSessions.isEmpty {
            PremiumEmptyState(icon: "moon.zzz.fill", title: "No Sleep Sessions", message: "Your recorded sleep sessions will appear here.", iconColor: AppTheme.Colors.deepSleep)
        } else {
            List {
                ForEach(viewModel.sleepSessions) { session in
                    NavigationLink { SessionDetailView(session: session) } label: {
                        SleepSessionRow(session: session, summary: viewModel.summaryFor(session: session))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct SleepSessionRow: View {
    let session: SleepSession
    let summary: SleepSummary?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle().fill(AppTheme.Colors.deepSleep.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: "moon.zzz.fill").foregroundStyle(AppTheme.Colors.deepSleep.gradient)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(formatDate(session.startTime)).font(AppTheme.Typography.headline)
                Text(formatDuration(session.duration)).font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if let summary = summary {
                CircularProgressRing(
                    progress: Double(summary.sleepScore) / 100.0,
                    gradient: AppTheme.Gradients.scoreGradient(for: summary.sleepScore),
                    lineWidth: 4, size: 44, showPercentage: false
                )
                .overlay(Text("\(summary.sleepScore)").font(AppTheme.Typography.caption).fontWeight(.bold))
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        "\(Int(duration) / 3600)h \((Int(duration) % 3600) / 60)m"
    }
}

// MARK: - Snapshots List

struct SnapshotsListView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        if viewModel.snapshots.isEmpty {
            PremiumEmptyState(icon: "camera.metering.spot", title: "No Snapshots", message: "Your HRV snapshots will appear here.", iconColor: AppTheme.Colors.info)
        } else {
            List {
                ForEach(viewModel.snapshots) { snapshot in
                    SnapshotRow(snapshot: snapshot)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct SnapshotRow: View {
    let snapshot: HRVSnapshot

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle().fill(snapshot.isMorningReadiness ? Color.orange.opacity(0.12) : AppTheme.Colors.info.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: snapshot.isMorningReadiness ? "sun.horizon.fill" : "camera.metering.spot")
                    .foregroundStyle(snapshot.isMorningReadiness ? Color.orange.gradient : AppTheme.Colors.info.gradient)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(formatDateTime(snapshot.timestamp)).font(AppTheme.Typography.subheadline)
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(snapshot.formattedDuration).font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textTertiary)
                    if let context = snapshot.context {
                        Text(context.rawValue).font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                Text(String(format: "%.0f ms", snapshot.rmssd)).font(AppTheme.Typography.headline)
                if let comparison = snapshot.comparedTo7DayBaseline {
                    Text("\(Int(comparison))%")
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill((comparison >= 100 ? AppTheme.Colors.success : AppTheme.Colors.warning).opacity(0.12)))
                        .foregroundColor(comparison >= 100 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - History ViewModel

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var sleepSessions: [SleepSession] = []
    @Published var snapshots: [HRVSnapshot] = []
    @Published var stressEvents: [StressEvent] = []
    private var sessionSummaries: [UUID: SleepSummary] = [:]

    func loadData(from coordinator: AppCoordinator) {
        sleepSessions = (try? coordinator.sessionRepository.loadAll()) ?? []
        snapshots = coordinator.snapshotRepository.loadAll()
        stressEvents = coordinator.stressEventRepository.loadAll()
        for session in sleepSessions {
            sessionSummaries[session.id] = SleepSummaryCalculator.calculate(from: session)
        }
    }

    func summaryFor(session: SleepSession) -> SleepSummary? { sessionSummaries[session.id] }
}
