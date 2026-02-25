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

    func testFirstStableWindowEmitsConfirmingState() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(
                windowSize: 4,
                toleranceLbs: 0.3,
                minWeightLbs: 5.0,
                idleTimeoutSec: 3.0,
                confirmDurationSec: 1.0,
                confirmToleranceLbs: 0.2,
                confirmMinSamples: 6
            )
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 179.9)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 100_000_000)

        guard case let .confirming(current, progress) = store.scanState else {
            XCTFail("Expected confirming state")
            return
        }

        XCTAssertEqual(current, 180.0, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThan(progress, 1.0)
    }

    func testOneSettledEventCreatesOneEntryAndShowsConfirmation() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(
                windowSize: 4,
                toleranceLbs: 0.3,
                minWeightLbs: 5.0,
                idleTimeoutSec: 3.0,
                confirmDurationSec: 0.0,
                confirmToleranceLbs: 0.2,
                confirmMinSamples: 4
            )
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 179.9)
        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 150_000_000)

        let entries = try store.repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightLbs ?? 0, 180.0, accuracy: 0.1)
        XCTAssertTrue(store.isShowingSavedConfirmation)
        XCTAssertNotNil(store.savedConfirmation)
    }

    func testSavedConfirmationAutoHidesAfterTimeout() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(
                windowSize: 4,
                toleranceLbs: 0.3,
                minWeightLbs: 5.0,
                idleTimeoutSec: 3.0,
                confirmDurationSec: 0.0,
                confirmToleranceLbs: 0.2,
                confirmMinSamples: 4
            )
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 179.9)
        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(store.isShowingSavedConfirmation)

        store.stopScanning()
        store.startScanningIfNeeded()
        XCTAssertTrue(store.isShowingSavedConfirmation)

        try await Task.sleep(nanoseconds: 4_200_000_000)
        XCTAssertFalse(store.isShowingSavedConfirmation)
    }

    func testPostIdleSecondWeighInCreatesSecondEntryAndUpdatesConfirmation() async throws {
        let scanner = MockScaleScanner()
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(
                windowSize: 3,
                toleranceLbs: 0.3,
                minWeightLbs: 5.0,
                idleTimeoutSec: 0.1,
                confirmDurationSec: 0.0,
                confirmToleranceLbs: 0.2,
                confirmMinSamples: 3
            )
        )

        store.startScanningIfNeeded()

        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.1)
        scanner.emit(weight: 180.0)
        scanner.emit(weight: 180.0)

        try await Task.sleep(nanoseconds: 250_000_000)

        scanner.emit(weight: 181.0)
        scanner.emit(weight: 181.1)
        scanner.emit(weight: 181.0)
        scanner.emit(weight: 181.0)

        try await Task.sleep(nanoseconds: 250_000_000)

        let entries = try store.repository.fetchAll()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(store.savedConfirmation?.weightLbs ?? 0, 181.0, accuracy: 0.2)
        XCTAssertTrue(store.isShowingSavedConfirmation)
    }

    func testManualHealthKitExportAddsMissingAndSkipsExistingSamples() async throws {
        let scanner = MockScaleScanner()
        let healthKit = MockHealthKitService()
        healthKit.bodyMassAuthorizationStatus = .sharingAuthorized
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0),
            healthKit: healthKit
        )

        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let secondTimestamp = Date(timeIntervalSince1970: 1_700_000_060)

        _ = try store.repository.save(weightLbs: 180.0, timestamp: firstTimestamp, source: .csvImport)
        _ = try store.repository.save(weightLbs: 181.2, timestamp: secondTimestamp, source: .live)

        healthKit.existingSamples = [
            BodyMassSample(timestamp: firstTimestamp, weightLbs: 180.0)
        ]

        await store.exportAllRecordsToHealthKit()

        XCTAssertEqual(healthKit.savedSamples.count, 1)
        XCTAssertEqual(healthKit.savedSamples.first?.timestamp, secondTimestamp)
        XCTAssertEqual(healthKit.savedSamples.first?.weightLbs ?? 0, 181.2, accuracy: 0.01)
        XCTAssertEqual(store.statusMessage, "Apple Health export complete: added 1, skipped 1, failed 0.")
        XCTAssertNil(store.healthKitErrorMessage)
    }

    func testManualHealthKitExportRequestsAuthorizationWhenNeeded() async throws {
        let scanner = MockScaleScanner()
        let healthKit = MockHealthKitService()
        healthKit.bodyMassAuthorizationStatus = .notDetermined
        healthKit.requestAuthorizationResult = true
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0),
            healthKit: healthKit
        )

        _ = try store.repository.save(
            weightLbs: 182.0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_120),
            source: .csvImport
        )

        await store.exportAllRecordsToHealthKit()

        XCTAssertEqual(healthKit.requestAuthorizationCallCount, 1)
        XCTAssertEqual(healthKit.bodyMassAuthorizationStatus, .sharingAuthorized)
        XCTAssertEqual(healthKit.savedSamples.count, 1)
        XCTAssertEqual(store.statusMessage, "Apple Health export complete: added 1, skipped 0, failed 0.")
        XCTAssertNil(store.healthKitErrorMessage)
    }

    func testManualHealthKitExportAbortsWhenAuthorizationDenied() async throws {
        let scanner = MockScaleScanner()
        let healthKit = MockHealthKitService()
        healthKit.bodyMassAuthorizationStatus = .notDetermined
        healthKit.requestAuthorizationResult = false
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0),
            healthKit: healthKit
        )

        _ = try store.repository.save(
            weightLbs: 183.0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_180),
            source: .csvImport
        )

        await store.exportAllRecordsToHealthKit()

        XCTAssertEqual(healthKit.requestAuthorizationCallCount, 1)
        XCTAssertTrue(healthKit.savedSamples.isEmpty)
        XCTAssertEqual(store.statusMessage, "HealthKit authorization is required to export.")
        XCTAssertEqual(store.healthKitErrorMessage, "HealthKit access was not granted.")
    }

    func testManualHealthKitExportContinuesWhenOneSaveFails() async throws {
        let scanner = MockScaleScanner()
        let healthKit = MockHealthKitService()
        healthKit.bodyMassAuthorizationStatus = .sharingAuthorized
        let store = makeStore(
            scanner: scanner,
            stabilizerConfig: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0),
            healthKit: healthKit
        )

        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_240)
        let secondTimestamp = Date(timeIntervalSince1970: 1_700_000_300)
        let thirdTimestamp = Date(timeIntervalSince1970: 1_700_000_360)

        _ = try store.repository.save(weightLbs: 180.0, timestamp: firstTimestamp, source: .csvImport)
        _ = try store.repository.save(weightLbs: 181.0, timestamp: secondTimestamp, source: .csvImport)
        _ = try store.repository.save(weightLbs: 182.0, timestamp: thirdTimestamp, source: .csvImport)

        healthKit.saveErrorsByKey[
            MockHealthKitService.SaveKey(timestamp: secondTimestamp, weightLbs: 181.0)
        ] = MockHealthKitService.MockError.forcedSaveFailure

        await store.exportAllRecordsToHealthKit()

        XCTAssertEqual(healthKit.savedSamples.count, 2)
        XCTAssertEqual(store.statusMessage, "Apple Health export complete: added 2, skipped 0, failed 1.")
        XCTAssertEqual(store.healthKitErrorMessage, "Apple Health export completed with 1 failure(s). Last error: Forced save failure.")
    }

    private func makeStore(
        scanner: MockScaleScanner,
        stabilizerConfig: StabilizerConfig,
        healthKit: MockHealthKitService = MockHealthKitService()
    ) -> AppStateStore {
        let suite = "AppStateStoreIntegrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: AppDefaults.hasSeenOnboarding)
        defaults.set(true, forKey: AppDefaults.didAttemptAutoHealthKitPrompt)

        let repository = WeightRepository(container: PersistenceController.makeContainer(inMemory: true))
        let csvService = CSVService(repository: repository)

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
    struct SaveKey: Hashable {
        let timestampSeconds: Int
        let weightTenths: Int

        init(timestamp: Date, weightLbs: Double) {
            self.timestampSeconds = Int(timestamp.timeIntervalSince1970)
            self.weightTenths = Int((WeightFormatting.roundToTenth(weightLbs) * 10).rounded())
        }
    }

    enum MockError: LocalizedError {
        case forcedSaveFailure

        var errorDescription: String? {
            switch self {
            case .forcedSaveFailure:
                return "Forced save failure."
            }
        }
    }

    var isHealthDataAvailable: Bool = true
    var bodyMassAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = false
    var requestAuthorizationCallCount = 0
    var existingSamples: [BodyMassSample] = []
    var savedSamples: [BodyMassSample] = []
    var saveErrorsByKey: [SaveKey: Error] = [:]

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        if requestAuthorizationResult {
            bodyMassAuthorizationStatus = .sharingAuthorized
            return true
        }

        bodyMassAuthorizationStatus = .sharingDenied
        return false
    }

    func fetchBodyMassSamples(from startDate: Date, to endDate: Date) async throws -> [BodyMassSample] {
        let lowerBound = min(startDate, endDate)
        let upperBound = max(startDate, endDate)

        return existingSamples.filter {
            $0.timestamp >= lowerBound && $0.timestamp <= upperBound
        }
    }

    func saveBodyMass(weightLbs: Double, at date: Date) async throws {
        let key = SaveKey(timestamp: date, weightLbs: weightLbs)
        if let error = saveErrorsByKey[key] {
            throw error
        }

        savedSamples.append(
            BodyMassSample(
                timestamp: date,
                weightLbs: WeightFormatting.roundToTenth(weightLbs)
            )
        )
    }
}
