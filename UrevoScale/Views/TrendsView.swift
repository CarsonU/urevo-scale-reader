import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var appState: AppStateStore
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]

    @State private var selectedRange: TrendRangePreset = .thirtyDays
    @State private var selectedDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rangePicker

                    if filteredSamples.isEmpty {
                        emptyState
                    } else {
                        chartCard
                        selectedReadingCard
                        statsGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
        .onChange(of: selectedRange) { _, _ in
            selectedDate = nil
        }
        .onChange(of: entries.count) { _, _ in
            selectedDate = nil
        }
    }

    private var allSamples: [WeightTrendSample] {
        entries.map {
            WeightTrendSample(
                id: $0.id,
                timestamp: $0.timestamp,
                weightLbs: $0.weightLbs
            )
        }
    }

    private var filteredSamples: [WeightTrendSample] {
        WeightTrendAnalytics.filteredSamples(
            from: allSamples,
            preset: selectedRange
        )
    }

    private var trendStats: WeightTrendStats {
        WeightTrendAnalytics.stats(for: filteredSamples)
    }

    private var chartModel: TrendChartModel {
        WeightTrendAnalytics.chartModel(
            from: filteredSamples,
            unit: appState.displayUnit
        )
    }

    private var highlightedSample: WeightTrendSample? {
        if let nearest = WeightTrendAnalytics.nearestSample(to: selectedDate, in: filteredSamples) {
            return nearest
        }
        return filteredSamples.last
    }

    private var highlightedChartPoint: TrendChartPoint? {
        guard let highlightedSample else {
            return nil
        }

        return chartModel.points.first { point in
            point.id == highlightedSample.id
        }
    }

    private var clippedChartPoints: [TrendChartPoint] {
        chartModel.points.filter { point in
            point.clipDirection != nil
        }
    }

    private var highlightedClipNote: String? {
        guard let clipDirection = highlightedChartPoint?.clipDirection else {
            return nil
        }

        switch clipDirection {
        case .high:
            return "This reading is above the chart range and is pinned to the top for readability."
        case .low:
            return "This reading is below the chart range and is pinned to the bottom for readability."
        }
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrendRangePreset.allCases) { preset in
                    Button {
                        selectedRange = preset
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedRange == preset ? Color.accentColor.opacity(0.18) : Color(.secondarySystemFill))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedRange == preset ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Over Time")
                .font(.headline)

            Chart {
                ForEach(chartModel.points) { point in
                    LineMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Weight", point.plottedDisplayWeight)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(.primary)
                }

                ForEach(clippedChartPoints) { point in
                    if let clipDirection = point.clipDirection {
                        PointMark(
                            x: .value("Date", point.timestamp),
                            y: .value("Weight", point.plottedDisplayWeight)
                        )
                        .symbolSize(44)
                        .foregroundStyle(.primary)
                        .annotation(position: clipDirection == .high ? .top : .bottom) {
                            clipBadge(for: clipDirection)
                        }
                    }
                }

                if let highlightedSample,
                   let highlightedChartPoint {
                    PointMark(
                        x: .value("Date", highlightedSample.timestamp),
                        y: .value("Weight", highlightedChartPoint.plottedDisplayWeight)
                    )
                    .symbolSize(70)
                    .foregroundStyle(.primary)
                }
            }
            .frame(height: 240)
            .chartYScale(domain: chartModel.yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXSelection(value: $selectedDate)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var selectedReadingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDate == nil ? "Latest Reading" : "Selected Reading")
                .font(.subheadline.weight(.semibold))

            if let highlightedSample {
                Text(weightString(for: highlightedSample.weightLbs))
                    .font(.title3.weight(.semibold))

                HStack(spacing: 8) {
                    Text(highlightedSample.timestamp, style: .date)
                    Text("·")
                    Text(highlightedSample.timestamp, style: .time)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let highlightedClipNote {
                    Text(highlightedClipNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap or drag on the chart to inspect a reading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "Net Change",
                value: netChangeDisplay
            )

            statCard(
                title: "Average",
                value: averageDisplay
            )

            statCard(
                title: "Min / Max",
                value: minMaxDisplay
            )

            statCard(
                title: "Weigh-ins",
                value: "\(trendStats.count)"
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No readings in this period.")
                .font(.headline)
            Text("Pick another range or add readings from the Weigh tab.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func clipBadge(for direction: TrendClipDirection) -> some View {
        Image(systemName: direction == .high ? "arrow.up" : "arrow.down")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(4)
            .background(
                Circle()
                    .fill(Color(.systemBackground))
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.25), lineWidth: 1)
            )
    }

    private var netChangeDisplay: String {
        guard let netChangeLbs = trendStats.netChangeLbs else {
            return "Not enough data"
        }

        let absolute = signedWeightString(for: netChangeLbs)
        if let percent = trendStats.netChangePercent {
            return "\(absolute) (\(String(format: "%+.1f%%", percent)))"
        }
        return absolute
    }

    private var averageDisplay: String {
        guard let averageLbs = trendStats.averageLbs else {
            return "—"
        }
        return weightString(for: averageLbs)
    }

    private var minMaxDisplay: String {
        guard let minimumLbs = trendStats.minimumLbs,
              let maximumLbs = trendStats.maximumLbs else {
            return "—"
        }
        return "\(weightString(for: minimumLbs)) / \(weightString(for: maximumLbs))"
    }

    private func weightString(for lbs: Double) -> String {
        String(format: "%.1f %@", displayWeight(lbs), appState.displayUnit.symbol)
    }

    private func signedWeightString(for lbs: Double) -> String {
        String(format: "%+.1f %@", displayWeight(lbs), appState.displayUnit.symbol)
    }

    private func displayWeight(_ lbs: Double) -> Double {
        appState.displayUnit.fromLbs(lbs)
    }
}
