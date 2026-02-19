import CoreBluetooth
import Foundation

final class BluetoothScaleService: NSObject, ScaleScanner {
    let readings: AsyncStream<Double>
    let state: AsyncStream<ScanState>

    private var readingContinuation: AsyncStream<Double>.Continuation?
    private var stateContinuation: AsyncStream<ScanState>.Continuation?

    private let userDefaults: UserDefaults
    private let managerQueue = DispatchQueue(label: "urevo.bluetooth.queue")

    private var centralManager: CBCentralManager!
    private var shouldScan = false

    init(userDefaults: UserDefaults = .standard) {
        var readingContinuation: AsyncStream<Double>.Continuation?
        let readings = AsyncStream<Double> { continuation in
            readingContinuation = continuation
        }

        var stateContinuation: AsyncStream<ScanState>.Continuation?
        let state = AsyncStream<ScanState> { continuation in
            stateContinuation = continuation
        }

        self.readings = readings
        self.state = state
        self.readingContinuation = readingContinuation
        self.stateContinuation = stateContinuation
        self.userDefaults = userDefaults

        super.init()

        centralManager = CBCentralManager(delegate: self, queue: managerQueue)
        self.stateContinuation?.yield(.idle)
    }

    deinit {
        readingContinuation?.finish()
        stateContinuation?.finish()
    }

    func startScanning() {
        managerQueue.async {
            self.shouldScan = true
            self.evaluateCentralStateForScanning()
        }
    }

    func stopScanning() {
        managerQueue.async {
            self.shouldScan = false
            if self.centralManager.isScanning {
                self.centralManager.stopScan()
            }
            self.stateContinuation?.yield(.idle)
        }
    }

    func resetPinnedScale() {
        userDefaults.removeObject(forKey: AppDefaults.pinnedPeripheralID)
    }

    private var pinnedPeripheralID: UUID? {
        get {
            guard let raw = userDefaults.string(forKey: AppDefaults.pinnedPeripheralID) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            userDefaults.set(newValue?.uuidString, forKey: AppDefaults.pinnedPeripheralID)
        }
    }

    private func evaluateCentralStateForScanning() {
        guard shouldScan else {
            return
        }

        switch centralManager.state {
        case .poweredOn:
            beginScanningIfNeeded()
        case .poweredOff:
            stateContinuation?.yield(.error(.poweredOff))
        case .unauthorized:
            stateContinuation?.yield(.error(.unauthorized))
        case .unsupported:
            stateContinuation?.yield(.error(.unsupported))
        case .resetting:
            stateContinuation?.yield(.error(.resetting))
        case .unknown:
            stateContinuation?.yield(.bluetoothUnavailable)
        @unknown default:
            stateContinuation?.yield(.error(.unknown))
        }
    }

    private func beginScanningIfNeeded() {
        guard !centralManager.isScanning else {
            stateContinuation?.yield(.scanning)
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        stateContinuation?.yield(.scanning)
    }

    private func shouldAccept(peripheralID: UUID) -> Bool {
        if let pinnedPeripheralID {
            return pinnedPeripheralID == peripheralID
        }
        pinnedPeripheralID = peripheralID
        return true
    }

    private func processDiscovery(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let manufacturerBlob = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data

        guard
            let manufacturerBlob,
            let parsed = ScaleProtocolDecoder.parseCompanyIdAndPayload(from: manufacturerBlob)
        else {
            return
        }

        guard
            ScaleProtocolDecoder.isCandidate(localName: localName, manufacturerData: parsed.payload),
            shouldAccept(peripheralID: peripheral.identifier),
            let weight = ScaleProtocolDecoder.decodeWeight(
                companyId: parsed.companyId,
                manufacturerData: parsed.payload
            )
        else {
            return
        }

        readingContinuation?.yield(weight)
    }
}

extension BluetoothScaleService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        evaluateCentralStateForScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        processDiscovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
}
