import Foundation

struct OrderRequest {
    let symbol: String
    let qty: Double
    let side: SignalDirection
    var type: String = "market"
    var timeInForce: String = "day"
}

struct OrderResult {
    let id: String
    let status: String
}

/// Wraps Alpaca's Trading API (https://docs.alpaca.markets/reference/postorder).
///
/// Auto-trading is OFF by default. This client is fully wired up so that
/// enabling execution later is a one-flag change (`isAutoTradingEnabled = true`),
/// not a rewrite. Until then, `submitOrder` always throws `.autoTradingDisabled`.
final class AlpacaTradingClient {
    private let credentials: AlpacaCredentialsStore
    private let session: URLSession

    /// Safety switch. Must be explicitly enabled before any order is submitted.
    var isAutoTradingEnabled = false

    init(credentials: AlpacaCredentialsStore, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    func submitOrder(_ order: OrderRequest) async throws -> OrderResult {
        guard isAutoTradingEnabled else { throw AlpacaError.autoTradingDisabled }
        guard credentials.hasCredentials else { throw AlpacaError.missingCredentials }

        var request = URLRequest(url: credentials.tradingBaseURL.appendingPathComponent("/v2/orders"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        credentials.authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body: [String: Any] = [
            "symbol": order.symbol,
            "qty": order.qty,
            "side": order.side == .buy ? "buy" : "sell",
            "type": order.type,
            "time_in_force": order.timeInForce
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AlpacaError.badResponse(code)
        }
        struct Response: Decodable { let id: String; let status: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return OrderResult(id: decoded.id, status: decoded.status)
    }
}
