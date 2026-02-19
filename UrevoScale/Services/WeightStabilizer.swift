import Foundation

enum StabilizerEvent: Equatable {
    case none
    case measuring(current: Double, samples: Int)
    case settled(weight: Double)
}

final class WeightStabilizer {
    private let config: StabilizerConfig
    private let nowProvider: () -> Date

    private var recent: [Double] = []
    private var settled = false
    private var lastReadingAt: Date?

    init(config: StabilizerConfig = StabilizerConfig(), nowProvider: @escaping () -> Date = Date.init) {
        self.config = config
        self.nowProvider = nowProvider
    }

    func feed(_ weight: Double) -> StabilizerEvent {
        feed(weight, at: nowProvider())
    }

    func feed(_ weight: Double, at now: Date) -> StabilizerEvent {
        if let lastReadingAt, now.timeIntervalSince(lastReadingAt) > config.idleTimeoutSec {
            reset()
        }
        self.lastReadingAt = now

        guard weight >= config.minWeightLbs else {
            return .none
        }

        recent.append(weight)
        if recent.count > config.windowSize {
            recent.removeFirst(recent.count - config.windowSize)
        }

        if settled {
            return .measuring(current: weight, samples: recent.count)
        }

        guard recent.count >= config.windowSize else {
            return .measuring(current: weight, samples: recent.count)
        }

        let spread = (recent.max() ?? weight) - (recent.min() ?? weight)
        guard spread <= config.toleranceLbs else {
            return .measuring(current: weight, samples: recent.count)
        }

        settled = true
        let average = recent.reduce(0, +) / Double(recent.count)
        return .settled(weight: WeightFormatting.roundToTenth(average))
    }

    func reset() {
        recent.removeAll(keepingCapacity: true)
        settled = false
        lastReadingAt = nil
    }

    var sampleCount: Int {
        recent.count
    }
}
