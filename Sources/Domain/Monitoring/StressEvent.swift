import Foundation

/// Represents a detected stress event
struct StressEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval

    // Metrics during stress
    let averageHR: Double
    let averageRMSSD: Double
    let baselineRMSSD: Double

    // Severity assessment
    let severity: StressSeverity

    // Comparison to baseline
    let rmssdRatio: Double  // RMSSD / baseline (e.g., 0.65 = 35% below baseline)

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        duration: TimeInterval,
        averageHR: Double,
        averageRMSSD: Double,
        baselineRMSSD: Double,
        severity: StressSeverity
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.averageHR = averageHR
        self.averageRMSSD = averageRMSSD
        self.baselineRMSSD = baselineRMSSD
        self.severity = severity
        self.rmssdRatio = baselineRMSSD > 0 ? averageRMSSD / baselineRMSSD : 1.0
    }
}

// MARK: - Stress Severity

enum StressSeverity: String, Codable, CaseIterable {
    case mild = "Mild"
    case moderate = "Moderate"
    case high = "High"

    var emoji: String {
        switch self {
        case .mild: return "🟡"
        case .moderate: return "🟠"
        case .high: return "🔴"
        }
    }

    var colorName: String {
        switch self {
        case .mild: return "yellow"
        case .moderate: return "orange"
        case .high: return "red"
        }
    }

    var iconName: String {
        switch self {
        case .mild: return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        }
    }

    var recommendation: String {
        switch self {
        case .mild:
            return "Take a few deep breaths when you have a moment."
        case .moderate:
            return "Consider taking a short break to relax."
        case .high:
            return "Your stress level is elevated. Try to take a break and do some breathing exercises."
        }
    }

    /// Determine severity from RMSSD ratio (current / baseline)
    static func from(rmssdRatio: Double, hrElevation: Double) -> StressSeverity {
        // High stress: RMSSD < 60% baseline OR (RMSSD < 70% AND HR > 15% elevated)
        if rmssdRatio < 0.60 {
            return .high
        } else if rmssdRatio < 0.70 && hrElevation > 0.15 {
            return .high
        } else if rmssdRatio < 0.70 {
            return .moderate
        } else if rmssdRatio < 0.80 {
            return .mild
        }
        return .mild
    }
}

// MARK: - Convenience Extensions

extension StressEvent {
    /// Get percentage below baseline
    var percentBelowBaseline: Int {
        Int((1.0 - rmssdRatio) * 100)
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) mins"
        }
    }

    /// Formatted time string
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
