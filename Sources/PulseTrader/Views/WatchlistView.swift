import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newSymbol = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add symbol (e.g. AAPL)", text: $newSymbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(addSymbol)
                        Button("Add", action: addSymbol)
                    }
                }
                Section("Watching") {
                    ForEach(appState.watchlist.symbols, id: \.self) { symbol in
                        NavigationLink(value: symbol) {
                            WatchlistRow(symbol: symbol)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            appState.watchlist.remove(appState.watchlist.symbols[index])
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
            .navigationDestination(for: String.self) { symbol in
                StockDetailView(symbol: symbol)
            }
            .refreshable { await appState.signalMonitor.refreshOnce() }
        }
    }

    private func addSymbol() {
        guard !newSymbol.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        appState.watchlist.add(newSymbol)
        newSymbol = ""
    }
}

private struct WatchlistRow: View {
    @EnvironmentObject private var appState: AppState
    let symbol: String

    private var lastCandle: Candle? {
        appState.signalMonitor.candlesBySymbol[symbol]?.last
    }

    var body: some View {
        HStack {
            Text(symbol).font(.headline)
            Spacer()
            if let candle = lastCandle {
                Text(candle.close, format: .currency(code: "USD"))
                    .foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }
}
