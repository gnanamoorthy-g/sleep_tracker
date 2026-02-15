import Foundation
import Combine
import os.log

/// Overnight Worker for continuous HRV processing
/// Runs every 5 minutes to process RR data, compute HRV, and detect sleep phases
final class OvernightWorker: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published private(set) var lastProcessedTime: Date?
    @Published private(set) var currentTimeslice: HRVTimeslice?
    @Published private(set) var detectedPhase: SleepPhase = .awake

    // MARK: - Configuration

    struct Configuration {
        /// Processing interval (default: 5 minutes)
        let processingInterval: TimeInterval = 300  // 5 minutes

        /// Minimum RR intervals needed for valid HRV calculation
        let minIntervalsPerSlice: Int = 30

        /// Window size for RR data to pull (slightly longer than interval)
        let rrWindowDuration: TimeInterval = 330  // 5.5 minutes

        static let `default` = Configuration()
    }

    // MARK: - Timeslice Result

    struct HRVTimeslice: Identifiable {
        let id = UUID()
        let timestamp: Date
        let windowStart: Date
        let windowEnd: Date

        // Time domain metrics
        let rmssd: Double
        let sdnn: Double
        let pnn50: Double

        // Frequency domain metrics (if available)
        let lfPower: Double?
        let hfPower: Double?
        let lfHfRatio: Double?

        // DFA (if available)
        let dfaAlpha1: Double?

        // Heart rate stats
        let averageHR: Double
        let minHR: Double
        let maxHR: Double

        // Quality metrics
        let sampleCount: Int
        let qualityScore: Double

        // Inferred state
        let phase: SleepPhase
        let isParasympatheticDominant: Bool
        let isDeepSleepWindow: Bool
    }

    // MARK: - Properties

    private let config: Configuration
    private let logger = Logger(subsystem: "com.sleeptracker", category: "OvernightWorker")
    private var processingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Data buffers
    private var rrBuffer: [(timestamp: Date, interval: Double)] = []
    private var hrBuffer: [(timestamp: Date, hr: Double)] = []
    private var timeslices: [HRVTimeslice] = []

    // Callbacks
    var onTimesliceProcessed: ((HRVTimeslice) -> Void)?
    var onPhaseChange: ((SleepPhase) -> Void)?
    var onDeepSleepDetected: (() -> Void)?

    // Baseline references
    private var wakingBaselineHR: Double?
    private var wakingBaselineRMSSD: Double?

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Start the overnight worker
    func start() {
        guard !isRunning else {
            logger.info("Overnight worker already running")
            return
        }

        isRunning = true
        timeslices.removeAll()

        // Start processing timer
        processingTimer = Timer.scheduledTimer(
            withTimeInterval: config.processingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.processCurrentWindow()
        }

        logger.info("Overnight worker started - processing every \(Int(config.processingInterval))s")
    }

    /// Stop the overnight worker
    func stop() {
        processingTimer?.invalidate()
        processingTimer = nil
        isRunning = false

        logger.info("Overnight worker stopped. Processed \(timeslices.count) timeslices.")
    }

    /// Add RR interval data to the buffer
    func addRRIntervals(_ intervals: [Double], timestamp: Date = Date()) {
        for interval in intervals {
            rrBuffer.append((timestamp: timestamp, interval: interval))
        }

        // Trim old data (keep last 10 minutes)
        let cutoff = Date().addingTimeInterval(-600)
        rrBuffer.removeAll { $0.timestamp < cutoff }
    }

    /// Add heart rate sample to the buffer
    func addHeartRate(_ hr: Double, timestamp: Date = Date()) {
        hrBuffer.append((timestamp: timestamp, hr: hr))

        // Trim old data
        let cutoff = Date().addingTimeInterval(-600)
        hrBuffer.removeAll { $0.timestamp < cutoff }
    }

    /// Set waking baselines for comparison
    func setWakingBaselines(hr: Double, rmssd: Double) {
        wakingBaselineHR = hr
        wakingBaselineRMSSD = rmssd
        logger.info("Waking baselines set - HR: \(hr), RMSSD: \(rmssd)")
    }

    /// Get all processed timeslices
    var processedTimeslices: [HRVTimeslice] {
        timeslices
    }

    /// Get overnight summary statistics
    func getOvernightSummary() -> OvernightSummary? {
        guard !timeslices.isEmpty else { return nil }

        let rmssdValues = timeslices.map { $0.rmssd }
        let hrValues = timeslices.map { $0.averageHR }

        let deepSlices = timeslices.filter { $0.isDeepSleepWindow }
        let parasympatheticSlices = timeslices.filter { $0.isParasympatheticDominant }

        return OvernightSummary(
            totalTimeslices: timeslices.count,
            averageRMSSD: rmssdValues.reduce(0, +) / Double(rmssdValues.count),
            maxRMSSD: rmssdValues.max() ?? 0,
            minRMSSD: rmssdValues.min() ?? 0,
            averageHR: hrValues.reduce(0, +) / Double(hrValues.count),
            minHR: hrValues.min() ?? 0,
            deepSleepWindowCount: deepSlices.count,
            parasympatheticDominantCount: parasympatheticSlices.count,
            recoveryIntensityCurve: calculateRecoveryIntensityCurve()
        )
    }

    struct OvernightSummary {
        let totalTimeslices: Int
        let averageRMSSD: Double
        let maxRMSSD: Double
        let minRMSSD: Double
        let averageHR: Double
        let minHR: Double
        let deepSleepWindowCount: Int
        let parasympatheticDominantCount: Int
        let recoveryIntensityCurve: [Double]  // Normalized RMSSD over time
    }

    // MARK: - Processing

    private func processCurrentWindow() {
        let now = Date()
        let windowStart = now.addingTimeInterval(-config.rrWindowDuration)

        logger.debug("Processing window: \(windowStart) to \(now)")

        // Get RR intervals in window
        let windowIntervals = rrBuffer
            .filter { $0.timestamp >= windowStart && $0.timestamp <= now }
            .map { $0.interval }

        // Get HR samples in window
        let windowHR = hrBuffer
            .filter { $0.timestamp >= windowStart && $0.timestamp <= now }
            .map { $0.hr }

        guard windowIntervals.count >= config.minIntervalsPerSlice else {
            logger.debug("Insufficient RR intervals: \(windowIntervals.count)")
            return
        }

        // Step 1: Clean RR intervals
        let processedRR = RRIntervalProcessor.process(windowIntervals)

        guard processedRR.isValid else {
            logger.debug("RR data quality insufficient")
            return
        }

        // Step 2: Compute time domain metrics
        guard let rmssd = HRVEngine.computeRMSSD(from: processedRR.cleanIntervals),
              let sdnn = HRVEngine.computeSDNN(from: processedRR.cleanIntervals),
              let pnn50 = HRVEngine.computePNN50(from: processedRR.cleanIntervals) else {
            logger.warning("Failed to compute time domain metrics")
            return
        }

        // Step 3: Compute frequency domain metrics (if enough data)
        let freqMetrics = FrequencyDomainAnalyzer.analyze(rrIntervals: processedRR.cleanIntervals)

        // Step 4: Compute DFA Alpha1 (if enough data)
        let dfaResult = DFAAnalyzer.calculateAlpha1(rrIntervals: processedRR.cleanIntervals)

        // Step 5: Calculate HR stats
        let avgHR: Double
        let minHR: Double
        let maxHR: Double

        if !windowHR.isEmpty {
            avgHR = windowHR.reduce(0, +) / Double(windowHR.count)
            minHR = windowHR.min() ?? avgHR
            maxHR = windowHR.max() ?? avgHR
        } else {
            // Estimate from RR intervals
            let avgRR = processedRR.cleanIntervals.reduce(0, +) / Double(processedRR.cleanIntervals.count)
            avgHR = 60000 / avgRR
            minHR = 60000 / (processedRR.cleanIntervals.max() ?? avgRR)
            maxHR = 60000 / (processedRR.cleanIntervals.min() ?? avgRR)
        }

        // Step 6: Determine phase and recovery state
        let phase = inferSleepPhase(
            rmssd: rmssd,
            avgHR: avgHR,
            lfHfRatio: freqMetrics?.lfHfRatio
        )

        let isParasympatheticDominant = detectParasympatheticDominance(
            rmssd: rmssd,
            lfHfRatio: freqMetrics?.lfHfRatio
        )

        let isDeepSleepWindow = detectDeepSleepWindow(
            rmssd: rmssd,
            avgHR: avgHR,
            hfPower: freqMetrics?.hfPower
        )

        // Create timeslice
        let timeslice = HRVTimeslice(
            timestamp: now,
            windowStart: windowStart,
            windowEnd: now,
            rmssd: rmssd,
            sdnn: sdnn,
            pnn50: pnn50,
            lfPower: freqMetrics?.lfPower,
            hfPower: freqMetrics?.hfPower,
            lfHfRatio: freqMetrics?.lfHfRatio,
            dfaAlpha1: dfaResult?.alpha1,
            averageHR: avgHR,
            minHR: minHR,
            maxHR: maxHR,
            sampleCount: processedRR.cleanIntervals.count,
            qualityScore: processedRR.qualityScore,
            phase: phase,
            isParasympatheticDominant: isParasympatheticDominant,
            isDeepSleepWindow: isDeepSleepWindow
        )

        // Store and notify
        timeslices.append(timeslice)
        currentTimeslice = timeslice
        lastProcessedTime = now

        // Check for phase change
        if phase != detectedPhase {
            let oldPhase = detectedPhase
            detectedPhase = phase
            onPhaseChange?(phase)
            logger.info("Phase changed: \(oldPhase.rawValue) -> \(phase.rawValue)")
        }

        // Notify deep sleep detection
        if isDeepSleepWindow {
            onDeepSleepDetected?()
        }

        onTimesliceProcessed?(timeslice)

        logger.info("Timeslice processed: RMSSD=\(String(format: "%.1f", rmssd)), HR=\(String(format: "%.0f", avgHR)), Phase=\(phase.rawValue)")
    }

    // MARK: - Detection Helpers

    private func inferSleepPhase(
        rmssd: Double,
        avgHR: Double,
        lfHfRatio: Double?
    ) -> SleepPhase {
        guard let baselineHR = wakingBaselineHR,
              let baselineRMSSD = wakingBaselineRMSSD else {
            return .light  // Default to light if no baseline
        }

        let hrRatio = avgHR / baselineHR
        let rmssdRatio = rmssd / baselineRMSSD

        // Deep sleep: HR in lowest range, RMSSD elevated, HF power high
        if hrRatio < 0.85 && rmssdRatio > 1.15 {
            return .deep
        }

        // REM: HR variable, RMSSD moderate, LF/HF elevated
        if let lfhf = lfHfRatio, lfhf > 2.0 && rmssdRatio < 1.1 && rmssdRatio > 0.9 {
            return .rem
        }

        // Awake: HR elevated, RMSSD suppressed
        if hrRatio > 0.95 && rmssdRatio < 0.9 {
            return .awake
        }

        // Default to light sleep
        return .light
    }

    private func detectParasympatheticDominance(
        rmssd: Double,
        lfHfRatio: Double?
    ) -> Bool {
        guard let baselineRMSSD = wakingBaselineRMSSD else {
            return rmssd > 50  // Default threshold if no baseline
        }

        let rmssdElevated = rmssd > baselineRMSSD * 1.10
        let lfhfLow = lfHfRatio.map { $0 < 1.0 } ?? true

        return rmssdElevated && lfhfLow
    }

    private func detectDeepSleepWindow(
        rmssd: Double,
        avgHR: Double,
        hfPower: Double?
    ) -> Bool {
        guard let baselineHR = wakingBaselineHR,
              let baselineRMSSD = wakingBaselineRMSSD else {
            return false
        }

        // Deep sleep validation:
        // - HR in lowest 20% (< 80% of baseline)
        // - RMSSD in top 25% (> 125% of baseline)
        // - HF power elevated
        let hrLow = avgHR < baselineHR * 0.80
        let rmssdHigh = rmssd > baselineRMSSD * 1.25

        return hrLow && rmssdHigh
    }

    private func calculateRecoveryIntensityCurve() -> [Double] {
        guard !timeslices.isEmpty else { return [] }

        let maxRMSSD = timeslices.map { $0.rmssd }.max() ?? 1
        return timeslices.map { $0.rmssd / maxRMSSD }
    }
}
