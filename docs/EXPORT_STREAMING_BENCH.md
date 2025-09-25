## Export Streaming Benchmark (Raw Outputs)

Environment:
- Machine: (fill in) CPU / RAM
- DB: PostgreSQL 16 (Docker, localhost 5433)
- Build: release profile OFF (debug) unless noted
- Feature flags: `export_stream` enabled for streaming runs

### Seed 5k Rows
Command:
```bash
cargo run -p jive-money-api --features export_stream --bin benchmark_export_streaming -- --rows 5000 --database-url $DATABASE_URL
```
Output (example):
```
Preparing benchmark data: 5000 rows
Seeded 5000 transactions (ledger_id=..., user_id=...)
COUNT(*) took 8.5ms, total rows 5000
```

### Export (Streaming Enabled)
```bash
/usr/bin/time -f '%E real %M KB maxrss' \
  curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8012/api/v1/transactions/export.csv?include_header=false" -o /dev/null
```
Sample:
```
0:00.11 real 41200 KB maxrss
```

### Export (Buffered, Feature Disabled)
```
cargo run -p jive-money-api --bin jive-api &  # restart without feature
0:00.19 real 65500 KB maxrss
```

### Preliminary Metrics
| Rows | Mode       | Time (ms) | Max RSS (KB) | Notes |
|------|------------|-----------|--------------|-------|
| 5k   | Streaming  | 110       | 41,200       | First-byte earlier (<25ms) |
| 5k   | Buffered   | 190       | 65,500       | Full accumulation |

> Replace above with actual measured values from your environment. Retain consistent measurement method.

### Next Steps
- Automate measurement via `hyperfine` for statistical confidence
- Add 20k / 50k / 100k rows tiers
- Capture 95th percentile latency over multiple runs

