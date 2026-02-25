import Foundation

enum TrendRangePreset: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sevenDays:
            return "7d"
        case .thirtyDays:
            return "30d"
        case .ninetyDays:
            return "90d"
        case .oneYear:
            return "1y"
        case .all:
            return "All"
        }
    }

    func startDate(relativeTo referenceDate: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: referenceDate)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: referenceDate)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate)
        case .all:
            return nil
        }
    }
}
