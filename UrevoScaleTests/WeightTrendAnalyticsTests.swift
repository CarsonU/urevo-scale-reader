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

    private func sample(at timestamp: Date, weight: Double) -> WeightTrendSample {
        WeightTrendSample(id: UUID(), timestamp: timestamp, weightLbs: weight)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
