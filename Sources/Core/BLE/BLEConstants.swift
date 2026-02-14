import CoreBluetooth

enum BLEConstants {
    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")

    static let stateRestorationIdentifier = "com.sleeptracker.ble.central"
}
