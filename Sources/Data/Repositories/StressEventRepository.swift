import Foundation
import os.log

/// Repository for storing and retrieving stress events
final class StressEventRepository {

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.sleeptracker", category: "StressEventRepository")

    private var stressEventsDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("StressEvents", isDirectory: true)
    }

    // MARK: - Initialization
    init() {
        createDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// Save a new stress event
    func save(_ event: StressEvent) {
        let fileURL = stressEventsDirectory.appendingPathComponent("\(event.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(event)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Saved stress event: \(event.id)")
        } catch {
            logger.error("Failed to save stress event: \(error.localizedDescription)")
        }
    }

    /// Load all stress events
    func loadAll() -> [StressEvent] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: stressEventsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let events = fileURLs.compactMap { url -> StressEvent? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(StressEvent.self, from: data)
            }

            // Sort by timestamp, most recent first
            return events.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("Failed to load stress events: \(error.localizedDescription)")
            return []
        }
    }

    /// Load stress events for a specific date
    func loadForDate(_ date: Date) -> [StressEvent] {
        let calendar = Calendar.current
        return loadAll().filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: date)
        }
    }

    /// Load stress events for a date range
    func loadForDateRange(from startDate: Date, to endDate: Date) -> [StressEvent] {
        loadAll().filter { event in
            event.timestamp >= startDate && event.timestamp <= endDate
        }
    }

    /// Get count of stress events for today
    var todayCount: Int {
        loadForDate(Date()).count
    }

    /// Delete a stress event
    func delete(_ event: StressEvent) {
        let fileURL = stressEventsDirectory.appendingPathComponent("\(event.id.uuidString).json")

        do {
            try fileManager.removeItem(at: fileURL)
            logger.info("Deleted stress event: \(event.id)")
        } catch {
            logger.error("Failed to delete stress event: \(error.localizedDescription)")
        }
    }

    /// Delete all stress events
    func deleteAll() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: stressEventsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for url in fileURLs {
                try fileManager.removeItem(at: url)
            }
            logger.info("Deleted all stress events")
        } catch {
            logger.error("Failed to delete all stress events: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: stressEventsDirectory.path) else { return }

        do {
            try fileManager.createDirectory(at: stressEventsDirectory, withIntermediateDirectories: true)
            logger.info("Created stress events directory")
        } catch {
            logger.error("Failed to create stress events directory: \(error.localizedDescription)")
        }
    }
}
