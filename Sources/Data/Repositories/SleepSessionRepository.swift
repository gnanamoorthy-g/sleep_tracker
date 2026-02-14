import Foundation
import os.log

protocol SleepSessionRepositoryProtocol {
    func save(_ session: SleepSession) throws
    func loadAll() throws -> [SleepSession]
    func load(id: UUID) throws -> SleepSession?
    func delete(id: UUID) throws
    func deleteAll() throws
}

/// File-based persistence for sleep sessions (Phase 1)
/// Will migrate to CoreData in Phase 2
final class SleepSessionRepository: SleepSessionRepositoryProtocol {

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.sleeptracker", category: "Repository")

    private var sessionsDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sessionsURL = documentsURL.appendingPathComponent("sessions", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: sessionsURL.path) {
            try? fileManager.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        }

        return sessionsURL
    }

    private func fileURL(for id: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - Save
    func save(_ session: SleepSession) throws {
        let url = fileURL(for: session.id)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(session)
        try data.write(to: url, options: .atomic)

        logger.info("Saved session \(session.id) with \(session.samples.count) samples")
    }

    // MARK: - Load All
    func loadAll() throws -> [SleepSession] {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        let sessions = contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SleepSession? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try? decoder.decode(SleepSession.self, from: data)
            }
            .sorted { $0.startTime > $1.startTime }

        logger.info("Loaded \(sessions.count) sessions")
        return sessions
    }

    // MARK: - Load Single
    func load(id: UUID) throws -> SleepSession? {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SleepSession.self, from: data)
    }

    // MARK: - Delete
    func delete(id: UUID) throws {
        let url = fileURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            logger.info("Deleted session \(id)")
        }
    }

    // MARK: - Delete All
    func deleteAll() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        )

        for url in contents {
            try fileManager.removeItem(at: url)
        }

        logger.info("Deleted all sessions")
    }
}
