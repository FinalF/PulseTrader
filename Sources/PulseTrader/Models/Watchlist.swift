import Foundation

/// The list of tickers the user is actively monitoring, persisted locally.
struct Watchlist: Codable, Equatable {
    var symbols: [String]

    static let `default` = Watchlist(symbols: ["AAPL", "TSLA", "NVDA", "SPY"])

    private static let storageKey = "com.pulsetrader.watchlist"

    func saveToDisk() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func loadFromDisk() -> Watchlist? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode(Watchlist.self, from: data) else { return nil }
        return list
    }

    mutating func add(_ symbol: String) {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty, !symbols.contains(upper) else { return }
        symbols.append(upper)
    }

    mutating func remove(_ symbol: String) {
        symbols.removeAll { $0 == symbol.uppercased() }
    }
}
