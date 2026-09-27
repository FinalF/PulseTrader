import SwiftUI

struct SignalsFeedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List(appState.signalMonitor.recentSignals) { signal in
                SignalBadgeView(signal: signal)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Signals")
            .overlay {
                if appState.signalMonitor.recentSignals.isEmpty {
                    ContentUnavailableView(
                        "No signals yet",
                        systemImage: "bolt.slash",
                        description: Text("Signals appear here as soon as an indicator triggers on your watchlist.")
                    )
                }
            }
            .refreshable { await appState.signalMonitor.refreshOnce() }
        }
    }
}
