# MarketSignalLab 0.2.0 — Phase 2A Historical Ingestion

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Phase 1 complete

- 16 / 16 configured symbols validate on the current Twelve Data account.
- Global provider rate limiter protects the Basic 8-credits/minute quota.
- QQQ live/recent fetch is working and persists locally.
- App Info shows version, build, local/UTC clock and runtime details.
- Diagnostics JSON supports direct ChatGPT collaboration.

## Phase 2A

### Historical downloader

The new **Historical Data** page downloads canonical 1-minute OHLCV bars for the currently selected asset.

- User-selectable start and end datetime.
- 3-day request chunks.
- Global Twelve Data pacing remains active.
- Maximum 90 days per import run in this phase.
- Progress, request count and received-bar count are visible in the UI.
- Provider errors stop the import cleanly and are recorded in diagnostics.
- Empty market periods can be skipped without aborting the run.

Twelve Data allows a maximum of 5,000 points in one historical response. Three-day chunks keep a 24/7 1-minute series below that ceiling while also working for US equities and ETFs.

### Local historical store

The old single-file JSON store has been replaced by a partitioned store:

`Application Support / MarketSignalLab / BarsV2 / <symbol> / <timeframe> / YYYY-MM.json`

- Bars are deduplicated by canonical bar ID.
- Partitions are monthly.
- Existing Phase 1 JSON files are migrated automatically when first loaded.
- The UI exposes local count, earliest bar and latest bar.
- Diagnostics include historical download state and storage coverage.

## Current universe

Tradeable:
SPY, QQQ, NVDA, TSLA, AMD, META, AAPL, MSFT, AMZN, GLD, USO.

Context:
IWM, VIXY, UUP, IEF, BTC/USD.

## Test workflow

1. Pull latest `main`.
2. Open **App Info** and confirm **Version 0.2.0 / Build 7**.
3. Select **QQQ**.
4. Open **Historical Data**.
5. Keep the default 7-day range for the first test.
6. Tap **Download Historical Data** and let it finish.
7. Prepare and share Diagnostics.

## Next

Phase 2B builds the first local research dataset from stored bars:

`canonical bars → session normalization → features → target/stop labels → walk-forward splits`

The project remains signal/research only. No broker execution is implemented.
