import SwiftUI
import Charts

struct StockDetailView: View {
    @EnvironmentObject private var appState: AppState
    let symbol: String

    private var candles: [Candle] {
        appState.signalMonitor.candlesBySymbol[symbol] ?? []
    }
    private var closes: [Double] { candles.map(\.close) }
    private var rsi: [Double?] { RSI.calculate(closes) }
    private var macd: MACDResult { MACD.calculate(closes) }
    private var bb: BollingerBandsResult { BollingerBands.calculate(closes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if candles.isEmpty {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Add your Alpaca API keys in Settings, then pull to refresh.")
                    )
                    .padding(.top, 60)
                } else {
                    priceChart
                    IndicatorPanelView(title: "RSI (14)", values: rsi, range: 0...100, thresholds: [30, 70])
                    macdChart
                    SignalHistoryView(symbol: symbol)
                }
            }
            .padding()
        }
        .navigationTitle(symbol)
        .refreshable { await appState.signalMonitor.refreshOnce() }
        .task { await appState.signalMonitor.refreshOnce() }
    }

    private var priceChart: some View {
        VStack(alignment: .leading) {
            Text("Price + Bollinger Bands").font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(candles) { candle in
                    LineMark(x: .value("Time", candle.timestamp), y: .value("Close", candle.close))
                        .foregroundStyle(.blue)
                }
                ForEach(Array(zip(candles, bb.upper)), id: \.0.id) { candle, upper in
                    if let upper {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Upper BB", upper))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
                ForEach(Array(zip(candles, bb.lower)), id: \.0.id) { candle, lower in
                    if let lower {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Lower BB", lower))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private var macdChart: some View {
        VStack(alignment: .leading) {
            Text("MACD (12, 26, 9)").font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(zip(candles, macd.macdLine)), id: \.0.id) { candle, value in
                    if let value {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("MACD", value))
                            .foregroundStyle(.blue)
                    }
                }
                ForEach(Array(zip(candles, macd.signalLine)), id: \.0.id) { candle, value in
                    if let value {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Signal", value))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(height: 160)
        }
    }
}
