import SwiftData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppStateStore
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]

    @State private var entryToEdit: WeightEntry?

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text("No readings yet. Step on your scale from the Weigh tab.")
                        .foregroundStyle(.secondary)
                }

                ForEach(entries) { entry in
                    Button {
                        entryToEdit = entry
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.timestamp, style: .date)
                                Text(entry.timestamp, style: .time)
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "%.1f lbs", entry.weightLbs))
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1f kg", DisplayUnit.kg.fromLbs(entry.weightLbs)))
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            appState.delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
        .sheet(item: $entryToEdit) { entry in
            HistoryEditView(entry: entry)
                .environmentObject(appState)
        }
    }
}
