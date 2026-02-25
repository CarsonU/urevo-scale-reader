import XCTest
@testable import UrevoScale

final class WeightFormattingTests: XCTestCase {
    func testRoundToTenth() {
        XCTAssertEqual(WeightFormatting.roundToTenth(176.44), 176.4)
        XCTAssertEqual(WeightFormatting.roundToTenth(176.45), 176.5)
    }

    func testDisplayUnitConversion() {
        let lbs = 176.4
        let kg = DisplayUnit.kg.fromLbs(lbs)

        XCTAssertEqual(kg, 80.013694068, accuracy: 0.000001)
        XCTAssertEqual(DisplayUnit.kg.toLbs(kg), lbs, accuracy: 0.000001)
    }

    func testWeightStringFormatting() {
        XCTAssertEqual(WeightFormatting.string(for: 176.4, unit: .lbs), "176.4 lbs")
        XCTAssertEqual(WeightFormatting.string(for: 176.4, unit: .kg), "80.0 kg")
    }
}
