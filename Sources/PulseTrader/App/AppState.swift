import Foundation

/// Central dependency container. Owns persistence, networking, and the
/// background signal monitor, and exposes them to the view tree.
@MainActor
final class AppState: ObservableObject {
    @Published var watchlist: Watchlist {
        didSet { watchlist.saveToDisk() }
    }

    let credentialsStore: AlpacaCredentialsStore
    let marketData: MarketDataService
    let signalMonitor: SignalMonitorService

    init() {
        let list = Watchlist.loadFromDisk() ?? Watchlist.default
        let store = AlpacaCredentialsStore(keychain: KeychainService())
        let dataClient = AlpacaMarketDataClient(credentials: store)
        let tradingClient = AlpacaTradingClient(credentials: store)
        let dataService = MarketDataService(client: dataClient)

        self.watchlist = list
        self.credentialsStore = store
        self.marketData = dataService
        self.signalMonitor = SignalMonitorService(marketData: dataService, tradingClient: tradingClient)

        // Wired up after `self` exists so the monitor always reads the live watchlist.
        signalMonitor.watchlistProvider = { [weak self] in self?.watchlist.symbols ?? [] }
    }
}
