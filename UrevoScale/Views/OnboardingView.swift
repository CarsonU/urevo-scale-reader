import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppStateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Text("UREVO Scale")
                .font(.largeTitle.bold())

            Text("Step on your scale and this app will auto-record a stabilized reading.")
                .font(.title3)

            VStack(alignment: .leading, spacing: 12) {
                Label("Bluetooth is used to scan for your scale advertisement packets.", systemImage: "dot.radiowaves.left.and.right")
                Label("Weight entries are stored locally on this phone.", systemImage: "lock.fill")
                Label("HealthKit integration is optional and can be enabled any time.", systemImage: "heart.fill")
            }
            .font(.body)

            Spacer()

            Button {
                appState.completeOnboardingAndStart()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
