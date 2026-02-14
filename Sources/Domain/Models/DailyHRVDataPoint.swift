import Foundation

/// Represents aggregated HRV data for a single day from multiple sources
struct DailyHRVDataPoint: Identifiable {
    let id: UUID
    let date: Date

    // MARK: - HRV Metrics
    let rmssd: Double
    let sdnn: Double?
    let averageHR: Double

    // MARK: - Data Sources
    let source: DataSource
    let hasMorningReadiness: Bool
    let hasSleepData: Bool

    // MARK: - Baseline Comparisons (calculated)
    var baseline7d: Double?
    var baseline30d: Double?
    var zScore: Double?
    var recoveryScore: Int?

    // MARK: - Optional Sleep Data
    var sleepDurationMinutes: Double?
    var deepSleepMinutes: Double?
    var lightSleepMinutes: Double?
    var remSleepMinutes: Double?
    var awakeMinutes: Double?
    var sleepScore: Int?

    enum DataSource: String {
        case morningReadiness = "Morning Readiness"
        case sleepSession = "Sleep"
        case continuous = "Continuous"
        case snapshot = "Snapshot"
        case combined = "Combined"  // morning + sleep
    }

    init(
        id: UUID = UUID(),
        date: Date,
        rmssd: Double,
        sdnn: Double? = nil,
        averageHR: Double,
        source: DataSource,
        hasMorningReadiness: Bool = false,
        hasSleepData: Bool = false
    ) {
        self.id = id
        self.date = date
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.averageHR = averageHR
        self.source = source
        self.hasMorningReadiness = hasMorningReadiness
        self.hasSleepData = hasSleepData
    }
}

// MARK: - Factory Methods

extension DailyHRVDataPoint {

    /// Create from morning readiness snapshot only
    static func fromMorningReadiness(_ snapshot: HRVSnapshot) -> DailyHRVDataPoint {
        DailyHRVDataPoint(
            date: snapshot.timestamp,
            rmssd: snapshot.rmssd,
            sdnn: snapshot.sdnn,
            averageHR: snapshot.averageHR,
            source: .morningReadiness,
            hasMorningReadiness: true,
            hasSleepData: false
        )
    }

    /// Create from sleep session with optional morning readiness
    static func fromSleepSession(
        _ session: SleepSession,
        summary: SleepSummary,
        morningReadiness: HRVSnapshot?
    ) -> DailyHRVDataPoint {
        // Calculate sleep HRV
        let sleepRMSSD = session.samples.compactMap { $0.rmssd }.reduce(0, +) /
            Double(max(1, session.samples.compactMap { $0.rmssd }.count))

        // If morning readiness available, average with sleep RMSSD (weight morning more for "readiness")
        let finalRMSSD: Double
        let source: DataSource

        if let morning = morningReadiness {
            // Weight: 60% morning, 40% sleep (morning is more relevant for readiness)
            finalRMSSD = (morning.rmssd * 0.6) + (sleepRMSSD * 0.4)
            source = .combined
        } else {
            finalRMSSD = sleepRMSSD
            source = .sleepSession
        }

        var dataPoint = DailyHRVDataPoint(
            date: session.startTime,
            rmssd: finalRMSSD,
            sdnn: nil,
            averageHR: summary.averageHR,
            source: source,
            hasMorningReadiness: morningReadiness != nil,
            hasSleepData: true
        )

        // Add sleep data (SleepSummary already has minutes, not percentages)
        dataPoint.sleepDurationMinutes = session.duration / 60
        dataPoint.deepSleepMinutes = summary.deepMinutes
        dataPoint.lightSleepMinutes = summary.lightMinutes
        dataPoint.remSleepMinutes = summary.remMinutes
        dataPoint.awakeMinutes = summary.awakeMinutes
        dataPoint.sleepScore = summary.sleepScore

        return dataPoint
    }

    /// Create from continuous monitoring data (fallback)
    static func fromContinuousData(_ data: [ContinuousHRVData]) -> DailyHRVDataPoint? {
        guard !data.isEmpty else { return nil }

        let totalSamples = data.map { $0.sampleCount }.reduce(0, +)
        guard totalSamples > 0 else { return nil }

        let weightedRMSSD = data.map { $0.averageRMSSD * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)
        let weightedHR = data.map { $0.averageHR * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)

        return DailyHRVDataPoint(
            date: data.first!.date,
            rmssd: weightedRMSSD,
            sdnn: nil,
            averageHR: weightedHR,
            source: .continuous,
            hasMorningReadiness: false,
            hasSleepData: false
        )
    }

    /// Create from quick snapshots (fallback)
    static func fromSnapshots(_ snapshots: [HRVSnapshot]) -> DailyHRVDataPoint? {
        guard !snapshots.isEmpty else { return nil }

        let avgRMSSD = snapshots.map { $0.rmssd }.reduce(0, +) / Double(snapshots.count)
        let avgHR = snapshots.map { $0.averageHR }.reduce(0, +) / Double(snapshots.count)
        let avgSDNN = snapshots.compactMap { $0.sdnn }.reduce(0, +) / Double(max(1, snapshots.compactMap { $0.sdnn }.count))

        return DailyHRVDataPoint(
            date: snapshots.first!.timestamp,
            rmssd: avgRMSSD,
            sdnn: avgSDNN,
            averageHR: avgHR,
            source: .snapshot,
            hasMorningReadiness: false,
            hasSleepData: false
        )
    }
}

// MARK: - Baseline Enrichment

extension DailyHRVDataPoint {

    /// Returns a copy with baseline calculations applied
    func withBaselines(from historicalPoints: [DailyHRVDataPoint]) -> DailyHRVDataPoint {
        var enriched = self

        // Calculate 7-day baseline
        let last7 = historicalPoints.suffix(7)
        if !last7.isEmpty {
            enriched.baseline7d = last7.map { $0.rmssd }.reduce(0, +) / Double(last7.count)
        }

        // Calculate 30-day baseline
        let last30 = historicalPoints.suffix(30)
        if !last30.isEmpty {
            enriched.baseline30d = last30.map { $0.rmssd }.reduce(0, +) / Double(last30.count)
        }

        // Calculate Z-score
        if last30.count >= 7 {
            let mean = last30.map { $0.rmssd }.reduce(0, +) / Double(last30.count)
            let variance = last30.map { pow($0.rmssd - mean, 2) }.reduce(0, +) / Double(last30.count - 1)
            let stdDev = sqrt(variance)
            if stdDev > 0 {
                enriched.zScore = (self.rmssd - mean) / stdDev
            }
        }

        // Calculate recovery score (% of 7-day baseline)
        if let baseline7d = enriched.baseline7d, baseline7d > 0 {
            enriched.recoveryScore = Int((self.rmssd / baseline7d) * 100)
        }

        return enriched
    }
}
