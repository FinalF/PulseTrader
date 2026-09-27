import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "list.star") }
            SignalsFeedView()
                .tabItem { Label("Signals", systemImage: "bolt.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
