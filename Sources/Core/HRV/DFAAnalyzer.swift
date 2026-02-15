import Foundation
import os.log

/// Detrended Fluctuation Analysis (DFA) for HRV complexity assessment
/// DFA Alpha1 measures short-term fractal scaling properties of heart rate variability
struct DFAAnalyzer {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "DFA")

    // MARK: - Configuration

    struct Configuration {
        /// Minimum box size for DFA Alpha1 (typically 4-16 beats)
        let minBoxSize: Int = 4

        /// Maximum box size for DFA Alpha1 (typically 16 beats)
        let maxBoxSize: Int = 16

        /// Minimum number of RR intervals required
        let minIntervals: Int = 100

        static let `default` = Configuration()
    }

    // MARK: - Result

    struct DFAResult {
        /// DFA Alpha1 - short-term fractal scaling exponent
        let alpha1: Double

        /// Interpretation of the alpha1 value
        let interpretation: DFAInterpretation

        /// Box sizes used in calculation
        let boxSizes: [Int]

        /// Fluctuation values for each box size (for plotting)
        let fluctuations: [Double]

        /// R-squared value of log-log regression
        let rSquared: Double
    }

    enum DFAInterpretation: String {
        case uncorrelated = "Uncorrelated (Random)"
        case healthyComplexity = "Healthy Complexity"
        case fatigueSignal = "Fatigue Signal"
        case rigidPattern = "Rigid Pattern"
        case highlyCorrelated = "Highly Correlated"

        var description: String {
            switch self {
            case .uncorrelated:
                return "Heart rate shows random behavior, similar to white noise."
            case .healthyComplexity:
                return "Healthy heart rate variability with optimal complexity."
            case .fatigueSignal:
                return "Lower complexity may indicate fatigue or recovery need."
            case .rigidPattern:
                return "Reduced variability, overly regular heart rate pattern."
            case .highlyCorrelated:
                return "Very high correlation, may indicate stress or disease."
            }
        }

        static func from(alpha1: Double) -> DFAInterpretation {
            switch alpha1 {
            case ..<0.5:
                return .uncorrelated
            case 0.5..<0.75:
                return .fatigueSignal
            case 0.75..<1.0:
                return .healthyComplexity
            case 1.0..<1.2:
                return .rigidPattern
            default:
                return .highlyCorrelated
            }
        }
    }

    // MARK: - Analysis

    /// Calculate DFA Alpha1 from RR intervals
    /// - Parameters:
    ///   - rrIntervals: Clean RR intervals in milliseconds
    ///   - config: Analysis configuration
    /// - Returns: DFA result or nil if insufficient data
    static func calculateAlpha1(
        rrIntervals: [Double],
        config: Configuration = .default
    ) -> DFAResult? {
        guard rrIntervals.count >= config.minIntervals else {
            logger.warning("Insufficient RR intervals for DFA: \(rrIntervals.count) < \(config.minIntervals)")
            return nil
        }

        logger.debug("Computing DFA Alpha1 for \(rrIntervals.count) RR intervals")

        // Step 1: Integrate the RR signal (cumulative sum of deviations from mean)
        let integratedSignal = integrateSignal(rrIntervals)

        // Step 2: Calculate fluctuations for each box size
        var boxSizes: [Int] = []
        var fluctuations: [Double] = []

        // Use box sizes from minBoxSize to maxBoxSize
        var boxSize = config.minBoxSize
        while boxSize <= min(config.maxBoxSize, rrIntervals.count / 4) {
            let fluctuation = calculateFluctuation(
                signal: integratedSignal,
                boxSize: boxSize
            )

            if fluctuation > 0 {
                boxSizes.append(boxSize)
                fluctuations.append(fluctuation)
            }

            boxSize += 1
        }

        guard boxSizes.count >= 3 else {
            logger.warning("Insufficient box sizes for regression: \(boxSizes.count)")
            return nil
        }

        // Step 3: Log-log regression to find alpha1 (slope)
        let (alpha1, rSquared) = logLogRegression(
            boxSizes: boxSizes,
            fluctuations: fluctuations
        )

        let interpretation = DFAInterpretation.from(alpha1: alpha1)

        logger.info("DFA Alpha1 = \(String(format: "%.3f", alpha1)), R² = \(String(format: "%.3f", rSquared)), Interpretation: \(interpretation.rawValue)")

        return DFAResult(
            alpha1: alpha1,
            interpretation: interpretation,
            boxSizes: boxSizes,
            fluctuations: fluctuations,
            rSquared: rSquared
        )
    }

    // MARK: - Integration

    /// Integrate the RR signal: y(k) = sum(RR(i) - RR_mean) for i = 1 to k
    private static func integrateSignal(_ rrIntervals: [Double]) -> [Double] {
        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)

        var integrated = [Double](repeating: 0, count: rrIntervals.count)
        var cumSum: Double = 0

        for i in 0..<rrIntervals.count {
            cumSum += rrIntervals[i] - mean
            integrated[i] = cumSum
        }

        return integrated
    }

    // MARK: - Fluctuation Calculation

    /// Calculate root mean square fluctuation for a given box size
    private static func calculateFluctuation(
        signal: [Double],
        boxSize: Int
    ) -> Double {
        let n = signal.count
        let numBoxes = n / boxSize

        guard numBoxes >= 1 else { return 0 }

        var totalFluctuation: Double = 0

        for boxIndex in 0..<numBoxes {
            let startIdx = boxIndex * boxSize
            let endIdx = min(startIdx + boxSize, n)

            // Extract box segment
            let segment = Array(signal[startIdx..<endIdx])

            // Detrend using linear regression (least squares fit)
            let trend = linearFit(segment)

            // Calculate fluctuation (RMS of residuals)
            var sumSquaredResiduals: Double = 0
            for (i, value) in segment.enumerated() {
                let residual = value - trend[i]
                sumSquaredResiduals += residual * residual
            }

            totalFluctuation += sumSquaredResiduals
        }

        // RMS fluctuation
        let meanFluctuation = totalFluctuation / Double(numBoxes * boxSize)
        return sqrt(meanFluctuation)
    }

    /// Linear fit for detrending
    private static func linearFit(_ segment: [Double]) -> [Double] {
        let n = Double(segment.count)
        guard n > 1 else { return segment }

        // Calculate linear regression coefficients
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (i, y) in segment.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else {
            // Return constant (mean) if no variation
            let mean = sumY / n
            return [Double](repeating: mean, count: segment.count)
        }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // Generate trend line
        return (0..<segment.count).map { Double($0) * slope + intercept }
    }

    // MARK: - Log-Log Regression

    /// Perform log-log linear regression to find scaling exponent
    private static func logLogRegression(
        boxSizes: [Int],
        fluctuations: [Double]
    ) -> (slope: Double, rSquared: Double) {
        let logN = boxSizes.map { log(Double($0)) }
        let logF = fluctuations.map { log($0) }

        let n = Double(logN.count)
        guard n > 1 else { return (1.0, 0) }

        let sumX = logN.reduce(0, +)
        let sumY = logF.reduce(0, +)
        let sumXY = zip(logN, logF).map { $0 * $1 }.reduce(0, +)
        let sumX2 = logN.map { $0 * $0 }.reduce(0, +)
        let sumY2 = logF.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return (1.0, 0) }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // Calculate R-squared
        let meanY = sumY / n
        var ssTotal: Double = 0
        var ssResidual: Double = 0

        for (i, y) in logF.enumerated() {
            ssTotal += (y - meanY) * (y - meanY)
            let predicted = slope * logN[i] + intercept
            ssResidual += (y - predicted) * (y - predicted)
        }

        let rSquared = ssTotal > 0 ? 1 - (ssResidual / ssTotal) : 0

        return (slope, max(0, rSquared))
    }
}
