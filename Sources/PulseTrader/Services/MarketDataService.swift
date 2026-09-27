import Foundation

/// Thin caching layer over the Alpaca market data client so views can read
/// the last-known candles without re-fetching.
actor MarketDataService {
    private let client: AlpacaMarketDataClient
    private var cache: [String: [Candle]] = [:]

    init(client: AlpacaMarketDataClient) {
        self.client = client
    }

    @discardableResult
    func candles(for symbol: String, timeframe: String = "5Min", limit: Int = 200) async throws -> [Candle] {
        let bars = try await client.fetchBars(symbol: symbol, timeframe: timeframe, limit: limit)
        cache[symbol] = bars
        return bars
    }

    func cachedCandles(for symbol: String) -> [Candle] {
        cache[symbol] ?? []
    }
}
