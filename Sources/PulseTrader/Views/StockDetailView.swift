import SwiftUI
import Charts

struct StockDetailView: View {
    @EnvironmentObject private var appState: AppState
    let symbol: String

    @State private var selectedIndex: Int?

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
                    IndicatorPanelView(
                        title: "RSI (14)",
                        candles: candles,
                        values: rsi,
                        range: 0...100,
                        thresholds: [30, 70],
                        selectedIndex: $selectedIndex
                    )
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

    // MARK: - Price + Bollinger Bands

    private var priceChart: some View {
        VStack(alignment: .leading) {
            Text("Price + Bollinger Bands").font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(candles) { candle in
                    LineMark(x: .value("Time", candle.timestamp), y: .value("Value", candle.close))
                        .foregroundStyle(by: .value("Series", "Price"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                ForEach(Array(zip(candles, bb.upper)), id: \.0.id) { candle, upper in
                    if let upper {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Value", upper))
                            .foregroundStyle(by: .value("Series", "BB upper"))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                ForEach(Array(zip(candles, bb.lower)), id: \.0.id) { candle, lower in
                    if let lower {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Value", lower))
                            .foregroundStyle(by: .value("Series", "BB lower"))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                if let idx = selectedIndex, candles.indices.contains(idx) {
                    RuleMark(x: .value("Selected", candles[idx].timestamp))
                        .foregroundStyle(.gray.opacity(0.5))
                        .annotation(position: .top, alignment: .leading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candles[idx].timestamp, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                                Text("Price \(candles[idx].close, format: .currency(code: "USD"))")
                                    .font(.caption.bold())
                                if let upper = bb.upper[idx] {
                                    Text("Upper \(upper, format: .number.precision(.fractionLength(2)))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if let lower = bb.lower[idx] {
                                    Text("Lower \(lower, format: .number.precision(.fractionLength(2)))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                }
            }
            .chartForegroundStyleScale([
                "Price": Color.blue,
                "BB upper": Color.gray,
                "BB lower": Color.gray
            ])
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, proxy: proxy, geometry: geo)
                                }
                        )
                }
            }
        }
    }

    // MARK: - MACD

    private var macdChart: some View {
        VStack(alignment: .leading) {
            Text("MACD (12, 26, 9)").font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(zip(candles, macd.macdLine)), id: \.0.id) { candle, value in
                    if let value {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Value", value))
                            .foregroundStyle(by: .value("Series", "MACD"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                ForEach(Array(zip(candles, macd.signalLine)), id: \.0.id) { candle, value in
                    if let value {
                        LineMark(x: .value("Time", candle.timestamp), y: .value("Value", value))
                            .foregroundStyle(by: .value("Series", "Signal"))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                }
                if let idx = selectedIndex, candles.indices.contains(idx) {
                    RuleMark(x: .value("Selected", candles[idx].timestamp))
                        .foregroundStyle(.gray.opacity(0.5))
                        .annotation(position: .top, alignment: .leading) {
                            VStack(alignment: .leading, spacing: 2) {
                                if let m = macd.macdLine[idx] {
                                    Text("MACD \(m, format: .number.precision(.fractionLength(2)))")
                                        .font(.caption2)
                                }
                                if let s = macd.signalLine[idx] {
                                    Text("Signal \(s, format: .number.precision(.fractionLength(2)))")
                                        .font(.caption2)
                                }
                            }
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                }
            }
            .chartForegroundStyleScale(["MACD": Color.blue, "Signal": Color.orange])
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, proxy: proxy, geometry: geo)
                                }
                        )
                }
            }
        }
    }

    // MARK: - Shared crosshair

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        let xPosition = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xPosition), !candles.isEmpty else { return }
        selectedIndex = candles.indices.min(by: {
            abs(candles[$0].timestamp.timeIntervalSince(date)) < abs(candles[$1].timestamp.timeIntervalSince(date))
        })
    }
}
