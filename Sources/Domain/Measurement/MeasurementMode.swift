import Foundation

/// Defines the different HRV measurement modes available in the app
enum MeasurementMode: String, Codable, CaseIterable {
    case continuous = "Continuous"
    case morningReadiness = "Morning Readiness"
    case snapshot = "Quick Snapshot"

    /// Duration for timed measurements (nil for continuous)
    var duration: TimeInterval? {
        switch self {
        case .continuous:
            return nil  // Indefinite
        case .morningReadiness:
            return 180  // 3 minutes
        case .snapshot:
            return 120  // 2 minutes
        }
    }

    /// Whether this mode requires explicit user action to start
    var requiresUserAction: Bool {
        switch self {
        case .continuous:
            return false  // Auto-starts
        case .morningReadiness, .snapshot:
            return true
        }
    }

    /// Display name for UI
    var displayName: String {
        rawValue
    }

    /// Icon name for SF Symbols
    var iconName: String {
        switch self {
        case .continuous:
            return "waveform.path.ecg"
        case .morningReadiness:
            return "sun.horizon.fill"
        case .snapshot:
            return "camera.metering.spot"
        }
    }

    /// Description for the user
    var description: String {
        switch self {
        case .continuous:
            return "24/7 monitoring with automatic sleep detection"
        case .morningReadiness:
            return "3-minute morning check for daily recovery assessment"
        case .snapshot:
            return "Quick 2-minute HRV reading anytime"
        }
    }
}

/// Context tags for HRV snapshots
enum SnapshotContext: String, Codable, CaseIterable {
    case general = "General"
    case preWorkout = "Pre-Workout"
    case postWorkout = "Post-Workout"
    case stressed = "Feeling Stressed"
    case relaxed = "Feeling Relaxed"
    case preMeal = "Before Meal"
    case postMeal = "After Meal"
    case preMeditation = "Before Meditation"
    case postMeditation = "After Meditation"

    var iconName: String {
        switch self {
        case .general: return "circle"
        case .preWorkout, .postWorkout: return "figure.run"
        case .stressed: return "exclamationmark.triangle"
        case .relaxed: return "leaf"
        case .preMeal, .postMeal: return "fork.knife"
        case .preMeditation, .postMeditation: return "brain.head.profile"
        }
    }
}
