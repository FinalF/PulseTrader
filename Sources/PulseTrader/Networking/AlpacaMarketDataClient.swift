import Foundation

enum AlpacaError: LocalizedError {
    case missingCredentials
    case autoTradingDisabled
    case badResponse(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Alpaca API credentials are not configured. Add them in Settings."
        case .autoTradingDisabled:
            return "Auto-trading is disabled in this build. Enable it explicitly before submitting live orders."
        case .badResponse(let code):
            return "Alpaca API returned an unexpected response (\(code))."
        case .decoding(let error):
            return "Failed to decode Alpaca response: \(error.localizedDescription)"
        }
    }
}

/// Fetches historical & recent bars from Alpaca's Market Data API v2.
/// Docs: https://docs.alpaca.markets/reference/stockbars
final class AlpacaMarketDataClient {
    private let credentials: AlpacaCredentialsStore
    private let session: URLSession

    init(credentials: AlpacaCredentialsStore, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    /// Fetch recent bars for a symbol. Default timeframe suits intraday indicator calcs.
    func fetchBars(symbol: String, timeframe: String = "5Min", limit: Int = 200) async throws -> [Candle] {
        guard credentials.hasCredentials else { throw AlpacaError.missingCredentials }

        var components = URLComponents(
            url: credentials.marketDataBaseURL.appendingPathComponent("/v2/stocks/\(symbol)/bars"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "timeframe", value: timeframe),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "adjustment", value: "raw")
        ]

        var request = URLRequest(url: components.url!)
        credentials.authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AlpacaError.badResponse(code)
        }

        do {
            let decoded = try JSONDecoder.alpaca.decode(AlpacaBarsResponse.self, from: data)
            return decoded.bars.map { bar in
                Candle(timestamp: bar.t, open: bar.o, high: bar.h, low: bar.l, close: bar.c, volume: bar.v)
            }
        } catch {
            throw AlpacaError.decoding(error)
        }
    }
}

// MARK: - Alpaca DTOs

private struct AlpacaBarsResponse: Decodable {
    let bars: [AlpacaBar]
}

private struct AlpacaBar: Decodable {
    let t: Date
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double
}

// MARK: - Date decoding

extension JSONDecoder {
    /// Alpaca timestamps are RFC3339 with fractional seconds, e.g. "2024-01-02T14:30:00.123Z".
    static let alpaca: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { dateDecoder in
            let container = try dateDecoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = withFraction.date(from: raw) { return date }
            if let date = withoutFraction.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return decoder
    }()
}
