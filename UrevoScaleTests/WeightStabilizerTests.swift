import Foundation
import XCTest
@testable import UrevoScale

final class WeightStabilizerTests: XCTestCase {
    func testFirstStableWindowEntersConfirming() {
        let config = StabilizerConfig(
            windowSize: 4,
            toleranceLbs: 0.3,
            minWeightLbs: 5.0,
            idleTimeoutSec: 3.0,
            confirmDurationSec: 1.0,
            confirmToleranceLbs: 0.2,
            confirmMinSamples: 6
        )
        let stabilizer = WeightStabilizer(config: config)
        let start = Date()

        _ = stabilizer.feed(180.0, at: start)
        _ = stabilizer.feed(180.1, at: start.addingTimeInterval(0.1))
        _ = stabilizer.feed(179.9, at: start.addingTimeInterval(0.2))
        let event = stabilizer.feed(180.0, at: start.addingTimeInterval(0.3))

        guard case let .confirming(current, progress) = event else {
            XCTFail("Expected confirming event")
            return
        }

        XCTAssertEqual(current, 180.0, accuracy: 0.01)
        XCTAssertEqual(progress, 0.0, accuracy: 0.0001)
    }

    func testSettlesOnlyAfterConfirmationDurationAndSamples() {
        let config = StabilizerConfig(
            windowSize: 4,
            toleranceLbs: 0.3,
            minWeightLbs: 5.0,
            idleTimeoutSec: 3.0,
            confirmDurationSec: 1.0,
            confirmToleranceLbs: 0.2,
            confirmMinSamples: 6
        )
        let stabilizer = WeightStabilizer(config: config)
        let start = Date()

        _ = stabilizer.feed(180.0, at: start)
        _ = stabilizer.feed(180.1, at: start.addingTimeInterval(0.1))
        _ = stabilizer.feed(179.9, at: start.addingTimeInterval(0.2))
        _ = stabilizer.feed(180.0, at: start.addingTimeInterval(0.3))

        let midEvent = stabilizer.feed(180.0, at: start.addingTimeInterval(0.6))
        guard case let .confirming(_, progress) = midEvent else {
            XCTFail("Expected confirming event")
            return
        }
        XCTAssertLessThan(progress, 1.0)

        let event = stabilizer.feed(180.0, at: start.addingTimeInterval(1.4))
        XCTAssertEqual(event, .settled(weight: 180.0))
    }

    func testDriftDuringConfirmingFallsBackToCollecting() {
        let config = StabilizerConfig(
            windowSize: 4,
            toleranceLbs: 0.3,
            minWeightLbs: 5.0,
            idleTimeoutSec: 3.0,
            confirmDurationSec: 1.0,
            confirmToleranceLbs: 0.2,
            confirmMinSamples: 6
        )
        let stabilizer = WeightStabilizer(config: config)
        let start = Date()

        _ = stabilizer.feed(180.0, at: start)
        _ = stabilizer.feed(180.1, at: start.addingTimeInterval(0.1))
        _ = stabilizer.feed(179.9, at: start.addingTimeInterval(0.2))
        _ = stabilizer.feed(180.0, at: start.addingTimeInterval(0.3))

        let event = stabilizer.feed(180.7, at: start.addingTimeInterval(0.5))
        guard case let .measuring(current, samples) = event else {
            XCTFail("Expected measuring event after confirm drift")
            return
        }

        XCTAssertEqual(current, 180.7, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(samples, 1)
    }

    func testIgnoresLowWeights() {
        let stabilizer = WeightStabilizer(config: StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0))

        let event = stabilizer.feed(3.2)

        XCTAssertEqual(event, .none)
        XCTAssertEqual(stabilizer.sampleCount, 0)
    }

    func testIdleTimeoutResetsSamples() {
        let config = StabilizerConfig(windowSize: 3, toleranceLbs: 0.2, minWeightLbs: 5.0, idleTimeoutSec: 1.0)
        let stabilizer = WeightStabilizer(config: config)

        let start = Date()
        _ = stabilizer.feed(180.0, at: start)
        _ = stabilizer.feed(180.1, at: start.addingTimeInterval(0.2))

        let eventAfterIdle = stabilizer.feed(180.2, at: start.addingTimeInterval(2.0))

        XCTAssertEqual(eventAfterIdle, .measuring(current: 180.2, samples: 1))
    }
}
