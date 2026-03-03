import Foundation

struct TrendChartPoint: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let displayWeight: Double
}

struct TrendChartModel: Equatable {
    let points: [TrendChartPoint]
    let yDomain: ClosedRange<Double>
}

enum WeightTrendAnalytics {
    static func filteredSamples(
        from samples: [WeightTrendSample],
        preset: TrendRangePreset,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeightTrendSample] {
        let filtered: [WeightTrendSample]

        if let startDate = preset.startDate(relativeTo: referenceDate, calendar: calendar) {
            filtered = samples.filter {
                $0.timestamp >= startDate && $0.timestamp <= referenceDate
            }
        } else {
            filtered = samples.filter { $0.timestamp <= referenceDate }
        }

        return filtered.sorted { $0.timestamp < $1.timestamp }
    }

    static func stats(for samples: [WeightTrendSample]) -> WeightTrendStats {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        let weights = sorted.map(\.weightLbs)

        guard !weights.isEmpty else {
            return WeightTrendStats(
                count: 0,
                averageLbs: nil,
                minimumLbs: nil,
                maximumLbs: nil,
                netChangeLbs: nil,
                netChangePercent: nil
            )
        }

        let count = weights.count
        let average = weights.reduce(0, +) / Double(count)
        let minimum = weights.min()
        let maximum = weights.max()

        let netChangeLbs: Double?
        let netChangePercent: Double?

        if let first = sorted.first?.weightLbs,
           let last = sorted.last?.weightLbs,
           count >= 2 {
            let netChange = last - first
            netChangeLbs = netChange

            if first != 0 {
                netChangePercent = (netChange / first) * 100.0
            } else {
                netChangePercent = nil
            }
        } else {
            netChangeLbs = nil
            netChangePercent = nil
        }

        return WeightTrendStats(
            count: count,
            averageLbs: average,
            minimumLbs: minimum,
            maximumLbs: maximum,
            netChangeLbs: netChangeLbs,
            netChangePercent: netChangePercent
        )
    }

    static func nearestSample(to targetDate: Date?, in samples: [WeightTrendSample]) -> WeightTrendSample? {
        guard let targetDate else {
            return nil
        }

        return samples.min {
            abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate))
        }
    }

    static func chartModel(from samples: [WeightTrendSample], unit: DisplayUnit) -> TrendChartModel {
        let sortedSamples = samples.sorted { $0.timestamp < $1.timestamp }

        guard !sortedSamples.isEmpty else {
            return TrendChartModel(points: [], yDomain: 0 ... 1)
        }

        let displayValues = sortedSamples.map { unit.fromLbs($0.weightLbs) }
        let yDomain = yDomain(for: displayValues, unit: unit)

        let points = zip(sortedSamples, displayValues).map { sample, displayWeight in
            return TrendChartPoint(
                id: sample.id,
                timestamp: sample.timestamp,
                displayWeight: displayWeight
            )
        }

        return TrendChartModel(
            points: points,
            yDomain: yDomain
        )
    }

    private static func yDomain(for values: [Double], unit: DisplayUnit) -> ClosedRange<Double> {
        guard let minimum = values.min(),
              let maximum = values.max() else {
            return 0 ... 1
        }

        var lowerBound = minimum
        var upperBound = maximum

        let minimumSpan = minimumDomainSpan(for: unit)
        let currentSpan = upperBound - lowerBound
        if currentSpan < minimumSpan {
            let center = (lowerBound + upperBound) / 2.0
            lowerBound = center - (minimumSpan / 2.0)
            upperBound = center + (minimumSpan / 2.0)
        }

        let adjustedSpan = upperBound - lowerBound
        let minimumPadding = minimumDomainPadding(for: unit)
        let padding = max(adjustedSpan * 0.12, minimumPadding)

        return (lowerBound - padding) ... (upperBound + padding)
    }

    private static func minimumDomainSpan(for unit: DisplayUnit) -> Double {
        switch unit {
        case .lbs:
            return 2.0
        case .kg:
            return 1.0
        }
    }

    private static func minimumDomainPadding(for unit: DisplayUnit) -> Double {
        switch unit {
        case .lbs:
            return 0.2
        case .kg:
            return 0.1
        }
    }
}
