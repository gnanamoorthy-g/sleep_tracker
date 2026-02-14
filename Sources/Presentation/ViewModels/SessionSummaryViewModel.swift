import Foundation
import Combine
import os.log

@MainActor
final class SessionSummaryViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var sessions: [SleepSession] = []
    @Published private(set) var selectedSession: SleepSession?
    @Published private(set) var isLoading = false

    // MARK: - Dependencies
    private let repository: SleepSessionRepository
    private let logger = Logger(subsystem: "com.sleeptracker", category: "SessionVM")

    // MARK: - Initialization
    init(repository: SleepSessionRepository = SleepSessionRepository()) {
        self.repository = repository
    }

    // MARK: - Public Methods
    func loadSessions() {
        isLoading = true

        do {
            sessions = try repository.loadAll()
            logger.info("Loaded \(self.sessions.count) sessions")
        } catch {
            logger.error("Failed to load sessions: \(error.localizedDescription)")
            sessions = []
        }

        isLoading = false
    }

    func selectSession(_ session: SleepSession) {
        selectedSession = session
    }

    func deleteSession(_ session: SleepSession) {
        do {
            try repository.delete(id: session.id)
            sessions.removeAll { $0.id == session.id }
            if selectedSession?.id == session.id {
                selectedSession = nil
            }
            logger.info("Deleted session \(session.id)")
        } catch {
            logger.error("Failed to delete session: \(error.localizedDescription)")
        }
    }

    func deleteAllSessions() {
        do {
            try repository.deleteAll()
            sessions = []
            selectedSession = nil
            logger.info("Deleted all sessions")
        } catch {
            logger.error("Failed to delete all sessions: \(error.localizedDescription)")
        }
    }
}
