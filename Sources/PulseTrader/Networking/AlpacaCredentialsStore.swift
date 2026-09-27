import Foundation

/// Stores Alpaca API credentials securely in the Keychain and exposes
/// the correct base URLs / auth headers for the market data and trading clients.
final class AlpacaCredentialsStore {
    private let keychain: KeychainService
    private let keyIDKey = "alpaca_key_id"
    private let secretKeyKey = "alpaca_secret_key"
    private let paperTradingKey = "alpaca_use_paper"

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    var keyID: String? {
        get { keychain.read(keyIDKey) }
        set { keychain.save(newValue, for: keyIDKey) }
    }

    var secretKey: String? {
        get { keychain.read(secretKeyKey) }
        set { keychain.save(newValue, for: secretKeyKey) }
    }

    var usePaperTrading: Bool {
        get { UserDefaults.standard.object(forKey: paperTradingKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: paperTradingKey) }
    }

    var hasCredentials: Bool {
        guard let id = keyID, let secret = secretKey else { return false }
        return !id.isEmpty && !secret.isEmpty
    }

    var authHeaders: [String: String] {
        guard let id = keyID, let secret = secretKey else { return [:] }
        return ["APCA-API-KEY-ID": id, "APCA-API-SECRET-KEY": secret]
    }

    /// Market data is the same endpoint whether you're on a paper or live account.
    var marketDataBaseURL: URL { URL(string: "https://data.alpaca.markets")! }

    /// Trading endpoint differs between paper and live accounts.
    var tradingBaseURL: URL {
        usePaperTrading
            ? URL(string: "https://paper-api.alpaca.markets")!
            : URL(string: "https://api.alpaca.markets")!
    }
}
