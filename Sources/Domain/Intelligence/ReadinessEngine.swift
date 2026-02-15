import Foundation
import os.log

/// Training Readiness and Biological Age Engine
/// Calculates daily readiness scores and physiological age estimation
struct ReadinessEngine {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "Readiness")

    // MARK: - Readiness Metrics

    struct ReadinessMetrics {
        /// HRV Z-score component (normalized to 0-100)
        let hrvZScore: Double

        /// RHR deviation component (normalized to 0-100)
        let rhrDeviation: Double

        /// Sleep score component (0-100)
        let sleepScore: Double

        /// Heart Rate Recovery score component (0-100)
        let hrrScore: Double

        /// Final readiness score (0-100)
        let readinessScore: Int

        /// Interpretation
        let interpretation: ReadinessInterpretation

        /// Recommendation for the day
        let recommendation: String
    }

    enum ReadinessInterpretation: String {
        case optimal = "Optimal"
        case good = "Good"
        case moderate = "Moderate"
        case low = "Low"
        case veryLow = "Very Low"

        var emoji: String {
            switch self {
            case .optimal: return "🟢"
            case .good: return "🔵"
            case .moderate: return "🟡"
            case .low: return "🟠"
            case .veryLow: return "🔴"
            }
        }

        var trainingRecommendation: String {
            switch self {
            case .optimal:
                return "Great day for high-intensity training or competition"
            case .good:
                return "Good for moderate to high intensity training"
            case .moderate:
                return "Consider moderate intensity with good recovery"
            case .low:
                return "Light activity or active recovery recommended"
            case .veryLow:
                return "Rest day recommended - prioritize recovery"
            }
        }

        static func from(score: Int) -> ReadinessInterpretation {
            switch score {
            case 85...:
                return .optimal
            case 70..<85:
                return .good
            case 55..<70:
                return .moderate
            case 40..<55:
                return .low
            default:
                return .veryLow
            }
        }
    }

    // MARK: - Weights (from requirements)

    private static let hrvWeight: Double = 0.40
    private static let rhrWeight: Double = 0.20
    private static let sleepWeight: Double = 0.20
    private static let hrrWeight: Double = 0.20

    // MARK: - Calculate Readiness

    /// Calculate training readiness score
    /// Readiness = 0.4(HRV Z-scaled) + 0.2(RHR deviation inverse) + 0.2(Sleep Score) + 0.2(HRR Score)
    static func calculateReadiness(
        todaySummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        hrrScore: Double? = nil  // Heart Rate Recovery score (0-100)
    ) -> ReadinessMetrics {
        logger.debug("Calculating training readiness")

        // Get baselines
        let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries)
        let zScore = todaySummary.zScore ?? BaselineEngine.calculateZScore(
            todayRMSSD: todaySummary.rmssd,
            from: historicalSummaries
        )

        // 1. HRV Z-Score Component (scale Z-score to 0-100)
        // Z > 0.5 = Green (high readiness), Z -0.5 to 0.5 = Neutral, Z < -0.5 = Recovery needed
        let hrvZScaled: Double
        if let z = zScore {
            // Map Z-score (-3 to +3) to (0 to 100), with Z=0 mapping to 70
            hrvZScaled = min(100, max(0, 70 + z * 15))
        } else {
            hrvZScaled = 70  // Default to neutral
        }

        // 2. RHR Deviation Component (inverse - lower RHR = higher score)
        let rhrDeviation = calculateRHRDeviationScore(
            todayRHR: todaySummary.minHR,
            historicalSummaries: historicalSummaries
        )

        // 3. Sleep Score Component
        let sleepScore = Double(todaySummary.sleepScore ?? 70)

        // 4. HRR Score Component (default to 70 if not available)
        let hrrScoreValue = hrrScore ?? 70

        // Calculate weighted readiness score
        let readinessDouble = hrvZScaled * hrvWeight +
                              rhrDeviation * rhrWeight +
                              sleepScore * sleepWeight +
                              hrrScoreValue * hrrWeight

        let readinessScore = Int(min(100, max(0, readinessDouble.rounded())))
        let interpretation = ReadinessInterpretation.from(score: readinessScore)

        logger.info("Readiness: \(readinessScore) - HRV: \(String(format: "%.0f", hrvZScaled)), RHR: \(String(format: "%.0f", rhrDeviation)), Sleep: \(String(format: "%.0f", sleepScore)), HRR: \(String(format: "%.0f", hrrScoreValue))")

        return ReadinessMetrics(
            hrvZScore: hrvZScaled,
            rhrDeviation: rhrDeviation,
            sleepScore: sleepScore,
            hrrScore: hrrScoreValue,
            readinessScore: readinessScore,
            interpretation: interpretation,
            recommendation: interpretation.trainingRecommendation
        )
    }

    /// Calculate RHR deviation score (0-100)
    /// Score = 100 * (1 - (RHR_today - baseline) / baseline)
    private static func calculateRHRDeviationScore(
        todayRHR: Double,
        historicalSummaries: [DailyHRVSummary]
    ) -> Double {
        let last7 = historicalSummaries.suffix(7)
        guard !last7.isEmpty else { return 70 }

        let baselineRHR = last7.map { $0.minHR }.reduce(0, +) / Double(last7.count)
        guard baselineRHR > 0 else { return 70 }

        let deviation = (todayRHR - baselineRHR) / baselineRHR
        let score = 100 * (1 - deviation)

        return min(100, max(0, score))
    }

    // MARK: - Biological Age Estimation

    struct BiologicalAgeResult {
        /// Estimated physiological age
        let biologicalAge: Int

        /// Difference from chronological age (negative = younger)
        let ageDifference: Int

        /// Percentile ranking for age group
        let percentile: Int

        /// Components contributing to the estimate
        let components: BiologicalAgeComponents

        /// Interpretation
        let interpretation: String
    }

    struct BiologicalAgeComponents {
        let rmssdPercentile: Double
        let rhrPercentile: Double
        let hrrPercentile: Double

        var averagePercentile: Double {
            (rmssdPercentile + rhrPercentile + hrrPercentile) / 3
        }
    }

    // MARK: - Age-based normative data (simplified)
    // Real implementation would use population-based percentile tables

    private static let rmssdNormsByAge: [(age: Int, p50: Double, p25: Double, p75: Double)] = [
        (20, 45, 30, 65),
        (30, 40, 25, 55),
        (40, 35, 22, 48),
        (50, 30, 18, 42),
        (60, 25, 15, 35),
        (70, 20, 12, 28)
    ]

    private static let rhrNormsByAge: [(age: Int, p50: Double, p25: Double, p75: Double)] = [
        (20, 65, 55, 75),
        (30, 68, 58, 78),
        (40, 70, 60, 80),
        (50, 72, 62, 82),
        (60, 74, 64, 84),
        (70, 76, 66, 86)
    ]

    /// Estimate biological age from HRV metrics
    static func estimateBiologicalAge(
        chronologicalAge: Int,
        avgRMSSD: Double,
        avgRHR: Double,
        avgHRR: Double = 30  // Default HRR if not available
    ) -> BiologicalAgeResult {
        logger.debug("Estimating biological age for chronological age \(chronologicalAge)")

        // Calculate percentiles for each metric
        let rmssdPercentile = calculateRMSSDPercentile(rmssd: avgRMSSD, age: chronologicalAge)
        let rhrPercentile = calculateRHRPercentile(rhr: avgRHR, age: chronologicalAge)
        let hrrPercentile = calculateHRRPercentile(hrr: avgHRR, age: chronologicalAge)

        let components = BiologicalAgeComponents(
            rmssdPercentile: rmssdPercentile,
            rhrPercentile: rhrPercentile,
            hrrPercentile: hrrPercentile
        )

        // Map average percentile to biological age
        // 50th percentile = same as chronological age
        // Each 10 percentile points above/below = 1 year younger/older
        let percentileDiff = components.averagePercentile - 50
        let ageDiff = -Int(percentileDiff / 10)  // Higher percentile = younger

        let biologicalAge = max(18, min(90, chronologicalAge + ageDiff))
        let overallPercentile = Int(components.averagePercentile)

        let interpretation: String
        if ageDiff <= -5 {
            interpretation = "Excellent! Your cardiovascular fitness suggests you're physiologically much younger than your age."
        } else if ageDiff < 0 {
            interpretation = "Good! Your heart health metrics are better than average for your age."
        } else if ageDiff == 0 {
            interpretation = "Your cardiovascular metrics are typical for your age group."
        } else if ageDiff <= 5 {
            interpretation = "Your metrics suggest some room for improvement in cardiovascular fitness."
        } else {
            interpretation = "Consider focusing on cardiovascular health through exercise and lifestyle changes."
        }

        logger.info("Biological age estimate: \(biologicalAge) (chronological: \(chronologicalAge), diff: \(ageDiff))")

        return BiologicalAgeResult(
            biologicalAge: biologicalAge,
            ageDifference: -ageDiff,  // Positive = younger
            percentile: overallPercentile,
            components: components,
            interpretation: interpretation
        )
    }

    /// Calculate RMSSD percentile for age
    private static func calculateRMSSDPercentile(rmssd: Double, age: Int) -> Double {
        // Simplified linear interpolation
        let norm = rmssdNormsByAge.first { abs($0.age - age) <= 5 } ?? rmssdNormsByAge[2]

        if rmssd >= norm.p75 {
            return 75 + 25 * min(1, (rmssd - norm.p75) / (norm.p75 * 0.5))
        } else if rmssd >= norm.p50 {
            return 50 + 25 * (rmssd - norm.p50) / (norm.p75 - norm.p50)
        } else if rmssd >= norm.p25 {
            return 25 + 25 * (rmssd - norm.p25) / (norm.p50 - norm.p25)
        } else {
            return max(0, 25 * rmssd / norm.p25)
        }
    }

    /// Calculate RHR percentile for age (lower is better)
    private static func calculateRHRPercentile(rhr: Double, age: Int) -> Double {
        let norm = rhrNormsByAge.first { abs($0.age - age) <= 5 } ?? rhrNormsByAge[2]

        // Invert: lower RHR = higher percentile
        if rhr <= norm.p25 {
            return 75 + 25 * min(1, (norm.p25 - rhr) / 10)
        } else if rhr <= norm.p50 {
            return 50 + 25 * (norm.p50 - rhr) / (norm.p50 - norm.p25)
        } else if rhr <= norm.p75 {
            return 25 + 25 * (norm.p75 - rhr) / (norm.p75 - norm.p50)
        } else {
            return max(0, 25 * (1 - (rhr - norm.p75) / 20))
        }
    }

    /// Calculate HRR percentile (simplified)
    private static func calculateHRRPercentile(hrr: Double, age: Int) -> Double {
        // Target HRR after 1 minute: 25+ bpm is good, 40+ is excellent
        // Decreases with age
        let ageAdjustedTarget = max(20, 35 - Double(max(0, age - 30)) * 0.3)

        if hrr >= ageAdjustedTarget * 1.5 {
            return 90
        } else if hrr >= ageAdjustedTarget {
            return 50 + 40 * (hrr - ageAdjustedTarget) / (ageAdjustedTarget * 0.5)
        } else if hrr >= ageAdjustedTarget * 0.6 {
            return 25 + 25 * (hrr - ageAdjustedTarget * 0.6) / (ageAdjustedTarget * 0.4)
        } else {
            return max(0, 25 * hrr / (ageAdjustedTarget * 0.6))
        }
    }
}
