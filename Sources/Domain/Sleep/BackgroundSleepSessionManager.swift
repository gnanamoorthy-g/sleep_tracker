import Foundation
import Combine
import os.log

/// Manages automatic sleep session recording based on SleepDetectionEngine state
@MainActor
final class BackgroundSleepSessionManager: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var currentSession: SleepSessionInProgress?
    @Published private(set) var lastCompletedSession: SleepSession?

    // MARK: - Dependencies
    private let sleepDetectionEngine: SleepDetectionEngine
    private let sessionRepository: SleepSessionRepository
    private let logger = Logger(subsystem: "com.sleeptracker", category: "BackgroundSleepSession")

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private var collectedSamples: [HRVSample] = []
    private var collectedEpochs: [SleepEpoch] = []

    // MARK: - Initialization

    init(sleepDetectionEngine: SleepDetectionEngine, sessionRepository: SleepSessionRepository = SleepSessionRepository()) {
        self.sleepDetectionEngine = sleepDetectionEngine
        self.sessionRepository = sessionRepository

        setupBindings()
    }

    // MARK: - Public Methods

    /// Add a sample to the current recording session
    func addSample(_ sample: HRVSample) {
        guard isRecording else { return }
        collectedSamples.append(sample)
    }

    /// Add an epoch to the current recording session
    func addEpoch(_ epoch: SleepEpoch) {
        guard isRecording else { return }
        collectedEpochs.append(epoch)
        updateCurrentSession()
    }

    /// Manually start recording (when user uses manual sleep toggle)
    func startManualRecording() {
        sleepDetectionEngine.startManualSleepMode()
        startRecording()
    }

    /// Manually stop recording
    func stopManualRecording() -> SleepSession? {
        sleepDetectionEngine.stopManualSleepMode()
        return stopRecording()
    }

    /// Get current recording duration
    var currentDuration: TimeInterval? {
        guard let startTime = sessionStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    /// Get formatted duration string
    var formattedDuration: String {
        guard let duration = currentDuration else { return "0:00:00" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen to sleep detection state changes
        sleepDetectionEngine.$currentState
            .removeDuplicates()
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: SleepDetectionEngine.SleepDetectionState) {
        switch state {
        case .sleeping:
            if !isRecording {
                startRecording()
            }
        case .awake:
            if isRecording && sleepDetectionEngine.shouldStopSleepRecording() {
                _ = stopRecording()
            }
        case .maybeAsleep, .waking:
            // Transitional states - don't change recording
            break
        }
    }

    private func startRecording() {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }

        sessionStartTime = Date()
        collectedSamples.removeAll()
        collectedEpochs.removeAll()
        isRecording = true

        currentSession = SleepSessionInProgress(
            startTime: sessionStartTime!,
            sampleCount: 0,
            epochCount: 0
        )

        logger.info("Started sleep session recording")
    }

    @discardableResult
    private func stopRecording() -> SleepSession? {
        guard isRecording, let startTime = sessionStartTime else {
            logger.warning("Not recording")
            return nil
        }

        let endTime = Date()
        isRecording = false

        // Create sleep session
        var session = SleepSession(id: UUID(), startTime: startTime)
        session.endTime = endTime
        session.samples = collectedSamples

        // Only save if session is long enough (> 1 hour)
        let duration = endTime.timeIntervalSince(startTime)
        if duration >= 3600 {
            do {
                try sessionRepository.save(session)
                lastCompletedSession = session
                logger.info("Saved sleep session: \(session.id), duration: \(duration / 3600)h")
            } catch {
                logger.error("Failed to save sleep session: \(error.localizedDescription)")
            }
        } else {
            logger.info("Discarded short session: \(duration / 60)m")
        }

        // Reset state
        sessionStartTime = nil
        collectedSamples.removeAll()
        collectedEpochs.removeAll()
        currentSession = nil

        return session
    }

    private func updateCurrentSession() {
        guard let startTime = sessionStartTime else { return }

        currentSession = SleepSessionInProgress(
            startTime: startTime,
            sampleCount: collectedSamples.count,
            epochCount: collectedEpochs.count
        )
    }
}

// MARK: - Session In Progress

struct SleepSessionInProgress {
    let startTime: Date
    let sampleCount: Int
    let epochCount: Int

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}
