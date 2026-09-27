# PulseTrader

An iOS app for intraday stock trading signals. It polls live market data,
computes MACD, RSI, and Bollinger Bands, and surfaces buy/sell alerts per
watchlist symbol. Order execution is *not* enabled yet by design — see
"Auto-trading roadmap" below.

## Requirements

- Xcode 15+ (iOS 16+ deployment target — needed for Swift Charts)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`
  (`brew install xcodegen`)
- A free [Alpaca](https://alpaca.markets) account for paper-trading market data
  and API keys

## Setup

```bash
# 1. Move the project to where you want it
mv PulseTrader "/Users/flame/Projects/Claude Project/PulseTrader"
cd "/Users/flame/Projects/Claude Project/PulseTrader"

# 2. Generate the Xcode project
xcodegen generate

# 3. Open it
open PulseTrader.xcodeproj
```

Build and run on a simulator (or device with your Apple ID as the signing
team, set in the project's Signing & Capabilities tab).

In the app, go to **Settings** and paste in your Alpaca **paper trading**
Key ID and Secret Key (Alpaca dashboard → "API Keys"). Then add symbols on
the **Watchlist** tab — signals show up under the **Signals** tab and as
push notifications as soon as an indicator triggers.

> No XcodeGen? Create a new Xcode "App" project named `PulseTrader`
> (SwiftUI interface, iOS 16 minimum), delete its default files, and drag
> the `Sources/PulseTrader` folder into it instead. For tests, add a new
> Unit Testing Bundle target and drag in `Tests/PulseTraderTests`.

## Design document

See [`DESIGN.md`](./DESIGN.md) for the full architecture, data model
contracts, persisted storage keys, and the auto-trading safety design. Keep
it updated alongside structural code changes — it has an explicit rule for
when an update is required.

## Architecture

```
Sources/PulseTrader/
  App/            App entry point + AppState (dependency container)
  Models/         Candle, Stock, Watchlist, TradeSignal
  Indicators/     Pure-math SMA/EMA, RSI, MACD, Bollinger Bands
  SignalEngine/   Combines indicator output into buy/sell TradeSignals
  Networking/     AlpacaCredentialsStore, market data + trading REST clients
  Services/       KeychainService, MarketDataService (caching), 
                  SignalMonitorService (polling loop + notifications)
  Views/          SwiftUI screens: Watchlist, Stock Detail (charts),
                  Signals feed, Settings
Tests/PulseTraderTests/  Unit tests for every indicator + the signal engine
```

The indicator math and signal logic are plain Swift with no UIKit/SwiftUI
dependency, so they're fully unit-testable (`Cmd+U` in Xcode).

### How signals are generated

`SignalMonitorService` polls every watched symbol on a timer (default 60s,
configurable in Settings), pulls the latest bars from Alpaca, and runs
`SignalEngine.evaluate(...)`:

- **RSI** < 30 → buy, > 70 → sell
- **MACD** crossing above/below its signal line → buy/sell
- **Bollinger Bands**: price touching the lower/upper band → buy/sell
- When 2+ of the above agree in the same direction, a higher-confidence
  **combined** signal is also emitted

Tune thresholds/periods via `SignalEngine.Config`.

## Auto-trading roadmap

`AlpacaTradingClient.submitOrder(...)` is fully implemented against
Alpaca's `/v2/orders` endpoint, but gated behind `isAutoTradingEnabled`
(defaults to `false`). Nothing will place a real order — paper or live —
until that flag is flipped and `SignalMonitorService` is wired to call
`submitOrder` on a triggered signal. This is intentional: get the signal
quality right first, then decide sizing/risk rules for auto-execution.

Other natural next steps:
- Stream real-time bars via Alpaca's WebSocket API instead of polling
- Backtesting mode to replay historical bars through `SignalEngine`
- Per-symbol indicator threshold overrides
- Risk controls (position sizing, max daily loss) before enabling auto-trade
- Background refresh via `BackgroundTasks` so signals fire even when the
  app isn't in the foreground (current polling only runs while the app is open)

## Notes

- All indicator math (`Indicators/`) has no network or UI dependency —
  it's safe to reuse in a backtester or command-line tool later.
- API keys are stored in the iOS Keychain, never in `UserDefaults` or on disk in plaintext.
