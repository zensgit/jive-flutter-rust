## CurrencyNotifier Test Isolation Refactor

### Background
`CurrencyNotifier` currently triggers multiple asynchronous side‑effects inside its constructor:

- `_initializeCurrencyCache()`
- `_loadSupportedCurrencies()` (network / remote fallback)
- `_loadManualRates()`
- `_loadExchangeRates()` (timers / delayed refresh logic)

This design causes widget tests (e.g. `currency_selection_page_test.dart`) to spin pending timers and background futures, leading to:

- `pumpAndSettle` timeouts
- `!timersPending` assertion failures
- Need for invasive fake subclasses or `@Skip`.

We temporarily skipped the selection page test in commit adding Hive/prefs init (see commit message referencing this issue). This document defines a minimal path to re‑enable those tests with low noise.

### Problems
1. Constructor side‑effects make deterministic widget tests hard.
2. Timers created before tests can override providers or inject mocks.
3. Tight coupling to concrete services (`ExchangeRateService`, `CryptoPriceService`, `ICurrencyRemote`).
4. Requires heavy stubbing for simple UI assertions (selecting a base currency list item).

### Goals
- Allow constructing a `CurrencyNotifier` in a quiescent state (no automatic async work, no timers) for unit/widget tests.
- Keep production behavior unchanged by default.
- Re‑enable skipped widget tests without race conditions or pending timers.

### Non‑Goals
- Comprehensive redesign of currency architecture.
- Changing public semantics for production code paths.

### Options Considered
#### Option A (Recommended): Constructor Flag
Add optional `suppressAutoInit: bool = false` parameter. Guard current side‑effect calls with:
```dart
if (!suppressAutoInit) {
  _initializeCurrencyCache();
  _loadSupportedCurrencies();
  _loadManualRates();
  _loadExchangeRates();
}
```
Expose a public `Future<void> initialize()` method to manually trigger the sequence when tests need realistic behavior.

Pros: Minimal diff, fast to implement, preserves existing provider behavior.
Cons: Another boolean flag to reason about; misuse possible.

#### Option B: Async Factory
Make constructor side‑effect free; provide `static Future<CurrencyNotifier> create(...)` to run initialization. Provider would change shape (possibly FutureProvider) or require pre‑boot logic.

Pros: Clear separation of construction vs initialization.
Cons: Larger ripple effect on provider wiring; more refactor.

#### Option C: Extract Repository Interface
Introduce `ICurrencyRepository` / `ICurrencyRates` abstraction; notifier only coordinates state. Tests inject pure in‑memory repo.

Pros: Cleaner architecture long term.
Cons: Highest initial cost, larger PR.

### Recommended Path
Adopt Option A now, revisit Option C if currency logic expands further.

### Implementation Steps (Option A)
1. Modify `CurrencyNotifier` constructor signature: add `this.suppressAutoInit = false`.
2. Wrap current initialization calls in guard block.
3. Add `Future<void> initialize()` replicating original sequence (idempotent if called twice).
4. Update widget tests to override provider with `suppressAutoInit: true` and manually seed state (or call `initialize()` selectively).
5. Remove `@Skip` from `currency_selection_page_test.dart` and simplify test (no heavy fakes required).
6. Add a test asserting no pending timers when constructed with `suppressAutoInit: true` after a pump.

### Acceptance Criteria
- Skipped test re‑enabled and passes reliably.
- `flutter test` has no timer‑pending assertion from currency tests.
- No behavioral regressions in existing currency preference or sync tests.

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Developers forget to call `initialize()` in new integration tests | Provide doc comment + optional debug assert if critical methods used before initialization |
| Flag proliferation | Keep single flag; consolidate later if broader pattern emerges |

### Follow Up
- If further complexity accrues (e.g., offline caching layers), schedule Option C to decouple IO from state management.

### Tracking
Issue Owner: (assign)  
Related Commit (skip introduction): 578d333  
Target PR: `feat/currency-notifier-test-isolation`

---
Add comments or refinements here before implementation PR.
