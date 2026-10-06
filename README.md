# MarketSignalLab 0.4.0 — Professional Research Terminal

Native iPad Swift Playgrounds research terminal for market-data ingestion, chart analysis, label research and walk-forward model preparation.

## Frontend redesign

### Global density control

Chart, Research and Data now expose a persistent top-right interface-size control.

Available modes:

- Ultra Compact · 70%
- Compact · 80%
- Dense · 90%
- Standard · 100%
- Large · 115%

The selection is stored locally and applies across the whole terminal: sidebar typography, controls, workspace typography, card padding and key chart dimensions all respond to the same density setting.

At 80% and 70%, the left watchlist also becomes physically narrower: section spacing, minimum row height, status-dot spacing, symbol/name spacing and row insets are compressed so the sidebar behaves like a dense professional market terminal instead of only shrinking the font.


Version 0.4.0 replaces the prototype navigation with a compact research-terminal shell inspired by professional trading workspaces.

The design principles are:

- a persistent watchlist at the left edge;
- a small number of stable workspaces instead of many modal pages;
- symbol selection synchronized across Chart, Research and Data;
- chart controls directly above the chart;
- research results summarized as readable metrics before exposing details;
- cross-symbol research available from one screen.

## Workspaces

### Chart

The Chart workspace now includes:

- candlestick and line modes;
- 1m, 5m, 15m, 30m and 1h aggregation from locally stored 1-minute bars;
- 1D, 5D, 1M and ALL ranges;
- SMA20, SMA50, VWAP and Volume toggles;
- OHLC inspection;
- draggable crosshair;
- dynamically scaled price axis;
- compact quote/status header;
- direct Refresh and Historical Data actions.

This is implemented with native Swift Charts and local aggregation. No broker execution is included.

### Research

The new Research Lab has two scopes.

**Symbol**

Choose any symbol independently and view:

- local-data coverage;
- session count;
- research-row count;
- feature count;
- walk-forward folds;
- LONG/SHORT target quality;
- label calibration status;
- ranked calibration candidates.

**All Symbols**

The cross-symbol matrix shows:

- local bars;
- sessions;
- labeled rows;
- LONG/SHORT target rates;
- calibration status.

**Build All Local** creates research summaries for every watchlist symbol that already has at least 300 local 1-minute bars.

### Data

Data Center centralizes:

- provider availability counts;
- local-history coverage by symbol;
- historical downloader entry points;
- universe validation.

## Custom watchlist symbols

Use **Add Ticker** from the sidebar.

Custom symbols:

- are persisted locally on the iPad;
- are merged with the built-in universe;
- can be Equity, ETF, Crypto, Index or Commodity proxy;
- are checked with Twelve Data when an API key is available;
- can be removed from the watchlist through the row context menu.

The API key remains in Keychain and is never written to the repository.

## Existing research pipeline

The existing research foundation remains intact:

- partitioned historical storage;
- causal features;
- target-before-stop labels;
- session-safe walk-forward folds;
- fixed and ATR-adaptive label-policy calibration;
- test sessions excluded from policy ranking;
- diagnostics JSON.

## Current test workflow

1. Pull latest `main`.
2. Confirm **App Info → Version 0.4.0 / Build 16**.
3. Open **Chart** and verify candlestick/line switching, interval controls, range controls and indicator toggles.
4. Drag across the chart to inspect candles with the crosshair.
5. Tap **Add Ticker**, add one test symbol, then verify it appears in the watchlist.
6. Open **Research → Symbol** and switch between QQQ and another ticker.
7. Open **Research → All Symbols** and run **Build All Local**.
8. Open **Data** and verify local history coverage.

The project remains signal/research only. No broker execution is implemented.
