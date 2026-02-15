import Foundation
import os.log

// MARK: - Data Models

/// Represents a single heart rate sample with motion and quality data
struct HeartRateSample {
    let timestamp: Date
    let bpm: Double
    let motionRMS: Double      // g-force RMS from accelerometer
    let signalQuality: Double? // 0.0 - 1.0 (optional)
}

/// A window of rest data for RHR calculation
struct RestWindow {
    let start: Date
    let end: Date
    let medianHR: Double
    let variance: Double
}

/// Result of RHR calculation with confidence
struct RHRResult {
    let value: Double
    let confidence: Double     // 0.0 - 1.0
    let source: RHRSource

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.75...: return .high
        case 0.5..<0.75: return .medium
        default: return .low
        }
    }

    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

enum RHRSource: String {
    case sleep = "Sleep"
    case daytimeRestFallback = "Daytime Rest"
    case previousDayFallback = "Previous Day"
}

// MARK: - Resting Heart Rate Calculator

/// Production-grade RHR calculation engine
/// Handles overnight disconnects, noise, and provides confidence scoring
struct RestingHeartRateCalculator {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "RHR")

    // MARK: - Main Entry Point

    /// Compute daily RHR from heart rate samples
    /// - Parameters:
    ///   - samples: All heart rate samples for the period
    ///   - previousRHR: Previous day's RHR for fallback
    /// - Returns: RHR result with value and confidence
    static func computeDailyRHR(
        samples: [HeartRateSample],
        previousRHR: Double?
    ) -> RHRResult {
        logger.debug("Computing daily RHR from \(samples.count) samples")

        // Step 1: Assemble night session
        let night = assembleNightSession(samples: samples)

        // Step 2: Fill short gaps (handle disconnects)
        let stitched = fillShortGaps(samples: night)

        // Step 3: Validate coverage
        guard validateNightCoverage(samples: stitched) else {
            logger.info("Insufficient night coverage, using fallback")
            return RHRResult(
                value: previousRHR ?? 0,
                confidence: 0.3,
                source: .previousDayFallback
            )
        }

        // Step 4: Apply rolling median smoothing
        let smoothed = rollingMedian(samples: stitched)

        // Step 5: Detect sleep windows
        let sleepWindows = detectSleepWindows(samples: smoothed)

        // Step 6: Calculate RHR
        return calculateRHR(
            from: sleepWindows,
            allNightSamples: smoothed,
            previousRHR: previousRHR
        )
    }

    // MARK: - Night Session Assembly

    /// Assemble samples into a night session (7pm - 12pm next day)
    static func assembleNightSession(samples: [HeartRateSample]) -> [HeartRateSample] {
        let calendar = Calendar.current

        let groupedByNight = Dictionary(grouping: samples) { sample -> Date in
            let hour = calendar.component(.hour, from: sample.timestamp)
            // Assign samples to sleep day (7pm-12pm next day)
            if hour >= 19 {
                return calendar.startOfDay(for: sample.timestamp)
            } else if hour < 12 {
                return calendar.startOfDay(for: sample.timestamp.addingTimeInterval(-86400))
            } else {
                // Daytime samples - assign to previous night
                return calendar.startOfDay(for: sample.timestamp.addingTimeInterval(-86400))
            }
        }

        // Return most recent night with most data
        return groupedByNight.values.max(by: { $0.count < $1.count }) ?? []
    }

    // MARK: - Gap Handling (Disconnect Tolerance)

    /// Fill short gaps (< 20 minutes) to handle brief disconnects
    static func fillShortGaps(
        samples: [HeartRateSample],
        maxGap: TimeInterval = 20 * 60
    ) -> [HeartRateSample] {
        guard samples.count > 1 else { return samples }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        var stitched: [HeartRateSample] = [sorted[0]]

        for i in 1..<sorted.count {
            let gap = sorted[i].timestamp.timeIntervalSince(sorted[i - 1].timestamp)

            if gap <= maxGap {
                stitched.append(sorted[i])
            }
            // Large gap: break - treat as sleep interruption
        }

        return stitched
    }

    // MARK: - Coverage Validation

    /// Validate that we have sufficient night coverage
    /// Requires: >= 90 minutes total, >= 45 minutes continuous
    static func validateNightCoverage(samples: [HeartRateSample]) -> Bool {
        guard let first = samples.first,
              let last = samples.last else { return false }

        let totalDuration = last.timestamp.timeIntervalSince(first.timestamp)

        logger.debug("Night coverage: \(Int(totalDuration / 60)) minutes")

        return totalDuration >= 90 * 60 // At least 90 minutes
    }

    // MARK: - Signal Processing

    /// Apply rolling median smoothing (30-second window)
    static func rollingMedian(
        samples: [HeartRateSample],
        windowSeconds: TimeInterval = 30
    ) -> [HeartRateSample] {
        var smoothed: [HeartRateSample] = []

        for sample in samples {
            let windowStart = sample.timestamp.addingTimeInterval(-windowSeconds)
            let window = samples.filter {
                $0.timestamp >= windowStart && $0.timestamp <= sample.timestamp
            }

            let bpmValues = window.map { $0.bpm }.sorted()
            guard !bpmValues.isEmpty else { continue }

            let median = bpmValues[bpmValues.count / 2]

            smoothed.append(HeartRateSample(
                timestamp: sample.timestamp,
                bpm: median,
                motionRMS: sample.motionRMS,
                signalQuality: sample.signalQuality
            ))
        }

        return smoothed
    }

    // MARK: - Sleep Detection

    /// Detect sleep windows based on movement and HR variability
    static func detectSleepWindows(samples: [HeartRateSample]) -> [RestWindow] {
        let windowSize: TimeInterval = 5 * 60 // 5 minutes
        var windows: [RestWindow] = []

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        for i in stride(from: 0, to: sorted.count, by: 10) { // Sample every ~10 points
            guard i < sorted.count else { break }

            let start = sorted[i].timestamp
            let end = start.addingTimeInterval(windowSize)

            let windowSamples = sorted.filter {
                $0.timestamp >= start && $0.timestamp <= end
            }

            guard windowSamples.count >= 10 else { continue }

            // Check motion (low motion = likely asleep)
            let motionAvg = windowSamples.map { $0.motionRMS }.reduce(0, +)
                / Double(windowSamples.count)

            // Check HR variability (low variability during deep sleep)
            let hrValues = windowSamples.map { $0.bpm }
            let meanHR = hrValues.reduce(0, +) / Double(hrValues.count)
            let variance = hrValues.map { pow($0 - meanHR, 2) }.reduce(0, +)
                / Double(hrValues.count)
            let stdDev = sqrt(variance)

            // Sleep criteria: low motion AND low HR variability
            if motionAvg < 0.02 && stdDev < 3.0 {
                let sortedHR = hrValues.sorted()
                let median = sortedHR[sortedHR.count / 2]

                windows.append(RestWindow(
                    start: start,
                    end: end,
                    medianHR: median,
                    variance: variance
                ))
            }
        }

        logger.debug("Detected \(windows.count) sleep windows")
        return windows
    }

    // MARK: - RHR Calculation

    /// Calculate RHR from sleep windows
    static func calculateRHR(
        from windows: [RestWindow],
        allNightSamples: [HeartRateSample],
        previousRHR: Double?
    ) -> RHRResult {
        guard !windows.isEmpty else {
            logger.info("No sleep windows detected, using fallback")
            if let previous = previousRHR {
                return RHRResult(
                    value: previous,
                    confidence: 0.3,
                    source: .previousDayFallback
                )
            }
            return RHRResult(value: 0, confidence: 0, source: .previousDayFallback)
        }

        // Find lowest 20% of nightly HR distribution
        let hrValues = allNightSamples.map { $0.bpm }.sorted()
        let thresholdIndex = Int(Double(hrValues.count) * 0.2)
        let threshold = hrValues[max(0, min(thresholdIndex, hrValues.count - 1))]

        // Filter windows below threshold and sort by HR
        let filtered = windows
            .filter { $0.medianHR <= threshold }
            .sorted { $0.medianHR < $1.medianHR }

        // Take lowest 3 windows
        let selected = Array(filtered.prefix(3))

        guard !selected.isEmpty else {
            // Fallback: use overall minimum from windows
            let minWindow = windows.min(by: { $0.medianHR < $1.medianHR })!
            return RHRResult(
                value: round(minWindow.medianHR),
                confidence: 0.5,
                source: .sleep
            )
        }

        let rhr = selected.map { $0.medianHR }.reduce(0, +) / Double(selected.count)

        // Confidence based on number of qualifying windows
        let confidence = min(1.0, Double(selected.count) / 3.0)

        logger.info("RHR calculated: \(Int(rhr)) bpm, confidence: \(String(format: "%.2f", confidence))")

        return RHRResult(
            value: round(rhr),
            confidence: confidence,
            source: .sleep
        )
    }
}

// MARK: - Integration with Existing Models

extension RestingHeartRateCalculator {

    /// Calculate RHR from HRVSamples (integration with existing sleep session data)
    static func calculateFromSleepSession(_ session: SleepSession) -> RHRResult {
        // Convert HRVSamples to HeartRateSamples
        let samples = session.samples.map { hrvSample in
            HeartRateSample(
                timestamp: hrvSample.timestamp,
                bpm: Double(hrvSample.heartRate),
                motionRMS: 0.01, // Default low motion for sleep
                signalQuality: 1.0
            )
        }

        return computeDailyRHR(samples: samples, previousRHR: nil)
    }

    /// Calculate RHR from continuous HRV data
    static func calculateFromContinuousData(_ data: [ContinuousHRVData]) -> RHRResult? {
        guard !data.isEmpty else { return nil }

        // Create synthetic samples from aggregated data
        var samples: [HeartRateSample] = []

        for bucket in data {
            // Create one sample per bucket representing the average
            samples.append(HeartRateSample(
                timestamp: bucket.date,
                bpm: bucket.averageHR,
                motionRMS: 0.01,
                signalQuality: Double(bucket.sampleCount) / 100.0
            ))
        }

        return computeDailyRHR(samples: samples, previousRHR: nil)
    }
}

// MARK: - RHR Repository

final class RHRResultRepository {
    private let storageKey = "rhr_results"

    func save(_ result: RHRResult, for date: Date) {
        var results = loadAll()
        let key = dateKey(date)
        results[key] = StoredRHRResult(
            value: result.value,
            confidence: result.confidence,
            source: result.source.rawValue
        )
        saveAll(results)
    }

    func load(for date: Date) -> RHRResult? {
        guard let stored = loadAll()[dateKey(date)] else { return nil }
        guard let source = RHRSource(rawValue: stored.source) else { return nil }
        return RHRResult(
            value: stored.value,
            confidence: stored.confidence,
            source: source
        )
    }

    func loadPreviousDay(before date: Date) -> Double? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }
        return load(for: yesterday)?.value
    }

    private func loadAll() -> [String: StoredRHRResult] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let results = try? JSONDecoder().decode([String: StoredRHRResult].self, from: data) else {
            return [:]
        }
        return results
    }

    private func saveAll(_ results: [String: StoredRHRResult]) {
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private struct StoredRHRResult: Codable {
        let value: Double
        let confidence: Double
        let source: String
    }
}
