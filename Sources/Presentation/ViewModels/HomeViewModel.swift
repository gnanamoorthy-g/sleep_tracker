import Foundation
import Combine

/// ViewModel for the Home dashboard
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var latestReport: RecoveryIntelligenceEngine.IntelligenceReport?
    @Published var lastNightsSleep: SleepSession?
    @Published var lastNightsSummary: SleepSummary?
    @Published var todaysMorningReadiness: HRVSnapshot?
    @Published var hasMorningReadinessToday: Bool = false
    @Published var baseline7d: Double?
    @Published var avgSleepScore: Int?
    @Published var weeklyStressCount: Int = 0
    @Published var dailyHRVComparison: DailyHRVComparison?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    func loadData(from coordinator: AppCoordinator) {
        loadSleepData(from: coordinator)
        loadMorningReadiness(from: coordinator)
        loadStressData(from: coordinator)
        loadBaselines(from: coordinator)
        loadRecoveryReport(from: coordinator)
        loadDailyHRVComparison(from: coordinator)
    }

    // MARK: - Private Methods

    private func loadSleepData(from coordinator: AppCoordinator) {
        let sessions: [SleepSession]
        do {
            sessions = try coordinator.sessionRepository.loadAll()
        } catch {
            sessions = []
        }

        // Find last night's session (ended today between midnight and noon)
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let noon = calendar.date(byAdding: .hour, value: 12, to: todayStart)!

        lastNightsSleep = sessions.first { session in
            guard let endTime = session.endTime else { return false }
            return endTime >= todayStart && endTime <= noon
        }

        // Calculate summary for last night's session
        if let session = lastNightsSleep {
            lastNightsSummary = SleepSummaryCalculator.calculate(from: session)
        }

        // Calculate average sleep score for last 7 days
        let last7Days = sessions.prefix(7)
        let scores = last7Days.compactMap { session -> Int? in
            let summary = SleepSummaryCalculator.calculate(from: session)
            return summary.sleepScore
        }
        if !scores.isEmpty {
            avgSleepScore = scores.reduce(0, +) / scores.count
        }
    }

    private func loadMorningReadiness(from coordinator: AppCoordinator) {
        hasMorningReadinessToday = coordinator.measurementCoordinator.hasMorningReadinessToday()
        todaysMorningReadiness = coordinator.snapshotRepository.loadForDate(Date())
            .first { $0.isMorningReadiness }
    }

    private func loadStressData(from coordinator: AppCoordinator) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let events = coordinator.stressEventRepository.loadForDateRange(from: weekAgo, to: Date())
        weeklyStressCount = events.count
    }

    private func loadBaselines(from coordinator: AppCoordinator) {
        let summaries = coordinator.summaryRepository.loadAll()
        baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries)
    }

    private func loadRecoveryReport(from coordinator: AppCoordinator) {
        let summaries = coordinator.summaryRepository.loadAll()

        guard let latest = summaries.last else { return }

        let historical = Array(summaries.dropLast())
        latestReport = RecoveryIntelligenceEngine.analyze(
            todaySummary: latest,
            historicalSummaries: historical
        )
    }

    private func loadDailyHRVComparison(from coordinator: AppCoordinator) {
        let today = Date()

        // Get morning readiness snapshot
        let morningSnapshot = coordinator.snapshotRepository.loadForDate(today)
            .first { $0.isMorningReadiness }

        // Get all snapshots for today
        let allSnapshots = coordinator.snapshotRepository.loadForDate(today)

        // Get continuous monitoring data for today
        let continuousData = coordinator.continuousDataRepository.loadForDate(today)

        // Create comparison
        dailyHRVComparison = DailyHRVComparison.create(
            date: today,
            morningSnapshot: morningSnapshot,
            continuousData: continuousData,
            allSnapshots: allSnapshots,
            baseline7d: baseline7d
        )
    }
}
