import Foundation
import UserNotifications

/// Polls the watchlist on an interval, runs the SignalEngine over fresh candles,
/// and publishes both the latest candles and any newly triggered signals.
@MainActor
final class SignalMonitorService: ObservableObject {
    @Published private(set) var recentSignals: [TradeSignal] = []
    @Published private(set) var candlesBySymbol: [String: [Candle]] = [:]
    @Published var pollingInterval: TimeInterval = 60
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    /// Supplied by AppState so this service never owns watchlist state directly.
    var watchlistProvider: (() -> [String])?

    private let marketData: MarketDataService
    private let tradingClient: AlpacaTradingClient
    private var loopTask: Task<Void, Never>?

    init(marketData: MarketDataService, tradingClient: AlpacaTradingClient) {
        self.marketData = marketData
        self.tradingClient = tradingClient
        requestNotificationPermission()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshOnce()
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
    }

    /// Fetches fresh candles for every watched symbol and evaluates signals once.
    /// Exposed publicly so views can trigger pull-to-refresh.
    func refreshOnce() async {
        let symbols = watchlistProvider?() ?? []
        for symbol in symbols {
            do {
                let candles = try await marketData.candles(for: symbol)
                candlesBySymbol[symbol] = candles
                lastError = nil

                let signals = SignalEngine.evaluate(symbol: symbol, candles: candles)
                for signal in signals {
                    recentSignals.insert(signal, at: 0)
                    notify(signal)
                }
                if recentSignals.count > 200 {
                    recentSignals.removeLast(recentSignals.count - 200)
                }
            } catch {
                lastError = error.localizedDescription
                print("⚠️ Refresh failed for \(symbol): \(error)")
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func notify(_ signal: TradeSignal) {
        let content = UNMutableNotificationContent()
        content.title = "\(signal.direction == .buy ? "Buy" : "Sell") signal: \(signal.symbol)"
        content.body = signal.reason
        content.sound = .default
        let request = UNNotificationRequest(identifier: signal.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
