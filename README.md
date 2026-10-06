# MarketSignalLab 0.3.5 — Phase 2B.5 Label Calibration

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Completed foundation

- Twelve Data ingestion with shared Basic-plan pacing.
- 16 configured tradeable/context symbols validated.
- Partitioned local 1-minute historical store with deduplication.
- Session-normalized causal feature pipeline.
- Target-before-stop labels with explicit ambiguous-candle handling.
- Session-safe chronological walk-forward folds.
- Diagnostics JSON and App Info collaboration/runtime pages.

## Phase 2B.5 — Label calibration

The **Research Dataset** page now includes a **Calibrate Label Policies** step before model training.

The calibration engine compares ten candidate label policies:

Fixed percentage candidates:

- 0.45% target / 0.25% stop
- 0.55% / 0.30%
- 0.65% / 0.35%
- 0.75% / 0.35% baseline
- 0.85% / 0.40%

ATR-adaptive candidates:

- 4.0× ATR target / 2.0× ATR stop
- 5.0× / 2.5×
- 6.0× / 3.0×
- 7.0× / 3.5×
- 8.0× / 4.0×

All candidates currently use a 90-minute horizon.

### Leakage rule

Label-policy ranking uses only the earliest walk-forward **train + validation** window.

No session that belongs to any walk-forward test block is used to rank the policies.

This makes label calibration a pre-test model-design step rather than an optimization against future test outcomes.

### Acceptance band

A candidate is accepted when:

- LONG target-event rate is 8–20%
- SHORT target-event rate is 8–20%
- ambiguous-bar rate is at most 1%

Ranking additionally considers:

- LONG/SHORT target balance
- session-to-session target-rate stability
- ambiguity
- closeness to the target-event acceptance band

The UI also reports a **payoff proxy**. This is a label-quality diagnostic, not a strategy backtest:

- target → +target threshold
- stop → -stop threshold
- timeout → horizon return
- ambiguous → zero

### Next decision

Run calibration on QQQ after the 60-day historical import.

If a policy passes the acceptance band, the next change will lock that policy and rebuild the complete dataset before Phase 2C.

If none passes, expand/refine the candidate grid rather than training a classifier on a sparse target definition.

## Current test workflow

1. Pull latest `main`.
2. Confirm **App Info → Version 0.3.5 / Build 15**.
3. Select QQQ.
4. Open **Research Dataset**.
5. Build Research Dataset if needed.
6. Tap **Calibrate Label Policies**.
7. Review the recommendation and candidate ranking.
8. Prepare and share Diagnostics.

The project remains signal/research only. No broker execution is implemented.
