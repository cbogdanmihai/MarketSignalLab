# MarketSignalLab 0.1.3 — Rate-limit hardening

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Phase 1.3 additions

- App-wide Twelve Data request pacing through a shared actor.
- Basic-plan-safe spacing: one request slot every 8.2 seconds.
- The limiter applies to both universe validation and manual bar fetches.
- HTTP 429 honors `Retry-After` when available and otherwise applies a 65-second cooldown.
- Successful responses with `api-credits-left: 0` proactively defer the next request.
- Validation no longer stacks a second manual delay on top of provider pacing.
- Manual Fetch is disabled while universe validation is running.
- Stable symbol validation states are still preserved across temporary throttling.
- Diagnostics workflow remains available and does not include the API key.

## Why this change

Twelve Data Basic currently provides 8 API credits per minute and 800 per day. A standard `/time_series` request costs 1 credit per symbol. The app therefore serializes requests globally instead of letting validation and manual fetches compete for the same quota.

## iPad workflow

1. Pull the latest `main`.
2. Open the `.swiftpm` project in Swift Playgrounds.
3. Settings → enter the Twelve Data API key → Save.
4. Tap **Validate Universe** once.
5. Let it complete; do not use **Force Revalidate** unless needed.
6. Fetch QQQ or another green symbol.
7. **Prepare Diagnostics** → **Share Diagnostics** → send the JSON to ChatGPT.

## Status meanings

- Green check: available on the current account.
- Orange lock: access/subscription restriction.
- Red x: unavailable or invalid symbol/data.
- Orange clock: temporarily rate limited.
- Yellow warning: other provider/network/decoding error.

## Architecture

`assets.json → shared rate limiter → validator/provider → canonical MarketBar → local repository → diagnostics`

The project remains signal/research only. No broker execution is implemented.
