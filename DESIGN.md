# PulseTrader — Design Document

This document is the source of truth for how PulseTrader is built: its layers,
its data contracts, and the rules for how they're allowed to change. It is
meant to be read alongside the code, not instead of it.

> **Keep this in sync.** Any change that adds/removes a service, changes a
> model's fields, changes a public function's signature in `Indicators/`,
> `SignalEngine/`, `Networking/`, or `Services/`, or changes a persisted key
> name, must update the relevant section below **in the same commit**. If
> you're not sure whether a change is "structural" enough to need a doc
> update, err on the side of updating it — a doc that's wrong is worse than
> no doc.

## 1. Goal

An iOS app for intraday stock trading that watches a list of symbols,
computes standard technical indicators on live price bars, and turns those
into buy/sell signals a human can act on. Order execution is scaffolded but
disabled by default (see §7).

## 2. Layers

```
Views (SwiftUI)
   ↓ reads/observes
AppState + Services   (SignalMonitorService, MarketDataService)
   ↓ calls
SignalEngine + Indicators   (pure math, no I/O)
   ↓ calls
Networking   (AlpacaMarketDataClient, AlpacaTradingClient)
   ↓ HTTP
Alpaca Markets API
```

Two things sit outside this vertical stack:

- **Local storage** — `KeychainService` (API keys) and `UserDefaults` via
  `Watchlist` (symbol list), reachable from `AppState`/`Networking`.
- **Notifications** — `SignalMonitorService` pushes local notifications
  directly via `UNUserNotificationCenter` when a signal fires.

### 2.1 Views (`Sources/PulseTrader/Views/`)

No business logic. Every view reads state from `AppState` /
`SignalMonitorService` via `@EnvironmentObject` and renders it. The only
logic that lives here is presentation logic (formatting, navigation).

| File | Owns |
|---|---|
| `RootTabView.swift` | Tab bar: Watchlist / Signals / Settings |
| `WatchlistView.swift` | Add/remove symbols, navigate to detail |
| `StockDetailView.swift` | Price + indicator charts for one symbol |
| `SignalsFeedView.swift` | Global feed of all recent signals |
| `SettingsView.swift` | API keys, polling interval, auto-trade toggle (disabled) |
| `Components/` | Reusable pieces: `SignalBadgeView`, `IndicatorPanelView`, `SignalHistoryView` |

### 2.2 AppState + Services (`Sources/PulseTrader/App/`, `Services/`)

`AppState` is the single dependency container, constructed once in
`PulseTraderApp.swift` and injected via `.environmentObject`. It owns:

- `watchlist: Watchlist` — the source of truth for tracked symbols, persisted
  on every mutation (`didSet`).
- `credentialsStore: AlpacaCredentialsStore`
- `marketData: MarketDataService`
- `signalMonitor: SignalMonitorService`

`SignalMonitorService` is the scheduler: a `Task` loop that wakes up every
`pollingInterval` seconds (default 60), and for each watched symbol:
1. fetches fresh candles via `MarketDataService`
2. runs `SignalEngine.evaluate(...)`
3. publishes any new `TradeSignal`s and fires a local notification

`MarketDataService` is a thin `actor`-based cache in front of
`AlpacaMarketDataClient` — callers get the last-known candles synchronously
via `cachedCandles(for:)` without re-fetching.

**Contract**: nothing outside `AppState` constructs `AlpacaCredentialsStore`,
`AlpacaMarketDataClient`, or `AlpacaTradingClient` directly — views and
services always go through `AppState`'s already-wired instances.

### 2.3 SignalEngine + Indicators (`Sources/PulseTrader/SignalEngine/`, `Indicators/`)

Pure Swift. No `Foundation` networking, no `UIKit`/`SwiftUI` imports beyond
`Foundation` itself. This is intentional — it's what makes `IndicatorTests.swift`
runnable without a simulator, and what would let this layer be reused in a
future backtester or CLI tool unchanged.

| File | Computes |
|---|---|
| `MovingAverages.swift` | SMA, EMA |
| `RSI.swift` | Wilder-smoothed RSI |
| `MACD.swift` | MACD line, signal line, histogram |
| `BollingerBands.swift` | Upper/middle/lower bands |
| `SignalEngine.swift` | Combines the above into `TradeSignal`s |

**Contract — `SignalEngine.evaluate(symbol:candles:config:)`**:
- Input: `[Candle]` ordered oldest → newest, `SignalEngine.Config` (periods
  and thresholds — see file for defaults).
- Output: zero or more `TradeSignal`s for the *latest* bar only. This
  function is stateless and re-evaluates from scratch each call; it does not
  track "have I already alerted on this crossover" — that dedup is the
  caller's job if ever needed.
- Current rules: RSI oversold/overbought, MACD signal-line crossover,
  price touching a Bollinger Band, and a `.combined` signal when 2+ of those
  agree in the same direction on the same bar.

Changing a threshold or period default only requires editing
`SignalEngine.Config`. Adding a new indicator means: add the math to
`Indicators/`, add its rule to `SignalEngine.evaluate`, add a case to
`SignalSource`, and add a test to `IndicatorTests.swift`.

### 2.4 Networking (`Sources/PulseTrader/Networking/`)

The only layer allowed to import `URLSession` / talk to the internet.

- `AlpacaCredentialsStore` — reads/writes keys via `KeychainService`, and
  decides which base URL to use (paper vs. live trading).
- `AlpacaMarketDataClient` — `GET /v2/stocks/{symbol}/bars`, decodes into
  `[Candle]`.
- `AlpacaTradingClient` — `POST /v2/orders`, gated by `isAutoTradingEnabled`
  (see §7).

**Contract**: both clients throw `AlpacaError` on failure
(`.missingCredentials`, `.autoTradingDisabled`, `.badResponse(Int)`,
`.decoding(Error)`) rather than returning optionals — callers are expected
to catch and surface `error.localizedDescription`.

## 3. Data models (`Sources/PulseTrader/Models/`)

| Type | Fields | Notes |
|---|---|---|
| `Candle` | `timestamp, open, high, low, close, volume` | One OHLCV bar |
| `Stock` | `symbol, displayName?` | Currently only `symbol` is used |
| `Watchlist` | `symbols: [String]` | Persisted as JSON in `UserDefaults` under key `com.pulsetrader.watchlist` |
| `TradeSignal` | `id, symbol, direction, source, reason, confidence, price, timestamp` | `direction: .buy/.sell`, `source: .rsi/.macd/.bollingerBands/.combined`, `confidence: 0...1` |

If you add a field to any of these, check whether it needs a default in
`Codable` decoding (for `Watchlist`) so existing persisted data doesn't fail
to load after an app update.

## 4. Persistence keys

| Store | Key | Holds |
|---|---|---|
| Keychain | `alpaca_key_id` | Alpaca API Key ID |
| Keychain | `alpaca_secret_key` | Alpaca API Secret Key |
| UserDefaults | `alpaca_use_paper` | Bool, paper vs. live trading |
| UserDefaults | `com.pulsetrader.watchlist` | JSON-encoded `Watchlist` |

Renaming any of these keys is a breaking change for existing installs
(the old value becomes unreadable) — treat it like a schema migration.

## 5. Signal → notification flow

```
SignalEngine.evaluate() returns [TradeSignal]
   → SignalMonitorService.recentSignals.insert(signal, at: 0)
   → SignalMonitorService.notify(signal) → UNUserNotificationCenter
```

`recentSignals` is capped at 200 entries (oldest dropped first). There is no
persistence for signal history yet — it resets on app relaunch. If that
changes, document the new storage here.

## 6. Testing (`Tests/PulseTraderTests/`)

`IndicatorTests.swift` covers SMA, RSI (trend sanity checks, not exact
reference values), MACD (nil-before-ready / non-nil-once-ready), Bollinger
Band ordering, and one `SignalEngine` integration test (oversold → buy).
Run with `Cmd+U` in Xcode. New indicator or signal-rule logic should ship
with a corresponding test in this file.

## 7. Auto-trading design (currently disabled)

`AlpacaTradingClient.submitOrder(_:)` is fully implemented against Alpaca's
order endpoint, but guarded by `isAutoTradingEnabled` (defaults to `false`).
As long as that flag is `false`, calling `submitOrder` always throws
`.autoTradingDisabled` before any network request is made — no order can
reach Alpaca, paper or live, through this code path.

**Nothing currently calls `submitOrder`.** `SignalMonitorService` only
evaluates and publishes signals; wiring a signal to an actual order is a
deliberate future step, not something that happens implicitly if the flag
is flipped.

Before enabling auto-trading, this section should be expanded with:
- Position sizing rules (fixed qty? % of buying power? per-symbol caps?)
- Max daily loss / circuit breaker
- Whether `.combined` signals only, or any single-indicator signal, can
  trigger an order
- Idempotency: what stops the same signal from submitting duplicate orders
  across polling cycles

## 8. Known limitations / roadmap

- Polling only runs while the app is foregrounded — no `BackgroundTasks`
  integration yet, so signals stop when the app is backgrounded/killed.
- No WebSocket streaming — all data is pulled via REST on a timer.
- No backtesting mode.
- No per-symbol override of `SignalEngine.Config` (thresholds are global).

Update this list as items are resolved or added.
