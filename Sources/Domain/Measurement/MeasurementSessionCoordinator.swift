import Foundation
import Combine
import os.log

/// Coordinates measurement sessions across different modes
@MainActor
final class MeasurementSessionCoordinator: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var currentMode: MeasurementMode?
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var snapshotContext: SnapshotContext = .general
    @Published private(set) var lastCompletedSnapshot: HRVSnapshot?

    // MARK: - Session Progress
    @Published private(set) var progress: Double = 0  // 0.0 to 1.0
    @Published private(set) var sessionComplete: Bool = false  // Signals timed session completion

    // MARK: - Dependencies
    private let snapshotRepository = HRVSnapshotRepository()
    private let continuousDataRepository = ContinuousHRVDataRepository()
    private let logger = Logger(subsystem: "com.sleeptracker", category: "MeasurementSession")

    // MARK: - Private Properties
    private var timerCancellable: AnyCancellable?
    private var sessionCancellable: AnyCancellable?
    private var hourlyFlushCancellable: AnyCancellable?

    // Collected data during session
    private var collectedHeartRates: [Int] = []
    private var collectedRMSSDs: [Double] = []
    private var collectedSDNNs: [Double] = []
    private var collectedPNN50s: [Double] = []

    // Continuous data buffer (flushed hourly)
    private var continuousHeartRates: [Int] = []
    private var continuousRMSSDs: [Double] = []
    private var continuousSDNNs: [Double] = []
    private var continuousPNN50s: [Double] = []
    private var continuousStartTime: Date?
    private var lastHourlySave: Int = -1  // Track hour to avoid duplicate saves

    // Baseline for comparison
    private var baseline7dRMSSD: Double?

    // MARK: - UserDefaults Keys
    private let lastMorningReadinessKey = "com.sleeptracker.lastMorningReadinessDate"

    // MARK: - Public Methods

    /// Set 7-day baseline for comparison
    func setBaseline(rmssd: Double) {
        baseline7dRMSSD = rmssd
    }

    /// Add sample data during session
    func addSample(heartRate: Int, rmssd: Double, sdnn: Double?, pnn50: Double?) {
        guard isSessionActive else { return }
        collectedHeartRates.append(heartRate)
        collectedRMSSDs.append(rmssd)
        if let sdnn = sdnn { collectedSDNNs.append(sdnn) }
        if let pnn50 = pnn50 { collectedPNN50s.append(pnn50) }

        // Also collect for continuous mode hourly aggregation
        if currentMode == .continuous {
            if continuousStartTime == nil {
                continuousStartTime = Date()
            }
            continuousHeartRates.append(heartRate)
            continuousRMSSDs.append(rmssd)
            if let sdnn = sdnn { continuousSDNNs.append(sdnn) }
            if let pnn50 = pnn50 { continuousPNN50s.append(pnn50) }

            // Check if we need to flush (on hour change)
            checkAndFlushHourlyData()
        }
    }

    /// Check if hour changed and flush data
    private func checkAndFlushHourlyData() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        if lastHourlySave != currentHour && !continuousRMSSDs.isEmpty {
            flushContinuousData()
            lastHourlySave = currentHour
        }
    }

    /// Flush continuous data to storage
    private func flushContinuousData() {
        guard !continuousRMSSDs.isEmpty, let startTime = continuousStartTime else { return }

        let avgHR = Double(continuousHeartRates.reduce(0, +)) / Double(max(1, continuousHeartRates.count))
        let minHR = Double(continuousHeartRates.min() ?? 0)
        let maxHR = Double(continuousHeartRates.max() ?? 0)
        let avgRMSSD = continuousRMSSDs.reduce(0, +) / Double(max(1, continuousRMSSDs.count))
        let avgSDNN = continuousSDNNs.isEmpty ? avgRMSSD * 1.2 : continuousSDNNs.reduce(0, +) / Double(continuousSDNNs.count)
        let avgPNN50: Double? = continuousPNN50s.isEmpty ? nil : continuousPNN50s.reduce(0, +) / Double(continuousPNN50s.count)

        let duration = Date().timeIntervalSince(startTime)

        let sampleCount = continuousRMSSDs.count

        let data = ContinuousHRVData(
            date: startTime,
            averageHR: avgHR,
            minHR: minHR,
            maxHR: maxHR,
            averageRMSSD: avgRMSSD,
            averageSDNN: avgSDNN,
            averagePNN50: avgPNN50,
            sampleCount: sampleCount,
            duration: duration
        )

        continuousDataRepository.save(data)
        logger.info("Saved hourly continuous data: RMSSD=\(avgRMSSD), samples=\(sampleCount)")

        // Clear buffer
        continuousHeartRates.removeAll()
        continuousRMSSDs.removeAll()
        continuousSDNNs.removeAll()
        continuousPNN50s.removeAll()
        continuousStartTime = Date()
    }

    /// Start a measurement session
    func startSession(mode: MeasurementMode, context: SnapshotContext = .general) {
        guard !isSessionActive else {
            logger.warning("Session already active")
            return
        }

        // Check morning readiness once-per-day constraint
        if mode == .morningReadiness && hasMorningReadinessToday() {
            logger.warning("Morning readiness already completed today")
            return
        }

        currentMode = mode
        snapshotContext = context
        sessionStartTime = Date()
        isSessionActive = true
        elapsedTime = 0
        progress = 0
        sessionComplete = false

        // Clear collected data
        collectedHeartRates.removeAll()
        collectedRMSSDs.removeAll()
        collectedSDNNs.removeAll()
        collectedPNN50s.removeAll()

        logger.info("Started \(mode.rawValue) session")

        // Start timer for timed sessions
        if let duration = mode.duration {
            startTimer(duration: duration)
        } else {
            // Continuous mode - just start the timer for tracking
            startContinuousTimer()
        }
    }

    /// Stop the current session and return results
    func stopSession() -> MeasurementSessionResult? {
        guard isSessionActive, let mode = currentMode, let startTime = sessionStartTime else {
            return nil
        }

        timerCancellable?.cancel()
        timerCancellable = nil

        let duration = Date().timeIntervalSince(startTime)

        // For timed sessions (snapshot/morning readiness), save the snapshot if we have enough data
        if mode != .continuous && !collectedRMSSDs.isEmpty {
            saveSnapshotForSession(mode: mode, startTime: startTime, duration: duration)
        }

        // For continuous mode, flush any remaining data
        if mode == .continuous && !continuousRMSSDs.isEmpty {
            flushContinuousData()
        }

        let result = MeasurementSessionResult(
            mode: mode,
            context: snapshotContext,
            startTime: startTime,
            endTime: Date(),
            duration: duration,
            snapshot: lastCompletedSnapshot
        )

        // Record morning readiness completion
        if mode == .morningReadiness {
            recordMorningReadinessCompletion()
        }

        resetSession()

        logger.info("Stopped \(mode.rawValue) session, duration: \(duration)s")
        return result
    }

    /// Save snapshot for manually stopped session
    private func saveSnapshotForSession(mode: MeasurementMode, startTime: Date, duration: TimeInterval) {
        // Calculate averages
        let avgHR = Double(collectedHeartRates.reduce(0, +)) / Double(max(1, collectedHeartRates.count))
        let minHR = Double(collectedHeartRates.min() ?? 0)
        let maxHR = Double(collectedHeartRates.max() ?? 0)
        let avgRMSSD = collectedRMSSDs.reduce(0, +) / Double(max(1, collectedRMSSDs.count))
        let avgSDNN = collectedSDNNs.isEmpty ? avgRMSSD * 1.2 : collectedSDNNs.reduce(0, +) / Double(collectedSDNNs.count)
        let avgPNN50: Double? = collectedPNN50s.isEmpty ? nil : collectedPNN50s.reduce(0, +) / Double(collectedPNN50s.count)

        // Calculate comparison to baseline
        var comparedTo7DayBaseline: Double?
        if let baseline = baseline7dRMSSD, baseline > 0 {
            comparedTo7DayBaseline = (avgRMSSD / baseline) * 100
        }

        var recoveryScore: Int?
        if let comparison = comparedTo7DayBaseline {
            recoveryScore = min(100, Int(comparison))
        }

        let snapshot = HRVSnapshot(
            timestamp: startTime,
            duration: duration,
            measurementMode: mode,
            context: snapshotContext,
            averageHR: avgHR,
            minHR: minHR,
            maxHR: maxHR,
            rmssd: avgRMSSD,
            sdnn: avgSDNN,
            pnn50: avgPNN50,
            comparedTo7DayBaseline: comparedTo7DayBaseline,
            recoveryScore: recoveryScore
        )

        snapshotRepository.save(snapshot)
        lastCompletedSnapshot = snapshot

        logger.info("Saved \(mode.rawValue) snapshot on manual stop: RMSSD=\(avgRMSSD)")
    }

    /// Cancel the current session without saving
    func cancelSession() {
        guard isSessionActive else { return }

        timerCancellable?.cancel()
        timerCancellable = nil
        resetSession()

        logger.info("Session cancelled")
    }

    /// Check if morning readiness prompt should be shown
    func shouldPromptMorningReadiness() -> Bool {
        // Only prompt between 6 AM and 11 AM
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 6 && hour < 11 else { return false }

        return !hasMorningReadinessToday()
    }

    /// Check if morning readiness has been completed today
    func hasMorningReadinessToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastMorningReadinessKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// Get the last morning readiness date
    var lastMorningReadinessDate: Date? {
        UserDefaults.standard.object(forKey: lastMorningReadinessKey) as? Date
    }

    /// Save a completed snapshot
    func saveSnapshot(_ snapshot: HRVSnapshot) {
        snapshotRepository.save(snapshot)
    }

    /// Get today's snapshots
    func todaysSnapshots() -> [HRVSnapshot] {
        snapshotRepository.loadForDate(Date())
    }

    /// Get all snapshots
    func allSnapshots() -> [HRVSnapshot] {
        snapshotRepository.loadAll()
    }

    // MARK: - Private Methods

    private func startTimer(duration: TimeInterval) {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.sessionStartTime else { return }

                self.elapsedTime = Date().timeIntervalSince(startTime)
                self.progress = min(self.elapsedTime / duration, 1.0)

                // Auto-complete when duration reached
                if self.elapsedTime >= duration && !self.sessionComplete {
                    self.sessionComplete = true
                    self.timerCancellable?.cancel()
                    // Auto-save snapshot for timed sessions
                    self.completeTimedSession()
                }
            }
    }

    /// Complete a timed session (snapshot or morning readiness)
    private func completeTimedSession() {
        guard let mode = currentMode, let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)

        // Only create snapshot if we have enough data
        guard !collectedRMSSDs.isEmpty else {
            logger.warning("No HRV data collected during session")
            resetSession()
            return
        }

        // Calculate averages
        let avgHR = Double(collectedHeartRates.reduce(0, +)) / Double(max(1, collectedHeartRates.count))
        let minHR = Double(collectedHeartRates.min() ?? 0)
        let maxHR = Double(collectedHeartRates.max() ?? 0)
        let avgRMSSD = collectedRMSSDs.reduce(0, +) / Double(max(1, collectedRMSSDs.count))
        let avgSDNN = collectedSDNNs.isEmpty ? avgRMSSD * 1.2 : collectedSDNNs.reduce(0, +) / Double(collectedSDNNs.count)
        let avgPNN50: Double? = collectedPNN50s.isEmpty ? nil : collectedPNN50s.reduce(0, +) / Double(collectedPNN50s.count)

        // Calculate comparison to baseline
        var comparedTo7DayBaseline: Double?
        if let baseline = baseline7dRMSSD, baseline > 0 {
            comparedTo7DayBaseline = (avgRMSSD / baseline) * 100
        }

        // Calculate recovery score based on baseline comparison
        var recoveryScore: Int?
        if let comparison = comparedTo7DayBaseline {
            recoveryScore = min(100, Int(comparison))
        }

        // Create and save snapshot
        let snapshot = HRVSnapshot(
            timestamp: startTime,
            duration: duration,
            measurementMode: mode,
            context: snapshotContext,
            averageHR: avgHR,
            minHR: minHR,
            maxHR: maxHR,
            rmssd: avgRMSSD,
            sdnn: avgSDNN,
            pnn50: avgPNN50,
            comparedTo7DayBaseline: comparedTo7DayBaseline,
            recoveryScore: recoveryScore
        )

        snapshotRepository.save(snapshot)
        lastCompletedSnapshot = snapshot

        logger.info("Saved \(mode.rawValue) snapshot: RMSSD=\(avgRMSSD), HR=\(avgHR)")

        // Record morning readiness completion
        if mode == .morningReadiness {
            recordMorningReadinessCompletion()
        }

        resetSession()
    }

    private func startContinuousTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.sessionStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
    }

    private func recordMorningReadinessCompletion() {
        UserDefaults.standard.set(Date(), forKey: lastMorningReadinessKey)
        logger.info("Recorded morning readiness completion")
    }

    private func resetSession() {
        currentMode = nil
        sessionStartTime = nil
        isSessionActive = false
        elapsedTime = 0
        progress = 0
        sessionComplete = false
        collectedHeartRates.removeAll()
        collectedRMSSDs.removeAll()
        collectedSDNNs.removeAll()
        collectedPNN50s.removeAll()
        // Also reset continuous data tracking
        continuousHeartRates.removeAll()
        continuousRMSSDs.removeAll()
        continuousSDNNs.removeAll()
        continuousPNN50s.removeAll()
        continuousStartTime = nil
    }
}

// MARK: - Session Result

struct MeasurementSessionResult {
    let mode: MeasurementMode
    let context: SnapshotContext
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let snapshot: HRVSnapshot?

    init(mode: MeasurementMode, context: SnapshotContext, startTime: Date, endTime: Date, duration: TimeInterval, snapshot: HRVSnapshot? = nil) {
        self.mode = mode
        self.context = context
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.snapshot = snapshot
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
