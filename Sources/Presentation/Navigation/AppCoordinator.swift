import Foundation
import Combine
import os.log

/// Coordinates app-wide state and services shared across all tabs
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Shared Services
    let bleManager: BLEManager
    let sleepDetectionEngine: SleepDetectionEngine
    let measurementCoordinator: MeasurementSessionCoordinator
    let stressMonitor: RealTimeStressMonitor
    let backgroundSleepManager: BackgroundSleepSessionManager

    // MARK: - Repositories
    let sessionRepository: SleepSessionRepository
    let summaryRepository: DailyHRVSummaryRepository
    let snapshotRepository: HRVSnapshotRepository
    let stressEventRepository: StressEventRepository
    let continuousDataRepository: ContinuousHRVDataRepository

    // MARK: - Published State
    @Published var selectedTab: Tab = .home
    @Published var showMorningReadinessPrompt: Bool = false
    @Published private(set) var baselineSource: BaselineSource = .none

    // MARK: - Baseline Source
    enum BaselineSource: String {
        case none = "No baseline"
        case populationDefault = "Default values"
        case continuousData = "Today's data"
        case historicalSleep = "7-day average"
    }

    // MARK: - Population Defaults (conservative values)
    private struct PopulationDefaults {
        static let heartRate: Double = 70  // Average resting HR
        static let rmssd: Double = 35      // Conservative RMSSD (works for most adults)
    }

    // MARK: - Tab Definition
    enum Tab: Int, CaseIterable {
        case home = 0
        case monitor = 1
        case insights = 2
        case history = 3
        case settings = 4

        var title: String {
            switch self {
            case .home: return "Home"
            case .monitor: return "Monitor"
            case .insights: return "Insights"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }

        var iconName: String {
            switch self {
            case .home: return "house.fill"
            case .monitor: return "waveform.path.ecg"
            case .insights: return "chart.bar.xaxis"
            case .history: return "calendar"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.sleeptracker", category: "AppCoordinator")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialize shared services
        self.bleManager = BLEManager.shared
        self.sleepDetectionEngine = SleepDetectionEngine()
        self.measurementCoordinator = MeasurementSessionCoordinator()
        self.stressMonitor = RealTimeStressMonitor()

        // Initialize repositories
        self.sessionRepository = SleepSessionRepository()
        self.summaryRepository = DailyHRVSummaryRepository()
        self.snapshotRepository = HRVSnapshotRepository()
        self.stressEventRepository = StressEventRepository()
        self.continuousDataRepository = ContinuousHRVDataRepository()

        // Initialize background sleep manager
        self.backgroundSleepManager = BackgroundSleepSessionManager(
            sleepDetectionEngine: sleepDetectionEngine,
            sessionRepository: sessionRepository
        )

        // Link stress monitor to sleep detection
        stressMonitor.sleepDetectionEngine = sleepDetectionEngine

        setupBindings()
        checkMorningReadiness()

        logger.info("AppCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Called when app becomes active
    func onAppBecomeActive() {
        checkMorningReadiness()
        loadBaselines()
    }

    /// Navigate to a specific tab
    func navigateTo(_ tab: Tab) {
        selectedTab = tab
    }

    /// Start continuous monitoring mode
    func startContinuousMonitoring() {
        measurementCoordinator.startSession(mode: .continuous)
    }

    /// Start morning readiness check
    func startMorningReadiness() {
        measurementCoordinator.startSession(mode: .morningReadiness)
        navigateTo(.monitor)
        showMorningReadinessPrompt = false
    }

    /// Start a quick snapshot
    func startSnapshot(context: SnapshotContext = .general) {
        measurementCoordinator.startSession(mode: .snapshot, context: context)
        navigateTo(.monitor)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Monitor connection state changes
        bleManager.$connectionState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .connected {
                    self.loadBaselines()
                    // Auto-start continuous monitoring when device connects
                    self.startContinuousMonitoringIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func startContinuousMonitoringIfNeeded() {
        // Only start if no session is active
        guard !measurementCoordinator.isSessionActive else { return }
        measurementCoordinator.startSession(mode: .continuous)
        logger.info("Auto-started continuous monitoring")
    }

    private func checkMorningReadiness() {
        showMorningReadinessPrompt = measurementCoordinator.shouldPromptMorningReadiness()
    }

    private func loadBaselines() {
        // Priority 1: Historical sleep data (most accurate, 7-day average)
        let summaries = summaryRepository.loadAll()
        if let baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries) {
            let avgHR = summaries.suffix(7).map { $0.meanHR }.reduce(0, +) / Double(min(7, summaries.count))
            applyBaseline(heartRate: avgHR, rmssd: baseline7d, source: .historicalSleep)
            return
        }

        // Priority 2: Today's continuous/snapshot data (personal but limited)
        if let (hr, rmssd) = calculateBaselineFromTodaysData() {
            applyBaseline(heartRate: hr, rmssd: rmssd, source: .continuousData)
            return
        }

        // Priority 3: Population defaults (fallback for new users)
        applyBaseline(
            heartRate: PopulationDefaults.heartRate,
            rmssd: PopulationDefaults.rmssd,
            source: .populationDefault
        )
        logger.info("Using population default baselines for new user")
    }

    private func applyBaseline(heartRate: Double, rmssd: Double, source: BaselineSource) {
        sleepDetectionEngine.setWakingBaseline(heartRate: heartRate, rmssd: rmssd)
        stressMonitor.setBaseline(rmssd: rmssd, restingHR: heartRate)
        measurementCoordinator.setBaseline(rmssd: rmssd)
        baselineSource = source
        logger.info("Applied baseline: HR=\(heartRate), RMSSD=\(rmssd), source=\(source.rawValue)")
    }

    private func calculateBaselineFromTodaysData() -> (heartRate: Double, rmssd: Double)? {
        let today = Date()

        // Collect data from continuous monitoring
        let continuousData = continuousDataRepository.loadForDate(today)
        let continuousSamples = continuousData.map { $0.sampleCount }.reduce(0, +)

        // Collect data from snapshots
        let snapshots = snapshotRepository.loadForDate(today)

        // Need at least 10 samples worth of data
        let totalSamples = continuousSamples + snapshots.count
        guard totalSamples >= 10 else { return nil }

        var totalHR: Double = 0
        var totalRMSSD: Double = 0
        var weightedCount: Double = 0

        // Add continuous data (weighted by sample count)
        for data in continuousData {
            totalHR += data.averageHR * Double(data.sampleCount)
            totalRMSSD += data.averageRMSSD * Double(data.sampleCount)
            weightedCount += Double(data.sampleCount)
        }

        // Add snapshot data (each snapshot = 1 sample)
        for snapshot in snapshots {
            totalHR += snapshot.averageHR
            totalRMSSD += snapshot.rmssd
            weightedCount += 1
        }

        guard weightedCount > 0 else { return nil }

        return (totalHR / weightedCount, totalRMSSD / weightedCount)
    }

    /// Update baselines with new real-time data (call periodically during monitoring)
    func updateBaselineWithNewData(heartRate: Double, rmssd: Double) {
        // Only update if we're using continuous data or defaults (not historical)
        guard baselineSource == .continuousData || baselineSource == .populationDefault else { return }

        // Recalculate from today's data
        if let (hr, newRmssd) = calculateBaselineFromTodaysData() {
            applyBaseline(heartRate: hr, rmssd: newRmssd, source: .continuousData)
        }
    }
}
