## Export Streaming Design (Draft)

Current implementation (GET /transactions/export.csv and POST JSON export) builds the entire CSV payload in memory before responding. This is acceptable for small/medium datasets (< ~5–10k rows) but risks:
- Elevated peak memory usage proportional to row count × serialized width
- Increased latency before first byte (TTFB) for large exports
- Potential timeouts on slow clients / large data

### Target Goals
- Stream CSV rows incrementally to the client
- Maintain existing endpoint semantics (query params + include_header)
- Preserve authorization and filtering logic
- Avoid loading all rows simultaneously; use DB cursor / chunked fetch
- Keep memory O(chunk_size) instead of O(total_rows)

### Proposed Approach
1. Introduce an async Stream body (e.g. `axum::body::Body` from a `tokio_stream::wrappers::ReceiverStream`).
2. Acquire a server-side channel (mpsc) or use `async_stream::try_stream!` to yield `Result<Bytes>` chunks.
3. Write header first (conditional on `include_header`).
4. Fetch rows in chunks: `LIMIT $N OFFSET loop*chunk` or preferably a server-side cursor / keyset pagination if ordering stable.
5. Serialize each row to a CSV line and push into the stream; flush periodically (small `Bytes` frames of ~8–32 KB to balance syscall overhead vs latency).
6. Close stream when no more rows; ensure cancellation drops DB cursor.

### Database Access Pattern
- Option A (simple): repeated `SELECT ... ORDER BY id LIMIT $chunk OFFSET $offset` until fewer than chunk results.
  - Pros: trivial to implement.
  - Cons: OFFSET penalty grows with large tables.
- Option B (keyset): track last (id, date) composite and use `WHERE (date,id) > ($last_date,$last_id)` ORDER BY (date,id) LIMIT $chunk.
  - Pros: stable performance.
  - Cons: Requires deterministic ordering and composite index.
- Option C (cursor): Use PostgreSQL declared cursor inside a transaction with `FETCH FORWARD $chunk`.
  - Pros: Minimal SQL complexity, effective for very large sets.
  - Cons: Keeps transaction open; need timeout/abort on client disconnect.

Initial recommendation: start with keyset pagination if the transactions table already has suitable indexes (date + id). Fall back to OFFSET if index not present, then iterate.

### Error Handling
- If an error occurs mid-stream (DB/network), terminate stream and rely on client detecting incomplete CSV (documented). Optionally append a trailing comment line starting with `# ERROR:` for internal tooling (not for production by default).
- Authorization is validated before streaming begins; per-row permissions should already be enforced by the query predicate.

### Backpressure & Chunk Size
- Default chunk size: 500 rows.
- Tune by measuring latency vs memory: each row ~150 bytes average → 500 rows ≈ 75 KB before encoding to Bytes (still reasonable).
- Emit each chunk as one Bytes frame; header as a separate first frame.

### Include Header Logic
- If `include_header=false`, skip header frame.
- Otherwise first frame = `b"col1,col2,...\n"`.

### CSV Writer
- Reuse existing row-to-CSV logic; adapt it to a function returning `String` line without accumulating in Vec.
- Avoid allocation churn: use a `String` buffer with `clear()` per row.

### Observability
- Add tracing spans: `export.start` (with row_estimate if available), `export.chunk_emitted` (chunk_index, rows_in_chunk), `export.complete` (total_rows, duration_ms).
- Consider a soft limit guard (e.g. if > 200k rows warn user or require async job + presigned URL pattern—out of scope for first iteration).

### Compatibility
- Existing clients expecting entire body still work; streaming is transparent at HTTP level.
- For very small datasets overhead is negligible (one header + one chunk frame).

### Future Extensions
1. Async job offload + download token when row count exceeds threshold.
2. Compression: optional `Accept-Encoding: gzip` support via layered body wrapper.
3. Column selection / dynamic schema negotiation.
4. Rate limiting or concurrency caps per user.

### Minimal Implementation Checklist
- [ ] Refactor current CSV builder into row serializer
- [ ] Add streaming variant behind feature flag `export_stream` (optional)
- [ ] Implement keyset pagination helper
- [ ] Write integration test for large (e.g. 5k rows) export ensuring early first-byte (<500ms on local) and total content hash matches non-stream version
- [ ] Bench memory before/after (heap snapshot or simple RSS sampling)

---
Status: Draft for review. Adjust chunk strategy after initial benchmarks.

