import Foundation
import UserNotifications
import os.log

/// Manages local notifications for stress alerts and reminders
final class NotificationManager {

    // MARK: - Singleton
    static let shared = NotificationManager()

    // MARK: - Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.sleeptracker", category: "Notifications")

    // Settings
    private let stressAlertsEnabledKey = "com.sleeptracker.notifications.stressAlerts"
    private let morningReminderEnabledKey = "com.sleeptracker.notifications.morningReminder"
    private let maxStressAlertsPerDay = 3

    // Tracking
    private var todayStressAlertCount: Int = 0
    private var lastStressAlertDate: Date?

    // MARK: - Initialization
    private init() {
        resetDailyCountIfNeeded()
    }

    // MARK: - Permission

    /// Request notification permissions
    func requestPermissions(completion: ((Bool) -> Void)? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("Notification permission error: \(error.localizedDescription)")
            } else if granted {
                self?.logger.info("Notification permission granted")
            } else {
                self?.logger.warning("Notification permission denied")
            }
            completion?(granted)
        }
    }

    /// Check if notifications are authorized
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            completion(authorized)
        }
    }

    // MARK: - Stress Alerts

    /// Send a stress alert notification
    func sendStressAlert(severity: StressSeverity) {
        resetDailyCountIfNeeded()

        // Check daily limit
        guard todayStressAlertCount < maxStressAlertsPerDay else {
            logger.info("Stress alert skipped - daily limit reached")
            return
        }

        // Check if enabled
        guard isStressAlertsEnabled else {
            logger.info("Stress alert skipped - disabled in settings")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Stress Detected"
        content.body = severity.recommendation
        content.sound = .default
        content.categoryIdentifier = "STRESS_ALERT"

        // Add severity to user info
        content.userInfo = ["severity": severity.rawValue]

        let request = UNNotificationRequest(
            identifier: "stress-\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send stress alert: \(error.localizedDescription)")
            } else {
                self?.todayStressAlertCount += 1
                self?.lastStressAlertDate = Date()
                self?.logger.info("Sent stress alert - Severity: \(severity.rawValue)")
            }
        }
    }

    // MARK: - Morning Readiness Reminder

    /// Schedule morning readiness reminder
    func scheduleMorningReadinessReminder(at hour: Int = 7, minute: Int = 30) {
        guard isMorningReminderEnabled else { return }

        // Remove existing reminder
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morning-readiness"])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Morning Readiness Check"
        content.body = "Take your 3-minute morning HRV check to assess today's recovery."
        content.sound = .default
        content.categoryIdentifier = "MORNING_READINESS"

        let request = UNNotificationRequest(
            identifier: "morning-readiness",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule morning reminder: \(error.localizedDescription)")
            } else {
                self?.logger.info("Scheduled morning readiness reminder for \(hour):\(minute)")
            }
        }
    }

    /// Cancel morning readiness reminder
    func cancelMorningReadinessReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morning-readiness"])
        logger.info("Cancelled morning readiness reminder")
    }

    // MARK: - Recovery Alerts

    /// Send recovery state alert (for overreaching risk, etc.)
    func sendRecoveryAlert(state: String, recommendation: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recovery Alert: \(state)"
        content.body = recommendation
        content.sound = .default
        content.categoryIdentifier = "RECOVERY_ALERT"

        let request = UNNotificationRequest(
            identifier: "recovery-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send recovery alert: \(error.localizedDescription)")
            } else {
                self?.logger.info("Sent recovery alert: \(state)")
            }
        }
    }

    // MARK: - Settings

    var isStressAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: stressAlertsEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: stressAlertsEnabledKey)
            logger.info("Stress alerts \(newValue ? "enabled" : "disabled")")
        }
    }

    var isMorningReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: morningReminderEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: morningReminderEnabledKey)
            if newValue {
                scheduleMorningReadinessReminder()
            } else {
                cancelMorningReadinessReminder()
            }
            logger.info("Morning reminder \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Clear Notifications

    /// Clear all delivered notifications
    func clearAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// Clear all pending notifications
    func clearAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Private Methods

    private func resetDailyCountIfNeeded() {
        if let lastDate = lastStressAlertDate,
           !Calendar.current.isDateInToday(lastDate) {
            todayStressAlertCount = 0
        }
    }
}
