import SwiftUI
import Charts

struct IndicatorPanelView: View {
    let title: String
    let candles: [Candle]
    let values: [Double?]
    let range: ClosedRange<Double>
    let thresholds: [Double]
    @Binding var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(zip(candles, values)), id: \.0.id) { candle, value in
                    if let value {
                        LineMark(x: .value("Time", candle.timestamp), y: .value(title, value))
                            .foregroundStyle(.purple)
                    }
                }
                ForEach(thresholds, id: \.self) { threshold in
                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                }
                if let idx = selectedIndex, candles.indices.contains(idx) {
                    RuleMark(x: .value("Selected", candles[idx].timestamp))
                        .foregroundStyle(.gray.opacity(0.5))
                        .annotation(position: .top) {
                            if let value = values[idx] {
                                Text(String(format: "%.1f", value))
                                    .font(.caption2.bold())
                                    .padding(4)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                }
            }
            .chartYScale(domain: range)
            .frame(height: 120)
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

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        let xPosition = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xPosition), !candles.isEmpty else { return }
        selectedIndex = candles.indices.min(by: {
            abs(candles[$0].timestamp.timeIntervalSince(date)) < abs(candles[$1].timestamp.timeIntervalSince(date))
        })
    }
}
