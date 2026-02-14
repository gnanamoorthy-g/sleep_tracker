import Foundation
import os.log

final class DailyHRVSummaryRepository {
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.sleeptracker", category: "HRVRepository")

    private var summariesDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("HRVSummaries", isDirectory: true)
    }

    init() {
        createDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    func save(_ summary: DailyHRVSummary) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(summary)
        let fileName = fileNameFor(date: summary.date)
        let fileURL = summariesDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        logger.info("Saved HRV summary for \(summary.date)")
    }

    func loadAll() -> [DailyHRVSummary] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: summariesDirectory,
                includingPropertiesForKeys: nil
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var summaries: [DailyHRVSummary] = []
            for url in fileURLs where url.pathExtension == "json" {
                if let data = try? Data(contentsOf: url),
                   let summary = try? decoder.decode(DailyHRVSummary.self, from: data) {
                    summaries.append(summary)
                }
            }

            return summaries.sorted { $0.date < $1.date }
        } catch {
            logger.error("Failed to load HRV summaries: \(error.localizedDescription)")
            return []
        }
    }

    func loadLast(days: Int) -> [DailyHRVSummary] {
        let allSummaries = loadAll()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        return allSummaries.filter { $0.date >= cutoffDate }
    }

    func load(for date: Date) -> DailyHRVSummary? {
        let fileName = fileNameFor(date: date)
        let fileURL = summariesDirectory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(DailyHRVSummary.self, from: data)
    }

    func delete(_ summary: DailyHRVSummary) throws {
        let fileName = fileNameFor(date: summary.date)
        let fileURL = summariesDirectory.appendingPathComponent(fileName)

        try fileManager.removeItem(at: fileURL)
        logger.info("Deleted HRV summary for \(summary.date)")
    }

    func deleteAll() throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: summariesDirectory,
            includingPropertiesForKeys: nil
        )

        for url in fileURLs {
            try fileManager.removeItem(at: url)
        }

        logger.info("Deleted all HRV summaries")
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: summariesDirectory.path) {
            try? fileManager.createDirectory(
                at: summariesDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private func fileNameFor(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "hrv_\(formatter.string(from: date)).json"
    }
}
