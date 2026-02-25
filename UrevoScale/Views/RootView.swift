import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppStateStore

    var body: some View {
        TabView {
            WeighView()
                .tabItem {
                    Label("Weigh", systemImage: "scalemass")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            appState.handleAppLaunch()
        }
        .fullScreenCover(isPresented: $appState.showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
    }
}
