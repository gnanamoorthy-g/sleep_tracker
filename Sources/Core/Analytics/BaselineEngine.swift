import Foundation

/// Computes rolling baselines and statistical metrics for HRV data
struct BaselineEngine {

    // MARK: - Rolling Baselines

    /// Calculate 7-day rolling baseline RMSSD
    static func calculate7DayBaseline(from summaries: [DailyHRVSummary]) -> Double? {
        let last7Days = summaries.suffix(7)
        guard !last7Days.isEmpty else { return nil }

        let rmssdValues = last7Days.map { $0.rmssd }
        return rmssdValues.reduce(0, +) / Double(rmssdValues.count)
    }

    /// Calculate 30-day rolling baseline RMSSD
    static func calculate30DayBaseline(from summaries: [DailyHRVSummary]) -> Double? {
        let last30Days = summaries.suffix(30)
        guard !last30Days.isEmpty else { return nil }

        let rmssdValues = last30Days.map { $0.rmssd }
        return rmssdValues.reduce(0, +) / Double(rmssdValues.count)
    }

    // MARK: - Z-Score Calculation

    /// Calculate Z-score deviation from 30-day baseline
    /// Z = (Today - Baseline30d) / σ30d
    static func calculateZScore(todayRMSSD: Double, from summaries: [DailyHRVSummary]) -> Double? {
        let last30Days = summaries.suffix(30)
        guard last30Days.count >= 7 else { return nil } // Need at least 7 days for meaningful stats

        let rmssdValues = last30Days.map { $0.rmssd }
        let mean = rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        let stdDev = calculateStandardDeviation(values: rmssdValues, mean: mean)

        guard stdDev > 0 else { return nil }

        return (todayRMSSD - mean) / stdDev
    }

    // MARK: - Standard Deviation

    static func calculateStandardDeviation(values: [Double], mean: Double? = nil) -> Double {
        guard values.count > 1 else { return 0 }

        let avg = mean ?? (values.reduce(0, +) / Double(values.count))
        let squaredDiffs = values.map { pow($0 - avg, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }

    // MARK: - Recovery Score

    /// Calculate recovery score as percentage of baseline
    /// Recovery = (TodayRMSSD / Baseline7d) × 100
    static func calculateRecoveryScore(todayRMSSD: Double, baseline7d: Double) -> Double {
        guard baseline7d > 0 else { return 100 }
        return (todayRMSSD / baseline7d) * 100
    }

    // MARK: - Trend Analysis

    /// Calculate slope of RMSSD trend over last N days
    static func calculateTrendSlope(from summaries: [DailyHRVSummary], days: Int = 7) -> Double {
        let recentDays = Array(summaries.suffix(days))
        guard recentDays.count >= 2 else { return 0 }

        // Simple linear regression
        let n = Double(recentDays.count)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (index, summary) in recentDays.enumerated() {
            let x = Double(index)
            let y = summary.rmssd
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
    }

    // MARK: - Z-Score Interpretation

    enum ZScoreInterpretation: String {
        case elevatedRecovery = "Elevated Recovery"
        case normal = "Normal"
        case stressed = "Stressed"
        case overreachingRisk = "Overreaching Risk"

        static func from(zScore: Double) -> ZScoreInterpretation {
            switch zScore {
            case 1.0...: return .elevatedRecovery
            case -1.0..<1.0: return .normal
            case -2.0..<(-1.0): return .stressed
            default: return .overreachingRisk
            }
        }
    }

    // MARK: - Update Summary with Baselines

    /// Creates a new summary with calculated baselines and z-score
    static func enrichWithBaselines(
        summary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary]
    ) -> DailyHRVSummary {
        let baseline7d = calculate7DayBaseline(from: historicalSummaries)
        let baseline30d = calculate30DayBaseline(from: historicalSummaries)
        let zScore = calculateZScore(todayRMSSD: summary.rmssd, from: historicalSummaries)

        let recoveryScore: Int?
        if let baseline = baseline7d {
            recoveryScore = Int(calculateRecoveryScore(todayRMSSD: summary.rmssd, baseline7d: baseline))
        } else {
            recoveryScore = nil
        }

        return DailyHRVSummary(
            id: summary.id,
            date: summary.date,
            meanHR: summary.meanHR,
            minHR: summary.minHR,
            maxHR: summary.maxHR,
            rmssd: summary.rmssd,
            sdnn: summary.sdnn,
            sleepDurationMinutes: summary.sleepDurationMinutes,
            deepSleepMinutes: summary.deepSleepMinutes,
            lightSleepMinutes: summary.lightSleepMinutes,
            remSleepMinutes: summary.remSleepMinutes,
            awakeMinutes: summary.awakeMinutes,
            baseline7d: baseline7d,
            baseline30d: baseline30d,
            zScore: zScore,
            recoveryScore: recoveryScore,
            sleepScore: summary.sleepScore
        )
    }
}
