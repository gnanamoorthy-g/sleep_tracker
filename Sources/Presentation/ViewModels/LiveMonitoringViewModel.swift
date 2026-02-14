import Foundation
import Combine
import os.log

@MainActor
final class LiveMonitoringViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var connectedPeripheral: BLEPeripheral?
    @Published private(set) var discoveredPeripherals: [BLEPeripheral] = []
    @Published private(set) var heartRate: Int?
    @Published private(set) var latestRRInterval: Double?
    @Published private(set) var rmssd: Double?
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var sampleCount = 0

    // Sleep tracking
    @Published private(set) var currentEpochs: [SleepEpoch] = []
    @Published private(set) var sleepSummary: SleepSummary?

    // MARK: - Dependencies
    let bleManager: BLEManager
    private let hrvEngine: HRVEngine
    private let epochAggregator: SleepEpochAggregator
    private let repository: SleepSessionRepository

    // MARK: - Private Properties
    private var currentSession: SleepSession?
    private var baseline: SleepInferenceEngine.Baseline = .default
    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private let logger = Logger(subsystem: "com.sleeptracker", category: "ViewModel")

    // MARK: - Initialization
    init(bleManager: BLEManager = BLEManager(),
         hrvEngine: HRVEngine = HRVEngine(),
         epochAggregator: SleepEpochAggregator = SleepEpochAggregator(),
         repository: SleepSessionRepository = SleepSessionRepository()) {
        self.bleManager = bleManager
        self.hrvEngine = hrvEngine
        self.epochAggregator = epochAggregator
        self.repository = repository

        setupBindings()
    }

    // MARK: - Public Methods
    func startScanning() {
        bleManager.startScanning()
    }

    func stopScanning() {
        bleManager.stopScanning()
    }

    func connect(to peripheral: BLEPeripheral) {
        bleManager.connect(to: peripheral)
    }

    func disconnect() {
        if isRecording {
            stopRecording()
        }
        bleManager.disconnect()
    }

    func startRecording() {
        guard !isRecording else { return }

        currentSession = SleepSession()
        hrvEngine.reset()
        epochAggregator.reset()
        currentEpochs.removeAll()
        sleepSummary = nil

        isRecording = true
        recordingDuration = 0
        sampleCount = 0

        // Start timer for duration tracking
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }

        logger.info("Recording started")
    }

    func stopRecording() {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        // Force complete any pending epoch
        epochAggregator.forceCompleteEpoch()

        // Calculate sleep summary
        calculateSleepSummary()

        if var session = currentSession {
            session.end()

            // Save session
            do {
                try repository.save(session)
                logger.info("Session saved with \(session.samples.count) samples")
            } catch {
                logger.error("Failed to save session: \(error.localizedDescription)")
            }
        }

        currentSession = nil
        isRecording = false

        logger.info("Recording stopped")
    }

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Bind connection state
        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        // Bind connected peripheral
        bleManager.$connectedPeripheral
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedPeripheral)

        // Bind discovered peripherals
        bleManager.$discoveredPeripherals
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredPeripherals)

        // Process heart rate data
        bleManager.heartRateDataPublisher
            .compactMap { HeartRateParser.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                self?.processPacket(packet)
            }
            .store(in: &cancellables)

        // Process epochs from aggregator
        epochAggregator.epochPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] epoch in
                self?.processEpoch(epoch)
            }
            .store(in: &cancellables)
    }

    private func processPacket(_ packet: HeartRatePacket) {
        // Update UI values
        heartRate = packet.heartRate
        latestRRInterval = packet.latestRRInterval

        // Add to HRV engine and compute metrics
        if !packet.rrIntervals.isEmpty {
            hrvEngine.addRRIntervals(packet.rrIntervals, timestamp: packet.timestamp)
            rmssd = hrvEngine.computeRMSSD()
        }

        // Record sample if recording
        if isRecording {
            let sample = HRVSample(from: packet, rmssd: rmssd)
            currentSession?.addSample(sample)
            sampleCount = currentSession?.samples.count ?? 0

            // Feed to epoch aggregator
            epochAggregator.addSample(
                heartRate: packet.heartRate,
                rrIntervals: packet.rrIntervals,
                rmssd: rmssd,
                timestamp: packet.timestamp
            )
        }
    }

    private func processEpoch(_ epoch: SleepEpoch) {
        // Update baseline after first few epochs
        if currentEpochs.count == 10 {
            baseline = SleepInferenceEngine.calculateBaseline(from: currentEpochs)
        }

        // Classify the epoch
        let classifiedEpoch = SleepInferenceEngine.classifyEpoch(epoch, baseline: baseline)
        currentEpochs.append(classifiedEpoch)

        logger.debug("Epoch added: phase=\(classifiedEpoch.phase?.rawValue ?? "nil")")
    }

    private func calculateSleepSummary() {
        guard !currentEpochs.isEmpty else { return }

        sleepSummary = SleepScoreCalculator.calculateScore(
            from: currentEpochs,
            baselineRMSSD: baseline.rmssd
        )
    }
}
