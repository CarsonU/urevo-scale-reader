import SwiftUI

struct HistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppStateStore

    let entry: WeightEntry

    @State private var timestamp: Date
    @State private var weightText: String
    @State private var showValidationError = false

    init(entry: WeightEntry) {
        self.entry = entry
        _timestamp = State(initialValue: entry.timestamp)
        _weightText = State(initialValue: String(format: "%.1f", entry.weightLbs))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Timestamp", selection: $timestamp)

                TextField("Weight (lbs)", text: $weightText)
                    .keyboardType(.decimalPad)

                if showValidationError {
                    Text("Enter a valid weight value.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        guard let weight = Double(weightText), weight > 0 else {
            showValidationError = true
            return
        }

        appState.update(entry, timestamp: timestamp, weight: weight)
        dismiss()
    }
}
