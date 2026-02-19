import Foundation
import SwiftData

@MainActor
protocol WeightRepositoryProtocol {
    @discardableResult
    func save(weightLbs: Double, timestamp: Date, source: EntrySource) throws -> WeightEntry
    func fetchAll() throws -> [WeightEntry]
    func delete(_ entry: WeightEntry) throws
    func update(_ entry: WeightEntry, timestamp: Date, weightLbs: Double) throws
    func hasDuplicate(timestamp: Date, weightLbs: Double) throws -> Bool
}

@MainActor
final class WeightRepository: WeightRepositoryProtocol {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext {
        container.mainContext
    }

    @discardableResult
    func save(weightLbs: Double, timestamp: Date, source: EntrySource) throws -> WeightEntry {
        let entry = WeightEntry(
            timestamp: timestamp,
            weightLbs: WeightFormatting.roundToTenth(weightLbs),
            source: source,
            createdAt: Date(),
            updatedAt: Date()
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func fetchAll() throws -> [WeightEntry] {
        var descriptor = FetchDescriptor<WeightEntry>()
        descriptor.sortBy = [SortDescriptor(\WeightEntry.timestamp, order: .reverse)]
        return try context.fetch(descriptor)
    }

    func delete(_ entry: WeightEntry) throws {
        context.delete(entry)
        try context.save()
    }

    func update(_ entry: WeightEntry, timestamp: Date, weightLbs: Double) throws {
        entry.timestamp = timestamp
        entry.weightLbs = WeightFormatting.roundToTenth(weightLbs)
        entry.updatedAt = Date()
        try context.save()
    }

    func hasDuplicate(timestamp: Date, weightLbs: Double) throws -> Bool {
        let allEntries = try fetchAll()
        let targetSecond = Int(timestamp.timeIntervalSince1970)
        let targetWeight = WeightFormatting.roundToTenth(weightLbs)

        return allEntries.contains {
            Int($0.timestamp.timeIntervalSince1970) == targetSecond
                && WeightFormatting.roundToTenth($0.weightLbs) == targetWeight
        }
    }
}
