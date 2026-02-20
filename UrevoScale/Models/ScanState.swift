import Foundation

enum ScanState: Equatable {
    case idle
    case scanning
    case measuring(current: Double, samples: Int)
    case confirming(current: Double, progress: Double)
    case settled(weight: Double)
    case error(ScanError)
    case bluetoothUnavailable
}
