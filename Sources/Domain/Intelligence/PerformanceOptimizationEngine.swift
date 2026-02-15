import Foundation
import os.log

/// Performance Optimization Engine
/// Provides training and lifestyle recommendations based on HRV patterns
struct PerformanceOptimizationEngine {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "Performance")

    // MARK: - Recommendation Types

    enum RecommendationType: String {
        case training = "Training"
        case recovery = "Recovery"
        case nutrition = "Nutrition"
        case sleep = "Sleep"
        case stress = "Stress Management"
    }

    struct Recommendation: Identifiable {
        let id = UUID()
        let type: RecommendationType
        let priority: Priority
        let title: String
        let description: String
        let action: String

        enum Priority: Int, Comparable {
            case high = 3
            case medium = 2
            case low = 1

            var emoji: String {
                switch self {
                case .high: return "🔴"
                case .medium: return "🟡"
                case .low: return "🟢"
                }
            }

            static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - Optimization Report

    struct OptimizationReport {
        let recommendations: [Recommendation]
        let primaryFocus: RecommendationType
        let overallStatus: OverallStatus
        let summary: String

        enum OverallStatus: String {
            case optimal = "Optimal"
            case good = "Good"
            case needsAttention = "Needs Attention"
            case critical = "Critical"

            var emoji: String {
                switch self {
                case .optimal: return "✨"
                case .good: return "👍"
                case .needsAttention: return "⚠️"
                case .critical: return "🚨"
                }
            }
        }

        var highPriorityCount: Int {
            recommendations.filter { $0.priority == .high }.count
        }
    }

    // MARK: - Generate Recommendations

    /// Generate personalized recommendations based on current state
    /// Rules from requirements:
    /// - HRV suppressed + high training load → Suggest deload
    /// - HRV stable + RHR low → Suggest push day
    /// - HRV suppressed + low calorie intake → Suggest increase carbs
    static func generateRecommendations(
        currentSummary: DailyHRVSummary,
        historicalSummaries: [DailyHRVSummary],
        readiness: ReadinessEngine.ReadinessMetrics? = nil,
        illnessFlag: HealthDetectionEngine.IllnessFlag? = nil,
        overtrainingFlag: HealthDetectionEngine.OvertrainingFlag? = nil,
        trainingLoadHigh: Bool = false,
        calorieIntakeLow: Bool = false
    ) -> OptimizationReport {
        logger.debug("Generating performance recommendations")

        var recommendations: [Recommendation] = []

        // Get baselines
        let baseline7d = BaselineEngine.calculate7DayBaseline(from: historicalSummaries)
        let baselineRHR = historicalSummaries.suffix(7).map { $0.minHR }.reduce(0, +) /
                          max(1, Double(historicalSummaries.suffix(7).count))

        let hrvSuppressed = baseline7d.map { currentSummary.rmssd < $0 * 0.85 } ?? false
        let hrvStable = baseline7d.map { abs(currentSummary.rmssd - $0) < $0 * 0.10 } ?? true
        let rhrLow = currentSummary.minHR < baselineRHR - 3
        let rhrElevated = currentSummary.minHR > baselineRHR + 5

        // Rule 1: HRV suppressed + high training load → Suggest deload
        if hrvSuppressed && trainingLoadHigh {
            recommendations.append(Recommendation(
                type: .training,
                priority: .high,
                title: "Consider a Deload Week",
                description: "Your HRV is suppressed while training load remains high. This pattern suggests accumulated fatigue.",
                action: "Reduce training volume by 40-50% this week while maintaining intensity."
            ))
        }

        // Rule 2: HRV stable + RHR low → Suggest push day
        if hrvStable && rhrLow {
            recommendations.append(Recommendation(
                type: .training,
                priority: .low,
                title: "Great Day for Hard Training",
                description: "Your HRV is stable and resting heart rate is below baseline. Your body shows excellent recovery.",
                action: "This is a good opportunity for high-intensity or challenging workout."
            ))
        }

        // Rule 3: HRV suppressed + low calorie intake → Suggest increase carbs
        if hrvSuppressed && calorieIntakeLow {
            recommendations.append(Recommendation(
                type: .nutrition,
                priority: .high,
                title: "Increase Carbohydrate Intake",
                description: "Low HRV combined with caloric restriction may impair recovery and performance.",
                action: "Add 50-100g of carbohydrates, especially around training and before bed."
            ))
        }

        // Rule 4: Illness indicators
        if let illness = illnessFlag, illness.isAlert {
            recommendations.append(Recommendation(
                type: .recovery,
                priority: .high,
                title: "Prioritize Rest",
                description: "Possible illness indicators detected. Your immune system may need support.",
                action: "Take a rest day. Focus on sleep, hydration, and light movement only."
            ))
        }

        // Rule 5: Overtraining indicators
        if let overtraining = overtrainingFlag, overtraining.isAlert {
            recommendations.append(Recommendation(
                type: .recovery,
                priority: .high,
                title: "Recovery Week Needed",
                description: overtraining.status.rawValue + " detected over \(overtraining.consecutiveDays) consecutive days.",
                action: "Plan a recovery week with 50% reduced training load and extra sleep."
            ))
        }

        // Rule 6: Poor sleep score
        if let sleepScore = currentSummary.sleepScore, sleepScore < 70 {
            recommendations.append(Recommendation(
                type: .sleep,
                priority: sleepScore < 50 ? .high : .medium,
                title: "Improve Sleep Quality",
                description: "Your sleep score of \(sleepScore) indicates suboptimal recovery during the night.",
                action: "Review sleep hygiene: consistent bedtime, dark room, no screens 1hr before bed."
            ))
        }

        // Rule 7: Elevated RHR without other symptoms
        if rhrElevated && !hrvSuppressed {
            recommendations.append(Recommendation(
                type: .stress,
                priority: .medium,
                title: "Monitor Stress Levels",
                description: "Your resting heart rate is elevated. This may indicate underlying stress or stimulant use.",
                action: "Consider breathing exercises or meditation. Limit caffeine, especially afternoon."
            ))
        }

        // Rule 8: Low readiness score
        if let readiness = readiness, readiness.readinessScore < 55 {
            recommendations.append(Recommendation(
                type: .training,
                priority: .medium,
                title: "Modify Training Intensity",
                description: "Your readiness score of \(readiness.readinessScore) suggests reduced capacity today.",
                action: "Keep intensity moderate. Focus on technique or skill work rather than pushing limits."
            ))
        }

        // Rule 9: Excellent readiness
        if let readiness = readiness, readiness.readinessScore >= 85 {
            recommendations.append(Recommendation(
                type: .training,
                priority: .low,
                title: "Capitalize on High Readiness",
                description: "Your readiness score of \(readiness.readinessScore) indicates excellent recovery.",
                action: "Great day for personal records, competitions, or skill acquisition."
            ))
        }

        // Sort by priority
        recommendations.sort { $0.priority > $1.priority }

        // Determine overall status
        let overallStatus: OptimizationReport.OverallStatus
        let highCount = recommendations.filter { $0.priority == .high }.count

        if highCount >= 2 {
            overallStatus = .critical
        } else if highCount == 1 {
            overallStatus = .needsAttention
        } else if !recommendations.isEmpty {
            overallStatus = .good
        } else {
            overallStatus = .optimal
        }

        // Determine primary focus
        let primaryFocus = recommendations.first?.type ?? .training

        // Generate summary
        let summary = generateSummary(
            status: overallStatus,
            recommendations: recommendations,
            readinessScore: readiness?.readinessScore
        )

        logger.info("Generated \(recommendations.count) recommendations. Status: \(overallStatus.rawValue)")

        return OptimizationReport(
            recommendations: recommendations,
            primaryFocus: primaryFocus,
            overallStatus: overallStatus,
            summary: summary
        )
    }

    private static func generateSummary(
        status: OptimizationReport.OverallStatus,
        recommendations: [Recommendation],
        readinessScore: Int?
    ) -> String {
        switch status {
        case .critical:
            return "Multiple areas need attention. Focus on recovery before intense training."
        case .needsAttention:
            return "One key area needs focus: \(recommendations.first?.title ?? "Recovery")."
        case .good:
            if let readiness = readinessScore {
                return "Overall good. Readiness at \(readiness)%. Some minor optimizations available."
            }
            return "Overall good with some minor optimizations available."
        case .optimal:
            return "Everything looks great! Your recovery and readiness are optimal."
        }
    }

    // MARK: - Training Intensity Suggestion

    enum TrainingIntensitySuggestion: String {
        case rest = "Rest Day"
        case veryLight = "Very Light"
        case light = "Light"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High / Competition Ready"

        var targetHRZone: String {
            switch self {
            case .rest: return "No structured exercise"
            case .veryLight: return "Zone 1 (50-60% max HR)"
            case .light: return "Zone 2 (60-70% max HR)"
            case .moderate: return "Zone 3 (70-80% max HR)"
            case .high: return "Zone 4 (80-90% max HR)"
            case .veryHigh: return "Zone 4-5 (85-100% max HR)"
            }
        }

        static func from(readinessScore: Int) -> TrainingIntensitySuggestion {
            switch readinessScore {
            case 90...: return .veryHigh
            case 80..<90: return .high
            case 65..<80: return .moderate
            case 50..<65: return .light
            case 35..<50: return .veryLight
            default: return .rest
            }
        }
    }

    /// Get suggested training intensity based on readiness
    static func suggestTrainingIntensity(
        readinessScore: Int,
        illnessAlert: Bool = false,
        overtrainingAlert: Bool = false
    ) -> TrainingIntensitySuggestion {
        if illnessAlert || overtrainingAlert {
            return .rest
        }

        return TrainingIntensitySuggestion.from(readinessScore: readinessScore)
    }
}
