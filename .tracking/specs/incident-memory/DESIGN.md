# Incident Memory Search — DESIGN (Phase 3 of Error Prevention System)

> One-page spec per Standard #21.
> Created: 2026-04-22 | Owner scope approval: defaults locked same day (continue momentum per Owner directive)

---

## Project in one line
Give 10T and every team member instant search across `SOLUTIONS_LOG.md`, all `Team/*/LESSONS.md` files, and past `PROGRESS.md` session logs — so the same bug class is not rediscovered twice.

## Why this exists
Standard #13 ("Read Full Context") exists because 10T skipped reading a PROGRESS file and asked a question already answered deeper in the log. SOLUTIONS_LOG.md's own header says *"Search this file FIRST when encountering errors"* — but "search" is manual and relies on someone remembering the log exists. Automating it moves from "if you remember to check" to "always checked."

Covers failure-pattern #4 from the SOLUTIONS_LOG meta-analysis: *same class of bug recurring because nobody re-read the log.*

---

## "Done" definition — Phase 3a

1. A Python package at `PKA/incident_memory/` containing:
   - `search.py` — core `search(query: str, max_results: int = 5) -> list[Match]` function
   - `indexer.py` — walks the configured corpus paths, extracts searchable text chunks
   - `scoring.py` — keyword-density + recency + file-priority scoring
   - `cli.py` — CLI entrypoint: `python -m pka_incident_memory "query string"`
   - `config.yaml` — corpus file list and scoring weights
2. Corpus indexed: `.10T/SOLUTIONS_LOG.md`, every `Team/*/LESSONS.md`, every `docs/superpowers/specs/*/PROGRESS.md`.
3. Query-time search (no pre-built index persisted to disk — corpus is small today, simplicity wins).
4. Results include: file path, matching line numbers, 3 lines of context before + 3 after each match, file mtime, score.
5. Scoring: keyword density (how many query terms match) + recency (newer files score higher) + file priority (SOLUTIONS_LOG > LESSONS > PROGRESS).
6. Multi-keyword queries use AND semantics by default; phrase matching via quoted substrings.
7. Tests cover: single keyword, multi-keyword AND, phrase quoting, empty result, max-result limit, scoring order (known-match file floats to top), case insensitivity, missing corpus file is skipped (not fatal).
8. Performance: a query completes in <200 ms against the current PKA corpus. Budget: <1 s worst-case for a 10× corpus.
9. Phase 3a does NOT ship an MCP server wrapper — CLI and importable Python function only. MCP wrapper is Phase 3b.

## Who uses it
- **10T** — at task intake: before delegating, query the index with keywords from the Owner's request; surface relevant past incidents + lessons to the assigned team member as part of the brief.
- **Team members** (Kit, Forge, Onyx, Arrow, etc.) — at start of debugging: `python -m pka_incident_memory "error message"` before independent investigation.
- **Chris** — on-demand via CLI when an unfamiliar error appears.
- **Future MCP wrapper (Phase 3b)** — Claude Code can invoke search as a tool call.

## What breaks if it's wrong

- **False positives (noisy matches)** → team ignores the tool → net-neutral vs today. Fixable via scoring tweaks.
- **False negatives (misses a known match)** → team re-discovers a known bug. Recoverable with a broader query. Mitigation: test fixture verifies every SOLUTIONS_LOG issue is findable by its own error message.
- **Indexing stale** → search misses recent incidents. Query-time indexing eliminates this.
- **Performance creep** as corpus grows → switch to pre-built index (sqlite FTS5) in Phase 3b if needed.

---

## Scope locked (Owner momentum-mode defaults)
- **Language:** Python (matches the rest of PKA's stack).
- **Dependencies:** stdlib only. `re`, `pathlib`, `yaml` (via pyyaml already in PKA's tool belt).
- **Corpus:** SOLUTIONS_LOG + all LESSONS.md + all PROGRESS.md under `docs/superpowers/specs/*/`.
- **Interface:** CLI + importable Python function. MCP wrapper deferred to Phase 3b.
- **Code location:** `PKA/incident_memory/`.

## Team
- **Lead:** Kit (Developer) — build search, indexer, scoring, cli, tests. Self-dogfood Phase 1 enforcement.
- **QA:** Gauge (QA) — regression on Phase 3a after Kit ships (deferred to own session).
- **Integration (Phase 3b, future):** Link (Integrations) — MCP server wrapper so Claude Code can invoke as a tool.
- **Manager:** 10T.

## Decisions (per Standard #22)

### Decision: Query-time grep, not pre-built index
**Date:** 2026-04-22
**Why:** The corpus is ~15 files, under 200 KB total. Grep + scoring is <100 ms. A persistent index adds complexity (staleness, corruption, build timing) we don't need at this scale. When corpus crosses 10×, revisit.
**Alternatives considered:** SQLite FTS5 (deferred — overkill today). Embedding-based semantic search (deferred to Phase 3b — adds dependency on an embedding model).

### Decision: AND semantics for multi-keyword, phrase quoting for exact matches
**Date:** 2026-04-22
**Why:** AND is higher precision than OR for a small corpus. Phrase quoting handles cases where AND's word-separation misses literal phrases. This mirrors how most developers already think about grep + google. No surprise.
**Alternatives considered:** OR semantics (too noisy). Regex as primary interface (overkill for the user).

### Decision: Corpus is markdown only, in PKA
**Date:** 2026-04-22
**Why:** All institutional memory lives in markdown today. Code comments, commit messages, bot logs are out of scope — those have their own tools. Keep the corpus definition tight.
**Alternatives considered:** Index commit messages too — deferred; git log is already searchable via git itself.

---

## Version log

| Date | Change | By |
|------|--------|----|
| 2026-04-22 | Initial spec — Phase 3a scope (CLI + Python function, stdlib only, markdown corpus) | 10T |
