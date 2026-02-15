import Foundation
import Combine
import os.log

/// Production-grade state machine for automatic sleep onset/offset detection
/// Features: Circadian constraints, pre-bed baseline, hysteresis, sleep probability scoring
final class SleepDetectionEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentState: SleepDetectionState = .awake
    @Published private(set) var sleepProbability: Double = 0
    @Published private(set) var sleepStartTime: Date?
    @Published private(set) var currentPhaseDuration: TimeInterval = 0
    @Published private(set) var isManualSleepMode: Bool = false

    // MARK: - Detection State

    enum SleepDetectionState: String {
        case awake = "Awake"
        case preSleep = "Falling Asleep"
        case sleeping = "Sleeping"
        case waking = "Waking Up"

        var emoji: String {
            switch self {
            case .awake: return "☀️"
            case .preSleep: return "😴"
            case .sleeping: return "🌙"
            case .waking: return "🌅"
            }
        }
    }

    // MARK: - Configuration

    struct Configuration {
        // Circadian window - only detect sleep during these hours
        let sleepWindowStartHour: Int
        let sleepWindowEndHour: Int

        // Sleep probability thresholds
        let sleepOnsetThreshold: Double
        let sleepConfirmThreshold: Double
        let wakeThreshold: Double

        // Confirmation durations (hysteresis) - in minutes
        let sleepOnsetMinutes: Int
        let sleepConfirmMinutes: Int
        let wakeOnsetMinutes: Int
        let wakeConfirmMinutes: Int

        // Minimum sleep duration to be valid (in minutes)
        let minimumSleepMinutes: Int

        // Pre-bed baseline window (hours)
        let preBedBaselineHours: Int

        // Component weights for sleep probability
        let hrDropWeight: Double
        let rmssdRiseWeight: Double
        let stabilityWeight: Double

        static let `default` = Configuration(
            sleepWindowStartHour: 18,  // 6 PM
            sleepWindowEndHour: 10,    // 10 AM
            sleepOnsetThreshold: 0.75,
            sleepConfirmThreshold: 0.80,
            wakeThreshold: 0.30,
            sleepOnsetMinutes: 10,
            sleepConfirmMinutes: 15,
            wakeOnsetMinutes: 5,
            wakeConfirmMinutes: 15,
            minimumSleepMinutes: 60,
            preBedBaselineHours: 3,
            hrDropWeight: 0.40,
            rmssdRiseWeight: 0.30,
            stabilityWeight: 0.30
        )
    }

    // MARK: - Adaptive Baseline

    struct AdaptiveBaseline {
        var heartRate: Double
        var rmssd: Double
        var hrStdDev: Double

        static let `default` = AdaptiveBaseline(heartRate: 70, rmssd: 40, hrStdDev: 5)
    }

    // MARK: - Metric Sample

    struct MetricSample {
        let hr: Double
        let rmssd: Double
        let hrStdDev: Double
        let timestamp: Date

        init(hr: Double, rmssd: Double, hrStdDev: Double = 0, timestamp: Date = Date()) {
            self.hr = hr
            self.rmssd = rmssd
            self.hrStdDev = hrStdDev
            self.timestamp = timestamp
        }
    }

    // MARK: - Properties

    private let config: Configuration
    private let logger = Logger(subsystem: "com.sleeptracker", category: "SleepDetection")

    // Baselines
    private var preBedBaseline: AdaptiveBaseline = .default
    private var adaptiveBaseline: AdaptiveBaseline = .default

    // State tracking
    private var stateEntryTime: Date?
    private var consecutiveHighProbabilityCount: Int = 0
    private var consecutiveLowProbabilityCount: Int = 0

    // Rolling window of recent metrics
    private var recentMetrics: [MetricSample] = []
    private let metricWindowMinutes: Int = 30
    private let sampleIntervalSeconds: TimeInterval = 30

    // Callbacks
    var onSleepStart: ((Date) -> Void)?
    var onWakeDetected: ((Date) -> Void)?
    var onStateChange: ((SleepDetectionState, SleepDetectionState) -> Void)?

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Update with new HR and RMSSD values
    /// Call every 30 seconds with aggregated data
    func update(heartRate: Double, rmssd: Double, hrStdDev: Double = 0, timestamp: Date = Date()) {
        // Store sample
        let sample = MetricSample(hr: heartRate, rmssd: rmssd, hrStdDev: hrStdDev, timestamp: timestamp)
        recentMetrics.append(sample)
        trimOldSamples(before: timestamp)

        // Handle manual sleep mode
        if isManualSleepMode && currentState != .sleeping {
            transitionTo(.sleeping, timestamp: timestamp)
            sleepStartTime = timestamp
            return
        }

        // Check circadian window
        if !isWithinSleepWindow(timestamp) {
            if currentState == .sleeping {
                logger.info("Outside sleep window but sleeping - continuing to track")
                // Continue tracking if already sleeping
            } else {
                // Outside sleep window, keep as awake
                return
            }
        }

        // Calculate sleep probability
        let probability = calculateSleepProbability(sample: sample)
        sleepProbability = probability

        // Apply hysteresis state machine
        processStateTransition(probability: probability, timestamp: timestamp)

        // Update phase duration
        if let entryTime = stateEntryTime {
            currentPhaseDuration = timestamp.timeIntervalSince(entryTime)
        }
    }

    /// Legacy method for backward compatibility
    func updateWithMetrics(heartRate: Double, rmssd: Double, timestamp: Date = Date()) {
        update(heartRate: heartRate, rmssd: rmssd, hrStdDev: 0, timestamp: timestamp)
    }

    /// Calculate pre-bed baseline from last 3 hours of waking data
    func calculatePreBedBaseline(from samples: [MetricSample]) {
        guard samples.count >= 10 else {
            logger.warning("Insufficient samples for pre-bed baseline")
            return
        }

        // Filter to last 3 hours
        let cutoff = Date().addingTimeInterval(-Double(config.preBedBaselineHours) * 3600)
        let preBedSamples = samples.filter { $0.timestamp >= cutoff }

        guard preBedSamples.count >= 5 else {
            logger.warning("Insufficient pre-bed samples")
            return
        }

        // Calculate medians (more robust than mean)
        let hrs = preBedSamples.map { $0.hr }.sorted()
        let rmssds = preBedSamples.map { $0.rmssd }.sorted()
        let stdDevs = preBedSamples.map { $0.hrStdDev }.sorted()

        let medianHR = hrs[hrs.count / 2]
        let medianRMSSD = rmssds[rmssds.count / 2]
        let medianStdDev = stdDevs[stdDevs.count / 2]

        preBedBaseline = AdaptiveBaseline(
            heartRate: medianHR,
            rmssd: medianRMSSD,
            hrStdDev: medianStdDev
        )

        adaptiveBaseline = preBedBaseline

        logger.info("Pre-bed baseline set - HR: \(String(format: "%.1f", medianHR)), RMSSD: \(String(format: "%.1f", medianRMSSD))")
    }

    /// Set waking baseline from recent waking data (legacy support)
    func setWakingBaseline(heartRate: Double, rmssd: Double) {
        adaptiveBaseline = AdaptiveBaseline(heartRate: heartRate, rmssd: rmssd, hrStdDev: 5)
        preBedBaseline = adaptiveBaseline
        logger.info("Waking baseline set - HR: \(heartRate), RMSSD: \(rmssd)")
    }

    /// Calculate waking baseline from array of samples (legacy support)
    func calculateWakingBaseline(from samples: [MetricSample]) {
        guard samples.count >= 10 else {
            logger.warning("Not enough samples for baseline calculation")
            return
        }

        let avgHR = samples.map { $0.hr }.reduce(0, +) / Double(samples.count)
        let avgRMSSD = samples.map { $0.rmssd }.reduce(0, +) / Double(samples.count)

        setWakingBaseline(heartRate: avgHR, rmssd: avgRMSSD)
    }

    /// Manually start sleep tracking (fallback)
    func startManualSleepMode() {
        isManualSleepMode = true
        transitionTo(.sleeping, timestamp: Date())
        sleepStartTime = Date()
        logger.info("Manual sleep mode started")
    }

    /// Manually stop sleep tracking
    func stopManualSleepMode() {
        isManualSleepMode = false
        transitionTo(.awake, timestamp: Date())
        logger.info("Manual sleep mode stopped")
    }

    /// Reset detection state
    func reset() {
        currentState = .awake
        sleepProbability = 0
        sleepStartTime = nil
        currentPhaseDuration = 0
        stateEntryTime = nil
        consecutiveHighProbabilityCount = 0
        consecutiveLowProbabilityCount = 0
        recentMetrics.removeAll()
        isManualSleepMode = false
        logger.info("Sleep detection reset")
    }

    /// Check if minimum sleep duration met
    var isValidSleepDuration: Bool {
        guard let start = sleepStartTime else { return false }
        let duration = Date().timeIntervalSince(start) / 60
        return duration >= Double(config.minimumSleepMinutes)
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
        return sleepDuration >= Double(config.minimumSleepMinutes) * 60
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

    /// Get recent metrics for external analysis
    var allRecentMetrics: [MetricSample] {
        return recentMetrics
    }

    // MARK: - Sleep Probability Calculation

    private func calculateSleepProbability(sample: MetricSample) -> Double {
        // Component 1: HR drop score (0-1)
        // HR < 85% of baseline = max score
        let hrRatio = sample.hr / adaptiveBaseline.heartRate
        let hrDropScore: Double
        if hrRatio <= 0.85 {
            hrDropScore = 1.0
        } else if hrRatio <= 0.95 {
            hrDropScore = (0.95 - hrRatio) / 0.10  // Linear interpolation
        } else {
            hrDropScore = 0
        }

        // Component 2: RMSSD rise score (0-1)
        // RMSSD > 115% of baseline = max score
        let rmssdRatio = sample.rmssd / adaptiveBaseline.rmssd
        let rmssdRiseScore: Double
        if rmssdRatio >= 1.15 {
            rmssdRiseScore = 1.0
        } else if rmssdRatio >= 1.0 {
            rmssdRiseScore = (rmssdRatio - 1.0) / 0.15  // Linear interpolation
        } else {
            rmssdRiseScore = 0
        }

        // Component 3: Stability score (low HR variability = more likely sleeping)
        let stabilityScore: Double
        if adaptiveBaseline.hrStdDev > 0 && sample.hrStdDev > 0 {
            let stdDevRatio = sample.hrStdDev / adaptiveBaseline.hrStdDev
            if stdDevRatio <= 0.5 {
                stabilityScore = 1.0
            } else if stdDevRatio <= 1.0 {
                stabilityScore = (1.0 - stdDevRatio) / 0.5
            } else {
                stabilityScore = 0
            }
        } else {
            stabilityScore = 0.5  // Neutral if no data
        }

        // Weighted combination
        let probability = hrDropScore * config.hrDropWeight +
                          rmssdRiseScore * config.rmssdRiseWeight +
                          stabilityScore * config.stabilityWeight

        return min(1.0, max(0, probability))
    }

    // MARK: - Hysteresis State Machine

    private func processStateTransition(probability: Double, timestamp: Date) {
        let isHighProbability = probability >= config.sleepOnsetThreshold
        let isLowProbability = probability < config.wakeThreshold
        let isConfirmProbability = probability >= config.sleepConfirmThreshold

        // Track consecutive readings
        if isHighProbability {
            consecutiveHighProbabilityCount += 1
            consecutiveLowProbabilityCount = 0
        } else if isLowProbability {
            consecutiveLowProbabilityCount += 1
            consecutiveHighProbabilityCount = 0
        } else {
            // In between - decay both counters slowly
            consecutiveHighProbabilityCount = max(0, consecutiveHighProbabilityCount - 1)
            consecutiveLowProbabilityCount = max(0, consecutiveLowProbabilityCount - 1)
        }

        // Samples needed for confirmation (at 30s intervals)
        let samplesForSleepOnset = config.sleepOnsetMinutes * 2
        let samplesForSleepConfirm = config.sleepConfirmMinutes * 2
        let samplesForWakeOnset = config.wakeOnsetMinutes * 2
        let samplesForWakeConfirm = config.wakeConfirmMinutes * 2

        switch currentState {
        case .awake:
            // Need consistent high probability to enter preSleep
            if consecutiveHighProbabilityCount >= samplesForSleepOnset {
                transitionTo(.preSleep, timestamp: timestamp)
            }

        case .preSleep:
            if consecutiveHighProbabilityCount >= samplesForSleepConfirm {
                // Confirmed sleeping
                transitionTo(.sleeping, timestamp: timestamp)
                sleepStartTime = timestamp.addingTimeInterval(-Double(config.sleepConfirmMinutes) * 60)
                onSleepStart?(sleepStartTime!)
            } else if isLowProbability && consecutiveLowProbabilityCount >= samplesForWakeOnset {
                // False alarm - return to awake
                transitionTo(.awake, timestamp: timestamp)
            }

        case .sleeping:
            // Need consistent low probability to enter waking
            // CRITICAL: Hysteresis - require sustained wake signals
            if consecutiveLowProbabilityCount >= samplesForWakeOnset {
                transitionTo(.waking, timestamp: timestamp)
            }

        case .waking:
            if consecutiveLowProbabilityCount >= samplesForWakeConfirm {
                // Confirmed awake
                transitionTo(.awake, timestamp: timestamp)
                isManualSleepMode = false
                onWakeDetected?(timestamp)
            } else if isConfirmProbability && consecutiveHighProbabilityCount >= 3 {
                // False alarm - return to sleeping
                transitionTo(.sleeping, timestamp: timestamp)
            }
        }
    }

    private func transitionTo(_ newState: SleepDetectionState, timestamp: Date) {
        guard newState != currentState else { return }

        let oldState = currentState
        currentState = newState
        stateEntryTime = timestamp
        currentPhaseDuration = 0

        // Reset counters on state change
        if newState == .awake {
            consecutiveHighProbabilityCount = 0
            sleepStartTime = nil
        } else if newState == .sleeping {
            consecutiveLowProbabilityCount = 0
        }

        logger.info("State transition: \(oldState.rawValue) -> \(newState.rawValue)")
        onStateChange?(oldState, newState)
    }

    // MARK: - Circadian Window

    private func isWithinSleepWindow(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Sleep window wraps around midnight
        // e.g., 18:00 (6 PM) to 10:00 (10 AM)
        if config.sleepWindowStartHour > config.sleepWindowEndHour {
            // Window crosses midnight
            return hour >= config.sleepWindowStartHour || hour < config.sleepWindowEndHour
        } else {
            return hour >= config.sleepWindowStartHour && hour < config.sleepWindowEndHour
        }
    }

    // MARK: - Helpers

    private func trimOldSamples(before timestamp: Date) {
        let cutoff = timestamp.addingTimeInterval(-Double(metricWindowMinutes) * 60)
        recentMetrics.removeAll { $0.timestamp < cutoff }
    }
}
