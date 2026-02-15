import Foundation
import Combine
import os.log

/// Tracks RR interval data coverage and gaps during overnight monitoring
/// Critical for HW9 which doesn't buffer data when BLE drops
final class RRCoverageTracker: ObservableObject {

    // MARK: - Published State

    @Published private(set) var coveragePercent: Double = 0
    @Published private(set) var totalExpectedSamples: Int = 0
    @Published private(set) var receivedSamples: Int = 0
    @Published private(set) var gapCount: Int = 0
    @Published private(set) var longestGapSeconds: TimeInterval = 0
    @Published private(set) var isLowCoverage: Bool = false

    // MARK: - Configuration

    struct Configuration {
        /// Minimum coverage threshold (below this, mark as low confidence)
        let minCoverageThreshold: Double = 0.80  // 80%

        /// Gap threshold - if no data for this long, count as gap
        let gapThresholdSeconds: TimeInterval = 30

        /// Expected HR samples per minute (typical HR ~60 bpm = 60 samples/min)
        let expectedSamplesPerMinute: Double = 60

        static let `default` = Configuration()
    }

    // MARK: - Data Gap

    struct DataGap: Identifiable {
        let id = UUID()
        let startTime: Date
        var endTime: Date?
        var durationSeconds: TimeInterval {
            (endTime ?? Date()).timeIntervalSince(startTime)
        }
    }

    // MARK: - Properties

    private let config: Configuration
    private let logger = Logger(subsystem: "com.sleeptracker", category: "RRCoverage")

    private var trackingStartTime: Date?
    private var lastSampleTime: Date?
    private var gaps: [DataGap] = []
    private var currentGap: DataGap?
    private var rrSampleCount: Int = 0

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Start tracking coverage for a sleep session
    func startTracking() {
        reset()
        trackingStartTime = Date()
        lastSampleTime = Date()
        logger.info("RR coverage tracking started")
    }

    /// Stop tracking and calculate final coverage
    func stopTracking() -> CoverageReport {
        // Close any open gap
        if var gap = currentGap {
            gap.endTime = Date()
            gaps.append(gap)
            currentGap = nil
        }

        let report = generateReport()
        logger.info("RR coverage tracking stopped. Coverage: \(String(format: "%.1f", report.coveragePercent))%")
        return report
    }

    /// Record received RR samples
    func recordRRSamples(count: Int, timestamp: Date = Date()) {
        rrSampleCount += count
        receivedSamples = rrSampleCount

        // Check if we're coming out of a gap
        if var gap = currentGap {
            gap.endTime = timestamp
            gaps.append(gap)
            currentGap = nil
            gapCount = gaps.count
            logger.debug("Gap ended. Duration: \(String(format: "%.0f", gap.durationSeconds))s")
        }

        lastSampleTime = timestamp
        updateCoverageMetrics()
    }

    /// Check for data gaps (call periodically, e.g., every second)
    func checkForGap(currentTime: Date = Date()) {
        guard let lastSample = lastSampleTime else { return }

        let secondsSinceLastSample = currentTime.timeIntervalSince(lastSample)

        if secondsSinceLastSample > config.gapThresholdSeconds {
            // We're in a gap
            if currentGap == nil {
                currentGap = DataGap(startTime: lastSample)
                logger.warning("Data gap detected - no samples for \(Int(secondsSinceLastSample))s")
            }
        }
    }

    /// Reset all tracking data
    func reset() {
        trackingStartTime = nil
        lastSampleTime = nil
        gaps.removeAll()
        currentGap = nil
        rrSampleCount = 0
        receivedSamples = 0
        gapCount = 0
        longestGapSeconds = 0
        coveragePercent = 0
        isLowCoverage = false
    }

    // MARK: - Coverage Report

    struct CoverageReport {
        let trackingDurationMinutes: Double
        let receivedSamples: Int
        let expectedSamples: Int
        let coveragePercent: Double
        let gapCount: Int
        let totalGapSeconds: TimeInterval
        let longestGapSeconds: TimeInterval
        let isLowCoverage: Bool

        var dataQuality: DataQuality {
            if coveragePercent >= 95 { return .excellent }
            else if coveragePercent >= 85 { return .good }
            else if coveragePercent >= 70 { return .acceptable }
            else if coveragePercent >= 50 { return .poor }
            else { return .unusable }
        }

        enum DataQuality: String {
            case excellent = "Excellent"
            case good = "Good"
            case acceptable = "Acceptable"
            case poor = "Poor"
            case unusable = "Unusable"
        }
    }

    func generateReport() -> CoverageReport {
        let trackingDuration = trackingStartTime.map { Date().timeIntervalSince($0) / 60 } ?? 0
        let expected = Int(trackingDuration * config.expectedSamplesPerMinute)
        let coverage = expected > 0 ? Double(rrSampleCount) / Double(expected) * 100 : 0

        let totalGapSeconds = gaps.reduce(0) { $0 + $1.durationSeconds }
        let maxGap = gaps.map { $0.durationSeconds }.max() ?? 0

        return CoverageReport(
            trackingDurationMinutes: trackingDuration,
            receivedSamples: rrSampleCount,
            expectedSamples: expected,
            coveragePercent: min(100, coverage),
            gapCount: gaps.count,
            totalGapSeconds: totalGapSeconds,
            longestGapSeconds: maxGap,
            isLowCoverage: coverage < config.minCoverageThreshold * 100
        )
    }

    // MARK: - Private Methods

    private func updateCoverageMetrics() {
        guard let startTime = trackingStartTime else { return }

        let trackingMinutes = Date().timeIntervalSince(startTime) / 60
        let expected = Int(trackingMinutes * config.expectedSamplesPerMinute)

        totalExpectedSamples = expected

        if expected > 0 {
            coveragePercent = min(100, Double(rrSampleCount) / Double(expected) * 100)
        }

        isLowCoverage = coveragePercent < config.minCoverageThreshold * 100

        // Update longest gap
        let maxGap = gaps.map { $0.durationSeconds }.max() ?? 0
        if let currentGapDuration = currentGap?.durationSeconds {
            longestGapSeconds = max(maxGap, currentGapDuration)
        } else {
            longestGapSeconds = maxGap
        }
    }

    /// Get all gaps that occurred
    var allGaps: [DataGap] {
        var result = gaps
        if let current = currentGap {
            result.append(current)
        }
        return result
    }
}
