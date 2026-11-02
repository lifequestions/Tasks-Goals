import CoreBluetooth
import Foundation

/// Finds the bike, connects to its Bluetooth serial service and sends commands.
final class BikeManager: NSObject, ObservableObject {
    enum Status: Equatable {
        case bluetoothOff, idle, scanning, connecting, ready, sending
    }

    struct Found: Identifiable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
        var rssi: Int
        var looksLikeCowboy: Bool { name.lowercased().contains("cowboy") }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var found: [Found] = []
    @Published private(set) var connectedName: String?
    @Published private(set) var log: [String] = []

    static let uartService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristic = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharacteristic = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private var central: CBCentralManager!
    private var bike: CBPeripheral?
    private var rx: CBCharacteristic?
    private var failedInSend = false
    private var acceptedInSend = 0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool { status == .ready || status == .sending }

    func scan() {
        guard central.state == .poweredOn else { status = .bluetoothOff; return }
        found = []
        status = .scanning
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        note("Looking for bikes…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.status == .scanning else { return }
            self.central.stopScan()
            self.status = .idle
        }
    }

    func connect(_ item: Found) {
        central.stopScan()
        status = .connecting
        bike = item.peripheral
        item.peripheral.delegate = self
        central.connect(item.peripheral)
        note("Connecting to \(item.name)…")
    }

    func disconnect() {
        if let bike { central.cancelPeripheralConnection(bike) }
    }

    /// Sends commands one by one with a short gap so the controller can keep up.
    struct SendResult {
        let sent: Int
        /// How many commands the bike answered with "accepted".
        let accepted: Int
        /// False if the bike refused a command or a write failed.
        let ok: Bool
    }

    func send(_ commands: [Command], then done: ((SendResult) -> Void)? = nil) {
        guard let bike, let rx, status == .ready else {
            note("Not connected to a bike.")
            return
        }
        status = .sending
        failedInSend = false
        acceptedInSend = 0
        let type: CBCharacteristicWriteType =
            rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        for (index, command) in commands.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                guard let self, self.bike === bike else { return }
                bike.writeValue(command.data, for: rx, type: type)
                self.note("Sent: \(command.label)")
                if index == commands.count - 1 {
                    // Give the bike a moment to answer the last command.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self else { return }
                        if self.status == .sending { self.status = .ready }
                        done?(SendResult(sent: commands.count, accepted: self.acceptedInSend, ok: !self.failedInSend))
                    }
                }
            }
        }
    }

    private func note(_ line: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        log.insert("\(time)  \(line)", at: 0)
        if log.count > 100 { log.removeLast() }
    }

    private func reset() {
        bike = nil
        rx = nil
        connectedName = nil
        status = central.state == .poweredOn ? .idle : .bluetoothOff
    }
}

extension BikeManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if status == .bluetoothOff { status = .idle }
        } else {
            reset()
            status = .bluetoothOff
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let name, !name.isEmpty else { return }
        if let i = found.firstIndex(where: { $0.id == peripheral.identifier }) {
            found[i].rssi = RSSI.intValue
        } else {
            found.append(Found(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue))
        }
        found.sort { ($0.looksLikeCowboy ? 1 : 0, $0.rssi) > ($1.looksLikeCowboy ? 1 : 0, $1.rssi) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedName = peripheral.name
        peripheral.discoverServices([Self.uartService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        note("Couldn't connect: \(error?.localizedDescription ?? "unknown error")")
        reset()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        note("Disconnected.")
        reset()
    }
}

extension BikeManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.uartService }) else {
            note("This device doesn't have the bike's settings service. Is it your Cowboy?")
            disconnect()
            return
        }
        peripheral.discoverCharacteristics([Self.rxCharacteristic, Self.txCharacteristic], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.rxCharacteristic { rx = characteristic }
            if characteristic.uuid == Self.txCharacteristic { peripheral.setNotifyValue(true, for: characteristic) }
        }
        if rx != nil {
            status = .ready
            note("Connected to \(peripheral.name ?? "bike").")
        } else {
            note("Couldn't find the bike's settings channel.")
            disconnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let bytes = characteristic.value.map({ [UInt8]($0) }), bytes.count >= 2, bytes[0] == 0x01 else { return }
        // The controller echoes 0x10 when a write worked and 0x90 when it refused one.
        if bytes[1] == 0x10 { acceptedInSend += 1; note("Bike accepted the change.") }
        if bytes[1] == 0x90 { failedInSend = true; note("Bike refused the change.") }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { failedInSend = true; note("Write failed: \(error.localizedDescription)") }
    }
}
