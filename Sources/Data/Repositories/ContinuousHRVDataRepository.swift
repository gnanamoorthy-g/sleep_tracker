import Foundation
import os.log

/// Repository for storing and retrieving continuous HRV monitoring data
final class ContinuousHRVDataRepository {

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.sleeptracker", category: "ContinuousHRVDataRepository")

    private var continuousDataDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("ContinuousHRVData", isDirectory: true)
    }

    // MARK: - Initialization
    init() {
        createDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// Save continuous HRV data entry
    func save(_ data: ContinuousHRVData) {
        let fileURL = continuousDataDirectory.appendingPathComponent("\(data.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL, options: .atomic)
            logger.debug("Saved continuous HRV data: \(data.id)")
        } catch {
            logger.error("Failed to save continuous HRV data: \(error.localizedDescription)")
        }
    }

    /// Load all continuous HRV data
    func loadAll() -> [ContinuousHRVData] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: continuousDataDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let entries = fileURLs.compactMap { url -> ContinuousHRVData? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(ContinuousHRVData.self, from: data)
            }

            // Sort by date, most recent first
            return entries.sorted { $0.date > $1.date }
        } catch {
            logger.error("Failed to load continuous HRV data: \(error.localizedDescription)")
            return []
        }
    }

    /// Load continuous HRV data for a specific date
    func loadForDate(_ date: Date) -> [ContinuousHRVData] {
        let calendar = Calendar.current
        return loadAll().filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }

    /// Get daily summary for a specific date
    func getDailySummary(for date: Date) -> ContinuousHRVData? {
        let hourlyData = loadForDate(date)
        return ContinuousHRVData.dailySummary(from: hourlyData)
    }

    /// Get daily summaries for a date range
    func getDailySummaries(from startDate: Date, to endDate: Date) -> [ContinuousHRVData] {
        var summaries: [ContinuousHRVData] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            if let summary = getDailySummary(for: currentDate) {
                summaries.append(summary)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        return summaries.sorted { $0.date < $1.date }
    }

    /// Load continuous HRV data for the last N days
    func loadForDays(_ days: Int) -> [ContinuousHRVData] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }
        return loadAll().filter { entry in
            entry.date >= startDate
        }
    }

    /// Get count of entries
    var count: Int {
        loadAll().count
    }

    /// Delete old data (older than specified days)
    func deleteOldData(olderThanDays days: Int) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: continuousDataDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var deletedCount = 0
            for url in fileURLs {
                guard url.pathExtension == "json" else { continue }
                guard let data = try? Data(contentsOf: url),
                      let entry = try? decoder.decode(ContinuousHRVData.self, from: data) else {
                    continue
                }

                if entry.date < cutoffDate {
                    try fileManager.removeItem(at: url)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                logger.info("Deleted \(deletedCount) old continuous HRV entries")
            }
        } catch {
            logger.error("Failed to delete old continuous HRV data: \(error.localizedDescription)")
        }
    }

    /// Delete all continuous HRV data
    func deleteAll() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: continuousDataDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for url in fileURLs {
                try fileManager.removeItem(at: url)
            }
            logger.info("Deleted all continuous HRV data")
        } catch {
            logger.error("Failed to delete all continuous HRV data: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: continuousDataDirectory.path) else { return }

        do {
            try fileManager.createDirectory(at: continuousDataDirectory, withIntermediateDirectories: true)
            logger.info("Created continuous HRV data directory")
        } catch {
            logger.error("Failed to create continuous HRV data directory: \(error.localizedDescription)")
        }
    }
}
