import Foundation
import HealthKit
import SwiftUI

@MainActor
final class AppStateStore: ObservableObject {
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var noScaleDetected = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var healthKitErrorMessage: String?
    @Published private(set) var importResult: ImportResult?
    @Published var displayUnit: DisplayUnit
    @Published var showOnboarding: Bool
    @Published private(set) var hasHealthKitPermission = false

    let repository: WeightRepositoryProtocol

    private let scanner: ScaleScanner
    private let stabilizer: WeightStabilizer
    private let csvService: CSVServiceProtocol
    private let healthKitService: HealthKitServicing
    private let userDefaults: UserDefaults

    private var readingTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private var scanStartedAt: Date?
    private var lastValidReadingAt: Date?

    init(
        scanner: ScaleScanner,
        stabilizer: WeightStabilizer,
        repository: WeightRepositoryProtocol,
        csvService: CSVServiceProtocol,
        healthKitService: HealthKitServicing,
        userDefaults: UserDefaults = .standard
    ) {
        self.scanner = scanner
        self.stabilizer = stabilizer
        self.repository = repository
        self.csvService = csvService
        self.healthKitService = healthKitService
        self.userDefaults = userDefaults

        let displayUnitRaw = userDefaults.string(forKey: AppDefaults.displayUnit) ?? DisplayUnit.lbs.rawValue
        self.displayUnit = DisplayUnit(rawValue: displayUnitRaw) ?? .lbs
        self.showOnboarding = !userDefaults.bool(forKey: AppDefaults.hasSeenOnboarding)

        refreshHealthKitPermission()
    }

    deinit {
        readingTask?.cancel()
        stateTask?.cancel()
        timeoutTask?.cancel()
    }

    func handleAppLaunch() {
        guard !showOnboarding else {
            return
        }
        startScanningIfNeeded()
    }

    func completeOnboardingAndStart() {
        userDefaults.set(true, forKey: AppDefaults.hasSeenOnboarding)
        showOnboarding = false
        startScanningIfNeeded()
    }

    func startScanningIfNeeded() {
        if readingTask == nil {
            readingTask = Task { [weak self] in
                guard let self else { return }
                for await reading in scanner.readings {
                    await self.handleIncomingReading(reading)
                }
            }
        }

        if stateTask == nil {
            stateTask = Task { [weak self] in
                guard let self else { return }
                for await state in scanner.state {
                    await self.handleScannerState(state)
                }
            }
        }

        if timeoutTask == nil {
            timeoutTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await self?.evaluateNoScaleTimeout()
                }
            }
        }

        scanStartedAt = Date()
        scanner.startScanning()
    }

    func stopScanning() {
        scanner.stopScanning()
        scanState = .idle
        noScaleDetected = false
    }

    func setDisplayUnit(_ newUnit: DisplayUnit) {
        displayUnit = newUnit
        userDefaults.set(newUnit.rawValue, forKey: AppDefaults.displayUnit)
    }

    func resetPinnedScale() {
        scanner.resetPinnedScale()
        statusMessage = "Pinned scale reset."
    }

    func dismissStatusMessage() {
        statusMessage = nil
    }

    func dismissImportResult() {
        importResult = nil
    }

    func refreshHealthKitPermission() {
        hasHealthKitPermission = healthKitService.bodyMassAuthorizationStatus == .sharingAuthorized
    }

    @discardableResult
    func requestHealthKitAuthorization() async -> Bool {
        do {
            let granted = try await healthKitService.requestAuthorization()
            refreshHealthKitPermission()
            if !granted {
                healthKitErrorMessage = "HealthKit access was not granted."
            } else {
                healthKitErrorMessage = nil
            }
            return granted
        } catch {
            healthKitErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearHealthKitError() {
        healthKitErrorMessage = nil
    }

    func importCSV(from url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try csvService.importWeights(from: url)
            importResult = result
            statusMessage = "Imported \(result.importedCount) record(s)."
        } catch {
            importResult = ImportResult(importedCount: 0, skippedCount: 0, duplicateCount: 0, errors: [error.localizedDescription])
        }
    }

    func exportCSVToTemporaryFile() throws -> URL {
        let entries = try repository.fetchAll()
        let fileName = "weights-\(Int(Date().timeIntervalSince1970)).csv"
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)

        try csvService.exportWeights(to: outputURL, entries: entries)
        return outputURL
    }

    func delete(_ entry: WeightEntry) {
        do {
            try repository.delete(entry)
        } catch {
            statusMessage = "Failed to delete entry: \(error.localizedDescription)"
        }
    }

    func update(_ entry: WeightEntry, timestamp: Date, weight: Double) {
        do {
            try repository.update(entry, timestamp: timestamp, weightLbs: weight)
        } catch {
            statusMessage = "Failed to update entry: \(error.localizedDescription)"
        }
    }

    private func handleIncomingReading(_ reading: Double) async {
        lastValidReadingAt = Date()
        noScaleDetected = false

        switch stabilizer.feed(reading) {
        case .none:
            break
        case let .measuring(current, samples):
            scanState = .measuring(current: WeightFormatting.roundToTenth(current), samples: samples)
        case let .settled(weight):
            await persistSettled(weight)
        }
    }

    private func persistSettled(_ weight: Double) async {
        let now = Date()

        do {
            _ = try repository.save(weightLbs: weight, timestamp: now, source: .live)
            scanState = .settled(weight: weight)
            statusMessage = "Recorded \(String(format: "%.1f", weight)) lbs"

            if !userDefaults.bool(forKey: AppDefaults.didAttemptAutoHealthKitPrompt) {
                userDefaults.set(true, forKey: AppDefaults.didAttemptAutoHealthKitPrompt)
                _ = await requestHealthKitAuthorization()
            }

            if hasHealthKitPermission {
                do {
                    try await healthKitService.saveBodyMass(weightLbs: weight, at: now)
                    healthKitErrorMessage = nil
                } catch {
                    healthKitErrorMessage = "Saved locally, but HealthKit write failed: \(error.localizedDescription)"
                }
            }
        } catch {
            scanState = .error(.unknown)
            statusMessage = "Failed to save reading: \(error.localizedDescription)"
        }
    }

    private func handleScannerState(_ newState: ScanState) async {
        switch newState {
        case .scanning:
            if case .measuring = scanState {
                return
            }
            if case .settled = scanState {
                return
            }
            scanState = .scanning
        case .idle:
            if case .settled = scanState {
                return
            }
            scanState = .idle
        case .error, .bluetoothUnavailable:
            noScaleDetected = false
            scanState = newState
        case .measuring, .settled:
            scanState = newState
        }
    }

    private func evaluateNoScaleTimeout() {
        switch scanState {
        case .scanning, .measuring:
            let now = Date()
            if let lastValidReadingAt,
               now.timeIntervalSince(lastValidReadingAt) > 20 {
                noScaleDetected = true
                return
            }
            if lastValidReadingAt == nil,
               let scanStartedAt,
               now.timeIntervalSince(scanStartedAt) > 20 {
                noScaleDetected = true
                return
            }
            noScaleDetected = false
        default:
            noScaleDetected = false
        }
    }
}
