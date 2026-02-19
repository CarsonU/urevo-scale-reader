import SwiftUI
import UIKit

struct WeighView: View {
    @EnvironmentObject private var appState: AppStateStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text(primaryTitle)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let activeWeight {
                    Text(String(format: "%.1f", displayWeight(activeWeight)))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                    Text(appState.displayUnit.symbol)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if appState.noScaleDetected {
                    Text("No scale detected in the last 20 seconds. Keep the app open and ensure the scale is nearby.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let healthKitErrorMessage = appState.healthKitErrorMessage {
                    Text(healthKitErrorMessage)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if shouldShowOpenSettings {
                    Button("Open iOS Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button("Start Scanning") {
                        appState.startScanningIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Stop") {
                        appState.stopScanning()
                    }
                    .buttonStyle(.bordered)
                }

                if let statusMessage = appState.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .navigationTitle("Weigh")
        }
    }

    private var activeWeight: Double? {
        switch appState.scanState {
        case let .measuring(current, _):
            return current
        case let .settled(weight):
            return weight
        default:
            return nil
        }
    }

    private var primaryTitle: String {
        switch appState.scanState {
        case .idle:
            return "Ready to start"
        case .scanning:
            return "Ready to weigh"
        case .measuring:
            return "Measuring..."
        case .settled:
            return "Reading saved"
        case let .error(error):
            return error.errorDescription ?? "Bluetooth error"
        case .bluetoothUnavailable:
            return "Bluetooth unavailable"
        }
    }

    private var subtitle: String? {
        switch appState.scanState {
        case let .measuring(_, samples):
            return "Collecting stable samples (\(samples)/8)."
        case .settled:
            return "Step off and back on for the next reading."
        case .scanning:
            return "Step on your scale while this screen is open."
        case .error(.poweredOff):
            return "Turn Bluetooth on in iOS Settings, then return here."
        case .error(.unauthorized):
            return "Allow Bluetooth access for this app in iOS Settings."
        case .bluetoothUnavailable:
            return "This device is not ready for Bluetooth scanning."
        default:
            return nil
        }
    }

    private var shouldShowOpenSettings: Bool {
        switch appState.scanState {
        case .error(.unauthorized), .error(.poweredOff):
            return true
        default:
            return false
        }
    }

    private func displayWeight(_ lbs: Double) -> Double {
        appState.displayUnit.fromLbs(lbs)
    }
}
