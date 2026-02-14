import SwiftUI

struct DeviceSelectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if bleManager.discoveredPeripherals.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for devices...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bleManager.discoveredPeripherals) { peripheral in
                        DeviceRowView(peripheral: peripheral) {
                            bleManager.connect(to: peripheral)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        bleManager.stopScanning()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.connectionState == .scanning {
                        ProgressView()
                    }
                }
            }
            .onAppear {
                if bleManager.connectionState != .scanning {
                    bleManager.startScanning()
                }
            }
        }
    }
}

struct DeviceRowView: View {
    let peripheral: BLEPeripheral
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(peripheral.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("UUID: \(peripheral.id.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Signal strength
                VStack(alignment: .trailing, spacing: 4) {
                    SignalStrengthView(bars: peripheral.signalBars)
                    Text("\(peripheral.rssi) dBm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct SignalStrengthView: View {
    let bars: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level <= bars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(level * 4 + 4))
            }
        }
    }
}

#Preview {
    DeviceSelectionView(bleManager: BLEManager())
}
