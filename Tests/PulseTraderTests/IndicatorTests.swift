import XCTest
@testable import PulseTrader

final class IndicatorTests: XCTestCase {

    func testSMABasic() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let sma = MovingAverages.sma(values, period: 3)
        XCTAssertNil(sma[0])
        XCTAssertNil(sma[1])
        XCTAssertEqual(sma[2], 2.0)
        XCTAssertEqual(sma[3], 3.0)
        XCTAssertEqual(sma[4], 4.0)
    }

    func testRSIReachesHighOnSustainedGains() {
        let prices = (0..<30).map { 100.0 + Double($0) } // strictly increasing
        let rsi = RSI.calculate(prices, period: 14)
        guard let last = rsi.last, let value = last else {
            return XCTFail("Expected an RSI value")
        }
        XCTAssertGreaterThan(value, 90, "RSI should be near 100 for a sustained uptrend")
    }

    func testRSIReachesLowOnSustainedLosses() {
        let prices = (0..<30).map { 200.0 - Double($0) } // strictly decreasing
        let rsi = RSI.calculate(prices, period: 14)
        guard let last = rsi.last, let value = last else {
            return XCTFail("Expected an RSI value")
        }
        XCTAssertLessThan(value, 10, "RSI should be near 0 for a sustained downtrend")
    }

    func testMACDNilBeforeEnoughData() {
        let prices = (0..<20).map { Double($0) }
        let macd = MACD.calculate(prices)
        XCTAssertNil(macd.macdLine.last!)
    }

    func testMACDProducesValuesWithEnoughData() {
        let prices = (0..<60).map { 100.0 + sin(Double($0) / 3.0) * 5 }
        let macd = MACD.calculate(prices)
        XCTAssertNotNil(macd.macdLine.last!)
        XCTAssertNotNil(macd.signalLine.last!)
    }

    func testBollingerBandsOrdering() {
        let prices = (0..<40).map { 100.0 + sin(Double($0) / 4.0) * 3 }
        let bb = BollingerBands.calculate(prices, period: 20)
        guard let upper = bb.upper.last!, let middle = bb.middle.last!, let lower = bb.lower.last! else {
            return XCTFail("Expected Bollinger Band values")
        }
        XCTAssertGreaterThan(upper, middle)
        XCTAssertGreaterThan(middle, lower)
    }

    func testSignalEngineDetectsOversoldBuy() {
        var prices = Array(repeating: 100.0, count: 40)
        for i in 30..<40 {
            prices[i] = prices[i - 1] - 3 // sharp decline drives RSI into oversold territory
        }
        let candles = prices.enumerated().map { index, price in
            Candle(
                timestamp: Date(timeIntervalSince1970: Double(index) * 300),
                open: price, high: price, low: price, close: price, volume: 1000
            )
        }
        let signals = SignalEngine.evaluate(symbol: "TEST", candles: candles)
        XCTAssertTrue(signals.contains { $0.direction == .buy })
    }
}
