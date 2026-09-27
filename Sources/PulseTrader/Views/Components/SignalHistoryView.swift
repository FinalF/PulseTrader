import SwiftUI

struct SignalHistoryView: View {
    @EnvironmentObject private var appState: AppState
    let symbol: String

    private var signals: [TradeSignal] {
        appState.signalMonitor.recentSignals.filter { $0.symbol == symbol }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Signals").font(.subheadline).foregroundStyle(.secondary)
            if signals.isEmpty {
                Text("No signals triggered yet.").foregroundStyle(.tertiary).font(.footnote)
            } else {
                ForEach(signals) { signal in
                    SignalBadgeView(signal: signal)
                }
            }
        }
    }
}
