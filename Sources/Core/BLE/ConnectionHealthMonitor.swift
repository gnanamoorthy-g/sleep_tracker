import Foundation
import Combine
import os.log

/// Monitors BLE connection health and stability metrics
final class ConnectionHealthMonitor: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var currentRSSI: Int = 0
    @Published private(set) var signalStrength: SignalStrength = .unknown
    @Published private(set) var connectionUptime: TimeInterval = 0
    @Published private(set) var disconnectionCount: Int = 0
    @Published private(set) var lastDataReceived: Date?

    // MARK: - Signal Strength
    enum SignalStrength: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case weak = "Weak"
        case unknown = "Unknown"

        init(rssi: Int) {
            switch rssi {
            case -50...0:
                self = .excellent
            case -60..<(-50):
                self = .good
            case -70..<(-60):
                self = .fair
            case ..<(-70):
                self = .weak
            default:
                self = .unknown
            }
        }

        var systemImageName: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .weak: return "wifi.slash"
            case .unknown: return "wifi.slash"
            }
        }
    }

    // MARK: - Private Properties
    private var connectionStartTime: Date?
    private var uptimeTimer: Timer?
    private var rssiHistory: [Int] = []
    private let maxRSSIHistory = 10
    private let logger = Logger(subsystem: "com.sleeptracker", category: "ConnectionHealth")

    // MARK: - Public Methods

    /// Called when connection is established
    func connectionEstablished() {
        connectionStartTime = Date()
        startUptimeTracking()
        logger.info("Connection health monitoring started")
    }

    /// Called when disconnection occurs
    func connectionLost() {
        stopUptimeTracking()
        disconnectionCount += 1
        connectionUptime = 0
        currentRSSI = 0
        signalStrength = .unknown
        logger.info("Connection lost. Total disconnections: \(self.disconnectionCount)")
    }

    /// Update RSSI reading
    func updateRSSI(_ rssi: Int) {
        currentRSSI = rssi
        signalStrength = SignalStrength(rssi: rssi)

        // Maintain rolling average
        rssiHistory.append(rssi)
        if rssiHistory.count > maxRSSIHistory {
            rssiHistory.removeFirst()
        }
    }

    /// Called when data is received from the device
    func dataReceived() {
        lastDataReceived = Date()
    }

    /// Reset all metrics (e.g., when forgetting device)
    func reset() {
        stopUptimeTracking()
        connectionStartTime = nil
        connectionUptime = 0
        disconnectionCount = 0
        currentRSSI = 0
        signalStrength = .unknown
        lastDataReceived = nil
        rssiHistory.removeAll()
        logger.info("Connection health metrics reset")
    }

    /// Average RSSI over recent readings
    var averageRSSI: Int? {
        guard !rssiHistory.isEmpty else { return nil }
        return rssiHistory.reduce(0, +) / rssiHistory.count
    }

    /// Check if connection appears healthy (receiving data)
    var isReceivingData: Bool {
        guard let lastData = lastDataReceived else { return false }
        // Consider healthy if data received within last 5 seconds
        return Date().timeIntervalSince(lastData) < 5.0
    }

    /// Get connection quality score (0-100)
    var connectionQualityScore: Int {
        var score = 0

        // RSSI contribution (up to 50 points)
        switch signalStrength {
        case .excellent: score += 50
        case .good: score += 40
        case .fair: score += 25
        case .weak: score += 10
        case .unknown: score += 0
        }

        // Data flow contribution (up to 30 points)
        if isReceivingData {
            score += 30
        }

        // Stability contribution (up to 20 points based on disconnection count)
        let stabilityScore = max(0, 20 - (disconnectionCount * 4))
        score += stabilityScore

        return min(100, score)
    }

    // MARK: - Private Methods

    private func startUptimeTracking() {
        stopUptimeTracking()

        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.connectionStartTime else { return }
            DispatchQueue.main.async {
                self.connectionUptime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopUptimeTracking() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
    }

    deinit {
        stopUptimeTracking()
    }
}
