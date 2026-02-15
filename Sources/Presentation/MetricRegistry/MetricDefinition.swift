import SwiftUI
import Foundation

/// Central registry of all metric definitions with labels, descriptions, and interpretations
/// Provides consistent UI display across the app
struct MetricDefinition: Identifiable {
    let id: MetricType
    let label: String
    let shortDescription: String
    let detailedDescription: String
    let interpretation: (Double, Double?) -> String  // (value, baseline) -> interpretation
    let colorLogic: (Double, Double?) -> MetricColor  // (value, baseline) -> color
    let unit: String
    let icon: String

    enum MetricColor: String {
        case green = "green"
        case yellow = "yellow"
        case red = "red"
        case blue = "blue"
        case gray = "gray"

        var color: Color {
            switch self {
            case .green: return .green
            case .yellow: return .yellow
            case .red: return .red
            case .blue: return .blue
            case .gray: return .gray
            }
        }
    }
}

// MARK: - Metric Types

enum MetricType: String, CaseIterable, Identifiable {
    case rhr = "RHR"
    case rmssd = "RMSSD"
    case sdnn = "SDNN"
    case pnn50 = "pNN50"
    case lfHfRatio = "LF/HF"
    case hrRecovery = "HRR"
    case sleepScore = "Sleep Score"
    case readiness = "Readiness"
    case illnessRisk = "Illness Risk"
    case biologicalAge = "Biological Age"
    case sympatheticLoad = "Sympathetic Load"
    case hrvRhrRatio = "HRV/RHR Ratio"
    case dfaAlpha1 = "DFA Alpha1"

    var id: String { rawValue }
}

// MARK: - Metric Registry

struct MetricRegistry {

    /// Get the definition for a specific metric type
    static func definition(for type: MetricType) -> MetricDefinition {
        switch type {
        case .rhr:
            return restingHeartRate
        case .rmssd:
            return rmssd
        case .sdnn:
            return sdnn
        case .pnn50:
            return pnn50
        case .lfHfRatio:
            return lfHfRatio
        case .hrRecovery:
            return hrRecovery
        case .sleepScore:
            return sleepScore
        case .readiness:
            return trainingReadiness
        case .illnessRisk:
            return illnessRisk
        case .biologicalAge:
            return biologicalAge
        case .sympatheticLoad:
            return sympatheticLoad
        case .hrvRhrRatio:
            return hrvRhrRatio
        case .dfaAlpha1:
            return dfaAlpha1
        }
    }

    /// Get all metric definitions
    static var allDefinitions: [MetricDefinition] {
        MetricType.allCases.map { definition(for: $0) }
    }

    // MARK: - Individual Definitions

    static let restingHeartRate = MetricDefinition(
        id: .rhr,
        label: "Resting Heart Rate",
        shortDescription: "Lowest heart rate at rest. Indicates recovery and cardiovascular efficiency.",
        detailedDescription: """
            Lower RHR (within healthy range) reflects stronger stroke volume and aerobic conditioning.
            Sudden elevation may signal stress, illness, or incomplete recovery.
            """,
        interpretation: { value, baseline in
            guard let baseline = baseline else {
                return "RHR: \(Int(value)) bpm"
            }
            let diff = value - baseline
            if diff < -3 {
                return "Excellent - \(Int(abs(diff))) bpm below your baseline"
            } else if diff <= 5 {
                return "Normal range for you"
            } else {
                return "Elevated by \(Int(diff)) bpm - monitor for stress or illness"
            }
        },
        colorLogic: { value, baseline in
            guard let baseline = baseline else { return .blue }
            let diff = value - baseline
            if diff < -3 { return .green }
            else if diff <= 5 { return .blue }
            else if diff <= 10 { return .yellow }
            else { return .red }
        },
        unit: "bpm",
        icon: "heart.fill"
    )

    static let rmssd = MetricDefinition(
        id: .rmssd,
        label: "RMSSD (HRV)",
        shortDescription: "Measures parasympathetic recovery activity.",
        detailedDescription: """
            Higher RMSSD indicates better nervous system recovery and adaptability.
            Lower values may reflect stress, fatigue, or illness onset.
            Compare against your baseline - not others.
            """,
        interpretation: { value, baseline in
            guard let baseline = baseline else {
                return "RMSSD: \(String(format: "%.1f", value)) ms"
            }
            let ratio = value / baseline
            if ratio > 1.15 {
                return "Elevated recovery - \(Int((ratio - 1) * 100))% above baseline"
            } else if ratio >= 0.85 {
                return "Normal range for you"
            } else {
                return "Below baseline by \(Int((1 - ratio) * 100))% - recovery needed"
            }
        },
        colorLogic: { value, baseline in
            guard let baseline = baseline else { return .blue }
            let ratio = value / baseline
            if ratio > 1.15 { return .green }
            else if ratio >= 0.85 { return .blue }
            else if ratio >= 0.70 { return .yellow }
            else { return .red }
        },
        unit: "ms",
        icon: "waveform.path.ecg"
    )

    static let sdnn = MetricDefinition(
        id: .sdnn,
        label: "SDNN",
        shortDescription: "Overall heart rhythm variability.",
        detailedDescription: """
            Represents total autonomic flexibility.
            Lower values may indicate reduced adaptability or chronic stress.
            """,
        interpretation: { value, baseline in
            if value > 100 {
                return "Excellent overall variability"
            } else if value > 50 {
                return "Good autonomic flexibility"
            } else {
                return "Consider stress management and recovery"
            }
        },
        colorLogic: { value, _ in
            if value > 100 { return .green }
            else if value > 50 { return .blue }
            else if value > 30 { return .yellow }
            else { return .red }
        },
        unit: "ms",
        icon: "chart.xyaxis.line"
    )

    static let pnn50 = MetricDefinition(
        id: .pnn50,
        label: "pNN50",
        shortDescription: "Percentage of heartbeats differing by >50ms.",
        detailedDescription: """
            Higher values reflect stronger parasympathetic dominance and recovery state.
            """,
        interpretation: { value, _ in
            if value > 30 {
                return "Strong parasympathetic activity"
            } else if value > 10 {
                return "Normal vagal tone"
            } else {
                return "Low parasympathetic activity"
            }
        },
        colorLogic: { value, _ in
            if value > 30 { return .green }
            else if value > 10 { return .blue }
            else if value > 5 { return .yellow }
            else { return .red }
        },
        unit: "%",
        icon: "percent"
    )

    static let lfHfRatio = MetricDefinition(
        id: .lfHfRatio,
        label: "LF/HF Ratio",
        shortDescription: "Balance between stress and recovery systems.",
        detailedDescription: """
            Higher values may indicate sympathetic dominance (stress load).
            Best interpreted as a trend metric.
            """,
        interpretation: { value, baseline in
            if value < 0.5 {
                return "Strong parasympathetic dominance"
            } else if value < 2.0 {
                return "Balanced autonomic state"
            } else if value < 4.0 {
                return "Sympathetic dominance - elevated stress"
            } else {
                return "High stress load detected"
            }
        },
        colorLogic: { value, _ in
            if value < 0.5 { return .blue }
            else if value < 2.0 { return .green }
            else if value < 4.0 { return .yellow }
            else { return .red }
        },
        unit: "",
        icon: "arrow.left.arrow.right"
    )

    static let hrRecovery = MetricDefinition(
        id: .hrRecovery,
        label: "HR Recovery",
        shortDescription: "How quickly your heart rate drops post-exercise.",
        detailedDescription: """
            A drop of 25+ bpm in 1 minute suggests strong parasympathetic reactivation.
            Slower recovery may indicate fatigue or overload.
            """,
        interpretation: { value, _ in
            if value >= 40 {
                return "Excellent recovery capacity"
            } else if value >= 25 {
                return "Good parasympathetic reactivation"
            } else if value >= 15 {
                return "Moderate - may indicate fatigue"
            } else {
                return "Below optimal - prioritize recovery"
            }
        },
        colorLogic: { value, _ in
            if value >= 40 { return .green }
            else if value >= 25 { return .green }
            else if value >= 15 { return .yellow }
            else { return .red }
        },
        unit: "bpm/min",
        icon: "arrow.down.heart.fill"
    )

    static let sleepScore = MetricDefinition(
        id: .sleepScore,
        label: "Sleep Score",
        shortDescription: "Overall overnight recovery quality.",
        detailedDescription: """
            Combines sleep duration, deep/REM %, HRV, RHR, and fragmentation.

            85-100: optimal recovery
            70-84: moderate
            <70: recovery debt
            """,
        interpretation: { value, _ in
            if value >= 85 {
                return "Optimal recovery overnight"
            } else if value >= 70 {
                return "Moderate recovery - room for improvement"
            } else if value >= 50 {
                return "Recovery debt accumulating"
            } else {
                return "Poor sleep - prioritize rest tonight"
            }
        },
        colorLogic: { value, _ in
            if value >= 85 { return .green }
            else if value >= 70 { return .blue }
            else if value >= 50 { return .yellow }
            else { return .red }
        },
        unit: "",
        icon: "moon.zzz.fill"
    )

    static let trainingReadiness = MetricDefinition(
        id: .readiness,
        label: "Training Readiness",
        shortDescription: "Capacity to handle stress today.",
        detailedDescription: """
            Combines HRV deviation, RHR, sleep score, and HR recovery.

            80-100: Push day
            60-79: Moderate intensity
            <60: Recovery focus
            """,
        interpretation: { value, _ in
            if value >= 80 {
                return "Great day for challenging training"
            } else if value >= 60 {
                return "Moderate intensity recommended"
            } else if value >= 40 {
                return "Light activity or skill work"
            } else {
                return "Rest day recommended"
            }
        },
        colorLogic: { value, _ in
            if value >= 80 { return .green }
            else if value >= 60 { return .blue }
            else if value >= 40 { return .yellow }
            else { return .red }
        },
        unit: "",
        icon: "figure.run"
    )

    static let illnessRisk = MetricDefinition(
        id: .illnessRisk,
        label: "Illness Risk Indicator",
        shortDescription: "Early physiological stress warning.",
        detailedDescription: """
            Triggered when HRV drops significantly and RHR rises.
            May indicate immune activation before symptoms.
            Not a diagnosis.
            """,
        interpretation: { value, _ in
            if value < 30 {
                return "No illness indicators detected"
            } else if value < 60 {
                return "Some indicators present - monitor symptoms"
            } else {
                return "Strong indicators - consider resting"
            }
        },
        colorLogic: { value, _ in
            if value < 30 { return .green }
            else if value < 60 { return .yellow }
            else { return .red }
        },
        unit: "%",
        icon: "cross.circle.fill"
    )

    static let biologicalAge = MetricDefinition(
        id: .biologicalAge,
        label: "Biological Age",
        shortDescription: "Estimated physiological cardiovascular age.",
        detailedDescription: """
            Derived from chronic HRV, RHR, and recovery patterns.
            Lower biological age reflects stronger cardiometabolic profile.
            """,
        interpretation: { value, baseline in
            guard let chronologicalAge = baseline else {
                return "Estimated: \(Int(value)) years"
            }
            let diff = value - chronologicalAge
            if diff <= -5 {
                return "\(Int(abs(diff))) years younger - excellent!"
            } else if diff < 0 {
                return "\(Int(abs(diff))) years younger than chronological age"
            } else if diff == 0 {
                return "Matches your chronological age"
            } else {
                return "\(Int(diff)) years older - focus on cardio fitness"
            }
        },
        colorLogic: { value, baseline in
            guard let chronologicalAge = baseline else { return .blue }
            let diff = value - chronologicalAge
            if diff <= -5 { return .green }
            else if diff < 0 { return .green }
            else if diff <= 5 { return .blue }
            else { return .yellow }
        },
        unit: "years",
        icon: "calendar.badge.clock"
    )

    static let sympatheticLoad = MetricDefinition(
        id: .sympatheticLoad,
        label: "Sympathetic Load",
        shortDescription: "Current nervous system stress level.",
        detailedDescription: """
            High levels may result from intense training, poor sleep, or emotional stress.
            Chronic elevation may impair hormonal balance and recovery.
            """,
        interpretation: { value, _ in
            if value < 30 {
                return "Low stress load - good recovery state"
            } else if value < 60 {
                return "Moderate stress - normal range"
            } else if value < 80 {
                return "Elevated stress load"
            } else {
                return "High stress - prioritize recovery"
            }
        },
        colorLogic: { value, _ in
            if value < 30 { return .green }
            else if value < 60 { return .blue }
            else if value < 80 { return .yellow }
            else { return .red }
        },
        unit: "",
        icon: "bolt.heart.fill"
    )

    static let hrvRhrRatio = MetricDefinition(
        id: .hrvRhrRatio,
        label: "HRV/RHR Ratio",
        shortDescription: "Recovery efficiency indicator.",
        detailedDescription: """
            Combines HRV and RHR into a single recovery metric.
            Higher values indicate better parasympathetic tone relative to heart rate.
            """,
        interpretation: { value, baseline in
            if value > 1.0 {
                return "Excellent recovery efficiency"
            } else if value > 0.6 {
                return "Good recovery state"
            } else if value > 0.4 {
                return "Moderate - room for improvement"
            } else {
                return "Low efficiency - focus on recovery"
            }
        },
        colorLogic: { value, _ in
            if value > 1.0 { return .green }
            else if value > 0.6 { return .blue }
            else if value > 0.4 { return .yellow }
            else { return .red }
        },
        unit: "",
        icon: "arrow.up.arrow.down"
    )

    static let dfaAlpha1 = MetricDefinition(
        id: .dfaAlpha1,
        label: "DFA Alpha1",
        shortDescription: "Heart rate complexity measure.",
        detailedDescription: """
            Measures fractal scaling of heart rate.
            0.75-1.0: Healthy complexity
            <0.75: May indicate fatigue
            >1.2: Rigid pattern - reduced adaptability
            """,
        interpretation: { value, _ in
            if value < 0.5 {
                return "Uncorrelated - unusual pattern"
            } else if value < 0.75 {
                return "May indicate fatigue or recovery need"
            } else if value < 1.0 {
                return "Healthy complexity"
            } else if value < 1.2 {
                return "Slightly rigid pattern"
            } else {
                return "Highly correlated - reduced variability"
            }
        },
        colorLogic: { value, _ in
            if value >= 0.75 && value < 1.0 { return .green }
            else if value >= 0.5 && value < 0.75 { return .yellow }
            else if value >= 1.0 && value < 1.2 { return .blue }
            else { return .red }
        },
        unit: "",
        icon: "waveform"
    )
}

// MARK: - SwiftUI Views

struct MetricCardView: View {
    let type: MetricType
    let value: Double
    let baseline: Double?

    private var definition: MetricDefinition {
        MetricRegistry.definition(for: type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: definition.icon)
                    .foregroundColor(definition.colorLogic(value, baseline).color)
                Text(definition.label)
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(formattedValue)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(definition.colorLogic(value, baseline).color)

                if !definition.unit.isEmpty {
                    Text(definition.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(definition.interpretation(value, baseline))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var formattedValue: String {
        if value == value.rounded() {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

struct MetricDetailView: View {
    let type: MetricType
    let value: Double?
    let baseline: Double?
    var onActionTapped: ((MetricAction) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var definition: MetricDefinition {
        MetricRegistry.definition(for: type)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: definition.icon)
                            .font(.title)
                            .foregroundColor(value != nil ? definition.colorLogic(value!, baseline).color : .gray)

                        VStack(alignment: .leading) {
                            Text(definition.label)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(definition.shortDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Current Value or Action Required
                    if let value = value {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Value")
                                .font(.headline)

                            HStack(alignment: .firstTextBaseline) {
                                Text(String(format: value == value.rounded() ? "%.0f" : "%.1f", value))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(definition.colorLogic(value, baseline).color)

                                Text(definition.unit)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }

                            Text(definition.interpretation(value, baseline))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // No value - show action required
                        NoValueActionCard(type: type, onActionTapped: { action in
                            onActionTapped?(action)
                            dismiss()
                        })
                    }

                    Divider()

                    // Detailed Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About This Metric")
                            .font(.headline)

                        Text(definition.detailedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // How to Measure (for all types)
                    if let howToMeasure = MetricMeasurementInfo.info(for: type) {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to Measure")
                                .font(.headline)

                            Text(howToMeasure.instructions)
                                .font(.body)
                                .foregroundColor(.secondary)

                            if let requirements = howToMeasure.requirements {
                                Text("Requirements:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.top, 4)

                                Text(requirements)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(definition.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    init(type: MetricType, value: Double?, baseline: Double?, onActionTapped: ((MetricAction) -> Void)? = nil) {
        self.type = type
        self.value = value
        self.baseline = baseline
        self.onActionTapped = onActionTapped
    }

    // Legacy init for compatibility
    init(type: MetricType, value: Double, baseline: Double?) {
        self.type = type
        self.value = value
        self.baseline = baseline
        self.onActionTapped = nil
    }
}

// MARK: - Metric Actions

enum MetricAction {
    case takeSnapshot
    case takeExtendedMeasurement
    case measureHRRecovery
    case startSleepTracking
    case takeMorningReadiness
}

// MARK: - No Value Action Card

struct NoValueActionCard: View {
    let type: MetricType
    var onActionTapped: ((MetricAction) -> Void)?

    private var actionInfo: (message: String, buttonLabel: String, action: MetricAction)? {
        switch type {
        case .pnn50:
            return (
                "pNN50 is calculated during HRV measurements. Take a quick snapshot or morning readiness check to measure this.",
                "Take HRV Snapshot",
                .takeSnapshot
            )
        case .lfHfRatio, .sympatheticLoad:
            return (
                "LF/HF ratio requires frequency domain analysis, which needs at least 3 minutes of continuous heart rate data.",
                "Take Extended Measurement",
                .takeExtendedMeasurement
            )
        case .dfaAlpha1:
            return (
                "DFA Alpha1 requires at least 100 consecutive heartbeats (about 2-3 minutes) for accurate fractal analysis.",
                "Take Extended Measurement",
                .takeExtendedMeasurement
            )
        case .hrRecovery:
            return (
                "Heart Rate Recovery measures how quickly your heart rate drops after exercise. This requires a post-workout measurement.",
                "Measure HR Recovery",
                .measureHRRecovery
            )
        case .sleepScore:
            return (
                "Sleep Score is calculated from overnight sleep tracking data including duration, stages, and HRV patterns.",
                "Start Sleep Tracking",
                .startSleepTracking
            )
        case .sdnn:
            return (
                "SDNN is calculated during HRV measurements. Take a quick snapshot or morning readiness check.",
                "Take HRV Snapshot",
                .takeSnapshot
            )
        case .readiness:
            return (
                "Readiness score combines multiple metrics. Take a morning readiness measurement for best results.",
                "Take Morning Readiness",
                .takeMorningReadiness
            )
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("No Data Available")
                    .font(.headline)
            }

            if let info = actionInfo {
                Text(info.message)
                    .font(.body)
                    .foregroundColor(.secondary)

                Button(action: {
                    onActionTapped?(info.action)
                }) {
                    HStack {
                        Image(systemName: actionIcon(for: info.action))
                        Text(info.buttonLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            } else {
                Text("This metric requires additional data that is not yet available.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func actionIcon(for action: MetricAction) -> String {
        switch action {
        case .takeSnapshot: return "camera.metering.spot"
        case .takeExtendedMeasurement: return "waveform.path.ecg"
        case .measureHRRecovery: return "arrow.down.heart.fill"
        case .startSleepTracking: return "moon.zzz.fill"
        case .takeMorningReadiness: return "sun.horizon.fill"
        }
    }
}

// MARK: - Measurement Info

struct MetricMeasurementInfo {
    let instructions: String
    let requirements: String?

    static func info(for type: MetricType) -> MetricMeasurementInfo? {
        switch type {
        case .rmssd, .sdnn:
            return MetricMeasurementInfo(
                instructions: "Measured during any HRV reading - snapshots, morning readiness, or sleep tracking. For best accuracy, stay still and relaxed during measurement.",
                requirements: "At least 60 seconds of heart rate data"
            )
        case .pnn50:
            return MetricMeasurementInfo(
                instructions: "Calculated from RR intervals during HRV measurement. Higher values indicate stronger parasympathetic activity.",
                requirements: "At least 60 seconds of heart rate data"
            )
        case .lfHfRatio, .sympatheticLoad:
            return MetricMeasurementInfo(
                instructions: "Requires frequency domain analysis using Welch's method. Take an extended measurement while sitting quietly.",
                requirements: "At least 3 minutes of continuous heart rate data with minimal movement"
            )
        case .dfaAlpha1:
            return MetricMeasurementInfo(
                instructions: "Uses Detrended Fluctuation Analysis to measure heart rate complexity. Best measured in a rested state.",
                requirements: "At least 100 consecutive heartbeats (~2-3 minutes)"
            )
        case .hrRecovery:
            return MetricMeasurementInfo(
                instructions: "Measure your peak heart rate during exercise, then immediately measure your heart rate 1 minute after stopping. The difference is your HR Recovery.",
                requirements: "Heart rate monitor during and after exercise"
            )
        case .sleepScore:
            return MetricMeasurementInfo(
                instructions: "Automatically calculated from overnight sleep tracking. Wear your heart rate monitor to bed and start a sleep session.",
                requirements: "Complete overnight sleep session with heart rate monitoring"
            )
        case .readiness:
            return MetricMeasurementInfo(
                instructions: "Best measured first thing in the morning. Take a morning readiness measurement within 30 minutes of waking.",
                requirements: "Morning HRV measurement before caffeine or exercise"
            )
        case .biologicalAge:
            return MetricMeasurementInfo(
                instructions: "Estimated from your average HRV, resting heart rate, and recovery patterns over time. More data improves accuracy.",
                requirements: "At least 7 days of HRV measurements"
            )
        case .illnessRisk:
            return MetricMeasurementInfo(
                instructions: "Automatically detected when HRV drops significantly below baseline while RHR rises. Not a medical diagnosis.",
                requirements: "Established baseline from 7+ days of measurements"
            )
        default:
            return nil
        }
    }
}
