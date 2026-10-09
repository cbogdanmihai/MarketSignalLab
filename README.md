# MarketSignalLab 0.7.0 — Phase 2C.1 Baseline + Data Operations

Native iPad Swift Playgrounds research terminal for market-data ingestion, chart analysis, causal feature research, label calibration and walk-forward model validation.

## Current QQQ research state

The QQQ label policy is locked and remains frozen unless explicitly changed:

- LONG target: 8.0× ATR
- LONG stop: 4.0× ATR
- SHORT target: 11.0× ATR
- SHORT stop: 4.5× ATR
- horizon: 90 minutes

The accepted calibration rates were approximately:

- LONG target: 9.4%
- SHORT target: 12.9%

Both are inside the 8–20% target-event acceptance band.

## Phase 2C.1 baseline

Research now includes the first local out-of-sample model baseline.

For each of the three chronological walk-forward folds and for LONG and SHORT separately, the app now:

1. builds the locked-policy research rows;
2. fits feature standardization on the training block only;
3. trains a logistic classifier on the training block only;
4. computes the no-skill probability from training prevalence;
5. selects the classification threshold on validation only;
6. scores the untouched test block;
7. reports Brier score, Brier skill vs no-skill, precision, recall, F1 and accuracy.

The first gate is deliberately conservative: mean Brier skill must be positive for both LONG and SHORT before the pipeline advances.

Probability calibration and richer models come after this baseline.

## Historical data operations

Historical Data now supports both selected-symbol and bulk downloads.

Bulk settings include:

- Tradeable / Context / All universe scope;
- shared start and end timestamps;
- 1-minute historical bars;
- skip symbols whose local coverage already spans the requested range;
- maximum request count;
- approximate provider runtime;
- per-asset and per-chunk progress;
- received-bar and skipped-symbol counts.

Bulk downloads are serialized through the shared Twelve Data rate limiter. Keep Swift Playgrounds open while a long bulk import is running.

Downloading new history invalidates research/calibration/model caches for that symbol, but a locked label policy remains frozen.

## Add Ticker

The Add Ticker sheet now uses explicit iPad keyboard focus instead of Form text-field behavior.

It supports:

- direct ticker/provider-symbol input;
- optional display name;
- Equity / ETF / Crypto / Index / Commodity proxy;
- provider validation when an API key is available;
- persistent local watchlist storage.

## Debugging

Runtime events now go to three places:

- the existing diagnostics JSON;
- the Swift Playgrounds console via tagged `print` output;
- an in-app **System → Debug Console** view.

Console lines use the form:

`[MarketSignalLab][INFO] ...`
`[MarketSignalLab][WARNING] ...`
`[MarketSignalLab][ERROR] ...`

The in-app console can be filtered and cleared.

## Chart

The chart remains the dynamic candle-index implementation:

- 1m → 1D
- 5m → 1D
- 15m → 5D
- 30m → 5D
- 1h → 1M
- horizontal pan;
- pinch zoom;
- +/- zoom;
- Fit and Latest controls;
- visible-range price scaling;
- synchronized volume;
- explicit crosshair mode.

Chart aggregation runs off the UI actor and only the visible viewport plus required indicator lookback is rendered.

## Leakage discipline

The rules remain strict:

- label calibration does not use walk-forward test blocks;
- label policy is locked before model training;
- feature scaling is fitted on train only;
- logistic model is trained on train only;
- decision threshold is selected on validation only;
- test blocks are used only for final fold scoring.

No live signal is allowed into the scanner until the baseline demonstrates out-of-sample skill.

## Verification

The repository contains a macOS GitHub Actions workflow that type-checks every Swift file under `Sources/AppModule` against the iOS Simulator SDK.

Current release:

- Version: 0.7.0
- Build: 32
- Release: Phase 2C.1 — Baseline + Data Operations

The project remains signal/research only. No broker execution is implemented.


## Phase 2C.3 — Regime-aware baseline

The probability-calibrated baseline exposed a strong directional regime drift: SHORT target prevalence fell materially across later development folds while the model continued to overpredict short-event probability.

To address this without increasing model complexity, the logistic baseline now adds six causal multi-session regime features:

- current-session return from the first eligible research row;
- return from the previous session close;
- previous-session return;
- previous 3-session return;
- previous 5-session return;
- prior 3-session realized-volatility average.

The model now uses 22 causal features in total.

These features use only information available at or before each row timestamp. No future labels are used.

## Sealed final holdout

Because model architecture is being refined after inspecting development walk-forward test results, the remaining sessions after the third development fold are now explicitly surfaced as a sealed final holdout.

The sealed holdout is not used for:

- label calibration;
- feature design;
- probability calibration;
- threshold selection;
- development model comparison.

It should remain unopened until the architecture and signal gate are frozen.


## Phase 2C.4 — Model comparison

The development OOS results showed that the self-regime 22-feature candidate degraded materially, especially on SHORT. The app no longer replaces the original model blindly.

Baseline training now compares three feature variants on the same development walk-forward folds:

- Core 16: the original intraday causal features;
- Self Regime 22: Core 16 plus the six self-regime features;
- Market Context 28: Core 16 plus causal SPY, IWM and VIXY context returns.

The market-context candidate uses, for each context symbol, current-session return and 5/15/60-minute returns. Rows are included only when all required context bars are available at the same timestamp. The candidate is run only when context coverage is at least 70%.

The recommended candidate is selected using the weakest-side development Brier skill, with average skill as a tie-breaker. The sealed holdout remains untouched.

If Market Context is unavailable, download matching SPY / IWM / VIXY 1-minute history via Historical Data → Bulk History and rerun the baseline experiment.


## One-tap market context preparation

Research now exposes **Prepare Context + Retrain** for the selected symbol.

The action:

- derives the required time range from the selected research dataset;
- adds one calendar day of warmup before the first research row;
- downloads only SPY, IWM and VIXY rather than the entire context universe;
- skips symbols whose local coverage already spans the required interval;
- uses the shared Twelve Data rate limiter;
- reports per-asset download progress in Research;
- automatically reruns the Core 16 / Self Regime 22 / Market Context 28 comparison after the context download finishes.

This avoids the previous ambiguity where the generic Context bulk scope did not include SPY because SPY is a tradeable asset.


## Phase 2C.5 — Nested ridge regularization

The Core 16 candidate remained best while Self Regime 22 and Market Context 28 degraded development OOS performance. Before adding more model complexity, the logistic baseline now tunes L2 regularization causally inside each training block.

For every outer walk-forward fold and direction:

- the outer training sessions are split chronologically into inner train and inner validation sessions;
- L2 is selected from a fixed grid using inner-validation Brier score only;
- the final logistic model is refit on the full outer training block with the selected L2;
- outer validation remains reserved for Platt calibration and decision-threshold selection;
- outer test remains development OOS only;
- the sealed holdout remains untouched.

The selected L2 is shown per fold in Research.

This change targets the likely overfitting/multicollinearity exposed by the larger feature sets without adding a neural model prematurely.


## Phase 2D — Asymmetric directional gate

Nested ridge regularization materially reduced the SHORT degradation, but no SHORT candidate achieved positive mean development Brier skill. At the same time, the Core 16 LONG candidate remained positive.

The architecture therefore stops forcing one model to serve both directions.

The new development gate selects the best candidate independently for LONG and SHORT and enables a direction only when:

- mean development Brier skill is positive;
- at least two of three development OOS folds have positive skill;
- at least three folds are available.

If a direction fails the gate, its output is explicitly NO_TRADE.

This development gate does not open the sealed holdout and does not yet create live signals. It is the architecture-freeze step before final development fitting and one-time sealed holdout evaluation.
