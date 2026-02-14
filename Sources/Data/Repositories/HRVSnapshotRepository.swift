import Foundation
import os.log

/// Repository for storing and retrieving HRV snapshots
final class HRVSnapshotRepository {

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.sleeptracker", category: "HRVSnapshotRepository")

    private var snapshotsDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("HRVSnapshots", isDirectory: true)
    }

    // MARK: - Initialization
    init() {
        createDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// Save a new snapshot
    func save(_ snapshot: HRVSnapshot) {
        let fileURL = snapshotsDirectory.appendingPathComponent("\(snapshot.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Saved snapshot: \(snapshot.id)")
        } catch {
            logger.error("Failed to save snapshot: \(error.localizedDescription)")
        }
    }

    /// Load all snapshots
    func loadAll() -> [HRVSnapshot] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: snapshotsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let snapshots = fileURLs.compactMap { url -> HRVSnapshot? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(HRVSnapshot.self, from: data)
            }

            // Sort by timestamp, most recent first
            return snapshots.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("Failed to load snapshots: \(error.localizedDescription)")
            return []
        }
    }

    /// Load snapshots for a specific date
    func loadForDate(_ date: Date) -> [HRVSnapshot] {
        let calendar = Calendar.current
        return loadAll().filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: date)
        }
    }

    /// Load today's morning readiness check (if any)
    func loadTodaysMorningReadiness() -> HRVSnapshot? {
        loadForDate(Date()).first { $0.isMorningReadiness }
    }

    /// Check if morning readiness has been completed today
    func hasMorningReadinessToday() -> Bool {
        loadTodaysMorningReadiness() != nil
    }

    /// Load snapshots for a date range
    func loadForDateRange(from startDate: Date, to endDate: Date) -> [HRVSnapshot] {
        loadAll().filter { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
        }
    }

    /// Load snapshots by context
    func loadByContext(_ context: SnapshotContext) -> [HRVSnapshot] {
        loadAll().filter { $0.context == context }
    }

    /// Delete a snapshot
    func delete(_ snapshot: HRVSnapshot) {
        let fileURL = snapshotsDirectory.appendingPathComponent("\(snapshot.id.uuidString).json")

        do {
            try fileManager.removeItem(at: fileURL)
            logger.info("Deleted snapshot: \(snapshot.id)")
        } catch {
            logger.error("Failed to delete snapshot: \(error.localizedDescription)")
        }
    }

    /// Delete all snapshots
    func deleteAll() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: snapshotsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for url in fileURLs {
                try fileManager.removeItem(at: url)
            }
            logger.info("Deleted all snapshots")
        } catch {
            logger.error("Failed to delete all snapshots: \(error.localizedDescription)")
        }
    }

    /// Get count of snapshots
    var count: Int {
        loadAll().count
    }

    /// Get count of snapshots for today
    var todayCount: Int {
        loadForDate(Date()).count
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: snapshotsDirectory.path) else { return }

        do {
            try fileManager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
            logger.info("Created HRV snapshots directory")
        } catch {
            logger.error("Failed to create snapshots directory: \(error.localizedDescription)")
        }
    }
}
