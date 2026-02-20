import Foundation

struct StabilizerConfig: Equatable {
    var windowSize: Int = 8
    var toleranceLbs: Double = 0.3
    var minWeightLbs: Double = 5.0
    var idleTimeoutSec: TimeInterval = 3.0
    var confirmDurationSec: TimeInterval = 1.0
    var confirmToleranceLbs: Double = 0.2
    var confirmMinSamples: Int = 6
}
