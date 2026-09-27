import SwiftUI

struct SignalBadgeView: View {
    let signal: TradeSignal

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: signal.direction == .buy ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(signal.direction == .buy ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(signal.direction == .buy ? "BUY" : "SELL") · \(signal.symbol)")
                    .font(.subheadline.bold())
                Text(signal.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(signal.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Int(signal.confidence * 100))%")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
