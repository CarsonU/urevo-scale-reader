import Foundation

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
}
