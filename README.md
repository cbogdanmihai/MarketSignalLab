# MarketSignalLab 0.6.0 — Phase 2B.7 Policy Lock

MarketSignalLab has reached the point where QQQ has an accepted asymmetric label policy and can move from label design into model research.

## Accepted QQQ policy

Current accepted calibration:

- LONG target: 8.0× ATR
- LONG stop: 4.0× ATR
- SHORT target: 11.0× ATR
- SHORT stop: 4.5× ATR
- horizon: 90 minutes

Observed calibration event rates are approximately:

- LONG target: 9.4%
- SHORT target: 12.9%

Both are inside the 8–20% acceptance band.

## Policy Lock

The Research workspace now exposes **Lock & Rebuild** when the recommended calibration is accepted.

Locking does four things:

1. Persists the selected policy per symbol in local UserDefaults.
2. Freezes the policy so later dataset builds use exactly the same label definition.
3. Rebuilds the full local research dataset with the locked asymmetric ATR thresholds.
4. Marks the dataset as using a locked policy in Research, App Info and Diagnostics.

The locked policy survives app restarts and historical-data refreshes until it is explicitly changed or removed.

## Research dataset behavior

The dataset builder now accepts either:

- the baseline fixed label configuration, or
- a locked LabelCalibrationPolicy.

For a locked ATR-adaptive policy, each row calculates ATR(14) causally at that timestamp, then derives independent LONG and SHORT target/stop thresholds from the frozen multipliers.

Features remain unchanged and causal.

Walk-forward folds remain session-safe and chronological.

## Leakage discipline

Label calibration continues to use the pre-test calibration window only.

The policy is selected before model training and then frozen.

The next phase must not re-optimize the label policy against walk-forward test outcomes.

## Next

After QQQ is locked and rebuilt, Phase 2C starts the first local baseline classifier.

Planned baseline sequence:

- no-skill prevalence baseline
- logistic classifier
- probability calibration
- walk-forward train / validation / test scoring
- Brier score and calibration error
- precision / recall by LONG and SHORT target
- threshold selection only on validation
- final reporting on untouched test sessions

No live signal is allowed into the scanner until the baseline beats the no-skill reference out of sample.

The project remains signal/research only. No broker execution is implemented.


## Chart 3 — TradingView-style dynamic viewport

The chart now uses candle index rather than wall-clock time for the horizontal axis. This removes large overnight/weekend gaps and makes pan/zoom behavior closer to professional charting terminals.

Adaptive interval defaults:

- 1m → 1D
- 5m → 1D
- 15m → 5D
- 30m → 5D
- 1h → 1M

Changing timeframe automatically selects a useful default range and jumps to the latest data. Manual 1D / 5D / 1M / ALL remains available.

Additional behavior:

- horizontal drag scrolls through candles;
- pinch gesture zooms candle density;
- +/- magnifiers zoom around the visible center;
- Fit resets the selected range;
- Latest jumps back to the newest candle;
- price and volume share the same scroll position;
- the right price scale rescales to the visible candles;
- the toolbar reports visible candles vs loaded candles;
- full current local history is retained up to a 20,000 aggregated-bar safety cap.

Crosshair remains an explicit inspection mode so it does not steal the normal scroll gesture.


## Compiler guard

The repository now includes a macOS GitHub Actions iOS type-check workflow for every Swift source under `Sources/AppModule`.

This was introduced after the dynamic-chart refactor so compiler errors are caught across the whole module instead of being discovered one at a time in Swift Playgrounds.

A full iOS Simulator SDK type-check was run successfully after the Chart 3.3 fixes.


## Runtime performance guard

Chart 3.4 removes the startup bottleneck discovered with ~16K local QQQ 1-minute bars.

Changes:

- chart aggregation is cached in view state instead of recomputed on every SwiftUI render;
- aggregation runs off the main UI actor;
- only the visible viewport plus indicator/session lookback is rendered;
- horizontal pan is implemented against the lightweight viewport instead of rendering the entire archive into Swift Charts;
- the root view no longer performs a duplicate selected-symbol load plus a full-universe storage scan on startup;
- selected-symbol storage statistics are derived from the already loaded bars instead of decoding the same local history a second time.

The repository-wide iOS Swift typecheck passes after these changes.
