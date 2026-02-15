import Foundation
import os.log

/// RR Interval Processing Pipeline
/// Handles ectopic beat removal, artifact detection, and interpolation
struct RRIntervalProcessor {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "RRProcessor")

    // MARK: - Configuration

    struct Configuration {
        /// Minimum valid RR interval (ms) - below this is ectopic
        let minRRInterval: Double = 300

        /// Maximum valid RR interval (ms) - above this is ectopic
        let maxRRInterval: Double = 2000

        /// Artifact threshold - if change > 20% of previous, mark as artifact
        let artifactThresholdPercent: Double = 0.20

        /// Minimum clean data duration required (seconds)
        let minCleanDataDuration: TimeInterval = 120  // 2 minutes

        static let `default` = Configuration()
    }

    // MARK: - Processed Result

    struct ProcessedRRResult {
        let cleanIntervals: [Double]
        let originalCount: Int
        let removedEctopicCount: Int
        let artifactCount: Int
        let interpolatedCount: Int
        let isValid: Bool
        let cleanDuration: TimeInterval

        var qualityScore: Double {
            guard originalCount > 0 else { return 0 }
            return Double(cleanIntervals.count) / Double(originalCount) * 100
        }
    }

    // MARK: - Processing Pipeline

    /// Process raw RR intervals through the validation pipeline
    /// - Parameters:
    ///   - intervals: Raw RR intervals in milliseconds
    ///   - config: Processing configuration
    /// - Returns: Processed result with clean intervals
    static func process(
        _ intervals: [Double],
        config: Configuration = .default
    ) -> ProcessedRRResult {
        guard !intervals.isEmpty else {
            return ProcessedRRResult(
                cleanIntervals: [],
                originalCount: 0,
                removedEctopicCount: 0,
                artifactCount: 0,
                interpolatedCount: 0,
                isValid: false,
                cleanDuration: 0
            )
        }

        logger.debug("Processing \(intervals.count) RR intervals")

        // Step 1: Remove ectopic beats (out of physiological range)
        var validIntervals: [(index: Int, value: Double)] = []
        var ectopicCount = 0

        for (index, interval) in intervals.enumerated() {
            if interval >= config.minRRInterval && interval <= config.maxRRInterval {
                validIntervals.append((index, interval))
            } else {
                ectopicCount += 1
                logger.debug("Ectopic removed at index \(index): \(interval)ms")
            }
        }

        // Step 2: Detect artifacts (sudden changes > 20%)
        var artifactIndices: Set<Int> = []

        for i in 1..<validIntervals.count {
            let current = validIntervals[i].value
            let previous = validIntervals[i - 1].value
            let changePercent = abs(current - previous) / previous

            if changePercent > config.artifactThresholdPercent {
                artifactIndices.insert(i)
                logger.debug("Artifact detected at index \(i): \(String(format: "%.1f", changePercent * 100))% change")
            }
        }

        // Step 3: Replace artifacts with cubic spline interpolation
        var cleanIntervals = validIntervals.map { $0.value }
        var interpolatedCount = 0

        if !artifactIndices.isEmpty {
            cleanIntervals = interpolateArtifacts(
                intervals: cleanIntervals,
                artifactIndices: artifactIndices
            )
            interpolatedCount = artifactIndices.count
        }

        // Calculate clean data duration
        let cleanDuration = cleanIntervals.reduce(0, +) / 1000.0  // Convert ms to seconds

        let isValid = cleanDuration >= config.minCleanDataDuration

        logger.info("RR Processing complete: \(cleanIntervals.count) clean intervals, duration: \(String(format: "%.1f", cleanDuration))s, valid: \(isValid)")

        return ProcessedRRResult(
            cleanIntervals: cleanIntervals,
            originalCount: intervals.count,
            removedEctopicCount: ectopicCount,
            artifactCount: artifactIndices.count,
            interpolatedCount: interpolatedCount,
            isValid: isValid,
            cleanDuration: cleanDuration
        )
    }

    // MARK: - Cubic Spline Interpolation

    /// Replace artifact values using cubic spline interpolation
    private static func interpolateArtifacts(
        intervals: [Double],
        artifactIndices: Set<Int>
    ) -> [Double] {
        var result = intervals

        // For each artifact, find surrounding valid points and interpolate
        for artifactIndex in artifactIndices.sorted() {
            guard artifactIndex > 0 && artifactIndex < intervals.count - 1 else {
                // For edge cases, use nearest neighbor
                if artifactIndex == 0 && intervals.count > 1 {
                    result[0] = intervals[1]
                } else if artifactIndex == intervals.count - 1 && intervals.count > 1 {
                    result[artifactIndex] = intervals[artifactIndex - 1]
                }
                continue
            }

            // Find valid neighbors for interpolation
            let (leftIndices, rightIndices) = findValidNeighbors(
                intervals: intervals,
                artifactIndex: artifactIndex,
                artifactIndices: artifactIndices
            )

            // Perform cubic spline interpolation if we have enough points
            if leftIndices.count >= 2 && rightIndices.count >= 2 {
                result[artifactIndex] = cubicInterpolate(
                    intervals: intervals,
                    leftIndices: leftIndices,
                    rightIndices: rightIndices,
                    targetIndex: artifactIndex
                )
            } else {
                // Fallback to linear interpolation
                result[artifactIndex] = linearInterpolate(
                    intervals: intervals,
                    leftIndices: leftIndices,
                    rightIndices: rightIndices,
                    targetIndex: artifactIndex
                )
            }
        }

        return result
    }

    /// Find valid neighbor indices for interpolation
    private static func findValidNeighbors(
        intervals: [Double],
        artifactIndex: Int,
        artifactIndices: Set<Int>
    ) -> (left: [Int], right: [Int]) {
        var leftIndices: [Int] = []
        var rightIndices: [Int] = []

        // Find up to 2 valid points on the left
        var i = artifactIndex - 1
        while i >= 0 && leftIndices.count < 2 {
            if !artifactIndices.contains(i) {
                leftIndices.insert(i, at: 0)
            }
            i -= 1
        }

        // Find up to 2 valid points on the right
        i = artifactIndex + 1
        while i < intervals.count && rightIndices.count < 2 {
            if !artifactIndices.contains(i) {
                rightIndices.append(i)
            }
            i += 1
        }

        return (leftIndices, rightIndices)
    }

    /// Cubic spline interpolation using Catmull-Rom spline
    private static func cubicInterpolate(
        intervals: [Double],
        leftIndices: [Int],
        rightIndices: [Int],
        targetIndex: Int
    ) -> Double {
        guard leftIndices.count >= 2 && rightIndices.count >= 1 else {
            return linearInterpolate(
                intervals: intervals,
                leftIndices: leftIndices,
                rightIndices: rightIndices,
                targetIndex: targetIndex
            )
        }

        // Get the four control points for Catmull-Rom spline
        let p0 = intervals[leftIndices[0]]
        let p1 = intervals[leftIndices[1]]
        let p2 = rightIndices.count >= 1 ? intervals[rightIndices[0]] : p1
        let p3 = rightIndices.count >= 2 ? intervals[rightIndices[1]] : p2

        // Calculate t (normalized position between p1 and p2)
        let t = Double(targetIndex - leftIndices[1]) / Double(rightIndices[0] - leftIndices[1])

        // Catmull-Rom spline formula
        let t2 = t * t
        let t3 = t2 * t

        let result = 0.5 * (
            (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        )

        return max(300, min(2000, result))  // Clamp to valid range
    }

    /// Linear interpolation fallback
    private static func linearInterpolate(
        intervals: [Double],
        leftIndices: [Int],
        rightIndices: [Int],
        targetIndex: Int
    ) -> Double {
        let leftValue = leftIndices.last.map { intervals[$0] } ?? intervals.first ?? 800
        let rightValue = rightIndices.first.map { intervals[$0] } ?? intervals.last ?? 800

        if leftIndices.isEmpty {
            return rightValue
        }
        if rightIndices.isEmpty {
            return leftValue
        }

        let leftIndex = leftIndices.last!
        let rightIndex = rightIndices.first!
        let t = Double(targetIndex - leftIndex) / Double(rightIndex - leftIndex)

        return leftValue + t * (rightValue - leftValue)
    }
}

// MARK: - Quality Assessment

extension RRIntervalProcessor {

    /// Assess the quality of RR interval data
    static func assessQuality(result: ProcessedRRResult) -> DataQuality {
        let qualityScore = result.qualityScore

        switch qualityScore {
        case 95...:
            return .excellent
        case 85..<95:
            return .good
        case 70..<85:
            return .acceptable
        case 50..<70:
            return .poor
        default:
            return .unusable
        }
    }

    enum DataQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case acceptable = "Acceptable"
        case poor = "Poor"
        case unusable = "Unusable"

        var isUsable: Bool {
            self != .unusable
        }
    }
}
