import Foundation
import SwiftData

enum PersistenceController {
    static let shared: ModelContainer = {
        makeContainer(inMemory: false)
    }()

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: WeightEntry.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
}
