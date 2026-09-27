import Foundation

enum SignalDirection: String, Codable {
    case buy, sell
}

enum SignalSource: String, Codable {
    case rsi, macd, bollingerBands, combined
}

/// A single buy/sell signal produced by the SignalEngine.
struct TradeSignal: Identifiable, Codable, Equatable {
    let id: UUID
    let symbol: String
    let direction: SignalDirection
    let source: SignalSource
    let reason: String
    let confidence: Double // 0...1
    let price: Double
    let timestamp: Date

    init(
        symbol: String,
        direction: SignalDirection,
        source: SignalSource,
        reason: String,
        confidence: Double,
        price: Double,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.direction = direction
        self.source = source
        self.reason = reason
        self.confidence = confidence
        self.price = price
        self.timestamp = timestamp
    }
}
