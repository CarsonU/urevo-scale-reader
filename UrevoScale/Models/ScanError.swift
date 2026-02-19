import Foundation

enum ScanError: LocalizedError, Equatable {
    case unauthorized
    case poweredOff
    case unsupported
    case resetting
    case unknown
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Bluetooth permission is denied."
        case .poweredOff:
            return "Bluetooth is turned off."
        case .unsupported:
            return "Bluetooth LE is not supported on this device."
        case .resetting:
            return "Bluetooth is resetting. Please wait."
        case .unknown:
            return "Bluetooth is currently unavailable."
        case .parsingFailed:
            return "Unable to decode scale advertisement data."
        }
    }
}
