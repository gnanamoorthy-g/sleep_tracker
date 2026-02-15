import Foundation
import os.log

/// Calculates sleep session confidence based on data quality
/// Accounts for BLE disconnects, RR coverage, HR smoothness, and detection stability
struct SleepConfidenceCalculator {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "SleepConfidence")

    // MARK: - Confidence Result

    struct ConfidenceResult {
        /// Overall confidence score (0-100)
        let score: Int

        /// Individual component scores
        let components: Components

        /// Confidence level interpretation
        let level: ConfidenceLevel

        /// Warnings about data quality
        let warnings: [String]

        /// Whether the session data is reliable enough for analysis
        let isReliable: Bool

        struct Components {
            let bleConnectivity: Int      // 0-100: Based on disconnect count
            let rrCoverage: Int           // 0-100: Based on data coverage %
            let hrSmoothness: Int         // 0-100: Based on HR stability
            let detectionStability: Int   // 0-100: Based on state transition count
        }
    }

    enum ConfidenceLevel: String {
        case high = "High"
        case moderate = "Moderate"
        case low = "Low"
        case veryLow = "Very Low"

        var emoji: String {
            switch self {
            case .high: return "✅"
            case .moderate: return "🟡"
            case .low: return "🟠"
            case .veryLow: return "🔴"
            }
        }

        var description: String {
            switch self {
            case .high:
                return "Data quality is excellent. Sleep metrics are reliable."
            case .moderate:
                return "Some data gaps detected. Metrics are reasonably accurate."
            case .low:
                return "Significant data quality issues. Interpret metrics with caution."
            case .veryLow:
                return "Major data problems. Consider this session unreliable."
            }
        }

        static func from(score: Int) -> ConfidenceLevel {
            switch score {
            case 85...: return .high
            case 65..<85: return .moderate
            case 40..<65: return .low
            default: return .veryLow
            }
        }
    }

    // MARK: - Weights

    private static let bleConnectivityWeight: Double = 0.30
    private static let rrCoverageWeight: Double = 0.35
    private static let hrSmoothnessWeight: Double = 0.20
    private static let detectionStabilityWeight: Double = 0.15

    // MARK: - Calculate Confidence

    /// Calculate confidence score for a sleep session
    /// - Parameters:
    ///   - disconnectCount: Number of BLE disconnections during session
    ///   - rrCoveragePercent: Percentage of expected RR samples received (0-100)
    ///   - hrSamples: Heart rate samples for smoothness calculation
    ///   - stateTransitionCount: Number of sleep state transitions
    ///   - sessionDurationMinutes: Total session duration
    /// - Returns: Confidence result with score and components
    static func calculate(
        disconnectCount: Int,
        rrCoveragePercent: Double,
        hrSamples: [Double],
        stateTransitionCount: Int,
        sessionDurationMinutes: Double
    ) -> ConfidenceResult {
        logger.debug("Calculating sleep confidence")

        var warnings: [String] = []

        // Component 1: BLE Connectivity (fewer disconnects = higher score)
        let bleScore = calculateBLEConnectivityScore(
            disconnects: disconnectCount,
            sessionMinutes: sessionDurationMinutes
        )
        if disconnectCount > 0 {
            warnings.append("Device disconnected \(disconnectCount) time(s) during sleep")
        }

        // Component 2: RR Coverage
        let rrScore = calculateRRCoverageScore(coveragePercent: rrCoveragePercent)
        if rrCoveragePercent < 80 {
            warnings.append("Only \(Int(rrCoveragePercent))% of expected heart data received")
        }

        // Component 3: HR Smoothness (fewer spikes = higher score)
        let hrScore = calculateHRSmoothnessScore(hrSamples: hrSamples)
        let spikeCount = countHRSpikes(hrSamples: hrSamples)
        if spikeCount > 10 {
            warnings.append("Detected \(spikeCount) abnormal HR spikes")
        }

        // Component 4: Detection Stability (fewer transitions = higher score)
        let stabilityScore = calculateDetectionStabilityScore(
            transitions: stateTransitionCount,
            sessionMinutes: sessionDurationMinutes
        )
        if stateTransitionCount > 20 {
            warnings.append("Unstable sleep detection (\(stateTransitionCount) state changes)")
        }

        // Weighted final score
        let finalScore = bleScore * bleConnectivityWeight +
                         rrScore * rrCoverageWeight +
                         hrScore * hrSmoothnessWeight +
                         stabilityScore * detectionStabilityWeight

        let score = Int(min(100, max(0, finalScore)))
        let level = ConfidenceLevel.from(score: score)

        logger.info("Sleep confidence: \(score) (\(level.rawValue)) - BLE: \(Int(bleScore)), RR: \(Int(rrScore)), HR: \(Int(hrScore)), Stability: \(Int(stabilityScore))")

        return ConfidenceResult(
            score: score,
            components: ConfidenceResult.Components(
                bleConnectivity: Int(bleScore),
                rrCoverage: Int(rrScore),
                hrSmoothness: Int(hrScore),
                detectionStability: Int(stabilityScore)
            ),
            level: level,
            warnings: warnings,
            isReliable: score >= 40
        )
    }

    // MARK: - Component Calculations

    /// BLE Connectivity Score
    /// 0 disconnects = 100, each disconnect reduces score
    private static func calculateBLEConnectivityScore(
        disconnects: Int,
        sessionMinutes: Double
    ) -> Double {
        if disconnects == 0 {
            return 100
        }

        // Calculate disconnects per hour
        let sessionHours = max(1, sessionMinutes / 60)
        let disconnectsPerHour = Double(disconnects) / sessionHours

        // Score decreases with more disconnects
        // 1 per hour = 80, 2 per hour = 60, etc.
        let score = 100 - (disconnectsPerHour * 20)

        return max(0, min(100, score))
    }

    /// RR Coverage Score
    /// Direct mapping of coverage percentage
    private static func calculateRRCoverageScore(coveragePercent: Double) -> Double {
        // Scale: 100% coverage = 100, 80% = 80, etc.
        // Below 50% coverage gets penalized more heavily
        if coveragePercent >= 80 {
            return coveragePercent
        } else if coveragePercent >= 50 {
            // Gradual penalty
            return 50 + (coveragePercent - 50)
        } else {
            // Heavy penalty for very low coverage
            return coveragePercent * 0.5
        }
    }

    /// HR Smoothness Score
    /// Based on coefficient of variation and spike count
    private static func calculateHRSmoothnessScore(hrSamples: [Double]) -> Double {
        guard hrSamples.count >= 10 else { return 50 }

        // Calculate coefficient of variation (CV)
        let mean = hrSamples.reduce(0, +) / Double(hrSamples.count)
        guard mean > 0 else { return 50 }

        let variance = hrSamples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hrSamples.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        // Lower CV = smoother HR = higher score
        // CV of 0.05 = 100, CV of 0.20 = 50, CV of 0.35+ = 0
        let cvScore: Double
        if cv <= 0.05 {
            cvScore = 100
        } else if cv <= 0.20 {
            cvScore = 100 - ((cv - 0.05) / 0.15) * 50
        } else if cv <= 0.35 {
            cvScore = 50 - ((cv - 0.20) / 0.15) * 50
        } else {
            cvScore = 0
        }

        // Penalize for spike count
        let spikeCount = countHRSpikes(hrSamples: hrSamples)
        let spikePenalty = min(30, Double(spikeCount) * 2)

        return max(0, cvScore - spikePenalty)
    }

    /// Count HR spikes (sudden changes > 20 bpm)
    private static func countHRSpikes(hrSamples: [Double]) -> Int {
        guard hrSamples.count >= 2 else { return 0 }

        var spikeCount = 0
        for i in 1..<hrSamples.count {
            let diff = abs(hrSamples[i] - hrSamples[i - 1])
            if diff > 20 {
                spikeCount += 1
            }
        }

        return spikeCount
    }

    /// Detection Stability Score
    /// Based on state transitions per hour
    private static func calculateDetectionStabilityScore(
        transitions: Int,
        sessionMinutes: Double
    ) -> Double {
        let sessionHours = max(1, sessionMinutes / 60)
        let transitionsPerHour = Double(transitions) / sessionHours

        // Expected: ~4-8 transitions per 8 hours (0.5-1 per hour)
        // Score: <1/hour = 100, 2/hour = 80, 5/hour = 50, >10/hour = 0
        if transitionsPerHour <= 1 {
            return 100
        } else if transitionsPerHour <= 2 {
            return 90 - (transitionsPerHour - 1) * 10
        } else if transitionsPerHour <= 5 {
            return 80 - (transitionsPerHour - 2) * 10
        } else if transitionsPerHour <= 10 {
            return 50 - (transitionsPerHour - 5) * 10
        } else {
            return 0
        }
    }

    // MARK: - Quick Assessment

    /// Quick assessment without detailed HR analysis
    static func quickAssessment(
        disconnectCount: Int,
        rrCoveragePercent: Double
    ) -> ConfidenceLevel {
        // Quick heuristic
        if disconnectCount == 0 && rrCoveragePercent >= 90 {
            return .high
        } else if disconnectCount <= 2 && rrCoveragePercent >= 75 {
            return .moderate
        } else if disconnectCount <= 5 && rrCoveragePercent >= 50 {
            return .low
        } else {
            return .veryLow
        }
    }
}
