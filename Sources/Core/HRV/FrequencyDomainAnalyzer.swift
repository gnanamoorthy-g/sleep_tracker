import Foundation
import Accelerate
import os.log

/// Frequency Domain HRV Analysis using Welch's PSD method
struct FrequencyDomainAnalyzer {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "FreqDomain")

    // MARK: - Frequency Bands (Hz)

    struct FrequencyBands {
        static let lfLow: Double = 0.04   // Low Frequency lower bound
        static let lfHigh: Double = 0.15  // Low Frequency upper bound
        static let hfLow: Double = 0.15   // High Frequency lower bound
        static let hfHigh: Double = 0.40  // High Frequency upper bound
    }

    // MARK: - Configuration

    struct Configuration {
        /// Resampling frequency for evenly spaced intervals (Hz)
        let resamplingFrequency: Double = 4.0

        /// Window size for Welch's method (samples)
        let windowSize: Int = 256

        /// Overlap ratio for Welch's method (0-1)
        let overlapRatio: Double = 0.5

        static let `default` = Configuration()
    }

    // MARK: - Result

    struct FrequencyDomainMetrics {
        /// Low Frequency power (0.04-0.15 Hz) - Sympathetic + Parasympathetic
        let lfPower: Double

        /// High Frequency power (0.15-0.40 Hz) - Parasympathetic (vagal)
        let hfPower: Double

        /// LF/HF Ratio - Sympathovagal balance indicator
        let lfHfRatio: Double

        /// Total power (LF + HF)
        let totalPower: Double

        /// Normalized LF power (%)
        var lfNormalized: Double {
            guard totalPower > 0 else { return 0 }
            return (lfPower / totalPower) * 100
        }

        /// Normalized HF power (%)
        var hfNormalized: Double {
            guard totalPower > 0 else { return 0 }
            return (hfPower / totalPower) * 100
        }

        /// Interpretation of LF/HF ratio
        var interpretation: LFHFInterpretation {
            LFHFInterpretation.from(ratio: lfHfRatio)
        }
    }

    enum LFHFInterpretation: String {
        case parasympatheticDominant = "Parasympathetic Dominant"
        case balanced = "Balanced"
        case sympatheticDominant = "Sympathetic Dominant"
        case highlyStressed = "Highly Stressed"

        static func from(ratio: Double) -> LFHFInterpretation {
            switch ratio {
            case ..<0.5:
                return .parasympatheticDominant
            case 0.5..<2.0:
                return .balanced
            case 2.0..<4.0:
                return .sympatheticDominant
            default:
                return .highlyStressed
            }
        }
    }

    // MARK: - Analysis

    /// Compute frequency domain metrics from RR intervals
    /// - Parameters:
    ///   - rrIntervals: Clean RR intervals in milliseconds
    ///   - config: Analysis configuration
    /// - Returns: Frequency domain metrics or nil if insufficient data
    static func analyze(
        rrIntervals: [Double],
        config: Configuration = .default
    ) -> FrequencyDomainMetrics? {
        guard rrIntervals.count >= config.windowSize else {
            logger.warning("Insufficient RR intervals for frequency analysis: \(rrIntervals.count) < \(config.windowSize)")
            return nil
        }

        logger.debug("Analyzing \(rrIntervals.count) RR intervals for frequency domain")

        // Step 1: Resample RR intervals to evenly spaced time series (4 Hz)
        let resampledSignal = resampleRRIntervals(
            rrIntervals,
            targetFrequency: config.resamplingFrequency
        )

        guard resampledSignal.count >= config.windowSize else {
            logger.warning("Resampled signal too short: \(resampledSignal.count)")
            return nil
        }

        // Step 2: Apply Hamming window
        let windowedSignal = applyHammingWindow(to: resampledSignal)

        // Step 3: Compute PSD using Welch's method
        let (frequencies, psd) = computeWelchPSD(
            signal: windowedSignal,
            samplingFrequency: config.resamplingFrequency,
            windowSize: config.windowSize,
            overlapRatio: config.overlapRatio
        )

        guard !psd.isEmpty else {
            logger.error("PSD computation failed")
            return nil
        }

        // Step 4: Integrate power in frequency bands
        let lfPower = integratePower(
            frequencies: frequencies,
            psd: psd,
            lowFreq: FrequencyBands.lfLow,
            highFreq: FrequencyBands.lfHigh
        )

        let hfPower = integratePower(
            frequencies: frequencies,
            psd: psd,
            lowFreq: FrequencyBands.hfLow,
            highFreq: FrequencyBands.hfHigh
        )

        // Step 5: Calculate LF/HF ratio
        let lfHfRatio = hfPower > 0 ? lfPower / hfPower : 0

        logger.info("Frequency analysis complete - LF: \(String(format: "%.2f", lfPower)), HF: \(String(format: "%.2f", hfPower)), Ratio: \(String(format: "%.2f", lfHfRatio))")

        return FrequencyDomainMetrics(
            lfPower: lfPower,
            hfPower: hfPower,
            lfHfRatio: lfHfRatio,
            totalPower: lfPower + hfPower
        )
    }

    // MARK: - Resampling

    /// Resample RR intervals to evenly spaced time series using linear interpolation
    private static func resampleRRIntervals(
        _ intervals: [Double],
        targetFrequency: Double
    ) -> [Double] {
        guard intervals.count >= 2 else { return [] }

        // Build cumulative time array (in seconds)
        var cumulativeTime: [Double] = [0]
        for interval in intervals {
            cumulativeTime.append(cumulativeTime.last! + interval / 1000.0)
        }

        let totalDuration = cumulativeTime.last!
        let sampleInterval = 1.0 / targetFrequency
        var resampledTime: [Double] = []
        var t = 0.0
        while t < totalDuration {
            resampledTime.append(t)
            t += sampleInterval
        }

        // Interpolate RR values at resampled times
        var resampledValues: [Double] = []
        for time in resampledTime {
            // Find surrounding original samples
            var lowerIndex = 0
            for i in 0..<cumulativeTime.count - 1 {
                if cumulativeTime[i] <= time && cumulativeTime[i + 1] > time {
                    lowerIndex = i
                    break
                }
            }

            // Linear interpolation
            if lowerIndex < intervals.count {
                let t0 = cumulativeTime[lowerIndex]
                let t1 = cumulativeTime[lowerIndex + 1]
                let v0 = intervals[lowerIndex]
                let v1 = lowerIndex + 1 < intervals.count ? intervals[lowerIndex + 1] : v0

                let alpha = (time - t0) / (t1 - t0)
                let value = v0 + alpha * (v1 - v0)
                resampledValues.append(value)
            }
        }

        // Remove mean (detrend)
        let mean = resampledValues.reduce(0, +) / Double(resampledValues.count)
        return resampledValues.map { $0 - mean }
    }

    // MARK: - Hamming Window

    /// Apply Hamming window to signal
    private static func applyHammingWindow(to signal: [Double]) -> [Double] {
        let n = signal.count
        var windowed = [Double](repeating: 0, count: n)

        for i in 0..<n {
            let w = 0.54 - 0.46 * cos(2.0 * Double.pi * Double(i) / Double(n - 1))
            windowed[i] = signal[i] * w
        }

        return windowed
    }

    // MARK: - Welch PSD

    /// Compute Power Spectral Density using Welch's method
    private static func computeWelchPSD(
        signal: [Double],
        samplingFrequency: Double,
        windowSize: Int,
        overlapRatio: Double
    ) -> (frequencies: [Double], psd: [Double]) {
        let hopSize = Int(Double(windowSize) * (1 - overlapRatio))
        let numSegments = (signal.count - windowSize) / hopSize + 1

        guard numSegments > 0 else { return ([], []) }

        // FFT setup
        let fftSize = windowSize
        let log2n = vDSP_Length(log2(Double(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var accumulatedPSD = [Double](repeating: 0, count: fftSize / 2)

        for seg in 0..<numSegments {
            let startIdx = seg * hopSize
            let segment = Array(signal[startIdx..<min(startIdx + windowSize, signal.count)])

            guard segment.count == windowSize else { continue }

            // Apply Hamming window to segment
            let windowedSegment = applyHammingWindow(to: segment)

            // Perform FFT
            var real = windowedSegment
            var imaginary = [Double](repeating: 0, count: windowSize)

            var splitComplex = DSPDoubleSplitComplex(
                realp: &real,
                imagp: &imaginary
            )

            // Convert to split complex format
            var combined = [Double](repeating: 0, count: windowSize * 2)
            for i in 0..<windowSize {
                combined[2 * i] = windowedSegment[i]
                combined[2 * i + 1] = 0
            }

            combined.withUnsafeBufferPointer { ptr in
                vDSP_ctozD(
                    UnsafePointer<DSPDoubleComplex>(OpaquePointer(ptr.baseAddress!)),
                    2,
                    &splitComplex,
                    1,
                    vDSP_Length(windowSize)
                )
            }

            // Forward FFT
            vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Calculate magnitude squared (power spectrum)
            for i in 0..<fftSize / 2 {
                let power = real[i] * real[i] + imaginary[i] * imaginary[i]
                accumulatedPSD[i] += power
            }
        }

        // Average PSD and normalize
        let scaleFactor = 1.0 / (Double(numSegments) * Double(windowSize) * samplingFrequency)
        var psd = accumulatedPSD.map { $0 * scaleFactor }

        // Calculate frequency bins
        var frequencies = [Double]()
        for i in 0..<fftSize / 2 {
            frequencies.append(Double(i) * samplingFrequency / Double(fftSize))
        }

        return (frequencies, psd)
    }

    // MARK: - Power Integration

    /// Integrate power in a frequency band using trapezoidal rule
    private static func integratePower(
        frequencies: [Double],
        psd: [Double],
        lowFreq: Double,
        highFreq: Double
    ) -> Double {
        guard frequencies.count == psd.count && !frequencies.isEmpty else { return 0 }

        var power: Double = 0
        let df = frequencies.count > 1 ? frequencies[1] - frequencies[0] : 1.0

        for i in 0..<frequencies.count {
            if frequencies[i] >= lowFreq && frequencies[i] <= highFreq {
                power += psd[i] * df
            }
        }

        return power
    }
}
