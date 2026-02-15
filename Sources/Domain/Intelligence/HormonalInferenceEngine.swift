import Foundation
import os.log

/// Hormonal Inference Engine
/// Infers autonomic nervous system state from HRV patterns
/// Note: This is NOT medical advice - informational only
struct HormonalInferenceEngine {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "Hormonal")

    // MARK: - ANS State

    enum ANSState: String, CaseIterable {
        case parasympatheticOptimized = "Parasympathetic Optimized"
        case sympatheticDominant = "Sympathetic Dominant"
        case chronicStressPattern = "Chronic Stress Pattern"
        case balanced = "Balanced"
        case recoveryMode = "Recovery Mode"
        case fightOrFlight = "Fight or Flight"

        var emoji: String {
            switch self {
            case .parasympatheticOptimized: return "🧘"
            case .sympatheticDominant: return "⚡"
            case .chronicStressPattern: return "🔥"
            case .balanced: return "⚖️"
            case .recoveryMode: return "💤"
            case .fightOrFlight: return "🏃"
            }
        }

        var description: String {
            switch self {
            case .parasympatheticOptimized:
                return "Your nervous system shows strong parasympathetic (rest-and-digest) activity. This is associated with good recovery and stress resilience."
            case .sympatheticDominant:
                return "Your nervous system is in a heightened state of alertness. This may be due to recent exercise, stress, or excitement."
            case .chronicStressPattern:
                return "Persistent low HRV may indicate chronic stress. Consider stress management techniques and recovery optimization."
            case .balanced:
                return "Your autonomic nervous system shows good balance between sympathetic and parasympathetic activity."
            case .recoveryMode:
                return "Your body is in active recovery mode with strong parasympathetic dominance during rest."
            case .fightOrFlight:
                return "Acute stress response detected. This is normal after intense activity or acute stressors."
            }
        }

        var recommendations: [String] {
            switch self {
            case .parasympatheticOptimized:
                return [
                    "Great time for challenging workouts",
                    "Mental performance likely optimal",
                    "Good stress resilience today"
                ]
            case .sympatheticDominant:
                return [
                    "Good energy for moderate activity",
                    "Consider avoiding additional stimulants",
                    "Balance with relaxation activities later"
                ]
            case .chronicStressPattern:
                return [
                    "Prioritize sleep quality",
                    "Consider meditation or breathing exercises",
                    "Review training load and life stressors",
                    "Ensure adequate nutrition and hydration"
                ]
            case .balanced:
                return [
                    "Continue your current routine",
                    "Good day for varied activities",
                    "Body is adapting well"
                ]
            case .recoveryMode:
                return [
                    "Light activity or rest recommended",
                    "Body is actively repairing",
                    "Support with good nutrition"
                ]
            case .fightOrFlight:
                return [
                    "Allow time for nervous system to calm",
                    "Avoid additional intense stressors",
                    "Breathing exercises may help"
                ]
            }
        }
    }

    // MARK: - Inference Result

    struct HormonalInference {
        let primaryState: ANSState
        let confidence: Double  // 0-100%
        let lfHfRatio: Double?
        let hrvLevel: HRVLevel
        let rhrLevel: RHRLevel
        let morningHRSpike: Bool
        let description: String
        let recommendations: [String]
        let disclaimer: String = "This is not medical advice. Patterns are inferred from HRV data for informational purposes only."
    }

    enum HRVLevel: String {
        case low = "Low"
        case normal = "Normal"
        case high = "High"

        static func from(rmssd: Double, baseline: Double) -> HRVLevel {
            let ratio = rmssd / baseline
            switch ratio {
            case ..<0.80: return .low
            case 0.80..<1.15: return .normal
            default: return .high
            }
        }
    }

    enum RHRLevel: String {
        case low = "Low"
        case normal = "Normal"
        case elevated = "Elevated"

        static func from(rhr: Double, baseline: Double) -> RHRLevel {
            let diff = rhr - baseline
            switch diff {
            case ..<(-3): return .low
            case (-3)...5: return .normal
            default: return .elevated
            }
        }
    }

    // MARK: - Inference Rules

    /// Infer hormonal/ANS state from HRV patterns
    /// Rules from requirements:
    /// - Low HRV + High RHR → "Sympathetic Dominant"
    /// - High HRV + Strong Morning HR spike → "Parasympathetic Optimized"
    /// - Low HRV persistent → "Chronic Stress Pattern"
    static func inferState(
        currentSummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        lfHfRatio: Double? = nil,
        morningHRSpike: Bool = false
    ) -> HormonalInference {
        logger.debug("Inferring ANS state")

        // Get baselines
        let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries) ?? currentSummary.rmssd
        let baselineRHR = historicalSummaries.suffix(7).map { $0.minHR }.reduce(0, +) /
                          max(1, Double(historicalSummaries.suffix(7).count))

        // Determine levels
        let hrvLevel = HRVLevel.from(rmssd: currentSummary.rmssd, baseline: baseline7d)
        let rhrLevel = RHRLevel.from(rhr: currentSummary.minHR, baseline: baselineRHR)

        // Check for chronic patterns
        let chronicLowHRV = checkChronicLowHRV(
            summaries: historicalSummaries,
            baseline: baseline7d
        )

        // Apply inference rules
        let (state, confidence) = inferStateFromPatterns(
            hrvLevel: hrvLevel,
            rhrLevel: rhrLevel,
            lfHfRatio: lfHfRatio,
            morningHRSpike: morningHRSpike,
            chronicLowHRV: chronicLowHRV
        )

        logger.info("ANS state: \(state.rawValue), Confidence: \(String(format: "%.0f", confidence))%")

        return HormonalInference(
            primaryState: state,
            confidence: confidence,
            lfHfRatio: lfHfRatio,
            hrvLevel: hrvLevel,
            rhrLevel: rhrLevel,
            morningHRSpike: morningHRSpike,
            description: state.description,
            recommendations: state.recommendations
        )
    }

    private static func inferStateFromPatterns(
        hrvLevel: HRVLevel,
        rhrLevel: RHRLevel,
        lfHfRatio: Double?,
        morningHRSpike: Bool,
        chronicLowHRV: Bool
    ) -> (state: ANSState, confidence: Double) {

        // Rule 1: Chronic stress pattern (persistent low HRV)
        if chronicLowHRV {
            return (.chronicStressPattern, 80)
        }

        // Rule 2: Low HRV + High RHR → Sympathetic Dominant
        if hrvLevel == .low && rhrLevel == .elevated {
            // Check if LF/HF supports this
            let lfhfSupport = lfHfRatio.map { $0 > 2.0 } ?? true
            let confidence = lfhfSupport ? 85.0 : 70.0
            return (.sympatheticDominant, confidence)
        }

        // Rule 3: High HRV + Strong Morning HR spike → Parasympathetic Optimized
        if hrvLevel == .high && morningHRSpike {
            return (.parasympatheticOptimized, 85)
        }

        // Rule 4: High HRV alone → Recovery Mode
        if hrvLevel == .high && rhrLevel == .low {
            return (.recoveryMode, 75)
        }

        // Rule 5: High RHR alone without low HRV → Fight or Flight
        if rhrLevel == .elevated && hrvLevel != .low {
            return (.fightOrFlight, 60)
        }

        // Rule 6: LF/HF based inference
        if let lfhf = lfHfRatio {
            if lfhf > 3.0 {
                return (.sympatheticDominant, 70)
            } else if lfhf < 0.5 {
                return (.parasympatheticOptimized, 65)
            }
        }

        // Default: Balanced
        return (.balanced, 70)
    }

    private static func checkChronicLowHRV(
        summaries: [DailyHRVSummary],
        baseline: Double
    ) -> Bool {
        // Check if last 3+ days have consistently low HRV
        let recent = summaries.suffix(5)
        guard recent.count >= 3 else { return false }

        let lowDays = recent.filter { $0.rmssd < baseline * 0.80 }.count
        return lowDays >= 3
    }

    // MARK: - Cortisol Awakening Response (CAR) Detection

    /// Detect morning cortisol awakening response from heart rate pattern
    /// A healthy CAR shows HR spike 20-30 minutes after waking
    static func detectMorningHRSpike(
        morningHRSamples: [(time: Date, hr: Double)]
    ) -> Bool {
        guard morningHRSamples.count >= 10 else { return false }

        // Sort by time
        let sorted = morningHRSamples.sorted { $0.time < $1.time }

        // Find first 5 minutes average (waking baseline)
        let first5Min = sorted.prefix(10)
        let wakingHR = first5Min.map { $0.hr }.reduce(0, +) / Double(first5Min.count)

        // Find peak in 20-40 minute window
        let laterSamples = sorted.dropFirst(10)
        let peakHR = laterSamples.map { $0.hr }.max() ?? wakingHR

        // Healthy CAR: 10-20% HR increase
        let increase = (peakHR - wakingHR) / wakingHR

        return increase >= 0.10 && increase <= 0.25
    }
}
