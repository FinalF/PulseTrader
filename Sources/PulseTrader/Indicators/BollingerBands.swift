import Foundation

struct BollingerBandsResult {
    let middle: [Double?]
    let upper: [Double?]
    let lower: [Double?]
}

enum BollingerBands {
    static func calculate(_ closes: [Double], period: Int = 20, standardDeviations: Double = 2.0) -> BollingerBandsResult {
        let middle = MovingAverages.sma(closes, period: period)
        var upper = [Double?](repeating: nil, count: closes.count)
        var lower = [Double?](repeating: nil, count: closes.count)

        guard closes.count >= period else {
            return BollingerBandsResult(middle: middle, upper: upper, lower: lower)
        }

        for i in (period - 1)..<closes.count {
            guard let mean = middle[i] else { continue }
            let window = closes[(i - period + 1)...i]
            let variance = window.reduce(0) { $0 + pow($1 - mean, 2) } / Double(period)
            let stdDev = sqrt(variance)
            upper[i] = mean + standardDeviations * stdDev
            lower[i] = mean - standardDeviations * stdDev
        }
        return BollingerBandsResult(middle: middle, upper: upper, lower: lower)
    }
}
