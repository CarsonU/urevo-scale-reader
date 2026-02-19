import Foundation
import HealthKit

protocol HealthKitServicing {
    var isHealthDataAvailable: Bool { get }
    var bodyMassAuthorizationStatus: HKAuthorizationStatus { get }

    func requestAuthorization() async throws -> Bool
    func saveBodyMass(weightLbs: Double, at date: Date) async throws
}

enum HealthKitError: LocalizedError {
    case unavailable
    case typeUnavailable
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is not available on this device."
        case .typeUnavailable:
            return "Body mass type is unavailable in HealthKit."
        case .authorizationFailed:
            return "HealthKit authorization failed."
        }
    }
}

final class HealthKitService: HealthKitServicing {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var bodyMassAuthorizationStatus: HKAuthorizationStatus {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: bodyMassType)
    }

    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable else {
            throw HealthKitError.unavailable
        }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.typeUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }

    func saveBodyMass(weightLbs: Double, at date: Date) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.unavailable
        }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.typeUnavailable
        }

        let quantity = HKQuantity(unit: HKUnit.pound(), doubleValue: weightLbs)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationFailed)
                }
            }
        }
    }
}
