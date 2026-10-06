# MarketSignalLab 0.1.5 — Provider compatibility fixes

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Phase 1.5 additions

- Keeps the global Twelve Data rate limiter from v0.1.3.
- Adds the App Info runtime/version page from v0.1.4.
- Fixes crypto `/time_series` decoding by allowing crypto metadata to omit `symbol` and `exchange_timezone`.
- Falls back to the configured asset timezone; `BTC/USD` therefore uses UTC.
- Replaces the unavailable direct `VIX` index entry with `VIXY`, a US-listed VIX short-term futures ETF proxy compatible with the same equity/ETF feed family used by the rest of the Basic universe.
- Provider messages containing “parameter is missing or invalid” now classify as unavailable instead of generic error.

## Current V1 universe

Tradeable:
SPY, QQQ, NVDA, TSLA, AMD, META, AAPL, MSFT, AMZN, GLD, USO.

Context:
IWM, VIXY, UUP, IEF, BTC/USD.

## iPad workflow

1. Pull the latest `main`.
2. Confirm **App Info → Version 0.1.5 / Build 6**.
3. Tap **Validate Universe**. Stable symbols are skipped; only unresolved/new entries should require provider calls.
4. Fetch QQQ.
5. Prepare and share diagnostics.

The project remains signal/research only. No broker execution is implemented.
