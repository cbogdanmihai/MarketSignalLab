# MarketSignalLab 0.3.0 — Phase 2B Research Dataset

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Phase 1 complete

- Twelve Data provider integration.
- Shared rate limiter for the Basic API quota.
- 16 / 16 configured symbols validated.
- Recent 1-minute bar fetch and local persistence.
- Diagnostics JSON for ChatGPT collaboration.
- App Info page with version/build/runtime details.

## Phase 2A complete

- Historical 1-minute downloader with date-range requests.
- Three-day request chunks.
- Empty market windows are skipped instead of aborting an import.
- Partitioned local historical store.
- Monthly JSON partitions with deduplication.
- Existing Phase 1 data migrates automatically.
- Local coverage stats: count, earliest timestamp and latest timestamp.

## Phase 2B

The new **Research Dataset** page builds a causal intraday dataset entirely on the iPad.

### Session normalization

For equities and ETFs, research rows use the regular US session:

`09:30–16:00 America/New_York`

Crypto uses UTC 24/7 calendar days.

Rows never mix rolling features across separate equity sessions.

### Feature set

Current numeric predictors:

- minute of session
- normalized session progress
- returns: 1m, 5m, 15m, 30m, 60m
- candle range / close
- ATR(14) / close
- realized volatility over 20 one-minute returns
- volume z-score over 20 bars
- distance to SMA20
- distance to SMA50
- distance to running session high
- distance to running session low
- distance to causal session VWAP

Every feature is causal: it uses only the current bar and prior bars.

### Labels

Default Phase 2B target/stop labels:

- target: +0.75%
- stop: -0.35%
- horizon: 90 minutes

Both LONG and SHORT outcomes are computed independently.

Outcomes:

- `target`
- `stop`
- `timeout`
- `ambiguous`

If target and stop are both touched in the same 1-minute candle, the row is marked `ambiguous` rather than inventing an intrabar path.

The dataset also records:

- future return at the horizon
- MFE across the full horizon
- MAE across the full horizon

### Walk-forward validation

With enough rows, the app creates three expanding chronological folds.

Each fold contains:

- train
- validation
- test

A 90-minute purge is applied before validation/test boundaries to reduce target leakage from overlapping label horizons.

There are no random train/test splits.

## Current test workflow

1. Pull latest `main`.
2. Confirm **App Info → Version 0.3.0 / Build 10**.
3. Select **QQQ**.
4. Open **Research Dataset**.
5. Tap **Build Research Dataset**.
6. Review row count, target rates and walk-forward folds.
7. Prepare and share Diagnostics.

## Next

Phase 2C trains the first calibrated local baseline model and evaluates it strictly on the walk-forward folds before any prediction is exposed as a trading signal.

The project remains signal/research only. No broker execution is implemented.
