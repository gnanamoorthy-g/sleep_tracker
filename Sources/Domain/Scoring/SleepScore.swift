import Foundation

/// Detailed sleep score with individual components
struct SleepScore: Codable {
    let totalScore: Int
    let durationComponent: Int
    let deepComponent: Int
    let hrvComponent: Int
    let continuityComponent: Int

    // Weights used in calculation
    static let durationWeight: Double = 0.30
    static let deepWeight: Double = 0.25
    static let hrvWeight: Double = 0.25
    static let continuityWeight: Double = 0.20

    var description: String {
        """
        Total: \(totalScore)
        Duration: \(durationComponent) (30%)
        Deep Sleep: \(deepComponent) (25%)
        HRV Recovery: \(hrvComponent) (25%)
        Continuity: \(continuityComponent) (20%)
        """
    }

    /// Create from component scores
    static func calculate(
        durationScore: Double,
        deepScore: Double,
        hrvScore: Double,
        continuityScore: Double
    ) -> SleepScore {
        let finalScore = durationScore * durationWeight +
                         deepScore * deepWeight +
                         hrvScore * hrvWeight +
                         continuityScore * continuityWeight

        return SleepScore(
            totalScore: Int(min(100, max(0, finalScore.rounded()))),
            durationComponent: Int(min(100, max(0, durationScore.rounded()))),
            deepComponent: Int(min(100, max(0, deepScore.rounded()))),
            hrvComponent: Int(min(100, max(0, hrvScore.rounded()))),
            continuityComponent: Int(min(100, max(0, continuityScore.rounded())))
        )
    }
}

/// Enhanced sleep score calculator that returns component breakdown
struct EnhancedSleepScoreCalculator {

    // MARK: - Optimal Values
    private static let optimalSleepHours: Double = 7.5
    private static let optimalDeepSleepRatio: Double = 0.20

    // MARK: - Calculate Detailed Score

    static func calculateDetailedScore(
        totalSleepMinutes: Double,
        deepSleepMinutes: Double,
        nightRMSSD: Double,
        baselineRMSSD: Double,
        awakenings: Int
    ) -> SleepScore {
        let durationScore = calculateDurationScore(totalHours: totalSleepMinutes / 60)
        let deepScore = calculateDeepSleepScore(
            deepMinutes: deepSleepMinutes,
            totalMinutes: totalSleepMinutes
        )
        let hrvScore = calculateHRVRecoveryScore(
            nightRMSSD: nightRMSSD,
            baselineRMSSD: baselineRMSSD
        )
        let continuityScore = calculateContinuityScore(awakenings: awakenings)

        return SleepScore.calculate(
            durationScore: durationScore,
            deepScore: deepScore,
            hrvScore: hrvScore,
            continuityScore: continuityScore
        )
    }

    // MARK: - Component Calculations

    /// Duration Score: 100 × (1 - |Actual - 7.5| / 7.5)
    static func calculateDurationScore(totalHours: Double) -> Double {
        let deviation = abs(totalHours - optimalSleepHours)
        let score = 100 * (1 - deviation / optimalSleepHours)
        return max(0, min(100, score))
    }

    /// Deep Sleep Score: 100 × (1 - |DeepRatio - 0.20| / 0.20)
    static func calculateDeepSleepScore(deepMinutes: Double, totalMinutes: Double) -> Double {
        guard totalMinutes > 0 else { return 0 }

        let deepRatio = deepMinutes / totalMinutes
        let deviation = abs(deepRatio - optimalDeepSleepRatio)
        let score = 100 * (1 - deviation / optimalDeepSleepRatio)
        return max(0, min(100, score))
    }

    /// HRV Recovery Score: Based on night RMSSD / baseline RMSSD ratio
    static func calculateHRVRecoveryScore(nightRMSSD: Double, baselineRMSSD: Double) -> Double {
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
    static func calculateContinuityScore(awakenings: Int) -> Double {
        let score = 100 - Double(awakenings * 5)
        return max(50, min(100, score))
    }
}
