import Foundation

/// A single OHLCV price bar for a given timeframe (e.g. 5-minute bar).
struct Candle: Identifiable, Codable, Equatable {
    var id: Date { timestamp }
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}
