import SwiftUI

struct DeviceSelectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if bleManager.discoveredPeripherals.isEmpty {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        ZStack {
                            Circle().fill(AppTheme.Colors.info.opacity(0.1)).frame(width: 100, height: 100)
                            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(AppTheme.Colors.info.gradient)
                        }
                        Text("Scanning for devices...").font(AppTheme.Typography.headline)
                        LoadingDots()
                        Text("Make sure your heart rate monitor is powered on and in pairing mode.")
                            .font(AppTheme.Typography.body).foregroundColor(AppTheme.Colors.textSecondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .padding()
                } else {
                    List(bleManager.discoveredPeripherals) { peripheral in
                        DeviceRowView(peripheral: peripheral) {
                            bleManager.connect(to: peripheral)
                            dismiss()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { bleManager.stopScanning(); dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.connectionState == .scanning { ProgressView() }
                }
            }
            .onAppear { if bleManager.connectionState != .scanning { bleManager.startScanning() } }
        }
    }
}

struct DeviceRowView: View {
    let peripheral: BLEPeripheral
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle().fill(AppTheme.Colors.danger.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: "heart.circle.fill").font(.system(size: 26)).foregroundStyle(AppTheme.Gradients.health)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(peripheral.name).font(AppTheme.Typography.headline).foregroundColor(AppTheme.Colors.textPrimary)
                    Text("UUID: \(peripheral.id.uuidString.prefix(8))...").font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                    PremiumSignalStrength(bars: peripheral.signalBars)
                    Text("\(peripheral.rssi) dBm").font(AppTheme.Typography.caption2).foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }
}

struct SignalStrengthView: View {
    let bars: Int
    var body: some View { PremiumSignalStrength(bars: bars) }
}

#Preview { DeviceSelectionView(bleManager: BLEManager()) }
