import XCTest
@testable import UrevoScale

final class WeightProtocolDecoderTests: XCTestCase {
    func testDecodeValidPacketMatchesPythonFormula() {
        let companyID: UInt16 = 0x0B01
        let payload = Data([0x5A, 0x00, 0x00, 0x00, 0x55, 0x52, 0x57, 0x53, 0x30, 0x31])

        let weight = ScaleProtocolDecoder.decodeWeight(companyId: companyID, manufacturerData: payload)

        XCTAssertEqual(weight, 290.6, accuracy: 0.0001)
    }

    func testDecodeReturnsNilForInvalidModelMarker() {
        let companyID: UInt16 = 0x0B01
        let payload = Data([0x5A, 0x00, 0x00, 0x00, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58])

        let weight = ScaleProtocolDecoder.decodeWeight(companyId: companyID, manufacturerData: payload)

        XCTAssertNil(weight)
    }

    func testCandidateDetectionUsesNameOrModelMarker() {
        let modelPayload = Data([0x00, 0x00, 0x00, 0x00, 0x55, 0x52, 0x57, 0x53, 0x30, 0x31])

        XCTAssertTrue(ScaleProtocolDecoder.isCandidate(localName: "urevo", manufacturerData: nil))
        XCTAssertTrue(ScaleProtocolDecoder.isCandidate(localName: nil, manufacturerData: modelPayload))
        XCTAssertFalse(ScaleProtocolDecoder.isCandidate(localName: "other", manufacturerData: Data([0x00, 0x01])))
    }

    func testCompanyIdAndPayloadParsing() {
        let blob = Data([0x01, 0x0B, 0x5A, 0x00, 0x00])

        let parsed = ScaleProtocolDecoder.parseCompanyIdAndPayload(from: blob)

        XCTAssertEqual(parsed?.companyId, 0x0B01)
        XCTAssertEqual(parsed?.payload, Data([0x5A, 0x00, 0x00]))
    }
}
