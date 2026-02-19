import SwiftUI
import UniformTypeIdentifiers

private struct ExportSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppStateStore

    @State private var isPresentingImporter = false
    @State private var exportSheetItem: ExportSheetItem?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Unit", selection: Binding(
                        get: { appState.displayUnit },
                        set: { appState.setDisplayUnit($0) }
                    )) {
                        ForEach(DisplayUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                }

                Section("HealthKit") {
                    HStack {
                        Text("Body Mass Access")
                        Spacer()
                        Text(appState.hasHealthKitPermission ? "Authorized" : "Not Authorized")
                            .foregroundStyle(appState.hasHealthKitPermission ? .green : .secondary)
                    }

                    Button("Enable HealthKit") {
                        Task {
                            _ = await appState.requestHealthKitAuthorization()
                        }
                    }

                    if let healthKitErrorMessage = appState.healthKitErrorMessage {
                        Text(healthKitErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("CSV") {
                    Button("Import CSV") {
                        isPresentingImporter = true
                    }

                    Button("Export CSV") {
                        do {
                            let url = try appState.exportCSVToTemporaryFile()
                            exportSheetItem = ExportSheetItem(url: url)
                        } catch {
                            exportErrorMessage = error.localizedDescription
                        }
                    }
                }

                Section("Scale") {
                    Button("Reset Pinned Scale") {
                        appState.resetPinnedScale()
                    }
                }

                if let importResult = appState.importResult {
                    Section("Last Import") {
                        Text("Imported: \(importResult.importedCount)")
                        Text("Duplicates: \(importResult.duplicateCount)")
                        Text("Skipped: \(importResult.skippedCount)")

                        if !importResult.errors.isEmpty {
                            Text(importResult.errors.prefix(3).joined(separator: "\n"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let statusMessage = appState.statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    return
                }
                Task {
                    await appState.importCSV(from: url)
                }
            case let .failure(error):
                exportErrorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .sheet(item: $exportSheetItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert("File Error", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { showing in
                if !showing {
                    exportErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Unknown error")
        }
    }
}
