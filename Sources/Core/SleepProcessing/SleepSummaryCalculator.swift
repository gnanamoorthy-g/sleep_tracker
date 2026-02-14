import Foundation

/// Helper to calculate a basic SleepSummary from a SleepSession's HRV samples
/// For full phase detection, use SleepScoreCalculator with epochs
struct SleepSummaryCalculator {

    /// Calculate a basic summary from session samples (without full phase detection)
    static func calculate(from session: SleepSession) -> SleepSummary {
        let samples = session.samples
        guard !samples.isEmpty else {
            return createEmptySummary()
        }

        let duration = session.duration

        // Calculate HR stats
        let heartRates = samples.map { Double($0.heartRate) }
        let avgHR = heartRates.reduce(0, +) / Double(heartRates.count)
        let minHR = heartRates.min() ?? 0
        let maxHR = heartRates.max() ?? 0

        // Calculate RMSSD stats
        let rmssdValues = samples.compactMap { $0.rmssd }
        let avgRMSSD = rmssdValues.isEmpty ? 0 : rmssdValues.reduce(0, +) / Double(rmssdValues.count)

        // Estimate sleep score based on duration and HR
        let durationHours = duration / 3600
        let durationScore = min(100, durationHours / 7.5 * 100)

        // Simple score estimation (proper scoring needs epochs)
        let sleepScore = Int(min(100, max(0, durationScore * 0.8 + 20)))

        // Estimate phase breakdown (rough approximation without epoch analysis)
        let totalMinutes = duration / 60
        let estimatedDeepMinutes = totalMinutes * 0.15
        let estimatedRemMinutes = totalMinutes * 0.20
        let estimatedLightMinutes = totalMinutes * 0.60
        let estimatedAwakeMinutes = totalMinutes * 0.05

        return SleepSummary(
            totalDuration: duration,
            sleepScore: sleepScore,
            awakeMinutes: estimatedAwakeMinutes,
            lightMinutes: estimatedLightMinutes,
            deepMinutes: estimatedDeepMinutes,
            remMinutes: estimatedRemMinutes,
            averageHR: avgHR,
            minHR: minHR,
            maxHR: maxHR,
            averageRMSSD: avgRMSSD,
            hrvRecoveryRatio: 1.0,
            awakenings: 0
        )
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
