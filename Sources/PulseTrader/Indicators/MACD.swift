import Foundation

struct MACDResult {
    let macdLine: [Double?]
    let signalLine: [Double?]
    let histogram: [Double?]
}

enum MACD {
    static func calculate(
        _ closes: [Double],
        fastPeriod: Int = 12,
        slowPeriod: Int = 26,
        signalPeriod: Int = 9
    ) -> MACDResult {
        let fastEMA = MovingAverages.ema(closes, period: fastPeriod)
        let slowEMA = MovingAverages.ema(closes, period: slowPeriod)

        var macdLine = [Double?](repeating: nil, count: closes.count)
        for i in 0..<closes.count {
            if let fast = fastEMA[i], let slow = slowEMA[i] {
                macdLine[i] = fast - slow
            }
        }

        let macdValuesOnly = macdLine.compactMap { $0 }
        let signalOnly = MovingAverages.ema(macdValuesOnly, period: signalPeriod)

        var signalLine = [Double?](repeating: nil, count: closes.count)
        var histogram = [Double?](repeating: nil, count: closes.count)
        var signalCursor = 0
        for i in 0..<closes.count {
            guard macdLine[i] != nil else { continue }
            if signalCursor < signalOnly.count, let sig = signalOnly[signalCursor] {
                signalLine[i] = sig
                histogram[i] = macdLine[i]! - sig
            }
            signalCursor += 1
        }

        return MACDResult(macdLine: macdLine, signalLine: signalLine, histogram: histogram)
    }
}
