import Foundation

struct DailyHRVSummary: Identifiable, Codable {
    let id: UUID
    let date: Date

    // Heart rate metrics
    let meanHR: Double
    let minHR: Double
    let maxHR: Double

    // HRV metrics
    let rmssd: Double
    let lnRMSSD: Double
    let sdnn: Double

    // Sleep metrics
    let sleepDurationMinutes: Double
    let deepSleepMinutes: Double
    let lightSleepMinutes: Double
    let remSleepMinutes: Double
    let awakeMinutes: Double

    // Baseline comparisons
    let baseline7d: Double?
    let baseline30d: Double?

    // Statistical metrics
    let zScore: Double?

    // Recovery metrics
    let recoveryScore: Int?
    let sleepScore: Int?

    init(
        id: UUID = UUID(),
        date: Date,
        meanHR: Double,
        minHR: Double,
        maxHR: Double,
        rmssd: Double,
        sdnn: Double,
        sleepDurationMinutes: Double,
        deepSleepMinutes: Double,
        lightSleepMinutes: Double,
        remSleepMinutes: Double,
        awakeMinutes: Double,
        baseline7d: Double? = nil,
        baseline30d: Double? = nil,
        zScore: Double? = nil,
        recoveryScore: Int? = nil,
        sleepScore: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.meanHR = meanHR
        self.minHR = minHR
        self.maxHR = maxHR
        self.rmssd = rmssd
        self.lnRMSSD = rmssd > 0 ? log(rmssd) : 0
        self.sdnn = sdnn
        self.sleepDurationMinutes = sleepDurationMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.baseline7d = baseline7d
        self.baseline30d = baseline30d
        self.zScore = zScore
        self.recoveryScore = recoveryScore
        self.sleepScore = sleepScore
    }

    // Create from a sleep session
    static func from(session: SleepSession, epochs: [SleepEpoch], summary: SleepSummary) -> DailyHRVSummary {
        let rmssdValues = session.samples.compactMap { $0.rmssd }
        let avgRMSSD = rmssdValues.isEmpty ? 0 : rmssdValues.reduce(0, +) / Double(rmssdValues.count)

        // Calculate SDNN from RR intervals
        let allRRIntervals = session.samples.flatMap { $0.rrIntervals }
        let sdnn = calculateSDNN(from: allRRIntervals)

        return DailyHRVSummary(
            date: session.startTime,
            meanHR: summary.averageHR,
            minHR: summary.minHR,
            maxHR: summary.maxHR,
            rmssd: avgRMSSD,
            sdnn: sdnn,
            sleepDurationMinutes: summary.totalDuration / 60,
            deepSleepMinutes: summary.deepMinutes,
            lightSleepMinutes: summary.lightMinutes,
            remSleepMinutes: summary.remMinutes,
            awakeMinutes: summary.awakeMinutes,
            sleepScore: summary.sleepScore
        )
    }

    private static func calculateSDNN(from rrIntervals: [Double]) -> Double {
        guard rrIntervals.count > 1 else { return 0 }

        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let squaredDiffs = rrIntervals.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(rrIntervals.count)

        return sqrt(variance)
    }
}

// MARK: - Recovery State
enum RecoveryState: String, Codable {
    case excellent = "Excellent"
    case normal = "Normal"
    case strained = "Strained"
    case fatigue = "Fatigue"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .normal: return "blue"
        case .strained: return "orange"
        case .fatigue: return "red"
        }
    }

    static func from(recoveryScore: Double) -> RecoveryState {
        switch recoveryScore {
        case 105...: return .excellent
        case 95..<105: return .normal
        case 85..<95: return .strained
        default: return .fatigue
        }
    }
}
