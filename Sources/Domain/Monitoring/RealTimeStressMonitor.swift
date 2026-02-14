import Foundation
import Combine
import os.log

/// Real-time stress monitoring based on HRV and HR deviations from baseline
@MainActor
final class RealTimeStressMonitor: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var isStressed: Bool = false
    @Published private(set) var currentStressLevel: StressSeverity?
    @Published private(set) var stressStartTime: Date?
    @Published private(set) var currentStressDuration: TimeInterval = 0

    // MARK: - Thresholds
    struct StressThresholds {
        let rmssdDropThreshold: Double = 0.70  // RMSSD < 70% of baseline
        let hrElevationThreshold: Double = 0.10  // HR > 10% above baseline
        let sustainedDuration: TimeInterval = 300  // 5 minutes
        let cooldownPeriod: TimeInterval = 600  // 10 minutes between alerts
    }

    // MARK: - Properties
    private let thresholds = StressThresholds()
    private let logger = Logger(subsystem: "com.sleeptracker", category: "StressMonitor")

    // Baselines
    private var baseline7dRMSSD: Double?
    private var baselineRestingHR: Double?

    // Tracking
    private var stressOnsetTime: Date?
    private var lastAlertTime: Date?
    private var recentMetrics: [StressMetricSample] = []
    private let metricWindowMinutes: Int = 5

    // Dependencies
    private let stressEventRepository: StressEventRepository
    private let notificationManager: NotificationManager

    // Sleep detection reference (to avoid alerting during sleep)
    weak var sleepDetectionEngine: SleepDetectionEngine?

    // MARK: - Initialization

    init(stressEventRepository: StressEventRepository = StressEventRepository(),
         notificationManager: NotificationManager = .shared) {
        self.stressEventRepository = stressEventRepository
        self.notificationManager = notificationManager
    }

    // MARK: - Public Methods

    /// Set the 7-day baseline RMSSD and resting HR
    func setBaseline(rmssd: Double, restingHR: Double) {
        baseline7dRMSSD = rmssd
        baselineRestingHR = restingHR
        logger.info("Stress baseline set - RMSSD: \(rmssd), Resting HR: \(restingHR)")
    }

    /// Update with new HR and RMSSD values
    /// Call this every 30 seconds with current metrics
    func updateWithMetrics(heartRate: Double, rmssd: Double, timestamp: Date = Date()) {
        // Skip if during sleep
        if let sleepEngine = sleepDetectionEngine,
           sleepEngine.currentState == .sleeping {
            return
        }

        // Skip if no baseline
        guard let baseline = baseline7dRMSSD,
              let baselineHR = baselineRestingHR else {
            return
        }

        // Store sample
        let sample = StressMetricSample(hr: heartRate, rmssd: rmssd, timestamp: timestamp)
        recentMetrics.append(sample)

        // Trim old samples
        let cutoff = timestamp.addingTimeInterval(-Double(metricWindowMinutes * 60))
        recentMetrics.removeAll { $0.timestamp < cutoff }

        // Calculate ratios
        let rmssdRatio = rmssd / baseline
        let hrElevation = (heartRate - baselineHR) / baselineHR

        // Check stress condition
        let isCurrentlyStressed = rmssdRatio < thresholds.rmssdDropThreshold &&
                                  hrElevation > thresholds.hrElevationThreshold

        processStressState(isCurrentlyStressed: isCurrentlyStressed,
                          rmssdRatio: rmssdRatio,
                          hrElevation: hrElevation,
                          timestamp: timestamp)
    }

    /// Reset stress monitoring state
    func reset() {
        isStressed = false
        currentStressLevel = nil
        stressStartTime = nil
        stressOnsetTime = nil
        currentStressDuration = 0
        recentMetrics.removeAll()
        logger.info("Stress monitor reset")
    }

    /// Get today's stress events
    func todaysStressEvents() -> [StressEvent] {
        stressEventRepository.loadForDate(Date())
    }

    /// Get all stress events
    func allStressEvents() -> [StressEvent] {
        stressEventRepository.loadAll()
    }

    // MARK: - Private Methods

    private func processStressState(isCurrentlyStressed: Bool,
                                   rmssdRatio: Double,
                                   hrElevation: Double,
                                   timestamp: Date) {
        if isCurrentlyStressed {
            if stressOnsetTime == nil {
                // Start tracking potential stress
                stressOnsetTime = timestamp
            }

            // Check if sustained long enough
            if let onsetTime = stressOnsetTime {
                let duration = timestamp.timeIntervalSince(onsetTime)
                currentStressDuration = duration

                if duration >= thresholds.sustainedDuration && !isStressed {
                    // Stress confirmed
                    triggerStressAlert(rmssdRatio: rmssdRatio,
                                      hrElevation: hrElevation,
                                      duration: duration,
                                      timestamp: timestamp)
                }
            }
        } else {
            // No longer stressed
            if isStressed {
                endStressEpisode(timestamp: timestamp)
            }

            stressOnsetTime = nil
            currentStressDuration = 0
        }
    }

    private func triggerStressAlert(rmssdRatio: Double,
                                   hrElevation: Double,
                                   duration: TimeInterval,
                                   timestamp: Date) {
        // Check cooldown
        if let lastAlert = lastAlertTime,
           timestamp.timeIntervalSince(lastAlert) < thresholds.cooldownPeriod {
            logger.info("Stress alert skipped - cooldown period")
            return
        }

        // Calculate severity
        let severity = StressSeverity.from(rmssdRatio: rmssdRatio, hrElevation: hrElevation)

        isStressed = true
        currentStressLevel = severity
        stressStartTime = stressOnsetTime
        lastAlertTime = timestamp

        // Send notification
        notificationManager.sendStressAlert(severity: severity)

        logger.info("Stress alert triggered - Severity: \(severity.rawValue)")
    }

    private func endStressEpisode(timestamp: Date) {
        guard let startTime = stressStartTime,
              let severity = currentStressLevel,
              let baseline = baseline7dRMSSD else {
            return
        }

        let duration = timestamp.timeIntervalSince(startTime)

        // Calculate average metrics during stress
        let stressMetrics = recentMetrics.filter { $0.timestamp >= startTime }
        let avgHR = stressMetrics.isEmpty ? 0 : stressMetrics.map { $0.hr }.reduce(0, +) / Double(stressMetrics.count)
        let avgRMSSD = stressMetrics.isEmpty ? 0 : stressMetrics.map { $0.rmssd }.reduce(0, +) / Double(stressMetrics.count)

        // Create and save stress event
        let event = StressEvent(
            timestamp: startTime,
            duration: duration,
            averageHR: avgHR,
            averageRMSSD: avgRMSSD,
            baselineRMSSD: baseline,
            severity: severity
        )

        stressEventRepository.save(event)

        // Reset state
        isStressed = false
        currentStressLevel = nil
        stressStartTime = nil
        currentStressDuration = 0

        logger.info("Stress episode ended - Duration: \(duration / 60)m")
    }
}

// MARK: - Metric Sample

extension RealTimeStressMonitor {
    struct StressMetricSample {
        let hr: Double
        let rmssd: Double
        let timestamp: Date
    }
}
