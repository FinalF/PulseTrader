import Foundation

enum RSI {
    /// Classic Wilder RSI. Returns nil for indices before there's enough data.
    static func calculate(_ closes: [Double], period: Int = 14) -> [Double?] {
        guard closes.count > period else {
            return Array(repeating: nil, count: closes.count)
        }
        var result = [Double?](repeating: nil, count: closes.count)
        var gains = 0.0
        var losses = 0.0

        for i in 1...period {
            let change = closes[i] - closes[i - 1]
            if change >= 0 { gains += change } else { losses -= change }
        }
        var avgGain = gains / Double(period)
        var avgLoss = losses / Double(period)
        result[period] = rsiValue(avgGain: avgGain, avgLoss: avgLoss)

        for i in (period + 1)..<closes.count {
            let change = closes[i] - closes[i - 1]
            let gain = max(change, 0)
            let loss = max(-change, 0)
            avgGain = (avgGain * Double(period - 1) + gain) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + loss) / Double(period)
            result[i] = rsiValue(avgGain: avgGain, avgLoss: avgLoss)
        }
        return result
    }

    private static func rsiValue(avgGain: Double, avgLoss: Double) -> Double {
        if avgLoss == 0 { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
}
