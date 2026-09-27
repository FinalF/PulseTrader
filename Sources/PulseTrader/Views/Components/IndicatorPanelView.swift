import SwiftUI
import Charts

struct IndicatorPanelView: View {
    let title: String
    let values: [Double?]
    let range: ClosedRange<Double>
    let thresholds: [Double]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    if let value {
                        LineMark(x: .value("Index", index), y: .value(title, value))
                            .foregroundStyle(.purple)
                    }
                }
                ForEach(thresholds, id: \.self) { threshold in
                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                }
            }
            .chartYScale(domain: range)
            .frame(height: 120)
        }
    }
}
