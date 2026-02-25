import Foundation

enum TrendClipDirection: Equatable {
    case low
    case high
}

struct TrendChartPoint: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let rawDisplayWeight: Double
    let plottedDisplayWeight: Double
    let clipDirection: TrendClipDirection?
}

struct TrendChartModel: Equatable {
    let points: [TrendChartPoint]
    let yDomain: ClosedRange<Double>
    let hasClippedPoints: Bool
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
            return TrendChartModel(points: [], yDomain: 0 ... 1, hasClippedPoints: false)
        }

        let displayValues = sortedSamples.map { unit.fromLbs($0.weightLbs) }
        let inlierValues = inlierValues(from: displayValues)
        let yDomain = yDomain(for: inlierValues, unit: unit)

        var hasClippedPoints = false
        let points = zip(sortedSamples, displayValues).map { sample, rawDisplayWeight in
            let clipDirection: TrendClipDirection?
            if rawDisplayWeight < yDomain.lowerBound {
                clipDirection = .low
            } else if rawDisplayWeight > yDomain.upperBound {
                clipDirection = .high
            } else {
                clipDirection = nil
            }

            if clipDirection != nil {
                hasClippedPoints = true
            }

            return TrendChartPoint(
                id: sample.id,
                timestamp: sample.timestamp,
                rawDisplayWeight: rawDisplayWeight,
                plottedDisplayWeight: clamped(rawDisplayWeight, to: yDomain),
                clipDirection: clipDirection
            )
        }

        return TrendChartModel(
            points: points,
            yDomain: yDomain,
            hasClippedPoints: hasClippedPoints
        )
    }

    private static func inlierValues(from values: [Double]) -> [Double] {
        let sorted = values.sorted()
        guard sorted.count >= 5 else {
            return sorted
        }

        let q1 = percentile(0.25, in: sorted)
        let q3 = percentile(0.75, in: sorted)
        let iqr = q3 - q1
        let lowerFence = q1 - (1.5 * iqr)
        let upperFence = q3 + (1.5 * iqr)

        let inliers = sorted.filter { value in
            value >= lowerFence && value <= upperFence
        }

        return inliers.isEmpty ? sorted : inliers
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

    private static func percentile(_ percentile: Double, in sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else {
            return 0
        }

        let position = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }

        let lowerValue = sortedValues[lowerIndex]
        let upperValue = sortedValues[upperIndex]
        let fraction = position - Double(lowerIndex)
        return lowerValue + ((upperValue - lowerValue) * fraction)
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

    private static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
