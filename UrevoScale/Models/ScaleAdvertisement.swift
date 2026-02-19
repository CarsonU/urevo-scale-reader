import Foundation

struct ScaleAdvertisement {
    let peripheralID: UUID
    let localName: String?
    let companyId: UInt16
    let manufacturerData: Data
    let rssi: Int
}
