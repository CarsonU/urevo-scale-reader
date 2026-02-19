import Foundation

protocol ScaleScanner: AnyObject {
    var readings: AsyncStream<Double> { get }
    var state: AsyncStream<ScanState> { get }

    func startScanning()
    func stopScanning()
    func resetPinnedScale()
}
