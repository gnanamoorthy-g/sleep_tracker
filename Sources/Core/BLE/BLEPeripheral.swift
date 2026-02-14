import Foundation
import CoreBluetooth

struct BLEPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral?
    let name: String
    let rssi: Int
    let discoveredAt: Date

    init(peripheral: CBPeripheral, rssi: Int, discoveredAt: Date = Date()) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
        self.discoveredAt = discoveredAt
    }

    static func == (lhs: BLEPeripheral, rhs: BLEPeripheral) -> Bool {
        lhs.id == rhs.id
    }

    // Preview/testing initializer
    init(id: UUID = UUID(), name: String, rssi: Int, discoveredAt: Date = Date()) {
        self.id = id
        self.peripheral = nil
        self.name = name
        self.rssi = rssi
        self.discoveredAt = discoveredAt
    }

    // Signal strength description
    var signalStrength: SignalStrength {
        switch rssi {
        case -50...0:
            return .excellent
        case -60..<(-50):
            return .good
        case -70..<(-60):
            return .fair
        default:
            return .weak
        }
    }

    var signalBars: Int {
        switch rssi {
        case -50...0:
            return 4
        case -60..<(-50):
            return 3
        case -70..<(-60):
            return 2
        default:
            return 1
        }
    }
}

enum SignalStrength: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
}
