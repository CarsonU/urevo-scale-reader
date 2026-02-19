import Foundation
import HealthKit
import SwiftData
import XCTest
@testable import UrevoScale

@MainActor
final class AppStateStoreIntegrationTests: XCTestCase {
    func testAutoScanStartsOnLaunch() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0)
        )

        store.handleAppLaunch()

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(scanner.didStartScanning)
    }

    func testOneSettledEventCreatesOneEntry() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0)
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 179.9)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 150_000_000)

        let entries = try store.repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightLbs, 180.0, accuracy: 0.1)
    }

    func testPostIdleSecondWeighInCreatesSecondEntry() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 3, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 0.1)
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 250_000_000)

        scanner.emit(weight: 181.0)
        scanner.emit(weight: 181.1)
        scanner.emit(weight: 181.0)

        try await Task.sleep(nanoseconds: 200_000_000)

        let entries = try store.repository.fetchAll()
        XCTAssertEqual(entries.count, 2)
    }

    private func makeStore(
        scanner: MockScaleScanner,
        stabilizerConfig: StabilizerConfig
    ) -> AppStateStore {
        let suite = "AppStateStoreIntegrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: AppDefaults.hasSeenOnboarding)
        defaults.set(true, forKey: AppDefaults.didAttemptAutoHealthKitPrompt)

        let repository = WeightRepository(container: PersistenceController.makeContainer(inMemory: true))
        let csvService = CSVService(repository: repository)
        let healthKit = MockHealthKitService()

        return AppStateStore(
            scanner: scanner,
            stabilizer: WeightStabilizer(config: stabilizerConfig),
            repository: repository,
            csvService: csvService,
            healthKitService: healthKit,
            userDefaults: defaults
        )
    }
}

final class MockScaleScanner: ScaleScanner {
    let readings: AsyncStream<Double>
    let state: AsyncStream<ScanState>

    private var readingContinuation: AsyncStream<Double>.Continuation?
    private var stateContinuation: AsyncStream<ScanState>.Continuation?

    private(set) var didStartScanning = false

    init() {
        var readingContinuation: AsyncStream<Double>.Continuation?
        readings = AsyncStream<Double> { continuation in
            readingContinuation = continuation
        }

        var stateContinuation: AsyncStream<ScanState>.Continuation?
        state = AsyncStream<ScanState> { continuation in
            stateContinuation = continuation
        }

        self.readingContinuation = readingContinuation
        self.stateContinuation = stateContinuation
    }

    func startScanning() {
        didStartScanning = true
        stateContinuation?.yield(.scanning)
    }

    func stopScanning() {
        stateContinuation?.yield(.idle)
    }

    func resetPinnedScale() {}

    func emit(weight: Double) {
        readingContinuation?.yield(weight)
    }
}

final class MockHealthKitService: HealthKitServicing {
    var isHealthDataAvailable: Bool = true
    var bodyMassAuthorizationStatus: HKAuthorizationStatus = .notDetermined

    func requestAuthorization() async throws -> Bool {
        bodyMassAuthorizationStatus = .sharingDenied
        return false
    }

    func saveBodyMass(weightLbs _: Double, at _: Date) async throws {}
}
