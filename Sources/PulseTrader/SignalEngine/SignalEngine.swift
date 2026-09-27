import Foundation

/// Turns raw indicator math into actionable buy/sell signals.
enum SignalEngine {

    struct Config {
        var rsiPeriod = 14
        var rsiOverbought = 70.0
        var rsiOversold = 30.0
        var macdFast = 12
        var macdSlow = 26
        var macdSignal = 9
        var bbPeriod = 20
        var bbStdDev = 2.0
    }

    /// Evaluates the latest bar of a candle series and returns any signals triggered.
    static func evaluate(symbol: String, candles: [Candle], config: Config = Config()) -> [TradeSignal] {
        let minRequired = max(config.macdSlow + config.macdSignal, config.bbPeriod, config.rsiPeriod + 1) + 1
        guard candles.count >= minRequired else { return [] }

        let closes = candles.map(\.close)
        let lastIndex = closes.count - 1
        let prevIndex = lastIndex - 1
        let latestPrice = closes[lastIndex]
        let timestamp = candles[lastIndex].timestamp

        var signals: [TradeSignal] = []

        // RSI: overbought / oversold
        let rsi = RSI.calculate(closes, period: config.rsiPeriod)
        if let rsiNow = rsi[lastIndex] {
            if rsiNow < config.rsiOversold {
                signals.append(TradeSignal(
                    symbol: symbol, direction: .buy, source: .rsi,
                    reason: "RSI \(Int(rsiNow)) is oversold (< \(Int(config.rsiOversold)))",
                    confidence: 0.5, price: latestPrice, timestamp: timestamp))
            } else if rsiNow > config.rsiOverbought {
                signals.append(TradeSignal(
                    symbol: symbol, direction: .sell, source: .rsi,
                    reason: "RSI \(Int(rsiNow)) is overbought (> \(Int(config.rsiOverbought)))",
                    confidence: 0.5, price: latestPrice, timestamp: timestamp))
            }
        }

        // MACD: signal-line crossover
        let macd = MACD.calculate(closes, fastPeriod: config.macdFast, slowPeriod: config.macdSlow, signalPeriod: config.macdSignal)
        if let macdNow = macd.macdLine[lastIndex], let sigNow = macd.signalLine[lastIndex],
           let macdPrev = macd.macdLine[prevIndex], let sigPrev = macd.signalLine[prevIndex] {
            let crossedUp = macdPrev <= sigPrev && macdNow > sigNow
            let crossedDown = macdPrev >= sigPrev && macdNow < sigNow
            if crossedUp {
                signals.append(TradeSignal(
                    symbol: symbol, direction: .buy, source: .macd,
                    reason: "MACD crossed above its signal line",
                    confidence: 0.6, price: latestPrice, timestamp: timestamp))
            } else if crossedDown {
                signals.append(TradeSignal(
                    symbol: symbol, direction: .sell, source: .macd,
                    reason: "MACD crossed below its signal line",
                    confidence: 0.6, price: latestPrice, timestamp: timestamp))
            }
        }

        // Bollinger Bands: price touching the bands
        let bb = BollingerBands.calculate(closes, period: config.bbPeriod, standardDeviations: config.bbStdDev)
        if let lower = bb.lower[lastIndex], latestPrice <= lower {
            signals.append(TradeSignal(
                symbol: symbol, direction: .buy, source: .bollingerBands,
                reason: "Price touched the lower Bollinger Band",
                confidence: 0.4, price: latestPrice, timestamp: timestamp))
        } else if let upper = bb.upper[lastIndex], latestPrice >= upper {
            signals.append(TradeSignal(
                symbol: symbol, direction: .sell, source: .bollingerBands,
                reason: "Price touched the upper Bollinger Band",
                confidence: 0.4, price: latestPrice, timestamp: timestamp))
        }

        // Combined, higher-confidence signal when 2+ indicators agree.
        let buys = signals.filter { $0.direction == .buy }
        let sells = signals.filter { $0.direction == .sell }
        if buys.count >= 2 {
            signals.append(TradeSignal(
                symbol: symbol, direction: .buy, source: .combined,
                reason: "\(buys.count) indicators agree: " + buys.map(\.reason).joined(separator: "; "),
                confidence: min(1.0, buys.map(\.confidence).reduce(0, +)),
                price: latestPrice, timestamp: timestamp))
        }
        if sells.count >= 2 {
            signals.append(TradeSignal(
                symbol: symbol, direction: .sell, source: .combined,
                reason: "\(sells.count) indicators agree: " + sells.map(\.reason).joined(separator: "; "),
                confidence: min(1.0, sells.map(\.confidence).reduce(0, +)),
                price: latestPrice, timestamp: timestamp))
        }

        return signals
    }
}
