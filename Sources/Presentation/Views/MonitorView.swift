import SwiftUI
import Combine

/// Live monitoring view - main HRV monitoring interface
struct MonitorView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = MonitorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Device Connection Section
                    DeviceConnectionSection()

                    // Only show monitoring UI when connected
                    if coordinator.bleManager.connectionState == .connected {
                        // Measurement Mode Selector
                        MeasurementModeSection(
                            measurementCoordinator: coordinator.measurementCoordinator
                        )

                        // Live Metrics
                        LiveMetricsSection(viewModel: viewModel)

                        // Sleep Detection Status
                        SleepDetectionSection(
                            sleepManager: coordinator.backgroundSleepManager,
                            sleepDetectionEngine: coordinator.sleepDetectionEngine
                        )

                        // Session Recording Status
                        if coordinator.backgroundSleepManager.isRecording {
                            RecordingStatusSection(sleepManager: coordinator.backgroundSleepManager)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Monitor")
            .sheet(isPresented: $viewModel.showDeviceSelection) {
                DeviceSelectionView(bleManager: coordinator.bleManager)
            }
            .onAppear {
                viewModel.setup(with: coordinator)
            }
        }
    }
}

// MARK: - Device Connection Section

struct DeviceConnectionSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showDeviceSelection = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text(coordinator.bleManager.connectionState.rawValue)
                        .font(.headline)

                    if let device = coordinator.bleManager.connectedPeripheral {
                        Text(device.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    if coordinator.bleManager.connectionState == .connected {
                        coordinator.bleManager.disconnect()
                    } else {
                        showDeviceSelection = true
                    }
                } label: {
                    Text(buttonTitle)
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            // Connection health when connected
            if coordinator.bleManager.connectionState == .connected {
                HStack(spacing: 16) {
                    Label(
                        coordinator.bleManager.connectionHealth.signalStrength.rawValue,
                        systemImage: coordinator.bleManager.connectionHealth.signalStrength.systemImageName
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if coordinator.bleManager.connectionHealth.isReceivingData {
                        Label("Receiving Data", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showDeviceSelection) {
            DeviceSelectionView(bleManager: coordinator.bleManager)
        }
    }

    private var statusIcon: String {
        switch coordinator.bleManager.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting, .reconnecting, .scanningForKnownDevice: return "antenna.radiowaves.left.and.right"
        case .scanning: return "magnifyingglass"
        case .disconnected: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch coordinator.bleManager.connectionState {
        case .connected: return .green
        case .connecting, .reconnecting, .scanning, .scanningForKnownDevice: return .orange
        case .disconnected: return .red
        }
    }

    private var buttonTitle: String {
        switch coordinator.bleManager.connectionState {
        case .connected: return "Disconnect"
        default: return "Connect"
        }
    }
}

// MARK: - Measurement Mode Section

struct MeasurementModeSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurement Mode")
                .font(.headline)

            // Show active timed session (snapshot/morning readiness)
            if measurementCoordinator.isSessionActive && measurementCoordinator.currentMode != .continuous {
                ActiveSessionCard(measurementCoordinator: measurementCoordinator, coordinator: coordinator)
            } else {
                // Continuous monitoring status (auto-starts when connected)
                ContinuousMonitoringStatus(measurementCoordinator: measurementCoordinator)

                // Mode selection buttons for timed measurements
                Text("Timed Measurements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ModeButton(mode: .snapshot, measurementCoordinator: measurementCoordinator)
                    ModeButton(mode: .morningReadiness, measurementCoordinator: measurementCoordinator)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ContinuousMonitoringStatus: View {
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator

    var body: some View {
        HStack {
            Image(systemName: "infinity")
                .foregroundColor(.green)
            Text("Continuous Monitoring")
                .font(.subheadline)
            Spacer()
            if measurementCoordinator.currentMode == .continuous && measurementCoordinator.isSessionActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            } else {
                Text("Waiting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ModeButton: View {
    let mode: MeasurementMode
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Button {
            // Stop continuous monitoring first, then start timed session
            if measurementCoordinator.currentMode == .continuous {
                _ = measurementCoordinator.stopSession()
            }
            switch mode {
            case .snapshot:
                measurementCoordinator.startSession(mode: .snapshot)
            case .morningReadiness:
                measurementCoordinator.startSession(mode: .morningReadiness)
            case .continuous:
                measurementCoordinator.startSession(mode: .continuous)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.title2)
                Text(mode.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .disabled(mode == .morningReadiness && measurementCoordinator.hasMorningReadinessToday())
    }
}

struct ActiveSessionCard: View {
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: measurementCoordinator.currentMode?.iconName ?? "waveform.path.ecg")
                    .foregroundColor(.blue)

                Text(measurementCoordinator.currentMode?.displayName ?? "Active")
                    .font(.headline)

                Spacer()

                // Timer
                Text(formatTime(measurementCoordinator.elapsedTime))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
            }

            // Progress bar for timed sessions
            if measurementCoordinator.currentMode?.duration != nil {
                ProgressView(value: measurementCoordinator.progress)
                    .tint(.blue)

                // Show completion status
                if measurementCoordinator.sessionComplete {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Complete!")
                            .foregroundColor(.green)
                    }
                }
            }

            Button {
                _ = measurementCoordinator.stopSession()
                // Restart continuous monitoring after stopping timed session
                coordinator.startContinuousMonitoring()
            } label: {
                Label(measurementCoordinator.sessionComplete ? "Done" : "Stop", systemImage: measurementCoordinator.sessionComplete ? "checkmark" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(measurementCoordinator.sessionComplete ? .green : .red)
        }
        .padding()
        .background(measurementCoordinator.sessionComplete ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Live Metrics Section

struct LiveMetricsSection: View {
    @ObservedObject var viewModel: MonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Metrics")
                .font(.headline)

            HStack(spacing: 16) {
                MetricCard(
                    title: "Heart Rate",
                    value: "\(viewModel.currentHeartRate)",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )

                MetricCard(
                    title: "RMSSD",
                    value: String(format: "%.0f", viewModel.currentRMSSD),
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .blue
                )
            }

            if viewModel.currentSDNN > 0 {
                HStack(spacing: 16) {
                    MetricCard(
                        title: "SDNN",
                        value: String(format: "%.0f", viewModel.currentSDNN),
                        unit: "ms",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )

                    if let pnn50 = viewModel.currentPNN50 {
                        MetricCard(
                            title: "pNN50",
                            value: String(format: "%.1f", pnn50),
                            unit: "%",
                            icon: "percent",
                            color: .green
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Sleep Detection Section

struct SleepDetectionSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var sleepManager: BackgroundSleepSessionManager
    @ObservedObject var sleepDetectionEngine: SleepDetectionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Tracking")
                    .font(.headline)
                Spacer()
                Text(sleepDetectionEngine.currentState.emoji)
            }

            HStack {
                Text(sleepDetectionEngine.currentState.rawValue)
                    .font(.subheadline)

                Spacer()

                // Manual sleep toggle
                if sleepManager.isRecording {
                    // Show duration and stop button when recording
                    Text(sleepManager.formattedDuration)
                        .font(.headline.monospacedDigit())

                    Button {
                        _ = sleepManager.stopManualRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    // Show start button when not recording
                    Button {
                        sleepManager.startManualRecording()
                    } label: {
                        Label("Start Sleep", systemImage: "moon.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Recording Status Section

struct RecordingStatusSection: View {
    @ObservedObject var sleepManager: BackgroundSleepSessionManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )

                Text("Recording Sleep Session")
                    .font(.headline)

                Spacer()

                Text(sleepManager.formattedDuration)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Button {
                _ = sleepManager.stopManualRecording()
            } label: {
                Label("Stop Recording", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Monitor ViewModel

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published var showDeviceSelection = false
    @Published var currentHeartRate: Int = 0
    @Published var currentRMSSD: Double = 0
    @Published var currentSDNN: Double = 0
    @Published var currentPNN50: Double?

    private var cancellables = Set<AnyCancellable>()
    private let hrvEngine = HRVEngine()
    private weak var coordinator: AppCoordinator?

    func setup(with coordinator: AppCoordinator) {
        self.coordinator = coordinator

        // Subscribe to heart rate data from BLE manager
        coordinator.bleManager.heartRateDataPublisher
            .compactMap { HeartRateParser.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                self?.processPacket(packet)
            }
            .store(in: &cancellables)
    }

    private func processPacket(_ packet: HeartRatePacket) {
        // Update heart rate
        currentHeartRate = packet.heartRate

        // Compute HRV metrics if we have RR intervals
        if !packet.rrIntervals.isEmpty {
            hrvEngine.addRRIntervals(packet.rrIntervals, timestamp: packet.timestamp)

            // Compute all metrics at once
            if let metrics = hrvEngine.computeMetrics() {
                currentRMSSD = metrics.rmssd
                currentSDNN = metrics.sdnn ?? 0
                currentPNN50 = metrics.pnn50

                // Feed samples to measurement coordinator for snapshot/morning readiness
                if let coord = coordinator {
                    coord.measurementCoordinator.addSample(
                        heartRate: packet.heartRate,
                        rmssd: metrics.rmssd,
                        sdnn: metrics.sdnn,
                        pnn50: metrics.pnn50
                    )
                }
            }
        }
    }
}
