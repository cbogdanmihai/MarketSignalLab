# MarketSignalLab 0.1.2 — Collaboration build

Native iPad Swift Playgrounds research app for market-data ingestion and signal research.

## Phase 1.2 additions

- Twelve Data universe validation.
- Explicit `rate_limited` state for HTTP 429.
- `Retry-After` support where the provider sends it.
- One automatic retry after a 429, with a conservative fallback cooldown.
- Provider-friendly spacing between validation requests.
- Normal validation skips symbols already in a stable state.
- Temporary 429 responses never overwrite a previously stable validation result.
- `Force Revalidate` remains available when a full probe is required.
- Local validation cache.
- `Prepare Diagnostics` + `Share Diagnostics` JSON workflow for ChatGPT collaboration.
- Diagnostics never contain the Twelve Data API key.

## iPad workflow

1. Open the project in Swift Playgrounds.
2. Settings → enter your Twelve Data API key → Save.
3. Tap **Validate Universe**.
4. Let validation finish. It is intentionally paced to reduce provider throttling.
5. Fetch bars for confirmed symbols.
6. Tap **Prepare Diagnostics**.
7. Tap **Share Diagnostics** and attach the JSON to ChatGPT.

## Status meanings

- Green check: available on the current account.
- Orange lock: access/subscription restriction.
- Red x: unavailable or invalid symbol/data.
- Orange clock: temporarily rate limited.
- Yellow warning: other provider/network/decoding error.

## Architecture

`assets.json → validator/provider → canonical MarketBar → local repository → diagnostics`

The project remains signal/research only. No broker execution is implemented.
