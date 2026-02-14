import SwiftUI

/// History view showing sleep sessions, snapshots, and trends
struct HistoryView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Picker
                Picker("View", selection: $selectedSegment) {
                    Text("Sleep").tag(0)
                    Text("Snapshots").tag(1)
                    Text("Trends").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selection
                switch selectedSegment {
                case 0:
                    SleepSessionsListView(viewModel: viewModel)
                case 1:
                    SnapshotsListView(viewModel: viewModel)
                case 2:
                    TrendsView()
                default:
                    EmptyView()
                }
            }
            .navigationTitle("History")
            .onAppear {
                viewModel.loadData(from: coordinator)
            }
        }
    }
}

// MARK: - Sleep Sessions List

struct SleepSessionsListView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        if viewModel.sleepSessions.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("No Sleep Sessions")
                    .font(.headline)
                Text("Your recorded sleep sessions will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            List {
                ForEach(viewModel.sleepSessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SleepSessionRow(session: session, summary: viewModel.summaryFor(session: session))
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct SleepSessionRow: View {
    let session: SleepSession
    let summary: SleepSummary?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(session.startTime))
                    .font(.headline)

                Text(formatDuration(session.duration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let summary = summary {
                VStack {
                    Text("\(summary.sleepScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(summary.sleepScore))
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: date)
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

// MARK: - Snapshots List

struct SnapshotsListView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        if viewModel.snapshots.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "camera.metering.spot")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("No Snapshots")
                    .font(.headline)
                Text("Your HRV snapshots will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            List {
                ForEach(viewModel.snapshots) { snapshot in
                    SnapshotRow(snapshot: snapshot)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct SnapshotRow: View {
    let snapshot: HRVSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if snapshot.isMorningReadiness {
                        Image(systemName: "sun.horizon.fill")
                            .foregroundColor(.orange)
                    }
                    Text(formatDateTime(snapshot.timestamp))
                        .font(.headline)
                }

                HStack(spacing: 8) {
                    Text(snapshot.formattedDuration)
                    if let context = snapshot.context {
                        Text("•")
                        Text(context.rawValue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f ms", snapshot.rmssd))
                    .font(.headline)

                if let comparison = snapshot.comparedTo7DayBaseline {
                    Text("\(Int(comparison))%")
                        .font(.caption)
                        .foregroundColor(comparison >= 100 ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 4)
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
        do {
            sleepSessions = try coordinator.sessionRepository.loadAll()
        } catch {
            sleepSessions = []
        }
        snapshots = coordinator.snapshotRepository.loadAll()
        stressEvents = coordinator.stressEventRepository.loadAll()

        // Pre-calculate summaries
        for session in sleepSessions {
            sessionSummaries[session.id] = SleepSummaryCalculator.calculate(from: session)
        }
    }

    func summaryFor(session: SleepSession) -> SleepSummary? {
        sessionSummaries[session.id]
    }
}
