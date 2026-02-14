import SwiftUI

struct ConnectedDeviceView: View {
    let peripheral: BLEPeripheral
    let onDisconnect: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Device icon with pulse animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(peripheral.name)
                            .font(.headline)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    SignalStrengthView(bars: peripheral.signalBars)
                    Text(peripheral.signalStrength.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Device details
            HStack {
                DeviceDetailItem(label: "Signal", value: "\(peripheral.rssi) dBm")
                Spacer()
                DeviceDetailItem(label: "UUID", value: String(peripheral.id.uuidString.prefix(8)))
            }
            .padding(.horizontal, 8)

            // Disconnect button
            Button(action: onDisconnect) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disconnect")
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct DeviceDetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

