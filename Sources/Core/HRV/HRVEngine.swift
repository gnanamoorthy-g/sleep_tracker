import Foundation
import os.log

/// HRV computation engine
/// Maintains a rolling buffer of RR intervals and computes HRV metrics
final class HRVEngine {

    // MARK: - Configuration
    struct Configuration {
        /// Maximum duration of RR intervals to keep (default: 10 minutes)
        let maxBufferDuration: TimeInterval

        /// Minimum intervals required for valid computation
        let minIntervalsForComputation: Int

        /// Window size for rolling computation (default: 5 minutes)
        let computationWindowDuration: TimeInterval

        static let `default` = Configuration(
            maxBufferDuration: 600,      // 10 minutes
            minIntervalsForComputation: 30,
            computationWindowDuration: 300  // 5 minutes
        )
    }

    // MARK: - Properties
    private var rrBuffer: [(timestamp: Date, interval: Double)] = []
    private let config: Configuration
    private let logger = Logger(subsystem: "com.sleeptracker", category: "HRV")

    // MARK: - Initialization
    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Add new RR intervals to the buffer
    func addRRIntervals(_ intervals: [Double], timestamp: Date = Date()) {
        for interval in intervals {
            rrBuffer.append((timestamp: timestamp, interval: interval))
        }

        // Trim buffer to max duration
        trimBuffer()
    }

    /// Compute RMSSD from the current buffer
    func computeRMSSD() -> Double? {
        let intervals = getRecentIntervals()

        guard intervals.count >= config.minIntervalsForComputation else {
            logger.debug("Insufficient intervals for RMSSD: \(intervals.count)")
            return nil
        }

        return Self.computeRMSSD(from: intervals)
    }

    /// Compute all HRV metrics from the current buffer
    func computeMetrics() -> HRVMetrics? {
        let intervals = getRecentIntervals()

        guard intervals.count >= config.minIntervalsForComputation else {
            logger.debug("Insufficient intervals for metrics: \(intervals.count)")
            return nil
        }

        guard let rmssd = Self.computeRMSSD(from: intervals) else {
            return nil
        }

        let sdnn = Self.computeSDNN(from: intervals)
        let pnn50 = Self.computePNN50(from: intervals)

        return HRVMetrics(
            rmssd: rmssd,
            sdnn: sdnn,
            pnn50: pnn50,
            sampleCount: intervals.count,
            windowDuration: config.computationWindowDuration
        )
    }

    /// Clear all stored intervals
    func reset() {
        rrBuffer.removeAll()
        logger.info("HRV buffer reset")
    }

    /// Current buffer size
    var bufferCount: Int {
        rrBuffer.count
    }

    // MARK: - Static Computation Methods (Pure Functions)

    /// Compute RMSSD from an array of RR intervals
    /// RMSSD = sqrt(mean(diff(RR[i] - RR[i-1])^2))
    static func computeRMSSD(from intervals: [Double]) -> Double? {
        guard intervals.count >= 2 else { return nil }

        var sumSquaredDiffs: Double = 0
        var count = 0

        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i - 1]
            sumSquaredDiffs += diff * diff
            count += 1
        }

        guard count > 0 else { return nil }

        let meanSquaredDiff = sumSquaredDiffs / Double(count)
        return sqrt(meanSquaredDiff)
    }

    /// Compute SDNN (Standard Deviation of NN intervals)
    static func computeSDNN(from intervals: [Double]) -> Double? {
        guard intervals.count >= 2 else { return nil }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let sumSquaredDeviations = intervals.reduce(0) { sum, interval in
            let deviation = interval - mean
            return sum + (deviation * deviation)
        }

        let variance = sumSquaredDeviations / Double(intervals.count - 1)
        return sqrt(variance)
    }

    /// Compute pNN50 (percentage of successive differences > 50ms)
    static func computePNN50(from intervals: [Double]) -> Double? {
        guard intervals.count >= 2 else { return nil }

        var nn50Count = 0

        for i in 1..<intervals.count {
            let diff = abs(intervals[i] - intervals[i - 1])
            if diff > 50 {
                nn50Count += 1
            }
        }

        return Double(nn50Count) / Double(intervals.count - 1) * 100
    }

    // MARK: - Private Methods

    private func trimBuffer() {
        let cutoffTime = Date().addingTimeInterval(-config.maxBufferDuration)
        rrBuffer.removeAll { $0.timestamp < cutoffTime }
    }

    private func getRecentIntervals() -> [Double] {
        let cutoffTime = Date().addingTimeInterval(-config.computationWindowDuration)
        return rrBuffer
            .filter { $0.timestamp >= cutoffTime }
            .map { $0.interval }
    }
}
