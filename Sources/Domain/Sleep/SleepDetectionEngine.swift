import Foundation
import Combine
import os.log

/// State machine for automatic sleep onset/offset detection
final class SleepDetectionEngine: ObservableObject {

    // MARK: - Published State
    @Published private(set) var currentState: SleepDetectionState = .awake
    @Published private(set) var isManualSleepMode: Bool = false

    // MARK: - Detection State
    enum SleepDetectionState: String {
        case awake = "Awake"
        case maybeAsleep = "Falling Asleep..."
        case sleeping = "Sleeping"
        case waking = "Waking Up..."

        var emoji: String {
            switch self {
            case .awake: return "☀️"
            case .maybeAsleep: return "😴"
            case .sleeping: return "🌙"
            case .waking: return "🌅"
            }
        }
    }

    // MARK: - Thresholds
    struct DetectionThresholds {
        // Sleep onset: HR drops + RMSSD increases
        let hrDropThreshold: Double = 0.85  // HR < 85% of waking baseline
        let rmssdIncreaseThreshold: Double = 1.10  // RMSSD > 110% of waking baseline

        // Wake detection: HR rises + RMSSD drops
        let hrRiseThreshold: Double = 0.95  // HR > 95% of waking baseline
        let rmssdDropThreshold: Double = 0.95  // RMSSD < 95% of waking baseline

        // Confirmation durations
        let sleepOnsetMinutes: TimeInterval = 10  // 10 minutes of sleep signals
        let sleepConfirmationMinutes: TimeInterval = 15  // 15 minutes to confirm sleeping
        let wakeOnsetMinutes: TimeInterval = 10  // 10 minutes of wake signals
        let wakeConfirmationMinutes: TimeInterval = 15  // 15 minutes to confirm awake

        // Minimum sleep duration to be considered valid
        let minimumSleepDuration: TimeInterval = 3600  // 1 hour
    }

    // MARK: - Properties
    private let thresholds = DetectionThresholds()
    private let logger = Logger(subsystem: "com.sleeptracker", category: "SleepDetection")

    // Waking baseline (established during day hours)
    private var wakingBaselineHR: Double?
    private var wakingBaselineRMSSD: Double?

    // Transition tracking
    private var transitionStartTime: Date?
    private var sleepStartTime: Date?

    // Rolling window of recent metrics
    private var recentMetrics: [MetricSample] = []
    private let metricWindowMinutes: Int = 15
    private let epochInterval: TimeInterval = 30  // 30-second epochs

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Update detection state with new HR and RMSSD values
    /// Call this every 30 seconds with aggregated epoch data
    func updateWithMetrics(heartRate: Double, rmssd: Double, timestamp: Date = Date()) {
        // Store metric sample
        recentMetrics.append(MetricSample(hr: heartRate, rmssd: rmssd, timestamp: timestamp))

        // Trim old samples (keep last 15 minutes)
        let cutoff = timestamp.addingTimeInterval(-Double(metricWindowMinutes * 60))
        recentMetrics.removeAll { $0.timestamp < cutoff }

        // Skip detection if no baseline established
        guard let baselineHR = wakingBaselineHR,
              let baselineRMSSD = wakingBaselineRMSSD else {
            logger.debug("Skipping detection - no baseline established")
            return
        }

        // If manual sleep mode is on, skip auto-detection but still track
        if isManualSleepMode && currentState != .sleeping {
            transitionToState(.sleeping, timestamp: timestamp)
            return
        }

        // Calculate normalized values
        let hrRatio = heartRate / baselineHR
        let rmssdRatio = rmssd / baselineRMSSD

        // Run state machine
        processStateTransition(hrRatio: hrRatio, rmssdRatio: rmssdRatio, timestamp: timestamp)
    }

    /// Set waking baseline from recent waking data
    func setWakingBaseline(heartRate: Double, rmssd: Double) {
        wakingBaselineHR = heartRate
        wakingBaselineRMSSD = rmssd
        logger.info("Waking baseline set - HR: \(heartRate), RMSSD: \(rmssd)")
    }

    /// Calculate waking baseline from array of samples (call during daytime)
    func calculateWakingBaseline(from samples: [MetricSample]) {
        guard samples.count >= 10 else {
            logger.warning("Not enough samples for baseline calculation")
            return
        }

        let avgHR = samples.map { $0.hr }.reduce(0, +) / Double(samples.count)
        let avgRMSSD = samples.map { $0.rmssd }.reduce(0, +) / Double(samples.count)

        setWakingBaseline(heartRate: avgHR, rmssd: avgRMSSD)
    }

    /// Manually start sleep tracking (fallback for auto-detection)
    func startManualSleepMode() {
        isManualSleepMode = true
        transitionToState(.sleeping, timestamp: Date())
        logger.info("Manual sleep mode started")
    }

    /// Manually stop sleep tracking
    func stopManualSleepMode() {
        isManualSleepMode = false
        if currentState == .sleeping {
            transitionToState(.awake, timestamp: Date())
        }
        logger.info("Manual sleep mode stopped")
    }

    /// Reset detection state
    func reset() {
        currentState = .awake
        isManualSleepMode = false
        transitionStartTime = nil
        sleepStartTime = nil
        recentMetrics.removeAll()
        logger.info("Sleep detection reset")
    }

    /// Check if sleep recording should start
    var shouldStartSleepRecording: Bool {
        return currentState == .sleeping && sleepStartTime != nil
    }

    /// Check if sleep recording should stop (wake detected after sufficient sleep)
    func shouldStopSleepRecording() -> Bool {
        guard currentState == .awake,
              let sleepStart = sleepStartTime else {
            return false
        }

        let sleepDuration = Date().timeIntervalSince(sleepStart)
        return sleepDuration >= thresholds.minimumSleepDuration
    }

    /// Get current sleep duration if sleeping
    var currentSleepDuration: TimeInterval? {
        guard let sleepStart = sleepStartTime else { return nil }
        return Date().timeIntervalSince(sleepStart)
    }

    /// Get formatted sleep duration
    var formattedSleepDuration: String? {
        guard let duration = currentSleepDuration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }

    // MARK: - Private Methods

    private func processStateTransition(hrRatio: Double, rmssdRatio: Double, timestamp: Date) {
        let isSleepSignal = hrRatio < thresholds.hrDropThreshold &&
                           rmssdRatio > thresholds.rmssdIncreaseThreshold

        let isWakeSignal = hrRatio > thresholds.hrRiseThreshold &&
                          rmssdRatio < thresholds.rmssdDropThreshold

        switch currentState {
        case .awake:
            if isSleepSignal {
                // Start tracking potential sleep onset
                if transitionStartTime == nil {
                    transitionStartTime = timestamp
                    transitionToState(.maybeAsleep, timestamp: timestamp)
                }
            } else {
                transitionStartTime = nil
            }

        case .maybeAsleep:
            if isSleepSignal {
                // Check if we've met the confirmation threshold
                if let startTime = transitionStartTime {
                    let duration = timestamp.timeIntervalSince(startTime)
                    if duration >= thresholds.sleepConfirmationMinutes * 60 {
                        transitionToState(.sleeping, timestamp: timestamp)
                        sleepStartTime = startTime
                    }
                }
            } else {
                // False alarm - return to awake
                transitionToState(.awake, timestamp: timestamp)
                transitionStartTime = nil
            }

        case .sleeping:
            if isWakeSignal {
                // Start tracking potential wake
                if transitionStartTime == nil {
                    transitionStartTime = timestamp
                    transitionToState(.waking, timestamp: timestamp)
                }
            } else {
                transitionStartTime = nil
            }

        case .waking:
            if isWakeSignal {
                // Check if we've met the wake confirmation threshold
                if let startTime = transitionStartTime {
                    let duration = timestamp.timeIntervalSince(startTime)
                    if duration >= thresholds.wakeConfirmationMinutes * 60 {
                        transitionToState(.awake, timestamp: timestamp)
                        isManualSleepMode = false
                    }
                }
            } else {
                // False alarm - return to sleeping
                transitionToState(.sleeping, timestamp: timestamp)
                transitionStartTime = nil
            }
        }
    }

    private func transitionToState(_ newState: SleepDetectionState, timestamp: Date) {
        guard newState != currentState else { return }

        let oldState = currentState
        currentState = newState

        logger.info("Sleep state transition: \(oldState.rawValue) -> \(newState.rawValue)")

        // Reset transition tracking when entering a stable state
        if newState == .awake || newState == .sleeping {
            transitionStartTime = nil
        }

        // Reset sleep start time when waking up
        if newState == .awake {
            sleepStartTime = nil
        }
    }
}

// MARK: - Metric Sample

extension SleepDetectionEngine {
    struct MetricSample {
        let hr: Double
        let rmssd: Double
        let timestamp: Date
    }
}
