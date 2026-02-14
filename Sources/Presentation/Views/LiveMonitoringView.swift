import SwiftUI

struct LiveMonitoringView: View {
    @StateObject private var viewModel = LiveMonitoringViewModel()
    @State private var showDeviceSelection = false
    @State private var showSleepData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Section
                    connectionSection

                    // Heart Rate Display (only when connected)
                    if viewModel.connectionState == .connected {
                        HeartRateView(heartRate: viewModel.heartRate)

                        MetricsGridView(
                            rrInterval: viewModel.latestRRInterval,
                            rmssd: viewModel.rmssd
                        )

                        // Recording Section
                        RecordingControlView(
                            isRecording: viewModel.isRecording,
                            duration: viewModel.formattedDuration,
                            sampleCount: viewModel.sampleCount,
                            onStart: { viewModel.startRecording() },
                            onStop: { viewModel.stopRecording() }
                        )

                        // Show sleep data button when we have epochs
                        if !viewModel.currentEpochs.isEmpty || viewModel.sleepSummary != nil {
                            Button(action: { showSleepData = true }) {
                                HStack {
                                    Image(systemName: "chart.xyaxis.line")
                                    Text("View Sleep Data")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Sleep Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SessionHistoryView()) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showDeviceSelection) {
                DeviceSelectionView(bleManager: viewModel.bleManager)
            }
            .sheet(isPresented: $showSleepData) {
                SleepDataView(
                    epochs: viewModel.currentEpochs,
                    summary: viewModel.sleepSummary
                )
            }
        }
    }

    // MARK: - Connection Section
    @ViewBuilder
    private var connectionSection: some View {
        switch viewModel.connectionState {
        case .disconnected:
            disconnectedView
        case .scanning, .scanningForKnownDevice:
            scanningView
        case .connecting:
            connectingView
        case .connected:
            if let peripheral = viewModel.connectedPeripheral {
                ConnectedDeviceView(peripheral: peripheral) {
                    viewModel.disconnect()
                }
            }
        case .reconnecting:
            reconnectingView
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Device Connected")
                .font(.headline)

            Text("Connect to your heart rate monitor to start tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showDeviceSelection = true }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Scan for Devices")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning for devices...")
                .font(.headline)

            Button("Cancel") {
                viewModel.stopScanning()
            }
            .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Connecting...")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var reconnectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Reconnecting...")
                .font(.headline)
                .foregroundColor(.orange)

            Button("Cancel") {
                viewModel.disconnect()
            }
            .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Sleep Data View
struct SleepDataView: View {
    let epochs: [SleepEpoch]
    let summary: SleepSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let summary = summary {
                        SleepSummaryCard(summary: summary)
                    }

                    SleepGraphView(epochs: epochs)

                    HRLineChartView(epochs: epochs, showRMSSD: true)
                }
                .padding()
            }
            .navigationTitle("Sleep Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    let state: BLEConnectionState

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            Text(state.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    private var statusColor: Color {
        switch state {
        case .disconnected:
            return .red
        case .scanning, .scanningForKnownDevice, .connecting, .reconnecting:
            return .orange
        case .connected:
            return .green
        }
    }
}

// MARK: - Heart Rate View
struct HeartRateView: View {
    let heartRate: Int?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            if let hr = heartRate {
                Text("\(hr)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
            } else {
                Text("--")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Text("BPM")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Metrics Grid View
struct MetricsGridView: View {
    let rrInterval: Double?
    let rmssd: Double?

    var body: some View {
        HStack(spacing: 20) {
            LiveMetricCard(
                title: "RR Interval",
                value: rrInterval.map { String(format: "%.0f", $0) } ?? "--",
                unit: "ms"
            )

            LiveMetricCard(
                title: "RMSSD",
                value: rmssd.map { String(format: "%.1f", $0) } ?? "--",
                unit: "ms"
            )
        }
    }
}

struct LiveMetricCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Recording Control View
struct RecordingControlView: View {
    let isRecording: Bool
    let duration: String
    let sampleCount: Int
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isRecording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)

                    Text("Recording")
                        .foregroundColor(.red)

                    Spacer()

                    Text(duration)
                        .font(.system(.body, design: .monospaced))

                    Spacer()

                    Text("\(sampleCount) samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }

            Button(action: {
                if isRecording {
                    onStop()
                } else {
                    onStart()
                }
            }) {
                HStack {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRecording ? Color.red : Color.green)
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    LiveMonitoringView()
}
