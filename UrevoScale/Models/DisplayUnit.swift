import Foundation

enum DisplayUnit: String, CaseIterable, Identifiable {
    case lbs
    case kg

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lbs:
            return "Pounds (lbs)"
        case .kg:
            return "Kilograms (kg)"
        }
    }

    var symbol: String {
        switch self {
        case .lbs:
            return "lbs"
        case .kg:
            return "kg"
        }
    }

    func fromLbs(_ value: Double) -> Double {
        switch self {
        case .lbs:
            return value
        case .kg:
            return value * 0.45359237
        }
    }

    func toLbs(_ value: Double) -> Double {
        switch self {
        case .lbs:
            return value
        case .kg:
            return value / 0.45359237
        }
    }
}
