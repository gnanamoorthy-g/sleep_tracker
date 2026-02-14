import Foundation
import os.log

/// Centralized logging configuration for the app
/// Uses Apple's unified logging system (os.log)
enum AppLogger {
    static let subsystem = "com.sleeptracker"

    static let ble = Logger(subsystem: subsystem, category: "BLE")
    static let parser = Logger(subsystem: subsystem, category: "Parser")
    static let hrv = Logger(subsystem: subsystem, category: "HRV")
    static let repository = Logger(subsystem: subsystem, category: "Repository")
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
    static let general = Logger(subsystem: subsystem, category: "General")
}
