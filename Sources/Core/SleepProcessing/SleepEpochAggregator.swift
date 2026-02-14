import Foundation
import Combine
import os.log

/// Aggregates HR and RR data into 30-second sleep epochs
final class SleepEpochAggregator {

    // MARK: - Configuration
    struct Configuration {
        /// Duration of each epoch in seconds (industry standard: 30 seconds)
        let epochDuration: TimeInterval

        /// Minimum samples required for a valid epoch
        let minSamplesPerEpoch: Int

        static let `default` = Configuration(
            epochDuration: 30,
            minSamplesPerEpoch: 10
        )
    }

    // MARK: - Sample Storage
    private struct TimestampedSample {
        let timestamp: Date
        let heartRate: Int
        let rrIntervals: [Double]
        let rmssd: Double?
    }

    // MARK: - Properties
    private var samples: [TimestampedSample] = []
    private var epochStartTime: Date?
    private let config: Configuration
    private let logger = Logger(subsystem: "com.sleeptracker", category: "EpochAggregator")

    // Publisher for completed epochs
    let epochSubject = PassthroughSubject<SleepEpoch, Never>()
    var epochPublisher: AnyPublisher<SleepEpoch, Never> {
        epochSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization
    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Add a new HR/RR sample
    func addSample(heartRate: Int, rrIntervals: [Double], rmssd: Double?, timestamp: Date = Date()) {
        // Start epoch timer if not started
        if epochStartTime == nil {
            epochStartTime = timestamp
        }

        let sample = TimestampedSample(
            timestamp: timestamp,
            heartRate: heartRate,
            rrIntervals: rrIntervals,
            rmssd: rmssd
        )
        samples.append(sample)

        // Check if epoch duration has elapsed
        if let start = epochStartTime,
           timestamp.timeIntervalSince(start) >= config.epochDuration {
            completeEpoch(endTime: timestamp)
        }
    }

    /// Force completion of current epoch (e.g., when session ends)
    func forceCompleteEpoch() {
        guard !samples.isEmpty else { return }
        completeEpoch(endTime: Date())
    }

    /// Reset the aggregator
    func reset() {
        samples.removeAll()
        epochStartTime = nil
        logger.info("Epoch aggregator reset")
    }

    // MARK: - Private Methods

    private func completeEpoch(endTime: Date) {
        guard let startTime = epochStartTime else { return }

        // Check minimum samples
        guard samples.count >= config.minSamplesPerEpoch else {
            logger.warning("Epoch discarded: insufficient samples (\(self.samples.count))")
            resetEpoch()
            return
        }

        // Calculate epoch metrics
        let avgHR = calculateAverageHR()
        let avgRMSSD = calculateAverageRMSSD()
        let hrStdDev = calculateHRStdDev()

        let epoch = SleepEpoch(
            startTime: startTime,
            endTime: endTime,
            averageHR: avgHR,
            averageRMSSD: avgRMSSD,
            hrStdDev: hrStdDev,
            phase: nil  // Phase will be set by SleepInferenceEngine
        )

        logger.debug("Epoch completed: HR=\(String(format: "%.1f", avgHR)), RMSSD=\(String(format: "%.1f", avgRMSSD)), StdDev=\(String(format: "%.2f", hrStdDev))")

        // Emit the epoch
        epochSubject.send(epoch)

        // Reset for next epoch
        resetEpoch()
    }

    private func resetEpoch() {
        samples.removeAll()
        epochStartTime = Date()
    }

    private func calculateAverageHR() -> Double {
        guard !samples.isEmpty else { return 0 }
        let total = samples.reduce(0) { $0 + $1.heartRate }
        return Double(total) / Double(samples.count)
    }

    private func calculateAverageRMSSD() -> Double {
        let validRMSSD = samples.compactMap { $0.rmssd }
        guard !validRMSSD.isEmpty else { return 0 }
        return validRMSSD.reduce(0, +) / Double(validRMSSD.count)
    }

    private func calculateHRStdDev() -> Double {
        guard samples.count >= 2 else { return 0 }

        let heartRates = samples.map { Double($0.heartRate) }
        let mean = heartRates.reduce(0, +) / Double(heartRates.count)

        let sumSquaredDeviations = heartRates.reduce(0) { sum, hr in
            let deviation = hr - mean
            return sum + (deviation * deviation)
        }

        return sqrt(sumSquaredDeviations / Double(heartRates.count))
    }
}
