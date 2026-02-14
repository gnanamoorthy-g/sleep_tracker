import Foundation
import UIKit
import os.log

/// Manages background task handling for continuous monitoring
final class BackgroundTaskManager {

    // MARK: - Singleton
    static let shared = BackgroundTaskManager()

    // MARK: - Properties
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var saveTimer: Timer?
    private let logger = Logger(subsystem: "com.sleeptracker", category: "BackgroundTask")

    // Callbacks
    var onEnterBackground: (() -> Void)?
    var onEnterForeground: (() -> Void)?
    var onPeriodicSave: (() -> Void)?

    // MARK: - Initialization
    private init() {
        setupNotifications()
    }

    // MARK: - Public Methods

    /// Start background task (call when critical work needs to complete)
    func beginBackgroundTask(withName name: String = "SleepTracker") {
        guard backgroundTask == .invalid else {
            logger.info("Background task already active")
            return
        }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.endBackgroundTask()
        }

        logger.info("Started background task: \(name)")
    }

    /// End background task
    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        logger.info("Ended background task")
    }

    /// Start periodic save timer (for long-running sessions)
    func startPeriodicSave(interval: TimeInterval = 60) {
        stopPeriodicSave()

        saveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.logger.info("Periodic save triggered")
            self?.onPeriodicSave?()
        }

        logger.info("Started periodic save with interval: \(interval)s")
    }

    /// Stop periodic save timer
    func stopPeriodicSave() {
        saveTimer?.invalidate()
        saveTimer = nil
        logger.info("Stopped periodic save")
    }

    /// Get remaining background time
    var remainingBackgroundTime: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }

    /// Check if we have significant background time remaining
    var hasSignificantBackgroundTime: Bool {
        let remaining = remainingBackgroundTime
        return remaining > 30 && remaining != .infinity
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnteringBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnteringForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleEnteringBackground() {
        logger.info("App entering background")

        // Begin background task to finish any pending work
        beginBackgroundTask(withName: "BackgroundSave")

        // Notify listeners
        onEnterBackground?()

        // Schedule end of background task
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            self?.endBackgroundTask()
        }
    }

    @objc private func handleEnteringForeground() {
        logger.info("App entering foreground")

        // End any active background task
        endBackgroundTask()

        // Notify listeners
        onEnterForeground?()
    }

    @objc private func handleWillTerminate() {
        logger.info("App will terminate")

        // Perform final save
        onPeriodicSave?()

        // End background task
        endBackgroundTask()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPeriodicSave()
    }
}

// MARK: - App State Helpers

extension BackgroundTaskManager {

    /// Check if app is currently in background
    var isInBackground: Bool {
        UIApplication.shared.applicationState == .background
    }

    /// Check if app is active
    var isActive: Bool {
        UIApplication.shared.applicationState == .active
    }
}
