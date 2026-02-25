import Foundation
import XCTest
@testable import UrevoScale

final class WeightTrendAnalyticsTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testFilteredSamplesReturnsChronologicalOrderWithinRange() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let calendar = utcCalendar

        let insideOlder = sample(at: now.addingTimeInterval(-5 * day), weight: 180.0)
        let insideNewer = sample(at: now.addingTimeInterval(-1 * day), weight: 179.0)
        let outside = sample(at: now.addingTimeInterval(-10 * day), weight: 181.0)
        let future = sample(at: now.addingTimeInterval(2 * day), weight: 178.0)

        let filtered = WeightTrendAnalytics.filteredSamples(
            from: [insideNewer, outside, future, insideOlder],
            preset: .sevenDays,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(filtered.map(\.id), [insideOlder.id, insideNewer.id])
    }

    func testFilteredSamplesIncludesBoundaryDate() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let calendar = utcCalendar
        let start = TrendRangePreset.thirtyDays.startDate(relativeTo: now, calendar: calendar)!

        let atBoundary = sample(at: start, weight: 180.0)
        let beforeBoundary = sample(at: start.addingTimeInterval(-1), weight: 181.0)
        let atNow = sample(at: now, weight: 179.0)

        let filtered = WeightTrendAnalytics.filteredSamples(
            from: [beforeBoundary, atNow, atBoundary],
            preset: .thirtyDays,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(filtered.map(\.id), [atBoundary.id, atNow.id])
    }

    func testAllPresetIncludesPastDataAndExcludesFutureData() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)

        let past = sample(at: now.addingTimeInterval(-10), weight: 180.0)
        let future = sample(at: now.addingTimeInterval(10), weight: 179.0)

        let filtered = WeightTrendAnalytics.filteredSamples(
            from: [future, past],
            preset: .all,
            referenceDate: now
        )

        XCTAssertEqual(filtered.map(\.id), [past.id])
    }

    func testStatsComputesAverageMinMaxAndNetChange() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let earliest = sample(at: now.addingTimeInterval(-3 * day), weight: 200.0)
        let middle = sample(at: now.addingTimeInterval(-2 * day), weight: 195.0)
        let latest = sample(at: now.addingTimeInterval(-1 * day), weight: 190.0)

        let stats = WeightTrendAnalytics.stats(for: [latest, earliest, middle])

        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats.averageLbs ?? 0, 195.0, accuracy: 0.0001)
        XCTAssertEqual(stats.minimumLbs ?? 0, 190.0, accuracy: 0.0001)
        XCTAssertEqual(stats.maximumLbs ?? 0, 200.0, accuracy: 0.0001)
        XCTAssertEqual(stats.netChangeLbs ?? 0, -10.0, accuracy: 0.0001)
        XCTAssertEqual(stats.netChangePercent ?? 0, -5.0, accuracy: 0.0001)
    }

    func testStatsForSingleSampleHasNoNetChange() {
        let sample = sample(at: Date(timeIntervalSince1970: 1_760_000_000), weight: 180.0)
        let stats = WeightTrendAnalytics.stats(for: [sample])

        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.averageLbs ?? 0, 180.0, accuracy: 0.0001)
        XCTAssertEqual(stats.minimumLbs ?? 0, 180.0, accuracy: 0.0001)
        XCTAssertEqual(stats.maximumLbs ?? 0, 180.0, accuracy: 0.0001)
        XCTAssertNil(stats.netChangeLbs)
        XCTAssertNil(stats.netChangePercent)
    }

    func testNearestSampleFindsClosestTimestamp() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let first = sample(at: base, weight: 180.0)
        let second = sample(at: base.addingTimeInterval(2_000), weight: 179.0)
        let third = sample(at: base.addingTimeInterval(5_000), weight: 178.0)

        let nearest = WeightTrendAnalytics.nearestSample(
            to: base.addingTimeInterval(2_500),
            in: [first, second, third]
        )

        XCTAssertEqual(nearest?.id, second.id)
    }

    func testNearestSampleReturnsNilForNilTargetDate() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let first = sample(at: base, weight: 180.0)

        let nearest = WeightTrendAnalytics.nearestSample(to: nil, in: [first])

        XCTAssertNil(nearest)
    }

    func testChartModelUsesAdaptiveDomainWithoutZeroBaseline() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let samples = [
            sample(at: base, weight: 180.0),
            sample(at: base.addingTimeInterval(day), weight: 179.5),
            sample(at: base.addingTimeInterval(2 * day), weight: 179.1),
            sample(at: base.addingTimeInterval(3 * day), weight: 178.9),
            sample(at: base.addingTimeInterval(4 * day), weight: 178.6)
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)

        XCTAssertEqual(model.points.count, samples.count)
        XCTAssertFalse(model.yDomain.contains(0))
        XCTAssertGreaterThan(model.yDomain.lowerBound, 150)
    }

    func testChartModelClipsSingleExtremeHighOutlier() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let highOutlier = sample(at: base.addingTimeInterval(5 * day), weight: 230.0)
        let samples = [
            sample(at: base, weight: 178.0),
            sample(at: base.addingTimeInterval(day), weight: 178.2),
            sample(at: base.addingTimeInterval(2 * day), weight: 178.3),
            sample(at: base.addingTimeInterval(3 * day), weight: 178.4),
            sample(at: base.addingTimeInterval(4 * day), weight: 178.5),
            highOutlier
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)
        let outlierPoint = model.points.first { $0.id == highOutlier.id }

        XCTAssertEqual(outlierPoint?.clipDirection, .high)
        XCTAssertEqual(outlierPoint?.plottedDisplayWeight ?? 0, model.yDomain.upperBound, accuracy: 0.0001)
        XCTAssertLessThan(model.yDomain.upperBound, 200)
        XCTAssertTrue(model.hasClippedPoints)
    }

    func testChartModelClipsSingleExtremeLowOutlier() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let lowOutlier = sample(at: base.addingTimeInterval(5 * day), weight: 120.0)
        let samples = [
            sample(at: base, weight: 178.0),
            sample(at: base.addingTimeInterval(day), weight: 178.2),
            sample(at: base.addingTimeInterval(2 * day), weight: 178.3),
            sample(at: base.addingTimeInterval(3 * day), weight: 178.4),
            sample(at: base.addingTimeInterval(4 * day), weight: 178.5),
            lowOutlier
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)
        let outlierPoint = model.points.first { $0.id == lowOutlier.id }

        XCTAssertEqual(outlierPoint?.clipDirection, .low)
        XCTAssertEqual(outlierPoint?.plottedDisplayWeight ?? 0, model.yDomain.lowerBound, accuracy: 0.0001)
        XCTAssertGreaterThan(model.yDomain.lowerBound, 170)
        XCTAssertTrue(model.hasClippedPoints)
    }

    func testChartModelEnforcesMinimumSpanInLbs() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let samples = [
            sample(at: base, weight: 177.2),
            sample(at: base.addingTimeInterval(day), weight: 177.3),
            sample(at: base.addingTimeInterval(2 * day), weight: 177.4),
            sample(at: base.addingTimeInterval(3 * day), weight: 177.5)
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)
        let domainWidth = model.yDomain.upperBound - model.yDomain.lowerBound

        XCTAssertEqual(domainWidth, 2.48, accuracy: 0.0001)
        XCTAssertFalse(model.hasClippedPoints)
    }

    func testChartModelEnforcesMinimumSpanInKg() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let samples = [
            sample(at: base, weight: 177.2),
            sample(at: base.addingTimeInterval(day), weight: 177.3),
            sample(at: base.addingTimeInterval(2 * day), weight: 177.4),
            sample(at: base.addingTimeInterval(3 * day), weight: 177.5)
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .kg)
        let domainWidth = model.yDomain.upperBound - model.yDomain.lowerBound

        XCTAssertEqual(domainWidth, 1.24, accuracy: 0.0001)
        XCTAssertFalse(model.hasClippedPoints)
    }

    func testChartModelDoesNotCapOutliersWhenFewerThanFiveSamples() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let outlier = sample(at: base.addingTimeInterval(3 * day), weight: 230.0)
        let samples = [
            sample(at: base, weight: 178.0),
            sample(at: base.addingTimeInterval(day), weight: 178.2),
            sample(at: base.addingTimeInterval(2 * day), weight: 178.4),
            outlier
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)
        let outlierPoint = model.points.first { $0.id == outlier.id }

        XCTAssertNil(outlierPoint?.clipDirection)
        XCTAssertGreaterThan(model.yDomain.upperBound, 230)
        XCTAssertFalse(model.hasClippedPoints)
    }

    func testChartModelKeepsRawValuesWhileStatsUseAllSamples() {
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        let outlier = sample(at: base.addingTimeInterval(5 * day), weight: 230.0)
        let samples = [
            sample(at: base, weight: 178.0),
            sample(at: base.addingTimeInterval(day), weight: 178.2),
            sample(at: base.addingTimeInterval(2 * day), weight: 178.3),
            sample(at: base.addingTimeInterval(3 * day), weight: 178.4),
            sample(at: base.addingTimeInterval(4 * day), weight: 178.5),
            outlier
        ]

        let model = WeightTrendAnalytics.chartModel(from: samples, unit: .lbs)
        let stats = WeightTrendAnalytics.stats(for: samples)
        let outlierPoint = model.points.first { $0.id == outlier.id }

        XCTAssertEqual(outlierPoint?.rawDisplayWeight ?? 0, 230.0, accuracy: 0.0001)
        XCTAssertEqual(outlierPoint?.clipDirection, .high)
        XCTAssertNotEqual(outlierPoint?.plottedDisplayWeight, outlierPoint?.rawDisplayWeight)
        XCTAssertEqual(stats.maximumLbs ?? 0, 230.0, accuracy: 0.0001)
    }

    private func sample(at timestamp: Date, weight: Double) -> WeightTrendSample {
        WeightTrendSample(id: UUID(), timestamp: timestamp, weightLbs: weight)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
