# MarketSignalLab 0.5.0 — Phase 2B.6 Asymmetric Label Calibration

Native iPad Swift Playgrounds research terminal for market-data ingestion, chart analysis, label research and walk-forward model preparation.

## Current objective

The frontend is now considered stable enough for research work. Development focus returns to the signal pipeline.

QQQ currently has sufficient history and clean session-safe walk-forward folds, but the best symmetric label policy still produces an imbalanced event frequency:

- LONG target rate: about 9.4%
- SHORT target rate: about 23.7%
- acceptance band: 8–20% per direction

That means model training remains blocked until the label definition is improved.

## Phase 2B.6

Label calibration now supports **asymmetric LONG and SHORT thresholds**.

This is intentional: the market does not need to have identical upside and downside excursion distributions, and forcing one symmetric ATR target can create artificial class imbalance.

The calibration grid still contains the original fixed and symmetric ATR policies, plus directional candidates around the current QQQ optimum:

- LONG 8.0× ATR / 4.0× stop · SHORT 9.0× / 4.0×
- LONG 8.0× / 4.0× · SHORT 10.0× / 4.0×
- LONG 8.0× / 4.0× · SHORT 11.0× / 4.5×
- LONG 7.5× / 3.75× · SHORT 9.0× / 4.0×
- LONG 7.5× / 3.75× · SHORT 10.0× / 4.0×

All candidates retain the 90-minute horizon.

## Leakage rule

Calibration still ranks policies using only the earliest walk-forward train + validation window.

Test sessions are reserved and remain untouched by label-policy selection.

## Acceptance rule

A candidate is accepted only when:

- LONG target-event rate is 8–20%
- SHORT target-event rate is 8–20%
- ambiguous-candle rate is at most 1%

Ranking also considers directional balance, session-to-session stability and ambiguity.

## Next workflow

1. Pull latest `main`.
2. Confirm **App Info → Version 0.5.0 / Build 22**.
3. Select QQQ.
4. Open **Research**.
5. Build Dataset if needed.
6. Run **Calibrate Labels** again.
7. Inspect whether a directional candidate becomes **ACCEPTED**.
8. Share Diagnostics.

If one candidate passes, the next phase is **Policy Lock**: rebuild the complete dataset using that selected label policy and freeze it before Phase 2C baseline model training.

If none passes, the grid will be refined again without touching the walk-forward test sessions.

The project remains signal/research only. No broker execution is implemented.
