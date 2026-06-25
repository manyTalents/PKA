# Vault — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Lessons

### 2026-04-08: SQLite schema collision when two modules share tables
- **Category:** database
- **Lesson:** When multiple modules write to the same SQLite file, give each module its own tables — never assume another module's schema matches your expectations.
- **Context:** SOLUTIONS_LOG #7. `strategy_sopr.py` expected columns like `strategy_id`, `quantity_base`, `stop_price` on the `positions` table, but `portfolio.py` had already created that table with different columns (`strategy`, `volume`, `quote_size`). Strategy A's exit checks failed every hour with "no such column" errors. Fix: created dedicated `sopr_positions` and `sopr_trades` tables. Verify schema with `PRAGMA table_info(table)` before querying.
- **Keywords:** SQLite, schema, collision, PRAGMA, table_info, shared database, module isolation

### 2026-04-11: Fragile index references — use named columns
- **Category:** database
- **Lesson:** Never reference query results by positional index (e.g., `row[8]`) — use named columns via `row["column_name"]` or `Row` factories to prevent silent data corruption when schema evolves.
- **Context:** Crypto bot code used `t[8]` to access trade fields from SQLite query results. When the schema was modified (columns added or reordered during bot evolution), the index silently pointed to the wrong column. Fix: use `sqlite3.Row` row factory or explicit column aliases in SELECT statements so fields are accessed by name.
- **Keywords:** index, positional, named columns, Row factory, schema evolution, silent corruption

### 2026-04-11: Schema drift between environments
- **Category:** database
- **Lesson:** SQLite schemas must be versioned — track schema version in a metadata table and run explicit migrations on startup to prevent drift between dev, staging, and production databases.
- **Context:** The crypto bot's `equity_snapshots` table was recreated multiple times during bot evolution, and the local dev database schema diverged from the production droplet. Queries that worked locally failed on the live bot. Fix: add a `schema_version` table, check version on startup, and apply incremental ALTER TABLE / CREATE TABLE migrations to bring the schema to current.
- **Keywords:** schema drift, migration, version, dev vs production, equity_snapshots, ALTER TABLE

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->


---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

