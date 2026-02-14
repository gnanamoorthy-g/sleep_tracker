import Foundation
import os.log

/// Calculates a deterministic sleep score (0-100)
/// Based on duration, deep sleep ratio, HRV recovery, and continuity
struct SleepScoreCalculator {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "SleepScore")

    // MARK: - Weights
    private static let durationWeight: Double = 0.30
    private static let deepSleepWeight: Double = 0.25
    private static let hrvRecoveryWeight: Double = 0.25
    private static let continuityWeight: Double = 0.20

    // MARK: - Optimal Values
    private static let optimalSleepHours: Double = 7.5
    private static let optimalDeepSleepRatio: Double = 0.20

    // MARK: - Calculate Score

    static func calculateScore(from epochs: [SleepEpoch], baselineRMSSD: Double) -> SleepSummary {
        guard !epochs.isEmpty else {
            return createEmptySummary()
        }

        // Calculate phase durations
        let phaseDurations = calculatePhaseDurations(epochs: epochs)
        let totalMinutes = phaseDurations.values.reduce(0, +)
        let totalDuration = totalMinutes * 60  // Convert to seconds

        // Calculate HR stats
        let hrStats = calculateHRStats(epochs: epochs)

        // Calculate average RMSSD during sleep
        let sleepEpochs = epochs.filter { $0.phase != .awake }
        let avgSleepRMSSD = sleepEpochs.isEmpty ? 0 :
            sleepEpochs.map { $0.averageRMSSD }.reduce(0, +) / Double(sleepEpochs.count)

        // Count awakenings (transitions to awake > 2 minutes)
        let awakenings = countAwakenings(epochs: epochs)

        // Calculate subscores
        let durationScore = calculateDurationScore(totalHours: totalMinutes / 60)
        let deepScore = calculateDeepSleepScore(
            deepMinutes: phaseDurations[.deep] ?? 0,
            totalMinutes: totalMinutes
        )
        let hrvScore = calculateHRVRecoveryScore(
            nightRMSSD: avgSleepRMSSD,
            baselineRMSSD: baselineRMSSD
        )
        let continuityScore = calculateContinuityScore(awakenings: awakenings)

        // Final weighted score
        let finalScore = durationScore * durationWeight +
                         deepScore * deepSleepWeight +
                         hrvScore * hrvRecoveryWeight +
                         continuityScore * continuityWeight

        let clampedScore = Int(min(100, max(0, finalScore.rounded())))

        logger.info("Sleep Score: \(clampedScore) (Duration: \(String(format: "%.0f", durationScore)), Deep: \(String(format: "%.0f", deepScore)), HRV: \(String(format: "%.0f", hrvScore)), Continuity: \(String(format: "%.0f", continuityScore)))")

        return SleepSummary(
            totalDuration: totalDuration,
            sleepScore: clampedScore,
            awakeMinutes: phaseDurations[.awake] ?? 0,
            lightMinutes: phaseDurations[.light] ?? 0,
            deepMinutes: phaseDurations[.deep] ?? 0,
            remMinutes: phaseDurations[.rem] ?? 0,
            averageHR: hrStats.average,
            minHR: hrStats.min,
            maxHR: hrStats.max,
            averageRMSSD: avgSleepRMSSD,
            hrvRecoveryRatio: baselineRMSSD > 0 ? avgSleepRMSSD / baselineRMSSD : 1.0,
            awakenings: awakenings
        )
    }

    // MARK: - Subscores

    /// Duration Score: 100 × (1 - |Actual - 7.5| / 7.5)
    private static func calculateDurationScore(totalHours: Double) -> Double {
        let deviation = abs(totalHours - optimalSleepHours)
        let score = 100 * (1 - deviation / optimalSleepHours)
        return max(0, min(100, score))
    }

    /// Deep Sleep Score: 100 × (1 - |DeepRatio - 0.20| / 0.20)
    private static func calculateDeepSleepScore(deepMinutes: Double, totalMinutes: Double) -> Double {
        guard totalMinutes > 0 else { return 0 }

        let deepRatio = deepMinutes / totalMinutes
        let deviation = abs(deepRatio - optimalDeepSleepRatio)
        let score = 100 * (1 - deviation / optimalDeepSleepRatio)
        return max(0, min(100, score))
    }

    /// HRV Recovery Score: Based on night RMSSD / baseline RMSSD ratio
    private static func calculateHRVRecoveryScore(nightRMSSD: Double, baselineRMSSD: Double) -> Double {
        guard baselineRMSSD > 0 else { return 85 }

        let recoveryRatio = nightRMSSD / baselineRMSSD

        // Linear interpolation between bands
        switch recoveryRatio {
        case 1.10...:
            return 100
        case 1.00..<1.10:
            return 85 + (recoveryRatio - 1.0) * 150  // 85 to 100
        case 0.90..<1.00:
            return 70 + (recoveryRatio - 0.9) * 150  // 70 to 85
        case 0.80..<0.90:
            return 50 + (recoveryRatio - 0.8) * 200  // 50 to 70
        default:
            return 50
        }
    }

    /// Continuity Score: 100 - (Awakenings × 5), minimum 50
    private static func calculateContinuityScore(awakenings: Int) -> Double {
        let score = 100 - Double(awakenings * 5)
        return max(50, min(100, score))
    }

    // MARK: - Helpers

    private static func calculatePhaseDurations(epochs: [SleepEpoch]) -> [SleepPhase: Double] {
        var durations: [SleepPhase: Double] = [:]

        for phase in SleepPhase.allCases {
            let phaseEpochs = epochs.filter { $0.phase == phase }
            let totalSeconds = phaseEpochs.reduce(0) { $0 + $1.duration }
            durations[phase] = totalSeconds / 60  // Convert to minutes
        }

        return durations
    }

    private static func calculateHRStats(epochs: [SleepEpoch]) -> (average: Double, min: Double, max: Double) {
        guard !epochs.isEmpty else { return (0, 0, 0) }

        let heartRates = epochs.map { $0.averageHR }
        let average = heartRates.reduce(0, +) / Double(heartRates.count)
        let min = heartRates.min() ?? 0
        let max = heartRates.max() ?? 0

        return (average, min, max)
    }

    private static func countAwakenings(epochs: [SleepEpoch]) -> Int {
        var awakenings = 0
        var consecutiveAwake = 0
        var wasAsleep = false

        for epoch in epochs {
            if epoch.phase == .awake {
                consecutiveAwake += 1
                // Count as awakening if > 2 minutes (4 epochs × 30 sec = 2 min)
                if wasAsleep && consecutiveAwake >= 4 {
                    awakenings += 1
                    wasAsleep = false
                }
            } else {
                wasAsleep = true
                consecutiveAwake = 0
            }
        }

        return awakenings
    }

    private static func createEmptySummary() -> SleepSummary {
        SleepSummary(
            totalDuration: 0,
            sleepScore: 0,
            awakeMinutes: 0,
            lightMinutes: 0,
            deepMinutes: 0,
            remMinutes: 0,
            averageHR: 0,
            minHR: 0,
            maxHR: 0,
            averageRMSSD: 0,
            hrvRecoveryRatio: 1.0,
            awakenings: 0
        )
    }
}
