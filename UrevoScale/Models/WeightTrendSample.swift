import Foundation

struct WeightTrendSample: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let weightLbs: Double
}

struct WeightTrendStats: Equatable {
    let count: Int
    let averageLbs: Double?
    let minimumLbs: Double?
    let maximumLbs: Double?
    let netChangeLbs: Double?
    let netChangePercent: Double?
}
