import Foundation

/// A single HRV snapshot measurement (2-3 minutes)
struct HRVSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let measurementMode: MeasurementMode

    // Context
    let context: SnapshotContext?

    // Heart Rate Metrics
    let averageHR: Double
    let minHR: Double
    let maxHR: Double

    // HRV Metrics
    let rmssd: Double
    let sdnn: Double
    let pnn50: Double?

    // Derived Metrics
    let lnRMSSD: Double  // Natural log of RMSSD

    // Comparison to baselines
    let comparedTo7DayBaseline: Double?  // Percentage (e.g., 105 = 5% above)
    let recoveryScore: Int?  // 0-100 or percentage of baseline

    // Optional notes
    let notes: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        duration: TimeInterval,
        measurementMode: MeasurementMode,
        context: SnapshotContext? = nil,
        averageHR: Double,
        minHR: Double,
        maxHR: Double,
        rmssd: Double,
        sdnn: Double,
        pnn50: Double? = nil,
        comparedTo7DayBaseline: Double? = nil,
        recoveryScore: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.measurementMode = measurementMode
        self.context = context
        self.averageHR = averageHR
        self.minHR = minHR
        self.maxHR = maxHR
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.pnn50 = pnn50
        self.lnRMSSD = log(rmssd)
        self.comparedTo7DayBaseline = comparedTo7DayBaseline
        self.recoveryScore = recoveryScore
        self.notes = notes
    }
}

// MARK: - Convenience Extensions

extension HRVSnapshot {
    /// Check if this is a morning readiness check
    var isMorningReadiness: Bool {
        measurementMode == .morningReadiness
    }

    /// Check if this is a quick snapshot
    var isQuickSnapshot: Bool {
        measurementMode == .snapshot
    }

    /// Get formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Recovery state based on comparison to baseline
    var recoveryState: RecoveryState {
        guard let comparison = comparedTo7DayBaseline else {
            return .normal
        }

        switch comparison {
        case 110...:
            return .excellent
        case 95..<110:
            return .normal
        case 85..<95:
            return .strained
        default:
            return .fatigue
        }
    }

    enum RecoveryState: String {
        case excellent = "Excellent"
        case normal = "Normal"
        case strained = "Strained"
        case fatigue = "Fatigued"

        var color: String {
            switch self {
            case .excellent: return "green"
            case .normal: return "blue"
            case .strained: return "orange"
            case .fatigue: return "red"
            }
        }
    }
}
