import SwiftUI
import Combine

/// Live monitoring view - main HRV monitoring interface
struct MonitorView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = MonitorViewModel()
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Device Connection Section
                    DeviceConnectionSection()
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Only show monitoring UI when connected
                    if coordinator.bleManager.connectionState == .connected {
                        // Measurement Mode Selector
                        MeasurementModeSection(
                            measurementCoordinator: coordinator.measurementCoordinator
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(AppTheme.Animation.spring.delay(0.1), value: showContent)

                        // Live Metrics
                        LiveMetricsSection(viewModel: viewModel)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(AppTheme.Animation.spring.delay(0.15), value: showContent)

                        // Sleep Detection Status
                        SleepDetectionSection(
                            sleepManager: coordinator.backgroundSleepManager,
                            sleepDetectionEngine: coordinator.sleepDetectionEngine
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(AppTheme.Animation.spring.delay(0.2), value: showContent)

                        // Session Recording Status
                        if coordinator.backgroundSleepManager.isRecording {
                            RecordingStatusSection(sleepManager: coordinator.backgroundSleepManager)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Monitor")
            .sheet(isPresented: $viewModel.showDeviceSelection) {
                DeviceSelectionView(bleManager: coordinator.bleManager)
            }
            .onAppear {
                viewModel.setup(with: coordinator)
                withAnimation(AppTheme.Animation.spring) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Device Connection Section

struct DeviceConnectionSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showDeviceSelection = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .scaleEffect(isPulsing && isConnecting ? 1.2 : 1)
                        .opacity(isPulsing && isConnecting ? 0.5 : 1)

                    Image(systemName: statusIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(statusColor.gradient)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(coordinator.bleManager.connectionState.rawValue)
                        .font(AppTheme.Typography.headline)

                    if let device = coordinator.bleManager.connectedPeripheral {
                        Text(device.name)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
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
                        .font(AppTheme.Typography.subheadline)
                }
                .buttonStyle(SecondaryButtonStyle(color: coordinator.bleManager.connectionState == .connected ? AppTheme.Colors.danger : AppTheme.Colors.info))
            }

            if coordinator.bleManager.connectionState == .connected {
                HStack(spacing: AppTheme.Spacing.lg) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        PremiumSignalStrength(bars: signalBars)
                        Text(coordinator.bleManager.connectionHealth.signalStrength.rawValue)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    if coordinator.bleManager.connectionHealth.isReceivingData {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Circle()
                                .fill(AppTheme.Colors.success)
                                .frame(width: 8, height: 8)
                            Text("Receiving Data")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.success)
                        }
                    }
                    Spacer()
                }
            }
        }
        .premiumCard()
        .sheet(isPresented: $showDeviceSelection) {
            DeviceSelectionView(bleManager: coordinator.bleManager)
        }
        .onAppear {
            if isConnecting {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private var isConnecting: Bool {
        [.connecting, .reconnecting, .scanning, .scanningForKnownDevice].contains(coordinator.bleManager.connectionState)
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
        case .connected: return AppTheme.Colors.success
        case .connecting, .reconnecting, .scanning, .scanningForKnownDevice: return AppTheme.Colors.warning
        case .disconnected: return AppTheme.Colors.danger
        }
    }

    private var signalBars: Int {
        switch coordinator.bleManager.connectionHealth.signalStrength {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak, .unknown: return 1
        }
    }

    private var buttonTitle: String {
        coordinator.bleManager.connectionState == .connected ? "Disconnect" : "Connect"
    }
}

// MARK: - Measurement Mode Section

struct MeasurementModeSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(title: "Measurement Mode", icon: "waveform.path.ecg", iconColor: AppTheme.Colors.info)

            if measurementCoordinator.isSessionActive && measurementCoordinator.currentMode != .continuous {
                ActiveSessionCard(measurementCoordinator: measurementCoordinator, coordinator: coordinator)
            } else {
                ContinuousMonitoringStatus(measurementCoordinator: measurementCoordinator)

                PremiumDivider(label: "Timed Measurements")

                HStack(spacing: AppTheme.Spacing.md) {
                    ModeButton(mode: .snapshot, measurementCoordinator: measurementCoordinator)
                    ModeButton(mode: .morningReadiness, measurementCoordinator: measurementCoordinator)
                }
            }
        }
        .premiumCard()
    }
}

struct ContinuousMonitoringStatus: View {
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator

    var body: some View {
        HStack {
            ZStack {
                Circle().fill(AppTheme.Colors.success.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "infinity").font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.Colors.success.gradient)
            }
            Text("Continuous Monitoring").font(AppTheme.Typography.subheadline)
            Spacer()
            if measurementCoordinator.currentMode == .continuous && measurementCoordinator.isSessionActive {
                PremiumStatusBadge(status: .active, size: .small)
            } else {
                Text("Waiting...").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
}

struct ModeButton: View {
    let mode: MeasurementMode
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Button {
            if measurementCoordinator.currentMode == .continuous { _ = measurementCoordinator.stopSession() }
            measurementCoordinator.startSession(mode: mode)
        } label: {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle().fill(mode == .morningReadiness ? AppTheme.Gradients.sunrise : AppTheme.Gradients.calm).frame(width: 44, height: 44)
                    Image(systemName: mode.iconName).font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                }
                Text(mode.displayName).font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium).fill(Color(UIColor.tertiarySystemBackground)))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(mode == .morningReadiness && measurementCoordinator.hasMorningReadinessToday())
        .opacity(mode == .morningReadiness && measurementCoordinator.hasMorningReadinessToday() ? 0.5 : 1)
    }
}

struct ActiveSessionCard: View {
    @ObservedObject var measurementCoordinator: MeasurementSessionCoordinator
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle().fill(AppTheme.Colors.info.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: measurementCoordinator.currentMode?.iconName ?? "waveform.path.ecg")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(AppTheme.Colors.info.gradient)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(measurementCoordinator.currentMode?.displayName ?? "Active")
                        .font(AppTheme.Typography.headline)
                    if measurementCoordinator.sessionComplete {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.success)
                            Text("Complete!")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.success)
                        }
                    }
                }

                Spacer()

                PremiumTimerDisplay(
                    elapsed: measurementCoordinator.elapsedTime,
                    total: measurementCoordinator.currentMode?.duration,
                    accentColor: AppTheme.Colors.info,
                    size: 64,
                    showRemainingLabel: false
                )
            }

            Button {
                _ = measurementCoordinator.stopSession()
                coordinator.startContinuousMonitoring()
            } label: {
                HStack {
                    Image(systemName: measurementCoordinator.sessionComplete ? "checkmark" : "stop.fill")
                    Text(measurementCoordinator.sessionComplete ? "Done" : "Stop")
                }
            }
            .buttonStyle(SecondaryButtonStyle(color: measurementCoordinator.sessionComplete ? AppTheme.Colors.success : AppTheme.Colors.danger))
            .frame(maxWidth: .infinity)
        }
        .padding(AppTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium).fill(measurementCoordinator.sessionComplete ? AppTheme.Colors.success.opacity(0.08) : AppTheme.Colors.info.opacity(0.08)))
    }
}

// MARK: - Live Metrics Section

struct LiveMetricsSection: View {
    @ObservedObject var viewModel: MonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PremiumSectionHeader(title: "Live Metrics", icon: "heart.fill", iconColor: AppTheme.Colors.danger)

            HStack(spacing: AppTheme.Spacing.md) {
                AnimatedHeartRateDisplay(heartRate: viewModel.currentHeartRate, isActive: viewModel.currentHeartRate > 0)
                    .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.Spacing.sm) {
                    PremiumMetricCard(title: "RMSSD", value: String(format: "%.0f", viewModel.currentRMSSD), unit: "ms", icon: "waveform.path.ecg", color: .purple)
                }
                .frame(maxWidth: .infinity)
            }

            if viewModel.currentSDNN > 0 {
                HStack(spacing: AppTheme.Spacing.md) {
                    PremiumMetricCard(title: "SDNN", value: String(format: "%.0f", viewModel.currentSDNN), unit: "ms", icon: "chart.line.uptrend.xyaxis", color: AppTheme.Colors.info)
                    if let pnn50 = viewModel.currentPNN50 {
                        PremiumMetricCard(title: "pNN50", value: String(format: "%.1f", pnn50), unit: "%", icon: "percent", color: AppTheme.Colors.success)
                    }
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Sleep Detection Section

struct SleepDetectionSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var sleepManager: BackgroundSleepSessionManager
    @ObservedObject var sleepDetectionEngine: SleepDetectionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                PremiumSectionHeader(title: "Sleep Tracking", icon: "moon.zzz.fill", iconColor: AppTheme.Colors.deepSleep)
                Text(sleepDetectionEngine.currentState.emoji).font(.title2)
            }

            HStack {
                Text(sleepDetectionEngine.currentState.rawValue).font(AppTheme.Typography.subheadline).foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()

                if sleepManager.isRecording {
                    Text(sleepManager.formattedDuration).font(AppTheme.Typography.headline).monospacedDigit()
                    Button { _ = sleepManager.stopManualRecording() } label: { Label("Stop", systemImage: "stop.fill") }
                        .buttonStyle(SecondaryButtonStyle(color: AppTheme.Colors.danger))
                } else {
                    Button { sleepManager.startManualRecording() } label: { Label("Start Sleep", systemImage: "moon.fill") }
                        .buttonStyle(SecondaryButtonStyle(color: AppTheme.Colors.deepSleep))
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Recording Status Section

struct RecordingStatusSection: View {
    @ObservedObject var sleepManager: BackgroundSleepSessionManager
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                ZStack {
                    Circle().fill(AppTheme.Colors.danger.opacity(0.15)).frame(width: 44, height: 44).scaleEffect(isPulsing ? 1.2 : 1).opacity(isPulsing ? 0.5 : 1)
                    Circle().fill(AppTheme.Colors.danger).frame(width: 12, height: 12)
                }
                Text("Recording Sleep Session").font(AppTheme.Typography.headline)
                Spacer()
                Text(sleepManager.formattedDuration).font(AppTheme.Typography.subheadline).monospacedDigit().foregroundColor(AppTheme.Colors.textSecondary)
            }

            Button { _ = sleepManager.stopManualRecording() } label: { Label("Stop Recording", systemImage: "stop.fill").frame(maxWidth: .infinity) }
                .buttonStyle(SecondaryButtonStyle(color: AppTheme.Colors.danger))
        }
        .premiumCard()
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large).stroke(AppTheme.Colors.danger.opacity(0.3), lineWidth: 2))
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isPulsing = true } }
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
    private var sampleCount: Int = 0

    func setup(with coordinator: AppCoordinator) {
        self.coordinator = coordinator
        coordinator.bleManager.heartRateDataPublisher
            .compactMap { HeartRateParser.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in self?.processPacket(packet) }
            .store(in: &cancellables)
    }

    private func processPacket(_ packet: HeartRatePacket) {
        currentHeartRate = packet.heartRate
        if !packet.rrIntervals.isEmpty {
            hrvEngine.addRRIntervals(packet.rrIntervals, timestamp: packet.timestamp)
            if let metrics = hrvEngine.computeMetrics() {
                currentRMSSD = metrics.rmssd
                currentSDNN = metrics.sdnn ?? 0
                currentPNN50 = metrics.pnn50
                if let coord = coordinator {
                    coord.measurementCoordinator.addSample(heartRate: packet.heartRate, rmssd: metrics.rmssd, sdnn: metrics.sdnn, pnn50: metrics.pnn50)
                    coord.sleepDetectionEngine.updateWithMetrics(heartRate: Double(packet.heartRate), rmssd: metrics.rmssd, timestamp: packet.timestamp)
                    if coord.backgroundSleepManager.isRecording {
                        coord.backgroundSleepManager.addSample(HRVSample(from: packet, rmssd: metrics.rmssd))
                    }
                    sampleCount += 1
                    if sampleCount % 50 == 0 { coord.updateBaselineWithNewData(heartRate: Double(packet.heartRate), rmssd: metrics.rmssd) }
                }
            }
        }
    }
}
