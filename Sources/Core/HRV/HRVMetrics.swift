import Foundation

// MARK: - Time Domain Metrics

struct HRVTimeDomain: Codable {
    /// Root Mean Square of Successive Differences (ms)
    let rmssd: Double

    /// Standard Deviation of NN intervals (ms)
    let sdnn: Double

    /// Percentage of successive RR intervals differing by >50ms
    let pnn50: Double
}

// MARK: - Frequency Domain Metrics

struct HRVFrequencyDomain: Codable {
    /// Low Frequency power (0.04-0.15 Hz) - Sympathetic + Parasympathetic
    let lfPower: Double

    /// High Frequency power (0.15-0.40 Hz) - Parasympathetic (vagal)
    let hfPower: Double

    /// LF/HF Ratio - Sympathovagal balance
    let lfHfRatio: Double

    /// Total power
    var totalPower: Double {
        lfPower + hfPower
    }

    /// Normalized LF (%)
    var lfNormalized: Double {
        guard totalPower > 0 else { return 0 }
        return (lfPower / totalPower) * 100
    }

    /// Normalized HF (%)
    var hfNormalized: Double {
        guard totalPower > 0 else { return 0 }
        return (hfPower / totalPower) * 100
    }
}

// MARK: - Complete HRV Metrics (matching requirements)

struct HRVMetrics: Codable {
    /// Root Mean Square of Successive Differences (in milliseconds)
    /// Primary measure of parasympathetic (vagal) activity
    let rmssd: Double

    /// Standard Deviation of NN intervals (in milliseconds)
    /// Overall HRV measure
    let sdnn: Double?

    /// Percentage of successive RR intervals differing by more than 50ms
    let pnn50: Double?

    /// Number of RR intervals used in calculation
    let sampleCount: Int

    /// Time window of the calculation
    let windowDuration: TimeInterval

    init(rmssd: Double, sdnn: Double? = nil, pnn50: Double? = nil,
         sampleCount: Int, windowDuration: TimeInterval) {
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.pnn50 = pnn50
        self.sampleCount = sampleCount
        self.windowDuration = windowDuration
    }

    /// Create time domain only metrics
    var timeDomain: HRVTimeDomain? {
        guard let sdnn = sdnn, let pnn50 = pnn50 else { return nil }
        return HRVTimeDomain(rmssd: rmssd, sdnn: sdnn, pnn50: pnn50)
    }
}

extension HRVMetrics: CustomStringConvertible {
    var description: String {
        "RMSSD: \(String(format: "%.1f", rmssd))ms (n=\(sampleCount))"
    }
}

// MARK: - Full HRV Metrics (Time + Frequency + DFA)

struct FullHRVMetrics: Codable {
    /// Time domain metrics
    let time: HRVTimeDomain

    /// Frequency domain metrics (optional - requires more data)
    let freq: HRVFrequencyDomain?

    /// DFA Alpha1 - fractal scaling exponent
    let dfaAlpha1: Double?

    /// Timestamp of calculation
    let timestamp: Date

    /// Sample count used
    let sampleCount: Int

    /// Data quality score (0-100)
    let qualityScore: Double

    /// Initialize with all components
    init(
        time: HRVTimeDomain,
        freq: HRVFrequencyDomain? = nil,
        dfaAlpha1: Double? = nil,
        timestamp: Date = Date(),
        sampleCount: Int,
        qualityScore: Double
    ) {
        self.time = time
        self.freq = freq
        self.dfaAlpha1 = dfaAlpha1
        self.timestamp = timestamp
        self.sampleCount = sampleCount
        self.qualityScore = qualityScore
    }
}

// MARK: - Sleep Metrics (from requirements)

struct SleepMetrics: Codable {
    /// Total sleep duration in minutes
    let durationMinutes: Double

    /// Sleep efficiency (time asleep / time in bed) as percentage
    let efficiency: Double

    /// Deep sleep percentage
    let deepPercent: Double

    /// REM sleep percentage
    let remPercent: Double

    /// Overnight average RMSSD
    let overnightRMSSD: Double

    /// Overnight resting heart rate (minimum)
    let overnightRHR: Double

    /// HRV deviation from baseline score (0-100)
    let hrvDeviationScore: Double

    /// Sleep fragmentation index (0-100, lower is better)
    let fragmentationIndex: Double

    /// Final sleep score (0-100)
    let sleepScore: Int

    /// Calculate sleep score using the formula from requirements
    static func calculateScore(
        durationScore: Double,
        efficiencyScore: Double,
        deepScore: Double,
        remScore: Double,
        hrvDeviationScore: Double,
        rhrInverseScore: Double,
        fragmentationPenalty: Double
    ) -> Int {
        // Weights from requirements:
        // 0.25(Duration) + 0.15(Efficiency) + 0.15(Deep) + 0.10(REM)
        // + 0.15(HRV Deviation) + 0.10(RHR Inverse) + 0.10(Fragmentation Penalty)
        let score = 0.25 * durationScore +
                    0.15 * efficiencyScore +
                    0.15 * deepScore +
                    0.10 * remScore +
                    0.15 * hrvDeviationScore +
                    0.10 * rhrInverseScore +
                    0.10 * (100 - fragmentationPenalty)  // Invert penalty

        return Int(min(100, max(0, score.rounded())))
    }
}

// MARK: - Readiness Metrics (from requirements)

struct ReadinessMetricsData: Codable {
    /// HRV Z-score from baseline
    let hrvZScore: Double

    /// RHR deviation from baseline
    let rhrDeviation: Double

    /// Sleep score (0-100)
    let sleepScore: Double

    /// Heart Rate Recovery score (0-100)
    let hrrScore: Double

    /// Final readiness score (0-100)
    let readinessScore: Int

    /// Calculate readiness using formula from requirements
    static func calculateScore(
        hrvZScaled: Double,
        rhrDeviationInverse: Double,
        sleepScore: Double,
        hrrScore: Double
    ) -> Int {
        // Readiness = 0.4(HRV Z-scaled) + 0.2(RHR deviation inverse) + 0.2(Sleep Score) + 0.2(HRR Score)
        let score = 0.4 * hrvZScaled +
                    0.2 * rhrDeviationInverse +
                    0.2 * sleepScore +
                    0.2 * hrrScore

        return Int(min(100, max(0, score.rounded())))
    }
}

// MARK: - Illness Flag (from requirements)

struct IllnessFlagData: Codable {
    enum Status: String, Codable {
        case normal
        case possibleIllness = "possible_illness"
    }

    let status: Status
    let confidence: Double  // 0-100%
}
