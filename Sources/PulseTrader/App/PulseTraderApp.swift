import SwiftUI

@main
struct PulseTraderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .task {
                    appState.signalMonitor.start()
                }
        }
    }
}
