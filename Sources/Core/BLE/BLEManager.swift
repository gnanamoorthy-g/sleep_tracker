import Foundation
import CoreBluetooth
import Combine
import os.log

// MARK: - Connection State
enum BLEConnectionState: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case scanningForKnownDevice = "Looking for device..."
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
}

// MARK: - BLE Manager
final class BLEManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = BLEManager()

    // MARK: - Published Properties
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var discoveredPeripherals: [BLEPeripheral] = []
    @Published private(set) var connectedPeripheral: BLEPeripheral?
    @Published private(set) var lastError: BLEError?
    @Published private(set) var isAutoConnectEnabled: Bool = true

    // MARK: - Health Monitor
    let connectionHealth = ConnectionHealthMonitor()

    // MARK: - Publishers
    let heartRateDataSubject = PassthroughSubject<Data, Never>()
    var heartRateDataPublisher: AnyPublisher<Data, Never> {
        heartRateDataSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    private var heartRateMeasurementCharacteristic: CBCharacteristic?
    private var shouldReconnect = false
    private var isAutoConnecting = false
    private var targetDeviceUUID: String?

    private let devicePersistence = DevicePersistenceManager.shared
    private let reconnectionStrategy = ReconnectionStrategy()
    private let logger = Logger(subsystem: "com.sleeptracker", category: "BLE")
    private let bleQueue = DispatchQueue(label: "com.sleeptracker.ble", qos: .userInitiated)

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: bleQueue,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BLEConstants.stateRestorationIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    // MARK: - Public Methods

    /// Start scanning for all heart rate devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth not powered on")
            updateState(.disconnected)
            return
        }

        logger.info("Starting scan for Heart Rate Service (180D)")
        isAutoConnecting = false
        targetDeviceUUID = nil
        updateState(.scanning)

        DispatchQueue.main.async {
            self.discoveredPeripherals.removeAll()
        }

        centralManager.scanForPeripherals(
            withServices: [BLEConstants.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    /// Stop scanning for devices
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning || connectionState == .scanningForKnownDevice {
            updateState(.disconnected)
        }
        logger.info("Stopped scanning")
    }

    /// Connect to a specific peripheral
    func connect(to peripheral: BLEPeripheral) {
        guard let cbPeripheral = peripheral.peripheral else {
            logger.error("Cannot connect: peripheral is nil")
            return
        }

        stopScanning()
        shouldReconnect = true
        reconnectionStrategy.reset()

        heartRatePeripheral = cbPeripheral
        heartRatePeripheral?.delegate = self
        updateState(.connecting)

        // Save device for future auto-connect
        devicePersistence.saveDevice(uuid: cbPeripheral.identifier.uuidString, name: peripheral.name)

        logger.info("Connecting to \(peripheral.name)")
        centralManager.connect(cbPeripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    /// Disconnect and optionally forget the device
    func disconnect(forgetDevice: Bool = false) {
        shouldReconnect = false
        reconnectionStrategy.cancelScheduledReconnection()

        if forgetDevice {
            devicePersistence.clearDevice()
            connectionHealth.reset()
            logger.info("Device forgotten")
        }

        if let peripheral = heartRatePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// Attempt to auto-connect to the last known device
    func attemptAutoConnect() {
        guard isAutoConnectEnabled,
              centralManager.state == .poweredOn,
              let savedDevice = devicePersistence.loadDevice() else {
            return
        }

        logger.info("Attempting auto-connect to: \(savedDevice.name)")
        isAutoConnecting = true
        targetDeviceUUID = savedDevice.uuid
        shouldReconnect = true

        updateState(.scanningForKnownDevice)

        // Scan for the specific device
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Timeout after 30 seconds if device not found
        bleQueue.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self,
                  self.isAutoConnecting,
                  self.connectionState == .scanningForKnownDevice else {
                return
            }
            self.logger.warning("Auto-connect timeout - device not found")
            self.stopScanning()
            self.isAutoConnecting = false
        }
    }

    /// Enable or disable auto-connect feature
    func setAutoConnect(enabled: Bool) {
        isAutoConnectEnabled = enabled
        if !enabled {
            isAutoConnecting = false
        }
    }

    /// Get the saved device info
    var savedDevice: PersistedDevice? {
        devicePersistence.loadDevice()
    }

    // MARK: - Private Methods

    private func updateState(_ state: BLEConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }

    private func handleDisconnection() {
        connectionHealth.connectionLost()

        if shouldReconnect, let peripheral = heartRatePeripheral {
            // Use exponential backoff for reconnection
            if reconnectionStrategy.shouldContinueReconnecting {
                updateState(.reconnecting)
                reconnectionStrategy.scheduleReconnection(on: bleQueue) { [weak self] in
                    guard let self = self else { return }
                    self.logger.info("Attempting scheduled reconnection...")
                    self.centralManager.connect(peripheral, options: nil)
                }
            } else {
                logger.warning("Max reconnection attempts reached, giving up")
                updateState(.disconnected)
                reconnectionStrategy.reset()
            }
        } else {
            updateState(.disconnected)
            heartRatePeripheral = nil
            heartRateMeasurementCharacteristic = nil
            DispatchQueue.main.async {
                self.connectedPeripheral = nil
            }
        }
    }

    private func handleSuccessfulConnection(peripheral: CBPeripheral) {
        reconnectionStrategy.reset()
        isAutoConnecting = false
        connectionHealth.connectionEstablished()
        devicePersistence.updateLastConnected()

        updateState(.connected)

        DispatchQueue.main.async {
            self.connectedPeripheral = BLEPeripheral(peripheral: peripheral, rssi: 0)
        }

        peripheral.discoverServices([BLEConstants.heartRateServiceUUID, BLEConstants.batteryServiceUUID])

        // Start periodic RSSI reading
        startRSSIMonitoring(for: peripheral)

        // Start keep-alive heartbeat for overnight stability
        startKeepAliveHeartbeat(for: peripheral)

        // Start stale connection detection
        startStaleConnectionDetection()
    }

    private func startRSSIMonitoring(for peripheral: CBPeripheral) {
        // Read RSSI every 10 seconds
        bleQueue.asyncAfter(deadline: .now() + 10) { [weak self, weak peripheral] in
            guard let self = self,
                  let peripheral = peripheral,
                  peripheral.state == .connected else {
                return
            }
            peripheral.readRSSI()
            self.startRSSIMonitoring(for: peripheral)
        }
    }

    // MARK: - Keep-Alive Heartbeat (Critical for HW9 overnight stability)

    private var keepAliveTimer: DispatchSourceTimer?
    private var staleConnectionTimer: DispatchSourceTimer?
    private var batteryCharacteristic: CBCharacteristic?

    /// Start keep-alive heartbeat to prevent BLE supervision timeout
    /// Sends a read request every 30 seconds to maintain connection
    private func startKeepAliveHeartbeat(for peripheral: CBPeripheral) {
        stopKeepAliveHeartbeat()

        let timer = DispatchSource.makeTimerSource(queue: bleQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self, weak peripheral] in
            guard let self = self,
                  let peripheral = peripheral,
                  peripheral.state == .connected else {
                return
            }

            // Read battery or RSSI as keep-alive signal
            if let batteryChar = self.batteryCharacteristic {
                peripheral.readValue(for: batteryChar)
                self.logger.debug("Keep-alive: reading battery characteristic")
            } else {
                peripheral.readRSSI()
                self.logger.debug("Keep-alive: reading RSSI")
            }
        }
        timer.resume()
        keepAliveTimer = timer

        logger.info("Keep-alive heartbeat started (30s interval)")
    }

    private func stopKeepAliveHeartbeat() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
    }

    /// Start stale connection detection
    /// If no data received for 90 seconds, force reconnect
    private func startStaleConnectionDetection() {
        stopStaleConnectionDetection()

        let timer = DispatchSource.makeTimerSource(queue: bleQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                guard let lastData = self.connectionHealth.lastDataReceived else {
                    // No data ever received - might still be initializing
                    return
                }

                let secondsSinceLastData = Date().timeIntervalSince(lastData)

                if secondsSinceLastData > 90 {
                    self.logger.warning("Stale connection detected - no data for \(Int(secondsSinceLastData))s")
                    self.bleQueue.async {
                        self.forceReconnect()
                    }
                } else if secondsSinceLastData > 60 {
                    self.logger.warning("Data gap detected: \(Int(secondsSinceLastData))s since last packet")
                }
            }
        }
        timer.resume()
        staleConnectionTimer = timer

        logger.info("Stale connection detection started")
    }

    private func stopStaleConnectionDetection() {
        staleConnectionTimer?.cancel()
        staleConnectionTimer = nil
    }

    /// Force disconnect and immediate reconnect
    func forceReconnect() {
        guard let peripheral = heartRatePeripheral else { return }

        logger.info("Force reconnecting...")

        // Log the disconnect event
        connectionHealth.logDisconnectEvent(reason: "Stale connection - force reconnect")

        centralManager.cancelPeripheralConnection(peripheral)

        // Immediate reconnect (don't use exponential backoff for force reconnect)
        bleQueue.asyncAfter(deadline: .now() + 1) { [weak self, weak peripheral] in
            guard let self = self, let peripheral = peripheral else { return }
            self.updateState(.reconnecting)
            self.centralManager.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            logger.info("Bluetooth state: Unknown")
        case .resetting:
            logger.info("Bluetooth state: Resetting")
        case .unsupported:
            logger.error("Bluetooth state: Unsupported")
            DispatchQueue.main.async {
                self.lastError = .bluetoothUnavailable
            }
        case .unauthorized:
            logger.error("Bluetooth state: Unauthorized")
            DispatchQueue.main.async {
                self.lastError = .bluetoothUnauthorized
            }
        case .poweredOff:
            logger.warning("Bluetooth state: Powered Off")
            updateState(.disconnected)
        case .poweredOn:
            logger.info("Bluetooth state: Powered On")
            // Attempt auto-connect when Bluetooth becomes available
            attemptAutoConnect()
        @unknown default:
            logger.warning("Bluetooth state: Unknown default")
        }
    }

    func centralManager(_ central: CBCentralManager,
                       willRestoreState dict: [String: Any]) {
        logger.info("Restoring BLE state")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let peripheral = peripherals.first {
            heartRatePeripheral = peripheral
            heartRatePeripheral?.delegate = self
            shouldReconnect = true

            if peripheral.state == .connected {
                handleSuccessfulConnection(peripheral: peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        let discovered = BLEPeripheral(peripheral: peripheral, rssi: RSSI.intValue)
        logger.info("Discovered: \(discovered.name) (RSSI: \(RSSI))")

        // Check if this is the device we're looking for (auto-connect)
        if isAutoConnecting,
           let targetUUID = targetDeviceUUID,
           peripheral.identifier.uuidString == targetUUID {
            logger.info("Found target device for auto-connect")
            stopScanning()
            connect(to: discovered)
            return
        }

        // Otherwise, add to discovered list for manual selection
        DispatchQueue.main.async {
            if let index = self.discoveredPeripherals.firstIndex(where: { $0.id == discovered.id }) {
                self.discoveredPeripherals[index] = discovered
            } else {
                self.discoveredPeripherals.append(discovered)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "Unknown")")
        handleSuccessfulConnection(peripheral: peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        logger.error("Failed to connect: \(error?.localizedDescription ?? "Unknown")")
        DispatchQueue.main.async {
            self.lastError = .connectionFailed(error)
        }
        handleDisconnection()
    }

    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        logger.info("Disconnected from \(peripheral.name ?? "Unknown")")
        handleDisconnection()
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = .serviceNotFound
            }
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            logger.info("Discovered service: \(service.uuid)")

            if service.uuid == BLEConstants.heartRateServiceUUID {
                peripheral.discoverCharacteristics(
                    [BLEConstants.heartRateMeasurementCharacteristicUUID],
                    for: service
                )
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = .characteristicNotFound
            }
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            logger.info("Discovered characteristic: \(characteristic.uuid)")

            if characteristic.uuid == BLEConstants.heartRateMeasurementCharacteristicUUID {
                heartRateMeasurementCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logger.info("Subscribed to Heart Rate Measurement (2A37)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.error("Error updating value: \(error.localizedDescription)")
            return
        }

        guard characteristic.uuid == BLEConstants.heartRateMeasurementCharacteristicUUID,
              let data = characteristic.value else {
            return
        }

        // Track data reception for health monitoring
        DispatchQueue.main.async {
            self.connectionHealth.dataReceived()
        }

        // Stream raw data through Combine publisher
        heartRateDataSubject.send(data)
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateNotificationStateFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.error("Notification state error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = .notificationFailed(error)
            }
            return
        }

        logger.info("Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            logger.error("Error reading RSSI: \(error.localizedDescription)")
            return
        }

        DispatchQueue.main.async {
            self.connectionHealth.updateRSSI(RSSI.intValue)
        }
    }
}
