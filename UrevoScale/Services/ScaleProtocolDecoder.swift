import Foundation

enum ScaleProtocolDecoder {
    private static let modelID = Data("URWS01".utf8)

    static func isCandidate(localName: String?, manufacturerData: Data?) -> Bool {
        if let localName, localName.lowercased() == "urevo" {
            return true
        }
        guard let manufacturerData else {
            return false
        }
        guard manufacturerData.count >= 10 else {
            return false
        }
        return manufacturerData.subdata(in: 4..<10) == modelID
    }

    static func decodeWeight(companyId: UInt16, manufacturerData: Data) -> Double? {
        guard manufacturerData.count >= 10 else {
            return nil
        }
        guard manufacturerData.subdata(in: 4..<10) == modelID else {
            return nil
        }

        let weightHigh = UInt16((companyId >> 8) & 0xFF)
        let weightLow = UInt16(manufacturerData[0])
        let raw = (weightHigh << 8) | weightLow

        if raw == 0 {
            return 0.0
        }

        return Double(raw) / 10.0
    }

    static func parseCompanyIdAndPayload(from manufacturerBlob: Data) -> (companyId: UInt16, payload: Data)? {
        guard manufacturerBlob.count >= 3 else {
            return nil
        }
        let companyId = UInt16(manufacturerBlob[0]) | (UInt16(manufacturerBlob[1]) << 8)
        let payload = manufacturerBlob.dropFirst(2)
        return (companyId, Data(payload))
    }
}
