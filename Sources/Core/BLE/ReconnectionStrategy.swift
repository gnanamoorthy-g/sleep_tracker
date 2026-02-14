import Foundation
import os.log

/// Manages exponential backoff strategy for BLE reconnection
final class ReconnectionStrategy {

    // MARK: - Configuration
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0
    private let maxAttempts: Int = 10

    // MARK: - State
    private(set) var currentAttempt: Int = 0
    private var reconnectionTimer: DispatchSourceTimer?
    private let logger = Logger(subsystem: "com.sleeptracker", category: "Reconnection")

    // MARK: - Public Methods

    /// Calculate the next delay using exponential backoff
    /// Returns: delay in seconds (1, 2, 4, 8, 16, 30, 30, 30...)
    func nextDelay() -> TimeInterval {
        let delay = min(pow(2.0, Double(currentAttempt)) * baseDelay, maxDelay)
        currentAttempt += 1
        logger.info("Reconnection attempt \(self.currentAttempt), delay: \(delay)s")
        return delay
    }

    /// Reset the backoff counter (call on successful connection)
    func reset() {
        currentAttempt = 0
        cancelScheduledReconnection()
        logger.info("Reconnection strategy reset")
    }

    /// Check if we've exceeded maximum reconnection attempts
    var shouldContinueReconnecting: Bool {
        return currentAttempt < maxAttempts
    }

    /// Schedule a reconnection attempt after the calculated delay
    /// - Parameters:
    ///   - queue: The dispatch queue to execute on
    ///   - action: The reconnection action to perform
    func scheduleReconnection(on queue: DispatchQueue, action: @escaping () -> Void) {
        cancelScheduledReconnection()

        guard shouldContinueReconnecting else {
            logger.warning("Max reconnection attempts (\(self.maxAttempts)) reached")
            return
        }

        let delay = nextDelay()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            self?.logger.info("Executing scheduled reconnection")
            action()
        }
        timer.resume()
        reconnectionTimer = timer
    }

    /// Cancel any pending reconnection attempt
    func cancelScheduledReconnection() {
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
    }

    /// Get remaining attempts before giving up
    var remainingAttempts: Int {
        return max(0, maxAttempts - currentAttempt)
    }
}
