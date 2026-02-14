import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Device Section
                Section("Device") {
                    DeviceSettingsRow()
                }

                // Monitoring Section
                Section("Monitoring") {
                    Toggle("Auto-Connect", isOn: $viewModel.autoConnectEnabled)
                        .onChange(of: viewModel.autoConnectEnabled) { newValue in
                            coordinator.bleManager.setAutoConnect(enabled: newValue)
                        }

                    NavigationLink {
                        Text("Sleep Detection Settings")
                    } label: {
                        Label("Sleep Detection", systemImage: "moon.zzz")
                    }
                }

                // Notifications Section
                Section("Notifications") {
                    Toggle("Stress Alerts", isOn: $viewModel.stressAlertsEnabled)
                        .onChange(of: viewModel.stressAlertsEnabled) { newValue in
                            NotificationManager.shared.isStressAlertsEnabled = newValue
                        }

                    Toggle("Morning Reminder", isOn: $viewModel.morningReminderEnabled)
                        .onChange(of: viewModel.morningReminderEnabled) { newValue in
                            NotificationManager.shared.isMorningReminderEnabled = newValue
                        }
                }

                // Baselines Section
                Section("Baselines") {
                    if let baseline7d = viewModel.baseline7d {
                        HStack {
                            Text("7-Day RMSSD")
                            Spacer()
                            Text(String(format: "%.1f ms", baseline7d))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let baseline30d = viewModel.baseline30d {
                        HStack {
                            Text("30-Day RMSSD")
                            Spacer()
                            Text(String(format: "%.1f ms", baseline30d))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Recalculate Baselines") {
                        viewModel.recalculateBaselines(with: coordinator)
                    }
                }

                // Data Section
                Section("Data") {
                    HStack {
                        Text("Sleep Sessions")
                        Spacer()
                        Text("\(viewModel.sessionCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("HRV Snapshots")
                        Spacer()
                        Text("\(viewModel.snapshotCount)")
                            .foregroundColor(.secondary)
                    }

                    Button("Export Data", role: .none) {
                        viewModel.exportData()
                    }

                    Button("Delete All Data", role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    Link("Support", destination: URL(string: "https://example.com/support")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadSettings(from: coordinator)
            }
            .alert("Delete All Data?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteAllData(with: coordinator)
                }
            } message: {
                Text("This will permanently delete all sleep sessions, snapshots, and stress events. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Device Settings Row

struct DeviceSettingsRow: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        if let device = coordinator.bleManager.savedDevice {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text("Last connected: \(formatDate(device.lastConnected))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if coordinator.bleManager.connectionState == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Button("Forget Device", role: .destructive) {
                coordinator.bleManager.disconnect(forgetDevice: true)
            }
        } else {
            HStack {
                Text("No device paired")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var autoConnectEnabled: Bool = true
    @Published var stressAlertsEnabled: Bool = false
    @Published var morningReminderEnabled: Bool = false
    @Published var baseline7d: Double?
    @Published var baseline30d: Double?
    @Published var sessionCount: Int = 0
    @Published var snapshotCount: Int = 0
    @Published var showDeleteConfirmation: Bool = false

    func loadSettings(from coordinator: AppCoordinator) {
        autoConnectEnabled = coordinator.bleManager.isAutoConnectEnabled
        stressAlertsEnabled = NotificationManager.shared.isStressAlertsEnabled
        morningReminderEnabled = NotificationManager.shared.isMorningReminderEnabled

        let summaries = coordinator.summaryRepository.loadAll()
        baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries)
        baseline30d = BaselineEngine.calculate30DayBaseline(from: summaries)

        sessionCount = (try? coordinator.sessionRepository.loadAll().count) ?? 0
        snapshotCount = coordinator.snapshotRepository.count
    }

    func recalculateBaselines(with coordinator: AppCoordinator) {
        let summaries = coordinator.summaryRepository.loadAll()
        baseline7d = BaselineEngine.calculate7DayBaseline(from: summaries)
        baseline30d = BaselineEngine.calculate30DayBaseline(from: summaries)
    }

    func exportData() {
        // TODO: Implement data export
    }

    func deleteAllData(with coordinator: AppCoordinator) {
        // Delete all repositories
        try? coordinator.sessionRepository.deleteAll()
        coordinator.snapshotRepository.deleteAll()
        coordinator.stressEventRepository.deleteAll()

        // Reload counts
        sessionCount = 0
        snapshotCount = 0
        baseline7d = nil
        baseline30d = nil
    }
}
