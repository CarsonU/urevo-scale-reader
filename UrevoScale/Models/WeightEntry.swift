import Foundation
import SwiftData

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var weightLbs: Double
    private var sourceValue: String
    var createdAt: Date
    var updatedAt: Date

    var source: EntrySource {
        get { EntrySource(rawValue: sourceValue) ?? .live }
        set { sourceValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        weightLbs: Double,
        source: EntrySource,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightLbs = weightLbs
        self.sourceValue = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension WeightEntry: Identifiable {}
