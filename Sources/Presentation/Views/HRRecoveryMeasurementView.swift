import SwiftUI
import Combine

/// View for measuring Heart Rate Recovery after exercise
/// HRR = Peak HR - HR after 1 minute of rest
struct HRRecoveryMeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HRRecoveryViewModel()
    var onComplete: ((Double) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text("HR Recovery Measurement")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Measure how quickly your heart rate drops after exercise")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                Divider()

                // Measurement Steps
                switch viewModel.phase {
                case .instructions:
                    InstructionsPhase(onStart: {
                        viewModel.startPeakCapture()
                    })

                case .capturingPeak:
                    CapturingPeakPhase(
                        currentHR: viewModel.currentHR,
                        peakHR: viewModel.peakHR,
                        onConfirmPeak: {
                            viewModel.confirmPeakHR()
                        }
                    )

                case .recovery:
                    RecoveryPhase(
                        peakHR: viewModel.peakHR ?? 0,
                        currentHR: viewModel.currentHR,
                        timeRemaining: viewModel.recoveryTimeRemaining,
                        onCancel: {
                            viewModel.cancel()
                        }
                    )

                case .complete:
                    CompletePhase(
                        peakHR: viewModel.peakHR ?? 0,
                        recoveryHR: viewModel.recoveryHR ?? 0,
                        hrRecovery: viewModel.calculatedHRR ?? 0,
                        onSave: {
                            if let hrr = viewModel.calculatedHRR {
                                onComplete?(hrr)
                                viewModel.save()
                            }
                            dismiss()
                        }
                    )
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.startMonitoring()
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
        }
    }
}

// MARK: - Instructions Phase

private struct InstructionsPhase: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Complete your exercise session")
                InstructionRow(number: 2, text: "At peak exertion, tap \"Capture Peak HR\"")
                InstructionRow(number: 3, text: "Stop exercising immediately and stand still")
                InstructionRow(number: 4, text: "Wait 60 seconds for recovery measurement")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Text("A good HRR is 25+ bpm drop in 1 minute")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Measurement")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top)
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

// MARK: - Capturing Peak Phase

private struct CapturingPeakPhase: View {
    let currentHR: Double?
    let peakHR: Double?
    var onConfirmPeak: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Continue exercising at peak intensity")
                .font(.headline)
                .foregroundColor(.orange)

            // Current HR Display
            VStack(spacing: 8) {
                Text("Current Heart Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currentHR.map { String(Int($0)) } ?? "--")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.red)

                    Text("bpm")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            if let peak = peakHR {
                Text("Peak captured: \(Int(peak)) bpm")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

            // Pulsing indicator
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                )
                .scaleEffect(currentHR != nil ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: currentHR)

            Button(action: onConfirmPeak) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Capture Peak HR & Start Recovery")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Recovery Phase

private struct RecoveryPhase: View {
    let peakHR: Double
    let currentHR: Double?
    let timeRemaining: Int
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("STOP EXERCISING - Stand Still")
                .font(.headline)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)

            // Timer
            VStack(spacing: 8) {
                Text("Time Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(timeRemaining)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)

                Text("seconds")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / 60.0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timeRemaining)
            }
            .frame(width: 120, height: 120)

            // HR Info
            HStack(spacing: 32) {
                VStack {
                    Text("Peak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(peakHR))")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                VStack {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentHR.map { String(Int($0)) } ?? "--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }

                VStack {
                    Text("Drop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let current = currentHR {
                        Text("\(Int(peakHR - current))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Complete Phase

private struct CompletePhase: View {
    let peakHR: Double
    let recoveryHR: Double
    let hrRecovery: Double
    var onSave: () -> Void

    private var interpretation: (text: String, color: Color) {
        switch hrRecovery {
        case 40...:
            return ("Excellent recovery capacity", .green)
        case 25..<40:
            return ("Good parasympathetic reactivation", .green)
        case 15..<25:
            return ("Moderate - may indicate fatigue", .yellow)
        default:
            return ("Below optimal - prioritize recovery", .red)
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Measurement Complete")
                .font(.title2)
                .fontWeight(.bold)

            // Result Card
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("HR Recovery")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(hrRecovery))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(interpretation.color)

                        Text("bpm/min")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Text(interpretation.text)
                    .font(.subheadline)
                    .foregroundColor(interpretation.color)

                Divider()

                HStack(spacing: 32) {
                    VStack {
                        Text("Peak HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(peakHR))")
                            .font(.headline)
                    }

                    VStack {
                        Text("Recovery HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(recoveryHR))")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button(action: onSave) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Result")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class HRRecoveryViewModel: ObservableObject {
    enum Phase {
        case instructions
        case capturingPeak
        case recovery
        case complete
    }

    @Published var phase: Phase = .instructions
    @Published var currentHR: Double?
    @Published var peakHR: Double?
    @Published var recoveryHR: Double?
    @Published var recoveryTimeRemaining: Int = 60

    var calculatedHRR: Double? {
        guard let peak = peakHR, let recovery = recoveryHR else { return nil }
        return peak - recovery
    }

    private var hrMonitorCancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?
    private let bleManager = BLEManager.shared

    func startMonitoring() {
        // Subscribe to heart rate updates via HeartRateParser
        hrMonitorCancellable = bleManager.heartRateDataPublisher
            .compactMap { HeartRateParser.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                guard let self = self else { return }
                let hr = Double(packet.heartRate)
                self.currentHR = hr

                // Update peak if in capturing phase
                if self.phase == .capturingPeak {
                    if self.peakHR == nil || hr > self.peakHR! {
                        self.peakHR = hr
                    }
                }
            }
    }

    func stopMonitoring() {
        hrMonitorCancellable?.cancel()
        timerCancellable?.cancel()
    }

    func startPeakCapture() {
        phase = .capturingPeak
        peakHR = currentHR
    }

    func confirmPeakHR() {
        // Use the highest recorded HR as peak
        if peakHR == nil {
            peakHR = currentHR
        }

        phase = .recovery
        recoveryTimeRemaining = 60

        // Start countdown timer
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                if self.recoveryTimeRemaining > 0 {
                    self.recoveryTimeRemaining -= 1
                } else {
                    // Capture recovery HR
                    self.recoveryHR = self.currentHR
                    self.phase = .complete
                    self.timerCancellable?.cancel()
                }
            }
    }

    func cancel() {
        timerCancellable?.cancel()
        phase = .instructions
        peakHR = nil
        recoveryHR = nil
        recoveryTimeRemaining = 60
    }

    func save() {
        guard let hrr = calculatedHRR else { return }

        // Save to repository
        let repository = HRRecoveryRepository()
        let measurement = HRRecoveryMeasurement(
            id: UUID(),
            timestamp: Date(),
            peakHR: peakHR ?? 0,
            recoveryHR: recoveryHR ?? 0,
            hrRecovery: hrr
        )
        repository.save(measurement)
    }
}

// MARK: - HR Recovery Data Model

struct HRRecoveryMeasurement: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let peakHR: Double
    let recoveryHR: Double
    let hrRecovery: Double
}

// MARK: - HR Recovery Repository

final class HRRecoveryRepository {
    private let storageKey = "hr_recovery_measurements"

    func save(_ measurement: HRRecoveryMeasurement) {
        var measurements = loadAll()
        measurements.append(measurement)
        saveAll(measurements)
    }

    func loadAll() -> [HRRecoveryMeasurement] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let measurements = try? JSONDecoder().decode([HRRecoveryMeasurement].self, from: data) else {
            return []
        }
        return measurements
    }

    func loadForDate(_ date: Date) -> HRRecoveryMeasurement? {
        let calendar = Calendar.current
        return loadAll().first { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    private func saveAll(_ measurements: [HRRecoveryMeasurement]) {
        if let data = try? JSONEncoder().encode(measurements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
