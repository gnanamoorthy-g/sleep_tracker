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

    // MARK: - Tab Definition
    enum Tab: Int, CaseIterable {
        case home = 0
        case monitor = 1
        case history = 2
        case settings = 3

        var title: String {
            switch self {
            case .home: return "Home"
            case .monitor: return "Monitor"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }

        var iconName: String {
            switch self {
            case .home: return "house.fill"
            case .monitor: return "waveform.path.ecg"
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
        // Load historical data for baselines
        let summaries = summaryRepository.loadAll()

        // Calculate and set baseline for sleep detection
        if let baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries) {
            let avgHR = summaries.suffix(7).map { $0.meanHR }.reduce(0, +) / Double(min(7, summaries.count))
            sleepDetectionEngine.setWakingBaseline(heartRate: avgHR, rmssd: baseline7d)
            stressMonitor.setBaseline(rmssd: baseline7d, restingHR: avgHR)
            // Also set baseline for snapshot comparison
            measurementCoordinator.setBaseline(rmssd: baseline7d)
        }
    }
}
