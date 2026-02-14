import Foundation

/// Compares HRV across different measurement modes for a single day
struct DailyHRVComparison: Identifiable {
    let id: UUID
    let date: Date

    // Morning Readiness (single measurement, 3 min)
    let morningReadiness: MeasurementSummary?

    // Continuous Monitoring (hourly updates aggregated)
    let continuous: MeasurementSummary?

    // Snapshots (average of all snapshots taken that day)
    let snapshots: MeasurementSummary?

    // 7-day baseline for comparison
    let baseline7d: Double?

    init(
        id: UUID = UUID(),
        date: Date,
        morningReadiness: MeasurementSummary? = nil,
        continuous: MeasurementSummary? = nil,
        snapshots: MeasurementSummary? = nil,
        baseline7d: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.morningReadiness = morningReadiness
        self.continuous = continuous
        self.snapshots = snapshots
        self.baseline7d = baseline7d
    }

    /// Check if any data is available
    var hasData: Bool {
        morningReadiness != nil || continuous != nil || snapshots != nil
    }
}

// MARK: - Measurement Summary

struct MeasurementSummary {
    let rmssd: Double
    let sdnn: Double
    let averageHR: Double
    let sampleCount: Int
    let lastUpdated: Date

    // Comparison to baseline (percentage, e.g., 105 = 5% above baseline)
    var comparedToBaseline: Double?

    init(
        rmssd: Double,
        sdnn: Double,
        averageHR: Double,
        sampleCount: Int,
        lastUpdated: Date = Date(),
        comparedToBaseline: Double? = nil
    ) {
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.averageHR = averageHR
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
        self.comparedToBaseline = comparedToBaseline
    }
}

// MARK: - Aggregation

extension DailyHRVComparison {

    /// Create comparison from available data sources
    static func create(
        date: Date,
        morningSnapshot: HRVSnapshot?,
        continuousData: [ContinuousHRVData],
        allSnapshots: [HRVSnapshot],
        baseline7d: Double?
    ) -> DailyHRVComparison {

        // Morning readiness
        let morningSummary: MeasurementSummary? = morningSnapshot.map { snapshot in
            var summary = MeasurementSummary(
                rmssd: snapshot.rmssd,
                sdnn: snapshot.sdnn,
                averageHR: snapshot.averageHR,
                sampleCount: 1,
                lastUpdated: snapshot.timestamp
            )
            if let baseline = baseline7d, baseline > 0 {
                summary.comparedToBaseline = (snapshot.rmssd / baseline) * 100
            }
            return summary
        }

        // Continuous monitoring - aggregate all hourly data for the day
        let continuousSummary: MeasurementSummary? = {
            guard !continuousData.isEmpty else { return nil }

            let totalSamples = continuousData.map { $0.sampleCount }.reduce(0, +)
            guard totalSamples > 0 else { return nil }

            // Weighted average based on sample count
            let weightedRMSSD = continuousData.map { $0.averageRMSSD * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)
            let weightedSDNN = continuousData.map { $0.averageSDNN * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)
            let weightedHR = continuousData.map { $0.averageHR * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)

            let latestUpdate = continuousData.map { $0.date }.max() ?? date

            var summary = MeasurementSummary(
                rmssd: weightedRMSSD,
                sdnn: weightedSDNN,
                averageHR: weightedHR,
                sampleCount: totalSamples,
                lastUpdated: latestUpdate
            )
            if let baseline = baseline7d, baseline > 0 {
                summary.comparedToBaseline = (weightedRMSSD / baseline) * 100
            }
            return summary
        }()

        // Snapshots - average of all quick snapshots (excluding morning readiness)
        let snapshotSummary: MeasurementSummary? = {
            let quickSnapshots = allSnapshots.filter { $0.isQuickSnapshot }
            guard !quickSnapshots.isEmpty else { return nil }

            let avgRMSSD = quickSnapshots.map { $0.rmssd }.reduce(0, +) / Double(quickSnapshots.count)
            let avgSDNN = quickSnapshots.map { $0.sdnn }.reduce(0, +) / Double(quickSnapshots.count)
            let avgHR = quickSnapshots.map { $0.averageHR }.reduce(0, +) / Double(quickSnapshots.count)

            let latestUpdate = quickSnapshots.map { $0.timestamp }.max() ?? date

            var summary = MeasurementSummary(
                rmssd: avgRMSSD,
                sdnn: avgSDNN,
                averageHR: avgHR,
                sampleCount: quickSnapshots.count,
                lastUpdated: latestUpdate
            )
            if let baseline = baseline7d, baseline > 0 {
                summary.comparedToBaseline = (avgRMSSD / baseline) * 100
            }
            return summary
        }()

        return DailyHRVComparison(
            date: date,
            morningReadiness: morningSummary,
            continuous: continuousSummary,
            snapshots: snapshotSummary,
            baseline7d: baseline7d
        )
    }
}
