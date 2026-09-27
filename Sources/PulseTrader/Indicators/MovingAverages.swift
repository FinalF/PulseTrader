import Foundation

enum MovingAverages {
    /// Simple moving average. Index i holds nil until `period` values are available.
    static func sma(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0, values.count >= period else {
            return Array(repeating: nil, count: values.count)
        }
        var result = [Double?](repeating: nil, count: values.count)
        var runningSum = 0.0
        for i in 0..<values.count {
            runningSum += values[i]
            if i >= period { runningSum -= values[i - period] }
            if i >= period - 1 { result[i] = runningSum / Double(period) }
        }
        return result
    }

    /// Exponential moving average, seeded with an SMA over the first `period` values.
    static func ema(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0, !values.isEmpty else { return [] }
        var result = [Double?](repeating: nil, count: values.count)
        guard values.count >= period else { return result }

        let multiplier = 2.0 / Double(period + 1)
        let seed = values[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = seed
        var previous = seed
        for i in period..<values.count {
            let value = (values[i] - previous) * multiplier + previous
            result[i] = value
            previous = value
        }
        return result
    }
}
