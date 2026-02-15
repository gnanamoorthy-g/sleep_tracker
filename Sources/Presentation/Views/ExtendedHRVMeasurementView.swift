import SwiftUI
import Combine

/// Extended HRV measurement for frequency domain (LF/HF) and DFA Alpha1 analysis
/// Requires 3+ minutes of continuous heart rate data
struct ExtendedHRVMeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExtendedHRVViewModel()
    var onComplete: ((FullHRVMetrics) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 48))
                        .foregroundColor(.purple)

                    Text("Extended HRV Analysis")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("3-minute measurement for advanced metrics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Progress
                VStack(spacing: 12) {
                    // Timer
                    Text(viewModel.formattedTime)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    // Progress bar
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .scaleEffect(y: 2)

                    Text("\(viewModel.rrIntervalsCollected) heartbeats collected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Current HR
                if let hr = viewModel.currentHR {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(Int(hr)) bpm")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Status
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Action Button
                if viewModel.isComplete {
                    Button(action: {
                        if let metrics = viewModel.computedMetrics {
                            onComplete?(metrics)
                        }
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Results")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Results preview
                    if let metrics = viewModel.computedMetrics {
                        ResultsPreview(metrics: metrics)
                    }
                } else if viewModel.isRecording {
                    Button(action: { viewModel.stop() }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: { viewModel.start() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Measurement")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }
}

private struct ResultsPreview: View {
    let metrics: FullHRVMetrics

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                MetricPreviewItem(label: "RMSSD", value: String(format: "%.1f", metrics.time.rmssd), unit: "ms")
                MetricPreviewItem(label: "pNN50", value: String(format: "%.1f", metrics.time.pnn50), unit: "%")
                if let freq = metrics.freq {
                    MetricPreviewItem(label: "LF/HF", value: String(format: "%.2f", freq.lfHfRatio), unit: "")
                }
                if let dfa = metrics.dfaAlpha1 {
                    MetricPreviewItem(label: "DFA α1", value: String(format: "%.2f", dfa), unit: "")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct MetricPreviewItem: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ExtendedHRVViewModel: ObservableObject {
    @Published var elapsedSeconds: Int = 0
    @Published var rrIntervalsCollected: Int = 0
    @Published var currentHR: Double?
    @Published var isRecording = false
    @Published var isComplete = false
    @Published var computedMetrics: FullHRVMetrics?

    private let targetDuration = 180 // 3 minutes
    private let minRRIntervals = 100
    private var rrIntervals: [Double] = []
    private var timerCancellable: AnyCancellable?
    private var hrCancellable: AnyCancellable?
    private let bleManager = BLEManager.shared

    var progress: Double {
        Double(elapsedSeconds) / Double(targetDuration)
    }

    var formattedTime: String {
        let remaining = max(0, targetDuration - elapsedSeconds)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var statusMessage: String {
        if isComplete {
            return "Measurement complete! Review your results below."
        } else if isRecording {
            return "Stay still and breathe normally. Avoid talking or moving."
        } else {
            return "Sit comfortably in a quiet place. The measurement will take 3 minutes."
        }
    }

    func start() {
        isRecording = true
        isComplete = false
        elapsedSeconds = 0
        rrIntervals = []
        rrIntervalsCollected = 0

        // Subscribe to heart rate data which includes RR intervals
        hrCancellable = bleManager.heartRateDataPublisher
            .compactMap { HeartRateParser.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                guard let self = self, self.isRecording else { return }

                // Extract RR intervals from packet
                let rrIntervalsMs = packet.rrIntervals.map { Double($0) }
                self.rrIntervals.append(contentsOf: rrIntervalsMs)
                self.rrIntervalsCollected = self.rrIntervals.count
                self.currentHR = Double(packet.heartRate)
            }

        // Timer
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.targetDuration {
                    self.complete()
                }
            }
    }

    func stop() {
        timerCancellable?.cancel()
        hrCancellable?.cancel()
        isRecording = false
    }

    private func complete() {
        stop()

        // Process RR intervals
        let processed = RRIntervalProcessor.process(rrIntervals)
        guard processed.isValid else {
            isComplete = true
            return
        }

        // Calculate time domain
        let rmssd = calculateRMSSD(processed.cleanIntervals)
        let sdnn = calculateSDNN(processed.cleanIntervals)
        let pnn50 = calculatePNN50(processed.cleanIntervals)

        let timeDomain = HRVTimeDomain(rmssd: rmssd, sdnn: sdnn, pnn50: pnn50)

        // Calculate frequency domain
        let freqMetrics = FrequencyDomainAnalyzer.analyze(rrIntervals: processed.cleanIntervals)
        let freqDomain = freqMetrics.map {
            HRVFrequencyDomain(lfPower: $0.lfPower, hfPower: $0.hfPower, lfHfRatio: $0.lfHfRatio)
        }

        // Calculate DFA Alpha1
        let dfaResult = DFAAnalyzer.calculateAlpha1(rrIntervals: processed.cleanIntervals)
        let dfaAlpha1 = dfaResult?.alpha1

        computedMetrics = FullHRVMetrics(
            time: timeDomain,
            freq: freqDomain,
            dfaAlpha1: dfaAlpha1,
            sampleCount: processed.cleanIntervals.count,
            qualityScore: processed.qualityScore
        )

        // Save to repository
        saveMetrics()

        isComplete = true
    }

    private func saveMetrics() {
        guard let metrics = computedMetrics else { return }

        let snapshot = HRVSnapshot(
            duration: TimeInterval(elapsedSeconds),
            measurementMode: .snapshot,
            averageHR: currentHR ?? 60,
            minHR: currentHR ?? 60,
            maxHR: currentHR ?? 60,
            rmssd: metrics.time.rmssd,
            sdnn: metrics.time.sdnn,
            pnn50: metrics.time.pnn50
        )

        let repository = HRVSnapshotRepository()
        repository.save(snapshot)

        // Also save extended metrics
        let extendedRepo = ExtendedHRVMetricsRepository()
        extendedRepo.save(metrics, for: Date())
    }

    // MARK: - Calculations

    private func calculateRMSSD(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 0 }
        var sumSquaredDiffs: Double = 0
        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i - 1]
            sumSquaredDiffs += diff * diff
        }
        return sqrt(sumSquaredDiffs / Double(intervals.count - 1))
    }

    private func calculateSDNN(_ intervals: [Double]) -> Double {
        guard !intervals.isEmpty else { return 0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        return sqrt(variance)
    }

    private func calculatePNN50(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 0 }
        var countOver50 = 0
        for i in 1..<intervals.count {
            if abs(intervals[i] - intervals[i - 1]) > 50 {
                countOver50 += 1
            }
        }
        return Double(countOver50) / Double(intervals.count - 1) * 100
    }
}

// MARK: - Extended Metrics Repository

final class ExtendedHRVMetricsRepository {
    private let storageKey = "extended_hrv_metrics"

    func save(_ metrics: FullHRVMetrics, for date: Date) {
        var allMetrics = loadAll()
        allMetrics[dateKey(date)] = metrics
        saveAll(allMetrics)
    }

    func load(for date: Date) -> FullHRVMetrics? {
        loadAll()[dateKey(date)]
    }

    private func loadAll() -> [String: FullHRVMetrics] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let metrics = try? JSONDecoder().decode([String: FullHRVMetrics].self, from: data) else {
            return [:]
        }
        return metrics
    }

    private func saveAll(_ metrics: [String: FullHRVMetrics]) {
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
