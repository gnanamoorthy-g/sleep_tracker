import Foundation

/// Intelligence engine for detecting recovery states and health signals
struct RecoveryIntelligenceEngine {

    // MARK: - Recovery States

    enum RecoveryState: String, CaseIterable {
        case parasympatheticDominant = "Parasympathetic Dominant"
        case sympatheticDominant = "Sympathetic Dominant"
        case overreachingRisk = "Overreaching Risk"
        case cnsFatigue = "CNS Fatigue"
        case recoveryDebt = "Recovery Debt"
        case normal = "Normal"
        case elevated = "Elevated Recovery"

        var emoji: String {
            switch self {
            case .parasympatheticDominant: return "🟢"
            case .sympatheticDominant: return "🟡"
            case .overreachingRisk: return "🔴"
            case .cnsFatigue: return "🟠"
            case .recoveryDebt: return "⚠️"
            case .normal: return "🔵"
            case .elevated: return "✨"
            }
        }

        var recommendation: String {
            switch self {
            case .parasympatheticDominant:
                return "Great recovery! Your body is well-rested and ready for training."
            case .sympatheticDominant:
                return "Your nervous system is activated. Consider lighter activities today."
            case .overreachingRisk:
                return "Warning: Signs of overreaching detected. Prioritize rest and recovery."
            case .cnsFatigue:
                return "CNS fatigue detected. Take a rest day and focus on sleep quality."
            case .recoveryDebt:
                return "You've accumulated recovery debt. Plan rest days soon."
            case .normal:
                return "Normal recovery state. Continue your regular routine."
            case .elevated:
                return "Excellent recovery! Good time for challenging workouts."
            }
        }
    }

    // MARK: - Analysis Result

    struct IntelligenceReport {
        let primaryState: RecoveryState
        let secondaryStates: [RecoveryState]
        let zScore: Double?
        let recoveryDebt: Double
        let stressIndex: Double
        let recommendations: [String]

        var isAlert: Bool {
            [.overreachingRisk, .cnsFatigue, .recoveryDebt].contains(primaryState)
        }
    }

    // MARK: - Thresholds

    private static let parasympatheticZScoreThreshold: Double = 1.0
    private static let sympatheticZScoreThreshold: Double = -1.5
    private static let overreachingZScoreThreshold: Double = -2.0
    private static let recoveryDebtThreshold: Double = 50.0
    private static let fatigueConsecutiveDays: Int = 2

    // MARK: - Analysis

    /// Analyze recovery state from historical HRV data
    static func analyze(
        todaySummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary]
    ) -> IntelligenceReport {
        var detectedStates: [RecoveryState] = []
        var recommendations: [String] = []

        let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries)
        let zScore = todaySummary.zScore ?? BaselineEngine.calculateZScore(
            todayRMSSD: todaySummary.rmssd,
            from: historicalSummaries
        )

        // Calculate recovery debt
        let recoveryDebt = calculateRecoveryDebt(
            todaySummary: todaySummary,
            historicalSummaries: historicalSummaries
        )

        // Calculate stress index
        let stressIndex = calculateStressIndex(
            todaySummary: todaySummary,
            historicalSummaries: historicalSummaries
        )

        // 1. Parasympathetic Dominance Detection
        if let z = zScore, let baseline = baseline7d {
            if z > parasympatheticZScoreThreshold && todaySummary.rmssd > baseline {
                detectedStates.append(.parasympatheticDominant)
            }
        }

        // 2. Sympathetic Dominance Spike
        if let z = zScore, z < sympatheticZScoreThreshold {
            detectedStates.append(.sympatheticDominant)
            recommendations.append("Consider stress management techniques today.")
        }

        // 3. Overreaching Risk
        if let z = zScore {
            let consecutiveLowDays = countConsecutiveLowZScoreDays(
                summaries: historicalSummaries,
                threshold: -1.5
            )

            if z < overreachingZScoreThreshold || consecutiveLowDays >= 3 {
                detectedStates.append(.overreachingRisk)
                recommendations.append("High priority: Schedule rest days immediately.")
            }
        }

        // 4. Recovery Debt Accumulation
        if recoveryDebt > recoveryDebtThreshold {
            detectedStates.append(.recoveryDebt)
            recommendations.append("Accumulated fatigue detected. Plan recovery week.")
        }

        // 5. CNS Fatigue Flag
        if detectCNSFatigue(
            todaySummary: todaySummary,
            historicalSummaries: historicalSummaries,
            baseline7d: baseline7d
        ) {
            detectedStates.append(.cnsFatigue)
            recommendations.append("Nervous system fatigue indicated. Reduce training intensity.")
        }

        // Determine primary state
        let primaryState: RecoveryState
        if detectedStates.contains(.overreachingRisk) {
            primaryState = .overreachingRisk
        } else if detectedStates.contains(.cnsFatigue) {
            primaryState = .cnsFatigue
        } else if detectedStates.contains(.recoveryDebt) {
            primaryState = .recoveryDebt
        } else if detectedStates.contains(.sympatheticDominant) {
            primaryState = .sympatheticDominant
        } else if detectedStates.contains(.parasympatheticDominant) {
            primaryState = .parasympatheticDominant
        } else if let z = zScore, z > 1.0 {
            primaryState = .elevated
        } else {
            primaryState = .normal
        }

        // Add primary state recommendation
        recommendations.insert(primaryState.recommendation, at: 0)

        return IntelligenceReport(
            primaryState: primaryState,
            secondaryStates: detectedStates.filter { $0 != primaryState },
            zScore: zScore,
            recoveryDebt: recoveryDebt,
            stressIndex: stressIndex,
            recommendations: recommendations
        )
    }

    // MARK: - Recovery Debt

    /// Calculate cumulative recovery debt
    /// Debt += max(0, Baseline - TodayRMSSD)
    /// Decay: Debt = Debt × 0.9 daily
    static func calculateRecoveryDebt(
        todaySummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary]
    ) -> Double {
        guard let baseline = BaselineEngine.calculate7DayBaseline(from: historicalSummaries) else {
            return 0
        }

        var debt: Double = 0
        let sortedSummaries = historicalSummaries.sorted { $0.date < $1.date }

        for summary in sortedSummaries {
            // Add deficit
            let deficit = max(0, baseline - summary.rmssd)
            debt += deficit

            // Apply daily decay
            debt *= 0.9
        }

        // Add today's contribution
        let todayDeficit = max(0, baseline - todaySummary.rmssd)
        debt += todayDeficit

        return debt
    }

    // MARK: - Stress Index

    /// Calculate stress index from Z-score and HR deviation
    /// StressIndex = w1 * |Z| + w2 * (HR deviation)
    static func calculateStressIndex(
        todaySummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary]
    ) -> Double {
        let w1: Double = 0.6
        let w2: Double = 0.4

        let zScore = todaySummary.zScore ?? 0
        let absZ = abs(min(0, zScore)) // Only negative Z contributes to stress

        // Calculate HR deviation from mean
        let recentHRs = historicalSummaries.suffix(7).map { $0.meanHR }
        guard !recentHRs.isEmpty else { return absZ * w1 }

        let meanHR = recentHRs.reduce(0, +) / Double(recentHRs.count)
        let hrDeviation = max(0, (todaySummary.meanHR - meanHR) / meanHR * 100)

        return w1 * absZ + w2 * hrDeviation
    }

    // MARK: - CNS Fatigue Detection

    /// Detect CNS fatigue: HR elevated, RMSSD suppressed, sleep score < 70, 2+ days
    static func detectCNSFatigue(
        todaySummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        baseline7d: Double?
    ) -> Bool {
        guard let baseline = baseline7d else { return false }

        let recentDays = historicalSummaries.suffix(3)
        guard recentDays.count >= 2 else { return false }

        var fatigueDays = 0

        for summary in recentDays {
            let rmssdSuppressed = summary.rmssd < baseline * 0.85
            let sleepPoor = (summary.sleepScore ?? 100) < 70

            if rmssdSuppressed && sleepPoor {
                fatigueDays += 1
            }
        }

        // Check today
        let todayRmssdSuppressed = todaySummary.rmssd < baseline * 0.85
        let todaySleepPoor = (todaySummary.sleepScore ?? 100) < 70

        if todayRmssdSuppressed && todaySleepPoor {
            fatigueDays += 1
        }

        return fatigueDays >= fatigueConsecutiveDays
    }

    // MARK: - Helpers

    private static func countConsecutiveLowZScoreDays(
        summaries: [DailyHRVSummary],
        threshold: Double
    ) -> Int {
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        var count = 0

        for summary in sortedSummaries {
            guard let zScore = summary.zScore, zScore < threshold else {
                break
            }
            count += 1
        }

        return count
    }
}

// MARK: - REST HR Anomaly Detection

extension RecoveryIntelligenceEngine {

    /// Detect resting HR anomaly (HR > mean + 2σ)
    static func detectHRAnamoly(
        todayHR: Double,
        historicalSummaries: [DailyHRVSummary]
    ) -> Bool {
        let recentHRs = historicalSummaries.suffix(14).map { $0.minHR }
        guard recentHRs.count >= 7 else { return false }

        let mean = recentHRs.reduce(0, +) / Double(recentHRs.count)
        let stdDev = BaselineEngine.calculateStandardDeviation(values: recentHRs, mean: mean)

        return todayHR > mean + 2 * stdDev
    }
}
