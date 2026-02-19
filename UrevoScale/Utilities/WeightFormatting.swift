import Foundation

enum WeightFormatting {
    static func roundToTenth(_ value: Double) -> Double {
        (value * 10.0).rounded() / 10.0
    }

    static func string(for weightLbs: Double, unit: DisplayUnit) -> String {
        let converted = unit.fromLbs(weightLbs)
        return String(format: "%.1f %@", converted, unit.symbol)
    }
}
