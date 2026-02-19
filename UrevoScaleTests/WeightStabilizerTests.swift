import Foundation
import XCTest
@testable import UrevoScale

final class WeightStabilizerTests: XCTestCase {
    func testSettlesWhenSpreadWithinTolerance() {
        let config = StabilizerConfig(windowSize: 4, toleranceLbs: 0.3, minWeightLbs: 5.0, idleTimeoutSec: 3.0)
        let stabilizer = WeightStabilizer(config: config)

        _ = stabilizer.feed(180.0)
        _ = stabilizer.feed(180.1)
        _ = stabilizer.feed(179.9)
        let event = stabilizer.feed(180.0)

        XCTAssertEqual(event, .settled(weight: 180.0))
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
