import SwiftUI
import UniformTypeIdentifiers

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeviceSettingsRow()
                } header: {
                    Label("Device", systemImage: "heart.circle.fill").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.danger)
                }

                Section {
                    Toggle("Auto-Connect", isOn: $viewModel.autoConnectEnabled)
                        .onChange(of: viewModel.autoConnectEnabled) { newValue in coordinator.bleManager.setAutoConnect(enabled: newValue) }
                        .tint(AppTheme.Colors.success)

                    NavigationLink { Text("Sleep Detection Settings") } label: { Label("Sleep Detection", systemImage: "moon.zzz") }
                } header: {
                    Label("Monitoring", systemImage: "waveform.path.ecg").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.info)
                }

                Section {
                    Toggle("Stress Alerts", isOn: $viewModel.stressAlertsEnabled)
                        .onChange(of: viewModel.stressAlertsEnabled) { newValue in NotificationManager.shared.isStressAlertsEnabled = newValue }
                        .tint(AppTheme.Colors.success)

                    Toggle("Morning Reminder", isOn: $viewModel.morningReminderEnabled)
                        .onChange(of: viewModel.morningReminderEnabled) { newValue in NotificationManager.shared.isMorningReminderEnabled = newValue }
                        .tint(AppTheme.Colors.success)
                } header: {
                    Label("Notifications", systemImage: "bell.fill").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.warning)
                }

                Section {
                    if let baseline7d = viewModel.baseline7d {
                        HStack {
                            Label("7-Day RMSSD", systemImage: "chart.bar.fill")
                            Spacer()
                            Text(String(format: "%.1f ms", baseline7d)).foregroundColor(AppTheme.Colors.textSecondary).font(AppTheme.Typography.subheadline)
                        }
                    }
                    if let baseline30d = viewModel.baseline30d {
                        HStack {
                            Label("30-Day RMSSD", systemImage: "chart.line.uptrend.xyaxis")
                            Spacer()
                            Text(String(format: "%.1f ms", baseline30d)).foregroundColor(AppTheme.Colors.textSecondary).font(AppTheme.Typography.subheadline)
                        }
                    }
                    Button { viewModel.recalculateBaselines(with: coordinator) } label: { Label("Recalculate Baselines", systemImage: "arrow.clockwise") }
                } header: {
                    Label("Baselines", systemImage: "target").font(AppTheme.Typography.caption).foregroundColor(.purple)
                }

                Section {
                    HStack { Label("Sleep Sessions", systemImage: "moon.fill"); Spacer(); Text("\(viewModel.sessionCount)").foregroundColor(AppTheme.Colors.textSecondary) }
                    HStack { Label("HRV Snapshots", systemImage: "camera.metering.spot"); Spacer(); Text("\(viewModel.snapshotCount)").foregroundColor(AppTheme.Colors.textSecondary) }

                    Button { viewModel.exportData(coordinator: coordinator) } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if viewModel.isExporting { ProgressView().scaleEffect(0.8) }
                        }
                    }
                    .disabled(viewModel.isExporting)

                    Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: { Label("Delete All Data", systemImage: "trash") }
                } header: {
                    Label("Data", systemImage: "externaldrive.fill").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.success)
                }

                Section {
                    HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundColor(AppTheme.Colors.textSecondary) }
                    Link(destination: URL(string: "https://example.com/privacy")!) { Label("Privacy Policy", systemImage: "hand.raised.fill") }
                    Link(destination: URL(string: "https://example.com/support")!) { Label("Support", systemImage: "questionmark.circle.fill") }
                } header: {
                    Label("About", systemImage: "info.circle.fill").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.loadSettings(from: coordinator) }
            .alert("Delete All Data?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { viewModel.deleteAllData(with: coordinator) }
            } message: { Text("This will permanently delete all sleep sessions, snapshots, and stress events. This action cannot be undone.") }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Device Settings Row

struct DeviceSettingsRow: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        if let device = coordinator.bleManager.savedDevice {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(device.name).font(AppTheme.Typography.headline)
                    Text("Last connected: \(formatDate(device.lastConnected))").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if coordinator.bleManager.connectionState == .connected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(AppTheme.Colors.success)
                }
            }
            Button("Forget Device", role: .destructive) { coordinator.bleManager.disconnect(forgetDevice: true) }
        } else {
            HStack { Text("No device paired").foregroundColor(AppTheme.Colors.textSecondary); Spacer() }
        }
    }

    private func formatDate(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var autoConnectEnabled = true
    @Published var stressAlertsEnabled = false
    @Published var morningReminderEnabled = false
    @Published var baseline7d: Double?
    @Published var baseline30d: Double?
    @Published var sessionCount = 0
    @Published var snapshotCount = 0
    @Published var showDeleteConfirmation = false
    @Published var isExporting = false
    @Published var showExportSheet = false
    @Published var exportURL: URL?

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

    func exportData(coordinator: AppCoordinator) {
        isExporting = true
        Task {
            do {
                let sessions = (try? coordinator.sessionRepository.loadAll()) ?? []
                let snapshots = coordinator.snapshotRepository.loadAll()
                let stressEvents = coordinator.stressEventRepository.loadAll()

                var csvContent = "Sleep Tracker Export\nGenerated: \(Date())\n\n"

                // Sleep Sessions
                csvContent += "SLEEP SESSIONS\nDate,Duration (min),Score,Avg HR,RMSSD,Deep %,Light %,REM %\n"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                for session in sessions {
                    let summary = SleepSummaryCalculator.calculate(from: session)
                    csvContent += "\(dateFormatter.string(from: session.startTime)),\(Int(session.duration/60)),\(summary.sleepScore),\(Int(summary.averageHR)),\(String(format: "%.1f", summary.averageRMSSD)),\(Int(summary.deepSleepPercentage)),\(Int(summary.lightSleepPercentage)),\(Int(summary.remSleepPercentage))\n"
                }

                // HRV Snapshots
                csvContent += "\nHRV SNAPSHOTS\nDate,Type,RMSSD,SDNN,HR,Duration\n"
                for snapshot in snapshots {
                    csvContent += "\(dateFormatter.string(from: snapshot.timestamp)),\(snapshot.measurementMode.rawValue),\(String(format: "%.1f", snapshot.rmssd)),\(String(format: "%.1f", snapshot.sdnn ?? 0)),\(Int(snapshot.averageHR)),\(snapshot.formattedDuration)\n"
                }

                // Stress Events
                csvContent += "\nSTRESS EVENTS\nDate,Severity,HR,RMSSD\n"
                for event in stressEvents {
                    csvContent += "\(dateFormatter.string(from: event.timestamp)),\(event.severity.rawValue),\(Int(event.averageHR)),\(String(format: "%.1f", event.averageRMSSD))\n"
                }

                let fileName = "SleepTracker_Export_\(dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).csv"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    exportURL = tempURL
                    isExporting = false
                    showExportSheet = true
                }
            } catch {
                await MainActor.run { isExporting = false }
            }
        }
    }

    func deleteAllData(with coordinator: AppCoordinator) {
        try? coordinator.sessionRepository.deleteAll()
        coordinator.snapshotRepository.deleteAll()
        coordinator.stressEventRepository.deleteAll()
        sessionCount = 0
        snapshotCount = 0
        baseline7d = nil
        baseline30d = nil
    }
}
