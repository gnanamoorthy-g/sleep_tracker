import Foundation

/// Represents aggregated HRV data from continuous monitoring for a specific time period
struct ContinuousHRVData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let hourOfDay: Int  // 0-23, for hourly aggregation

    // Heart Rate Metrics
    let averageHR: Double
    let minHR: Double
    let maxHR: Double

    // HRV Metrics
    let averageRMSSD: Double
    let averageSDNN: Double
    let averagePNN50: Double?

    // Sample count for this period
    let sampleCount: Int

    // Duration of data collection in seconds
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        hourOfDay: Int? = nil,
        averageHR: Double,
        minHR: Double,
        maxHR: Double,
        averageRMSSD: Double,
        averageSDNN: Double,
        averagePNN50: Double? = nil,
        sampleCount: Int,
        duration: TimeInterval
    ) {
        self.id = id
        self.date = date
        self.hourOfDay = hourOfDay ?? Calendar.current.component(.hour, from: date)
        self.averageHR = averageHR
        self.minHR = minHR
        self.maxHR = maxHR
        self.averageRMSSD = averageRMSSD
        self.averageSDNN = averageSDNN
        self.averagePNN50 = averagePNN50
        self.sampleCount = sampleCount
        self.duration = duration
    }
}

// MARK: - Daily Aggregation

extension ContinuousHRVData {
    /// Create a daily summary from multiple hourly entries
    static func dailySummary(from hourlyData: [ContinuousHRVData]) -> ContinuousHRVData? {
        guard !hourlyData.isEmpty else { return nil }

        let totalSamples = hourlyData.map { $0.sampleCount }.reduce(0, +)
        guard totalSamples > 0 else { return nil }

        // Weighted averages based on sample count
        let weightedHR = hourlyData.map { $0.averageHR * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)
        let weightedRMSSD = hourlyData.map { $0.averageRMSSD * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)
        let weightedSDNN = hourlyData.map { $0.averageSDNN * Double($0.sampleCount) }.reduce(0, +) / Double(totalSamples)

        let pnn50Values = hourlyData.compactMap { $0.averagePNN50 }
        let weightedPNN50: Double? = pnn50Values.isEmpty ? nil :
            zip(hourlyData.filter { $0.averagePNN50 != nil }, pnn50Values)
                .map { ($0.1 * Double($0.0.sampleCount)) }
                .reduce(0, +) / Double(hourlyData.filter { $0.averagePNN50 != nil }.map { $0.sampleCount }.reduce(0, +))

        return ContinuousHRVData(
            date: hourlyData.first?.date ?? Date(),
            hourOfDay: -1,  // -1 indicates daily summary
            averageHR: weightedHR,
            minHR: hourlyData.map { $0.minHR }.min() ?? 0,
            maxHR: hourlyData.map { $0.maxHR }.max() ?? 0,
            averageRMSSD: weightedRMSSD,
            averageSDNN: weightedSDNN,
            averagePNN50: weightedPNN50,
            sampleCount: totalSamples,
            duration: hourlyData.map { $0.duration }.reduce(0, +)
        )
    }
}
