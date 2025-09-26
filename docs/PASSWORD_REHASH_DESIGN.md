## Password Rehash Design (bcrypt → Argon2id)

### Goal
Gradually migrate legacy bcrypt password hashes to Argon2id transparently upon successful user login, improving security without forcing password resets.

### Current State
- Login handler supports both Argon2 (`$argon2`) and bcrypt (`$2a, $2b, $2y`).
- No automatic upgrade path: bcrypt hashes remain until manual intervention.

### Approach
1. On successful bcrypt verification, immediately generate a new Argon2id hash for the provided plaintext password.
2. Replace `users.password_hash` within the same request context.
3. Log (debug level) a one-line message: `rehash=success algo=bcrypt→argon2 user_id=...` (omit email for privacy).
4. If rehash fails (rare), continue login without blocking; emit warning log.

### Pseudocode
```rust
if hash.starts_with("$2") { // bcrypt branch success
   if let Ok(new_hash) = argon2_rehash(password) {
       if let Err(e) = sqlx::query("UPDATE users SET password_hash=$1, updated_at=NOW() WHERE id=$2")
           .bind(new_hash)
           .bind(user.id)
           .execute(&pool).await {
           tracing::warn!(user_id=%user.id, err=?e, "password rehash failed");
       } else {
           tracing::debug!(user_id=%user.id, "password rehash succeeded");
       }
   }
}
```

### Safety / Consistency
- Operation occurs post-authentication; failure does not alter authentication result.
- Single-row UPDATE by primary key avoids race conditions (last write wins). Rare concurrent logins produce at most duplicated work.
- Future logins will exclusively take Argon2 path.

### Telemetry
- Add counter metric `auth.rehash.success` / `auth.rehash.failure` (optional phase 2).

### Backward Compatibility
- No schema changes required.
- Rollback: leave bcrypt branch intact; already-upgraded users unaffected.

### Edge Cases
| Case | Behavior |
|------|----------|
| Incorrect password | No rehash attempt |
| Unknown hash prefix | Skip rehash |
| DB update failure | Warn, continue login |
| Concurrent rehash | Last success wins |

### Rollout Plan
1. Implement code path behind feature flag `rehash_on_login` (initial).
2. Deploy + monitor debug logs for a subset environment.
3. Remove flag after confidence; keep code always-on.

### Success Criteria
- ≥90% bcrypt hashes converted within 30 days of active user logins.
- Zero authentication regressions attributable to rehash logic.

### Deferred Items
- Background batch rehash for dormant accounts.
- Pepper support.
- Password strength enforcement on legacy accounts.

