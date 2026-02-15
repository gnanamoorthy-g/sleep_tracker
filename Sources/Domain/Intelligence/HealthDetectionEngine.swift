import Foundation
import os.log

/// Health Detection Engine for Illness and Overtraining Detection
/// Based on HRV patterns and physiological markers
struct HealthDetectionEngine {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "HealthDetection")

    // MARK: - Illness Detection

    struct IllnessFlag {
        enum Status: String {
            case normal = "Normal"
            case possibleIllness = "Possible Illness"
        }

        let status: Status
        let confidence: Double  // 0-100%
        let indicators: [IllnessIndicator]
        let recommendation: String

        var isAlert: Bool {
            status == .possibleIllness && confidence >= 50
        }
    }

    struct IllnessIndicator {
        let name: String
        let value: Double
        let threshold: Double
        let deviation: Double  // How much it deviates from normal
        let weight: Double     // Weight in confidence calculation
    }

    // MARK: - Overtraining Detection

    struct OvertrainingFlag {
        enum Status: String {
            case normal = "Normal"
            case sympatheticOverload = "Sympathetic Overload"
            case parasympatheticOverload = "Parasympathetic Overload"
        }

        let status: Status
        let confidence: Double  // 0-100%
        let consecutiveDays: Int
        let indicators: [OvertrainingIndicator]
        let recommendation: String

        var isAlert: Bool {
            status != .normal && confidence >= 50
        }
    }

    struct OvertrainingIndicator {
        let name: String
        let description: String
        let severity: Double  // 0-1
    }

    // MARK: - Illness Detection Algorithm

    /// Detect possible illness from HRV data
    /// Triggers if:
    /// - RMSSD drop > 20%
    /// - RHR increase > 7 bpm
    /// - LF/HF increase > 1 SD from baseline
    /// - Persistent for >= 2 days
    static func detectIllness(
        currentSummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        currentLFHF: Double? = nil
    ) -> IllnessFlag {
        logger.debug("Checking illness indicators")

        var indicators: [IllnessIndicator] = []
        var totalWeight: Double = 0
        var weightedSeverity: Double = 0

        // Get baselines
        guard let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries) else {
            return IllnessFlag(
                status: .normal,
                confidence: 0,
                indicators: [],
                recommendation: "Continue monitoring. Not enough baseline data yet."
            )
        }

        let baseline7dHR = calculateBaselineHR(from: historicalSummaries)

        // Indicator 1: RMSSD drop > 20%
        let rmssdDropPercent = (baseline7d - currentSummary.rmssd) / baseline7d * 100
        if rmssdDropPercent > 20 {
            let severity = min(1.0, rmssdDropPercent / 50)  // 50% drop = max severity
            let weight: Double = 0.35
            indicators.append(IllnessIndicator(
                name: "RMSSD Drop",
                value: currentSummary.rmssd,
                threshold: baseline7d * 0.80,
                deviation: rmssdDropPercent,
                weight: weight
            ))
            weightedSeverity += severity * weight
            totalWeight += weight
        }

        // Indicator 2: RHR increase > 7 bpm
        let rhrIncrease = currentSummary.minHR - baseline7dHR
        if rhrIncrease > 7 {
            let severity = min(1.0, rhrIncrease / 15)  // 15 bpm increase = max severity
            let weight: Double = 0.35
            indicators.append(IllnessIndicator(
                name: "RHR Elevated",
                value: currentSummary.minHR,
                threshold: baseline7dHR + 7,
                deviation: rhrIncrease,
                weight: weight
            ))
            weightedSeverity += severity * weight
            totalWeight += weight
        }

        // Indicator 3: LF/HF elevated (if available)
        if let lfhf = currentLFHF {
            let baselineLFHF = calculateBaselineLFHF(from: historicalSummaries)
            let lfhfSD = calculateLFHFStandardDeviation(from: historicalSummaries)

            if lfhfSD > 0 {
                let zScore = (lfhf - baselineLFHF) / lfhfSD
                if zScore > 1.0 {
                    let severity = min(1.0, zScore / 3)  // Z > 3 = max severity
                    let weight: Double = 0.30
                    indicators.append(IllnessIndicator(
                        name: "LF/HF Elevated",
                        value: lfhf,
                        threshold: baselineLFHF + lfhfSD,
                        deviation: zScore,
                        weight: weight
                    ))
                    weightedSeverity += severity * weight
                    totalWeight += weight
                }
            }
        }

        // Check persistence (2+ days)
        let persistenceDays = countConsecutiveAbnormalDays(
            summaries: historicalSummaries,
            baseline7d: baseline7d,
            baselineHR: baseline7dHR
        )

        let persistenceMultiplier = persistenceDays >= 2 ? 1.5 : (persistenceDays == 1 ? 1.0 : 0.5)

        // Calculate final confidence
        var confidence = totalWeight > 0 ? (weightedSeverity / totalWeight) * 100 * persistenceMultiplier : 0
        confidence = min(100, confidence)

        let status: IllnessFlag.Status = confidence >= 40 ? .possibleIllness : .normal

        let recommendation: String
        if status == .possibleIllness {
            if confidence >= 70 {
                recommendation = "Strong indicators of illness detected. Consider resting and monitoring symptoms closely."
            } else {
                recommendation = "Some indicators suggest possible illness. Take it easy and monitor how you feel."
            }
        } else {
            recommendation = "No illness indicators detected. Continue your normal routine."
        }

        logger.info("Illness detection: \(status.rawValue), Confidence: \(String(format: "%.1f", confidence))%")

        return IllnessFlag(
            status: status,
            confidence: confidence,
            indicators: indicators,
            recommendation: recommendation
        )
    }

    // MARK: - Overtraining Detection Algorithm

    /// Detect overtraining from HRV patterns
    /// Sympathetic Overload: 3+ consecutive days of
    /// - RMSSD suppressed > 15%
    /// - RHR elevated > 5 bpm
    /// - HRR drop < 15 bpm
    static func detectOvertraining(
        currentSummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        hrrScore: Double? = nil  // Heart Rate Recovery score
    ) -> OvertrainingFlag {
        logger.debug("Checking overtraining indicators")

        guard let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries) else {
            return OvertrainingFlag(
                status: .normal,
                confidence: 0,
                consecutiveDays: 0,
                indicators: [],
                recommendation: "Continue monitoring. Not enough baseline data yet."
            )
        }

        let baseline7dHR = calculateBaselineHR(from: historicalSummaries)

        // Check current day indicators
        let rmssdSuppressed = (baseline7d - currentSummary.rmssd) / baseline7d > 0.15
        let rhrElevated = currentSummary.minHR - baseline7dHR > 5
        let hrrPoor = hrrScore.map { $0 < 15 } ?? false

        var indicators: [OvertrainingIndicator] = []

        if rmssdSuppressed {
            let suppression = (baseline7d - currentSummary.rmssd) / baseline7d * 100
            indicators.append(OvertrainingIndicator(
                name: "RMSSD Suppressed",
                description: "HRV \(String(format: "%.0f", suppression))% below baseline",
                severity: min(1.0, suppression / 30)
            ))
        }

        if rhrElevated {
            let elevation = currentSummary.minHR - baseline7dHR
            indicators.append(OvertrainingIndicator(
                name: "RHR Elevated",
                description: "Resting HR \(String(format: "%.0f", elevation)) bpm above normal",
                severity: min(1.0, elevation / 10)
            ))
        }

        if hrrPoor {
            indicators.append(OvertrainingIndicator(
                name: "HRR Impaired",
                description: "Heart Rate Recovery below optimal",
                severity: 0.7
            ))
        }

        // Count consecutive days with overtraining indicators
        let consecutiveDays = countConsecutiveOvertrainingDays(
            summaries: historicalSummaries,
            baseline7d: baseline7d,
            baselineHR: baseline7dHR
        )

        // Determine status
        let status: OvertrainingFlag.Status
        var confidence: Double = 0

        if consecutiveDays >= 3 && indicators.count >= 2 {
            status = .sympatheticOverload
            confidence = min(100, Double(consecutiveDays) * 20 + Double(indicators.count) * 15)
        } else if consecutiveDays >= 5 && currentSummary.rmssd > baseline7d * 1.3 {
            // Parasympathetic overtraining: HRV paradoxically elevated for too long
            status = .parasympatheticOverload
            confidence = min(100, Double(consecutiveDays) * 15)
            indicators.append(OvertrainingIndicator(
                name: "HRV Paradox",
                description: "HRV abnormally elevated - may indicate deep fatigue",
                severity: 0.6
            ))
        } else {
            status = .normal
            confidence = 0
        }

        let recommendation: String
        switch status {
        case .sympatheticOverload:
            recommendation = "Sympathetic overload detected. Reduce training intensity and prioritize sleep and recovery."
        case .parasympatheticOverload:
            recommendation = "Parasympathetic saturation detected. Your body may be deeply fatigued. Consider a rest week."
        case .normal:
            if consecutiveDays >= 2 {
                recommendation = "Early signs of accumulated fatigue. Monitor closely and consider lighter training."
            } else {
                recommendation = "No overtraining indicators. Recovery looks good."
            }
        }

        logger.info("Overtraining detection: \(status.rawValue), Consecutive days: \(consecutiveDays)")

        return OvertrainingFlag(
            status: status,
            confidence: confidence,
            consecutiveDays: consecutiveDays,
            indicators: indicators,
            recommendation: recommendation
        )
    }

    // MARK: - Helper Methods

    private static func calculateBaselineHR(from summaries: [DailyHRVSummary]) -> Double {
        let last7 = summaries.suffix(7)
        guard !last7.isEmpty else { return 60 }
        return last7.map { $0.minHR }.reduce(0, +) / Double(last7.count)
    }

    private static func calculateBaselineLFHF(from summaries: [DailyHRVSummary]) -> Double {
        // Default baseline LF/HF if not stored
        return 1.5
    }

    private static func calculateLFHFStandardDeviation(from summaries: [DailyHRVSummary]) -> Double {
        // Default standard deviation if not stored
        return 0.5
    }

    private static func countConsecutiveAbnormalDays(
        summaries: [DailyHRVSummary],
        baseline7d: Double,
        baselineHR: Double
    ) -> Int {
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        var count = 0

        for summary in sortedSummaries {
            let rmssdLow = summary.rmssd < baseline7d * 0.80
            let hrHigh = summary.minHR > baselineHR + 7

            if rmssdLow || hrHigh {
                count += 1
            } else {
                break
            }
        }

        return count
    }

    private static func countConsecutiveOvertrainingDays(
        summaries: [DailyHRVSummary],
        baseline7d: Double,
        baselineHR: Double
    ) -> Int {
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        var count = 0

        for summary in sortedSummaries {
            let rmssdSuppressed = summary.rmssd < baseline7d * 0.85
            let hrElevated = summary.minHR > baselineHR + 5

            if rmssdSuppressed && hrElevated {
                count += 1
            } else {
                break
            }
        }

        return count
    }
}
