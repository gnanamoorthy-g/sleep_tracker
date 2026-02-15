import CoreBluetooth

enum BLEConstants {
    // Heart Rate Service
    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")

    // Battery Service (for keep-alive reads)
    static let batteryServiceUUID = CBUUID(string: "180F")
    static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")

    // State Restoration
    static let stateRestorationIdentifier = "com.sleeptracker.ble.central"

    // Keep-alive intervals
    static let keepAliveInterval: TimeInterval = 30  // seconds
    static let staleConnectionThreshold: TimeInterval = 90  // seconds
}
