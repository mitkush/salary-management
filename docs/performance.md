# Performance

Timings measured while building, on the seeded data set: 10,000 employees and 14,992 salary revisions across 6 countries.

**How these were measured:**
- **Machine:** a MacBook with PostgreSQL 16.15 (Homebrew), Ruby 3.4.11 and Rails 8.1, in the development environment.
- **Runs:** each figure is a single run, not a repeated benchmark. Treat them as orders of magnitude.
- **Payroll:** the timings were taken inside a transaction that was then rolled back, so nothing was kept.

| What | Result | Notes |
|---|---|---|
| Seed 10,000 employees | ~2.1 s | Includes Rails boot. Bulk `insert_all` in batches of 1,000 with a fixed random seed. A fresh `docker compose up` seeds the same data automatically. |
| Dashboard median query (`EXPLAIN ANALYZE`) | 9 ms | Uses the unique `(employee_id, effective_on)` index to find each employee's current revision. It took 28 ms right after the bulk insert, before Postgres had refreshed its table statistics. |
| Dashboard summary (all six figures) | 77 ms | First call, including warm-up |
| Dashboard breakdown by country | 22 ms | |
| 12-month trends | 352 ms | 12 month-end points, each using the stats query, plus one grouped query each for joiners and leavers |
| Employee list page | Constant query count | A spec checks that 5 and 25 employees use the same number of queries (no N+1) |
| Excel import, 10,000 rows | 3.8 s | 403 KB file. Reading it with `roo` takes 1.7 s. The first version took 9.5 s with 30,022 queries, 3 per row (two uniqueness checks and loading the country). Skipping the uniqueness validators the importer already covers, and passing preloaded countries, brought it down to 22 queries. |
| Generate a payroll month | 1.3 s | 9,329 entries, written in batches of 1,000 with `upsert_all` |
| Recalculate the open month | 1.1 s | Refreshes the calculated columns and keeps HR's bonus, deduction and note |
| Export a payroll month to Excel | 0.7 s | 669 KB file. A single ordered `pluck` of the export columns, without loading full records |

**Choices that keep these fast:**
- Aggregates (dashboard, trends, payroll totals) run in SQL.
- Per-employee payroll maths runs in Ruby with `BigDecimal`, in batches.
- Lists are paginated on the server.
- Large writes use bulk inserts and upserts.
