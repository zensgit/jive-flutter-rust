## Currency System Overview

This document describes the Flutter currency architecture, catalog loading, user preference sync, and fallback behavior after PR1 / PR2 enhancements.

### Components
- `CurrencyNotifier` (Riverpod `StateNotifier`): Manages currency preferences, catalog, exchange rates, manual overrides.
- `ICurrencyRemote` / `CurrencyService`: HTTP API abstraction for `/currencies`, `/currencies/preferences`, rates & conversions.
- Hive storage (box: `preferences`): Persists
  - `currency_preferences` (serialized `CurrencyPreferences`)
  - `currency_pending_prefs` (pending sync payload when last push failed)
  - Manual rates and expiries (various keys)

### Catalog Loading Flow
1. App start → `CurrencyNotifier` constructed → `_initializeCurrencyCache()` loads built‑in list → triggers `tryFlushPendingPreferences()` (fire & forget).
2. `_loadSupportedCurrencies()` called:
   - Sends `GET /currencies` with optional `If-None-Match` (ETag).
   - On `200`: updates server catalog, sets `catalogMeta.lastSyncAt`, clears fallback/error, merges server preferences (`/currencies/preferences`), attempts flush of any pending preference push.
   - On `304`: updates `lastCheckedAt`; keeps existing catalog; fallback stays only if nothing loaded yet.
   - On failure / empty: sets `usingFallback=true`, records `lastError`; built‑in (default) list is used for UI.

### Catalog Meta (read via `currencyCatalogMetaProvider`)
| Field | Meaning |
|-------|---------|
| `usingFallback` | No server catalog available (first load failed / empty) so built‑in list is displayed. |
| `lastError` | Last catalog fetch error message (for diagnostics / UI banner). |
| `lastSyncAt` | Time of last successful 200 response refreshing catalog. |
| `lastCheckedAt` | Time of last attempt (includes 304). |
| `etag` | Last seen server ETag (weak form). |

### User Preference Sync (Debounce + Pending Queue)
User actions that change preferences:
- Add / remove selected currency
- Change base currency

Instead of immediate push, changes are debounced (500ms). After the window:
1. `_attemptPushPreferences()` calls `setUserCurrencyPreferences` with current `selectedCurrencies` and `baseCurrency`.
2. On success: any stored pending payload is cleared.
3. On failure (network / server error): a pending record is saved under Hive key `currency_pending_prefs`:
   ```json
   {
     "currencies": ["USD","CNY","EUR"],
     "primary": "USD",
     "queued_at": "2025-09-18T10:23:45Z"
   }
   ```

Flush triggers (`tryFlushPendingPreferences()`):
- Notifier construction (startup) – best effort.
- After any catalog refresh (success or failure) – opportunistic.
- Can be invoked manually (future UI or dev tools) if exposed.

### Rationale
- Debounce reduces bursty duplicate writes (e.g., toggling multiple currencies quickly).
- Pending queue guarantees eventual consistency without blocking UX.
- Catalog meta improves observability (UI can show fallback banner, sync times, last error).

### Extension Points (Planned / Optional)
| Feature | Idea |
|---------|------|
| Retry Backoff | Track retry count; exponential delays (2s → 5s → 15s). |
| Min Catalog Interval | Skip network if lastCheckedAt < threshold (e.g., 10m) unless forced. |
| Telemetry | Count successful/failed pushes & ETag hit ratio. |
| Separate Storage Abstraction | Replace direct Hive calls with `CurrencyPrefsStore` for cleaner testing. |
| Pending Badge UI | Show a small sync icon when `hasPendingPreferences` is true. |

### Testing Strategy (Implemented & Planned)
- Meta tests: verify `usingFallback`, `lastSyncAt`, `lastCheckedAt` transitions on 200 / 304 / failure.
- Preference sync tests: debounce merge, failure to pending, subsequent flush success.
- Startup pending flush test: pre-create `currency_pending_prefs` before provider init; constructor fire‑and‑forget `tryFlushPendingPreferences()` clears it on successful remote call.
- Future: add tests for catalog interval gating & retry backoff once implemented.

### Operational Notes
- Pending preference overwrites: only the latest failed state is stored (simplifies recovery).
- Manual flush safety: if server still fails, pending is preserved.
- Fallback UI: shows when `usingFallback=true` – differentiate network issue vs still not yet loaded via `lastError`.

### Quick Dev Checklist
- Add new currency field? Ensure model mirrors API & formatting logic in `Currency`.
- Adjust debounce? Modify constant in `_schedulePreferencePush()`.
- Diagnose user complaint about missing currency: check meta.banner (fallback?) and server `/currencies` response / ETag.
