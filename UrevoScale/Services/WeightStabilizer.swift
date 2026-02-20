import Foundation

enum StabilizerEvent: Equatable {
    case none
    case measuring(current: Double, samples: Int)
    case confirming(current: Double, progress: Double)
    case settled(weight: Double)
}

final class WeightStabilizer {
    private enum Phase: Equatable {
        case collecting
        case confirming(startedAt: Date)
        case locked
    }

    private let config: StabilizerConfig
    private let nowProvider: () -> Date
    private let collectingLimit: Int
    private let confirmingLimit: Int

    private var phase: Phase = .collecting
    private var collectingRecent: [Double] = []
    private var confirmingRecent: [Double] = []
    private var lastReadingAt: Date?

    init(config: StabilizerConfig = StabilizerConfig(), nowProvider: @escaping () -> Date = Date.init) {
        self.config = config
        self.nowProvider = nowProvider
        self.collectingLimit = max(config.windowSize, 1)
        self.confirmingLimit = max(config.windowSize, config.confirmMinSamples, 1)
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

        switch phase {
        case .collecting:
            append(weight, to: &collectingRecent, limit: collectingLimit)
            guard collectingRecent.count >= config.windowSize else {
                return .measuring(current: weight, samples: collectingRecent.count)
            }

            let spread = spread(of: collectingRecent)
            guard spread <= config.toleranceLbs else {
                return .measuring(current: weight, samples: collectingRecent.count)
            }

            phase = .confirming(startedAt: now)
            confirmingRecent = collectingRecent
            return .confirming(current: weight, progress: 0.0)

        case let .confirming(startedAt):
            append(weight, to: &confirmingRecent, limit: confirmingLimit)

            let confirmSpread = spread(of: confirmingRecent)
            if confirmSpread > config.confirmToleranceLbs {
                phase = .collecting
                collectingRecent = Array(confirmingRecent.suffix(collectingLimit))
                confirmingRecent.removeAll(keepingCapacity: true)
                return .measuring(current: weight, samples: collectingRecent.count)
            }

            let elapsed = now.timeIntervalSince(startedAt)
            let timeProgress = min(max(elapsed / config.confirmDurationSec, 0), 1)
            let sampleProgress = min(
                Double(confirmingRecent.count) / Double(max(config.confirmMinSamples, 1)),
                1
            )
            let progress = min(timeProgress, sampleProgress)

            let hasDuration = elapsed >= config.confirmDurationSec
            let hasSamples = confirmingRecent.count >= config.confirmMinSamples
            guard hasDuration && hasSamples else {
                return .confirming(current: weight, progress: progress)
            }

            phase = .locked
            let average = confirmingRecent.reduce(0, +) / Double(confirmingRecent.count)
            return .settled(weight: WeightFormatting.roundToTenth(average))

        case .locked:
            append(weight, to: &collectingRecent, limit: collectingLimit)
            return .measuring(current: weight, samples: collectingRecent.count)
        }
    }

    func reset() {
        phase = .collecting
        collectingRecent.removeAll(keepingCapacity: true)
        confirmingRecent.removeAll(keepingCapacity: true)
        lastReadingAt = nil
    }

    var sampleCount: Int {
        switch phase {
        case .collecting, .locked:
            return collectingRecent.count
        case .confirming:
            return confirmingRecent.count
        }
    }

    private func append(_ weight: Double, to values: inout [Double], limit: Int) {
        values.append(weight)
        if values.count > limit {
            values.removeFirst(values.count - limit)
        }
    }

    private func spread(of values: [Double]) -> Double {
        (values.max() ?? 0) - (values.min() ?? 0)
    }
}
