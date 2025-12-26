//
//  BluetoothManager.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Bluetooth Low Energy manager for Uplift desk communication
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredDesks: [UpliftDesk] = []
    @Published var connectedDesk: UpliftDesk?
    @Published var isScanning = false
    @Published var currentHeight: Double = 0.0 // Height in inches
    @Published var isMoving = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isAutoConnecting = false
    @Published var autoConnectEnabled = true

    // MARK: - BLE UUIDs
    // Updated to match the actual desk UUIDs
    private let primaryServiceUUID = CBUUID(string: "FF00")  // Changed from FE60
    private let heightCharacteristicUUID = CBUUID(string: "FF02")  // Changed from FE62
    private let controlCharacteristicUUID = CBUUID(string: "FF01")  // Changed from FE61

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var heightCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?

    // Keep strong references to peripherals so they don't get deallocated
    private var peripherals: [UUID: CBPeripheral] = [:]

    // Auto-reconnect
    private var lastConnectedDeskUUID: UUID?
    private let lastConnectedDeskKey = "lastConnectedDeskUUID"
    private let autoConnectEnabledKey = "autoConnectEnabled"

    // Movement detection
    private var heightHistory: [Double] = []
    private let movementWindowSize = 4
    private var movementStartTime: Date?
    private let minimumMovementDuration: TimeInterval = 1.0

    // MARK: - Initialization
    override init() {
        super.init()
        loadSavedSettings()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func loadSavedSettings() {
        // Load last connected desk UUID
        if let uuidString = UserDefaults.standard.string(forKey: lastConnectedDeskKey),
           let uuid = UUID(uuidString: uuidString) {
            lastConnectedDeskUUID = uuid
            print("📱 Loaded last connected desk: \(uuid)")
        }

        // Load auto-connect preference
        if UserDefaults.standard.object(forKey: autoConnectEnabledKey) != nil {
            autoConnectEnabled = UserDefaults.standard.bool(forKey: autoConnectEnabledKey)
        }
    }

    private func saveLastConnectedDesk(_ uuid: UUID) {
        lastConnectedDeskUUID = uuid
        UserDefaults.standard.set(uuid.uuidString, forKey: lastConnectedDeskKey)
        print("💾 Saved last connected desk: \(uuid)")
    }

    // MARK: - Public Methods

    func startAutoConnect() {
        guard autoConnectEnabled,
              let lastUUID = lastConnectedDeskUUID,
              centralManager.state == .poweredOn,
              connectedDesk == nil else {
            return
        }

        print("🔄 Starting auto-connect to last desk: \(lastUUID)")
        isAutoConnecting = true

        // Check if we already have the peripheral from a previous session
        if let knownPeripheral = centralManager.retrievePeripherals(withIdentifiers: [lastUUID]).first {
            print("✅ Found known peripheral, attempting direct connection...")
            peripherals[lastUUID] = knownPeripheral
            centralManager.connect(knownPeripheral, options: nil)

            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if self?.isAutoConnecting == true && self?.connectedDesk == nil {
                    print("⏱️ Auto-connect timeout, starting scan...")
                    self?.startScanning()
                }
            }
        } else {
            // Start scanning to find the desk
            print("🔍 Peripheral not found in cache, starting scan...")
            startScanning()
        }
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on")
            return
        }

        discoveredDesks.removeAll()
        isScanning = true

        // Scan for ALL peripherals (no service filter) to debug
        print("🔍 Starting BLE scan for all devices...")
        centralManager.scanForPeripherals(
            withServices: nil,  // Changed: scan for ALL devices
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        print("🛑 Scan stopped. Found \(discoveredDesks.count) device(s)")
    }

    func connect(to desk: UpliftDesk) {
        // Get peripheral from desk or from our stored peripherals
        let peripheral: CBPeripheral
        if let deskPeripheral = desk.peripheral {
            peripheral = deskPeripheral
        } else if let storedPeripheral = peripherals[desk.id] {
            print("⚠️ Using stored peripheral reference")
            peripheral = storedPeripheral
        } else {
            print("❌ Cannot connect: peripheral not found")
            print("   Desk UUID: \(desk.id)")
            print("   Stored peripherals: \(peripherals.keys.map { $0.uuidString })")
            return
        }

        print("🔌 Attempting to connect to: \(desk.name)")
        print("   Peripheral UUID: \(peripheral.identifier)")
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let desk = connectedDesk else { return }

        // Get peripheral from desk or from our stored peripherals
        if let peripheral = desk.peripheral ?? peripherals[desk.id] {
            print("🔌 Disconnecting from: \(desk.name)")
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            print("❌ Cannot disconnect: peripheral not found")
        }
    }

    // MARK: - Desk Control Commands

    func wakeDesk() {
        let command: [UInt8] = [0xf1, 0xf1, 0x00, 0x00, 0x00, 0x7e]
        sendCommand(command)
    }

    func moveToStanding() {
        wakeDesk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let command: [UInt8] = [0xf1, 0xf1, 0x06, 0x00, 0x06, 0x7e]
            self?.sendCommand(command)
        }
    }

    func moveToSitting() {
        wakeDesk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let command: [UInt8] = [0xf1, 0xf1, 0x05, 0x00, 0x05, 0x7e]
            self?.sendCommand(command)
        }
    }

    func pressRaise() {
        wakeDesk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let command: [UInt8] = [0xf1, 0xf1, 0x01, 0x00, 0x01, 0x7e]
            self?.sendCommand(command)
        }
    }

    func pressLower() {
        wakeDesk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let command: [UInt8] = [0xf1, 0xf1, 0x02, 0x00, 0x02, 0x7e]
            self?.sendCommand(command)
        }
    }

    func stopMovement() {
        // Send stop command (0x2B is typically stop in many desk protocols)
        wakeDesk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let command: [UInt8] = [0xf1, 0xf1, 0x2B, 0x00, 0x2B, 0x7e]
            self?.sendCommand(command)
        }
    }

    func readHeight() {
        let command: [UInt8] = [0xf1, 0xf1, 0x07, 0x00, 0x07, 0x7e]
        sendCommand(command)
    }

    // MARK: - Private Methods

    private func sendCommand(_ command: [UInt8]) {
        guard let characteristic = controlCharacteristic,
              let peripheral = connectedDesk?.peripheral else {
            print("Cannot send command: desk not connected or characteristic not found")
            return
        }

        let data = Data(command)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func processHeightUpdate(_ data: Data) {
        // Convert raw BLE data to height in inches
        // Based on the Python implementation, we need to convert the raw value
        guard data.count >= 2 else { return }

        let bytes = [UInt8](data)
        let rawHeight = UInt16(bytes[1]) << 8 | UInt16(bytes[0])
        let heightInInches = Double(rawHeight) / 100.0 // Assuming raw value is in 0.01 inch units

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentHeight = heightInInches
            self.detectMovement(heightInInches)
        }
    }

    private func detectMovement(_ height: Double) {
        heightHistory.append(height)

        // Keep only the last N samples
        if heightHistory.count > movementWindowSize {
            heightHistory.removeFirst()
        }

        // Check if we have enough samples
        guard heightHistory.count == movementWindowSize else {
            return
        }

        // Check if all values in the window are the same
        let allSame = heightHistory.allSatisfy { abs($0 - heightHistory.first!) < 0.01 }

        if allSame {
            // Check if minimum movement duration has passed
            if let startTime = movementStartTime,
               Date().timeIntervalSince(startTime) >= minimumMovementDuration {
                isMoving = false
                movementStartTime = nil
            }
        } else {
            // Movement detected
            if !isMoving {
                movementStartTime = Date()
            }
            isMoving = true
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothState = central.state
        }

        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Trigger auto-connect if enabled
            if autoConnectEnabled && lastConnectedDeskUUID != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startAutoConnect()
                }
            }
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is not supported")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Enhanced logging to help identify the desk
        print("📡 Found device: \(peripheral.name ?? "Unknown")")
        print("   UUID: \(peripheral.identifier)")
        print("   RSSI: \(RSSI) dBm")

        // Print advertised services
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("   Services: \(serviceUUIDs.map { $0.uuidString }.joined(separator: ", "))")
        } else {
            print("   Services: None advertised")
        }

        // Print manufacturer data if available
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            print("   Manufacturer Data: \(manufacturerData.map { String(format: "%02x", $0) }.joined())")
        }

        // Print local name if different from peripheral name
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("   Local Name: \(localName)")
        }

        print("---")

        // Store strong reference to peripheral so it doesn't get deallocated
        peripherals[peripheral.identifier] = peripheral

        let desk = UpliftDesk(peripheral: peripheral, rssi: RSSI.intValue)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.discoveredDesks.contains(where: { $0.id == desk.id }) {
                self.discoveredDesks.append(desk)
            }

            // Auto-connect if this is the saved desk
            if self.isAutoConnecting,
               let lastUUID = self.lastConnectedDeskUUID,
               peripheral.identifier == lastUUID {
                print("🎯 Found saved desk! Auto-connecting...")
                self.stopScanning()
                self.connect(to: desk)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral: \(peripheral.name ?? "Unknown")")
        print("   Starting service discovery...")

        // Save this as the last connected desk
        saveLastConnectedDesk(peripheral.identifier)

        // Clear auto-connecting flag
        isAutoConnecting = false

        peripheral.delegate = self

        // Try discovering services without filter first to see what's available
        peripheral.discoverServices(nil)  // Changed: discover ALL services
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral")
        DispatchQueue.main.async { [weak self] in
            self?.connectedDesk = nil
            self?.heightCharacteristic = nil
            self?.controlCharacteristic = nil
            self?.isMoving = false
            self?.heightHistory.removeAll()
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        print("   Peripheral: \(peripheral.name ?? "Unknown")")
        print("   UUID: \(peripheral.identifier)")
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }

        print("🔍 Found \(services.count) service(s):")
        for service in services {
            print("   Service: \(service.uuid.uuidString)")

            // Discover characteristics for ALL services to see what's available
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("❌ Error discovering characteristics: \(error!.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found for service \(service.uuid.uuidString)")
            return
        }

        print("📋 Service \(service.uuid.uuidString) has \(characteristics.count) characteristic(s):")
        for characteristic in characteristics {
            print("   Characteristic: \(characteristic.uuid.uuidString)")
            print("      Properties: \(characteristicPropertiesString(characteristic.properties))")

            // Check if this is our height characteristic
            if characteristic.uuid == heightCharacteristicUUID {
                heightCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("   ✅ Height characteristic found and subscribed!")
            }
            // Check if this is our control characteristic
            else if characteristic.uuid == controlCharacteristicUUID {
                controlCharacteristic = characteristic
                print("   ✅ Control characteristic found!")
            }
        }

        // If we found both characteristics, update connected desk
        if heightCharacteristic != nil && controlCharacteristic != nil {
            print("🎉 All required characteristics found! Connection complete.")

            // Update connected desk
            if let desk = discoveredDesks.first(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                DispatchQueue.main.async { [weak self] in
                    self?.connectedDesk = desk
                    print("✅ UI updated: desk connected")
                }
            } else {
                let desk = UpliftDesk(peripheral: peripheral, rssi: 0)
                DispatchQueue.main.async { [weak self] in
                    self?.connectedDesk = desk
                    print("✅ UI updated: desk connected (new)")
                }
            }

            // Read initial height
            readHeight()
        } else {
            print("⚠️ Still missing characteristics:")
            print("   Height: \(heightCharacteristic != nil ? "✅" : "❌")")
            print("   Control: \(controlCharacteristic != nil ? "✅" : "❌")")
        }
    }

    // Helper function to describe characteristic properties
    private func characteristicPropertiesString(_ properties: CBCharacteristicProperties) -> String {
        var props: [String] = []
        if properties.contains(.read) { props.append("read") }
        if properties.contains(.write) { props.append("write") }
        if properties.contains(.writeWithoutResponse) { props.append("writeNoResp") }
        if properties.contains(.notify) { props.append("notify") }
        if properties.contains(.indicate) { props.append("indicate") }
        return props.isEmpty ? "none" : props.joined(separator: ", ")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error reading characteristic: \(error!.localizedDescription)")
            return
        }

        if characteristic.uuid == heightCharacteristicUUID {
            guard let data = characteristic.value else { return }
            processHeightUpdate(data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
        }
    }
}
