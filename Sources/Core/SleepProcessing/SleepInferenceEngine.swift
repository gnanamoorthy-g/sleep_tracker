import Foundation
import os.log

/// Deterministic sleep phase classification engine
/// Based on normalized HR and HRV metrics
struct SleepInferenceEngine {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "SleepInference")

    // MARK: - Baseline
    struct Baseline {
        let heartRate: Double
        let rmssd: Double

        static let `default` = Baseline(heartRate: 70, rmssd: 40)
    }

    // MARK: - Classification

    /// Classify a sleep epoch into a sleep phase
    /// - Parameters:
    ///   - epoch: The epoch to classify
    ///   - baseline: Baseline HR and RMSSD values for normalization
    /// - Returns: The inferred sleep phase
    static func classify(epoch: SleepEpoch, baseline: Baseline) -> SleepPhase {
        // Calculate normalized values
        let hrNorm = epoch.averageHR / baseline.heartRate
        let hrvNorm = epoch.averageRMSSD / baseline.rmssd
        let hrStdDev = epoch.hrStdDev

        logger.debug("Classification: HR_norm=\(String(format: "%.2f", hrNorm)), HRV_norm=\(String(format: "%.2f", hrvNorm)), StdDev=\(String(format: "%.2f", hrStdDev))")

        // Deep Sleep: Low HR, High HRV, Low variability
        // HR_norm < 0.95, HRV_norm > 1.10, hrStdDev < 3
        if hrNorm < 0.95 && hrvNorm > 1.10 && hrStdDev < 3 {
            return .deep
        }

        // REM Sleep: Moderate HR, Moderate HRV, Higher variability
        // HR_norm 0.95-1.05, HRV_norm 0.95-1.10, hrStdDev >= 3
        if hrNorm >= 0.95 && hrNorm <= 1.05 &&
           hrvNorm >= 0.95 && hrvNorm <= 1.10 &&
           hrStdDev >= 3 {
            return .rem
        }

        // Light Sleep: Low-moderate HR, Moderate HRV
        // HR_norm < 1.05, HRV_norm >= 0.90
        if hrNorm < 1.05 && hrvNorm >= 0.90 {
            return .light
        }

        // Awake: High HR, Low HRV (default)
        // HR_norm > 1.05 or HRV_norm < 0.90
        return .awake
    }

    /// Classify an epoch and return a new epoch with the phase set
    static func classifyEpoch(_ epoch: SleepEpoch, baseline: Baseline) -> SleepEpoch {
        let phase = classify(epoch: epoch, baseline: baseline)

        return SleepEpoch(
            id: epoch.id,
            startTime: epoch.startTime,
            endTime: epoch.endTime,
            averageHR: epoch.averageHR,
            averageRMSSD: epoch.averageRMSSD,
            hrStdDev: epoch.hrStdDev,
            phase: phase
        )
    }

    /// Calculate baseline from initial awake period (first 5 minutes of data)
    static func calculateBaseline(from epochs: [SleepEpoch]) -> Baseline {
        guard !epochs.isEmpty else { return .default }

        // Use first few epochs (awake baseline)
        let baselineEpochs = Array(epochs.prefix(10))

        let avgHR = baselineEpochs.map { $0.averageHR }.reduce(0, +) / Double(baselineEpochs.count)
        let avgRMSSD = baselineEpochs.map { $0.averageRMSSD }.reduce(0, +) / Double(baselineEpochs.count)

        // Ensure valid baseline values
        let validHR = avgHR > 40 ? avgHR : Baseline.default.heartRate
        let validRMSSD = avgRMSSD > 10 ? avgRMSSD : Baseline.default.rmssd

        logger.info("Baseline calculated: HR=\(String(format: "%.1f", validHR)), RMSSD=\(String(format: "%.1f", validRMSSD))")

        return Baseline(heartRate: validHR, rmssd: validRMSSD)
    }
}
