import SwiftData
import SwiftUI

@main
struct UrevoScaleApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appState: AppStateStore

    init() {
        let container = PersistenceController.shared
        let repository = WeightRepository(container: container)
        let csvService = CSVService(repository: repository)
        let scanner = BluetoothScaleService()
        let healthKitService = HealthKitService()
        let stabilizer = WeightStabilizer()

        self.modelContainer = container
        _appState = StateObject(
            wrappedValue: AppStateStore(
                scanner: scanner,
                stabilizer: stabilizer,
                repository: repository,
                csvService: csvService,
                healthKitService: healthKitService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .modelContainer(modelContainer)
    }
}
