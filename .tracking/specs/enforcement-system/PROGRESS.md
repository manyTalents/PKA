# Enforcement System — PROGRESS

> Per Standard #15. Updated regularly across sessions.
> If this file grows too large, compress older sessions into a summary section at the bottom and keep the most recent session detailed.

---

## Project description
Convert the advisory rules in `STANDARDS.md` and the incidents in `SOLUTIONS_LOG.md` into automatic checks that block bugs at commit, deploy, and runtime — across every repo the Owner works in. See `DESIGN.md` for full scope and phases.

## Current status
**Phase:** 1 — Pre-commit + CI static checks
**State:** DESIGN.md approved. Scope locked. Kit starting implementation; Helm queued for install script; Gauge queued for regression tests.
**Unblocked as of:** 2026-04-22 — Owner approved repo location (PKA/enforcement/), engine (pre-commit framework), language (Python), and 6-rule starter set (#6, #7, #11, #14, #19, #20).

## Resume point
If the session ends now, the next agent should:
1. Read this file (PROGRESS.md) and DESIGN.md in full.
2. Check `PKA/enforcement/` for whatever scaffolding exists so far.
3. If `.pre-commit-config.yaml` exists and the 6 rules are drafted → run Gauge's regression tests next.
4. If rules are not drafted yet → Kit picks up with Rule #6 (timezone-aware datetimes) first, since it's the simplest regex and proves the whole loop works.
5. When Phase 1 is installable on MTM, hand off to Helm for install script + CI integration.
6. After MTM pilot is green, move to Task #8 (rollout to remaining repos).

---

## Session log

### Session 1 — 2026-04-22 (10T + Owner)

**Context.** Started from the Owner's question about Open Brain (YouTube `dxq7WtWxi44`). Analysis showed PKA is already a stronger knowledge base than Karpathy's Wiki or "Open Brain" patterns — but its 23 Standards and 12 SOLUTIONS_LOG incidents are **advisory**, not **enforced**. Owner's actual goal is "improve function on projects, especially keeping errors out."

**Decisions captured (also in DESIGN.md Decisions section):**
- Build enforcement before adding any new knowledge-management tool.
- Phase 1 starts with 5 Standards, not all 23.
- MTM repo pilots first; crypto bot and VEOE follow.
- 10T acts as manager/enforcer, not coder. Kit leads implementation; Helm deploys; Gauge validates.

**Work completed this session:**
- Read CLAUDE.md, OWNER_CONTEXT.md, STANDARDS.md, ORCHESTRATOR.md, SOLUTIONS_LOG.md end-to-end.
- Identified four failure patterns across 12 documented incidents (silent failures; state lost on restart; change not cascaded; recurring bug classes).
- Created `PKA/docs/superpowers/specs/enforcement-system/` folder.
- Wrote DESIGN.md (Phase 1 scope, "done" definition, team, decisions, open questions).
- Wrote this PROGRESS.md.
- Queued follow-on tasks in TodoList (Phases 2-4, MTM pilot, rollout to remaining repos).

**Next step:** Kit scaffolds `PKA/enforcement/` with pre-commit config and rule stubs. Owner may monitor or walk away — system resumes from scaffold state regardless.

---

### Session 1b — 2026-04-22 (Owner scope approvals)
Owner locked the four open scope questions:
- Location: `PKA/enforcement/` (inside PKA folder)
- Engine: `pre-commit` framework
- Language: Python
- Rule set: Standards #6, #7, #11, #14, #19, #20 (added #19 Long Compute to original 5)

10T updated DESIGN.md Decisions section and version log. No code written yet — that is Kit's scope.

---

### Session 1c — 2026-04-22 (Kit — Phase 1 scaffold)

**Scope delivered:** the full `PKA/enforcement/` tree per DESIGN.md Phase 1.

**Files created (15):**
- `enforcement/README.md` — install + usage (1-2 pages).
- `enforcement/requirements.txt` — `pre-commit`, `pytest`, `pyyaml`. Rule scripts themselves are stdlib-only.
- `enforcement/.pre-commit-hooks.yaml` — six hook definitions other repos will reference by id.
- `enforcement/rules/__init__.py` and six rule scripts:
  - `check_timezone_aware.py` (Standard #6) — AST walk for `datetime.now()` / `datetime.utcnow()` with no args.
  - `check_enqueue_job_id.py` (Standard #7) — AST walk for `*.enqueue(..., deduplicate=True)` missing `job_id=`.
  - `check_hcp_customer_fields.py` (Standard #11) — regex for `customer_name = ... company_name ...` excluding `customer.company_name` and `customer["..."]["company_name"]` dict access.
  - `check_no_workaround.py` (Standard #14) — regex for `# HACK`, `# WORKAROUND`, `# XXX`, `# FIXME`, `# TODO: workaround` without a ticket reference (`#123`, `ABC-123`, or URL).
  - `check_long_compute.py` (Standard #19) — AST walk for `for` loops over large `range(N>=100)` or variable iterables with no call to `to_csv`/`save`/`dump`/`log`/etc. in body.
  - `check_plaintext_secrets.py` (Standard #20) — regex over known key shapes (`sk-...`, `sk_live_...`, `AKIA...`, `ghp_...`, `xox[baprs]-`, `SOMETHING_KEY=<32+hex>`). Skips `.env*` files and placeholder content.
- `enforcement/tests/__init__.py`
- `enforcement/tests/test_rules.py` — parametrized subprocess smoke test, one pass + one fail per rule (12 total).
- `enforcement/tests/fixtures/pass_*.py` and `fail_*.py` — one pair per rule.

**Test results:** `python -m pytest tests/` → **12/12 passing in 3.4s**. Every rule exits 0 silently on its pass fixture and exits 1 with a `path:line: message` on its fail fixture. YAML validated via `yaml.safe_load`. Whole pre-commit run target of <5s comfortably met.

**Patterns worth sharing (also added to Kit's LESSONS.md):**
- Every violation message embeds a one-line Standard quote so the blocked developer sees the "why" inline — meets DESIGN.md requirement and keeps Slack pings out of the loop.
- Every rule supports an inline `# noqa: <slug>` escape hatch (`noqa: tz-aware`, `noqa: hcp-customer`, `noqa: long-compute`, `noqa: secret`). Rules #7 and #14 intentionally have no escape — if you hit those, you need to fix the code, not silence it.
- Tests invoke rules as scripts via `subprocess.run([sys.executable, ...])` rather than importing — this is exactly how pre-commit runs them in production, so the test surface matches the real surface.
- Rule scripts silently skip files with the wrong suffix, unreadable files, or syntactically broken Python. A linter that crashes on an invalid file would block the commit for the wrong reason.

**Known false-positive risks (for 10T + Owner visibility):**
- `#11 HCP fields` is line-based regex and will false-positive on exotic assignments. Whitelist via `# noqa: hcp-customer`.
- `#19 long compute` will flag many innocuous small loops over variables. This is intentional per DESIGN — the cost of missing a silent batch failure is higher than the cost of a `# noqa: long-compute`. Expect MTM's baseline sweep to produce a notable noqa count; that is fine.
- `#20 secrets` uses placeholder filtering (EXAMPLE, YOUR_KEY, REPLACE_ME, xxxx, <your-key>). A cleverly-worded fake could slip through; acceptable because the audit has already run once and ongoing prevention is the goal.

**Ready for Helm:** The rules run standalone with `python rules/check_*.py <paths>`. The `.pre-commit-hooks.yaml` catalog is valid and ready to be referenced from each repo's `.pre-commit-config.yaml`. Helm's install script needs to: clone/update this enforcement repo, drop a `.pre-commit-config.yaml` into the target repo that pins a `rev:` here, run `pre-commit install`, and run `pre-commit run --all-files` for the baseline sweep.

**Ready for Gauge:** Test loop works end-to-end. Gauge expands the fixture matrix — multiple variants per rule, intentional edge cases (nested calls, multi-line `enqueue`, comments inside strings, secrets inside triple-quoted strings, `# noqa` positioning), and a perf benchmark confirming <1s per file on typical source files.

**Deferred / flagged:**
- No install script (explicitly Helm's scope).
- No GitHub Actions or CI integration (explicitly Helm's scope).
- Sandbox has Python 3.10; scripts use 3.12+-friendly typing syntax (PEP 604 unions) only in ways compatible with `from __future__ import annotations`, so they parse on 3.10 too. No `match` statements used.

---

### Session 1d — 2026-04-22 (Helm — install tooling)

**Scope delivered:** one-command installer + CI workflow so any target repo can adopt Phase 1 enforcement without hand-editing YAML.

**Files created (3) / updated (2):**
- `enforcement/install.py` — cross-platform installer. Validates git repo, ensures pre-commit (installs `--user` if missing, falls back to `python -m pre_commit` if not on PATH), renders config from template, runs `pre-commit install`, optionally sweeps baseline. Flags: `--baseline-sweep`, `--force`. stdlib + subprocess only.
- `enforcement/templates/pre-commit-config.template.yaml` — one hook per rule, `repo: local`, `language: system`, `{{ENFORCEMENT_ROOT}}` placeholder substituted at install time. Mirrors Kit's `.pre-commit-hooks.yaml` 1:1.
- `enforcement/ci/github-actions-pre-commit.yml` — two variants (hosted PKA repo vs. self-hosted runner with PKA on disk). Self-hosted variant is active/usable today; hosted variant is commented scaffolding for post-publish.
- `enforcement/README.md` — new "Install into a repo — one command" section with Windows + *nix one-liners and flag docs. "What's here vs. what's next" updated.
- `Team/Helm (DevOps)/LESSONS.md` — lesson on `python -m <pkg>` fallback after `pip install --user`.

**Test results:** Rehearsed end-to-end in `/tmp/Helm Rehearsal Repo/` (space in path intentional). Install succeeded with pre-commit not on PATH (fallback engaged). Clean file committed (all 6 hooks passed). Dirty file blocked on commit with rule #6's standard-quoted message. Re-running `--baseline-sweep` on tracked dirty file correctly logged 1 violation line and kept install SUCCESS despite pre-commit exit 1. `--force` guard verified (aborts with exit 2 when config exists). Non-git-repo rejection verified (exit 2).

**Patterns worth sharing:**
- `pip install --user` can drop the console script off PATH on a fresh box. The portable wrapper is `python -m <pkg>`, which is strictly more reliable than trusting the shim. Cross-pollinate to any future Python CLI installer we write.
- YAML tolerates forward slashes in Windows paths, so rendering with `Path.as_posix()` dodges backslash-escaping in the template. Cheaper than per-OS branching.
- Using argv-lists with subprocess (never shell-string concat) means paths with spaces (OneDrive, "Program Files") just work. No manual quoting.

**Ready for MTM pilot:** [Owner — PowerShell, one line]
`python C:\Users\chris\OneDrive\Documentos\PKA\enforcement\install.py "C:\Users\chris\OneDrive\Documentos\ManyTalentsMore" --baseline-sweep`

**Deferred / flagged:**
- No merge for existing `.pre-commit-config.yaml` — `--force` overwrites. Deferred until a real repo needs a merge.
- CI Variant A has `<owner>/PKA` and `secrets.PKA_READ_TOKEN` placeholders to fill in once PKA is published to GitHub.
- Installer calls `python` on PATH, not `py`. Fine for Chris today; flag if a future operator has only the `py` launcher.
- Gauge's expanded regression suite + perf benchmark delivered in Session 1e (this session, parallel).

---

### Session 1e — 2026-04-22 (Gauge — regression coverage + perf)

**Scope delivered:** expanded fixture matrix, per-rule regression tests, perf suite, and COVERAGE.md.

**Numbers:**
- Fixture files: 12 → 48 (includes `.env` and `.env.example` needed by Rule #20).
- Test cases: 12 smoke → 55 (12 baseline retained + 41 per-rule parametrized + 2 xfail pins).
- Run: `53 passed, 2 xfailed in 4.26s`. No unexplained failures.

**Coverage highlights per rule:** see `enforcement/tests/COVERAGE.md`. Every rule now has: multiple positive cases, multiple negative cases, edge case(s) where relevant, and suppression mechanism verification for the 4 rules that support `# noqa:`.

**Rule bugs documented (not fixed per constraint, pinned as strict xfail):**
- Rule #6 misses aliased imports (`datetime as dt`).
- Rule #14 false-positives on trigger tokens inside docstrings.
- Rule #20 placeholder regex allows any line containing the word `example` to bypass (too broad — prevention-system defect).
- Rule #19 noqa placement is subtle (`for` line, not `def` line) — documented, not a bug.

**Performance vs DESIGN budget:**
- Per rule on 5000-line synthetic file: all well under 1s (slowest `check_long_compute.py` ~0.17s).
- Sequential total all-6 rules: ~0.58s vs 5s budget — ~9× headroom.

**Deliverables landed in `enforcement/tests/`:**
- `test_rules.py` — rewritten parametrized matrix (backward-compat baseline + 6 per-rule suites).
- `test_performance.py` — synthetic generator + per-rule and total budgets.
- `COVERAGE.md` — one-pager with risk table, bug log, Phase 2 milestones.
- 36 new fixtures covering Rule #6/#7/#11/#14/#19/#20.

**LESSONS.md:** one entry added on line-regex vs AST tradeoffs and the `strict=True` xfail pattern for documenting known rule limitations.

**Ready for:** Helm to wire the test suite into CI as a required gate (CI workflow already exists from Session 1d), and for Kit to address the three real rule bugs (Rule #6 alias, Rule #14 docstring, Rule #20 "example" regex) in a Session 1f tightening pass before MTM pilot. Each has a fix sketch in COVERAGE.md.

---

### Session 1f — 2026-04-22 (Kit — rule tightening pass)

**Scope delivered:** the three rule bugs Gauge pinned as strict xfail in Session 1e, fixed before MTM pilot.

**Files changed (5):**
- `enforcement/rules/check_timezone_aware.py` — new `_build_datetime_alias_map` walks `ast.ImportFrom` before the call pass; `_is_naive_now` now takes the alias set and matches the head of the dotted call name against it for `.now` / `.utcnow`. Catches `from datetime import datetime as dt; dt.now()`.
- `enforcement/rules/check_no_workaround.py` — new `_python_string_literal_lines` uses `tokenize.generate_tokens` to enumerate lines occupied by STRING tokens; `check_file` skips those lines on `.py` files. `# HACK` text inside docstrings / triple-quoted strings no longer false-positives. Non-Python text files (.md, .txt, .yml) retain pure-regex behaviour.
- `enforcement/rules/check_plaintext_secrets.py` — placeholder check moved from whole-line to matched span (`m.group(0)`). Allowlist broadened to cover embedded `EXAMPLE`, `REPLACE_ME`, `PLACEHOLDER`, `DUMMY`, `FAKE`, `<angle-slug>`, `xxxx+`, `YOUR_*_KEY`. Canonical `AKIAIOSFODNN7EXAMPLE` still passes; a real `sk-ant-...` on a line that mentions the prose word "example" now fires.
- `enforcement/tests/test_rules.py` — removed both `@pytest.mark.xfail(strict=True)` decorators. Updated docstrings to reference Session 1f.
- `enforcement/tests/COVERAGE.md` — struck bugs 1-3 in the bug-log, moved them to a "Fixed in Session 1f" subsection. Kept bug 4 (Rule #19 noqa placement) in the Open section per Gauge's note that it's a doc issue, not a defect.

**Test results:** `python -m pytest tests/` → **55 passed, 0 failed, 0 xfailed in 5.26s**.

**Performance check:** Rule #14 went from ~0.05s to ~0.18s on the synthetic 5000-line file (tokenize cost). Still 5× inside the 1s per-rule budget. Rules #6 and #20 unchanged within noise. Sequential all-6 total: 0.79s vs 5s budget — ~6× headroom.

**Patterns worth sharing (added to Kit's LESSONS.md):**
- `tokenize.generate_tokens` is the right tool when a text rule needs "is this line inside a string literal?" — beats regex state machines (escaped-quote / f-string bugs) and `ast.Expr(value=Constant(str))` (only finds expression-statement docstrings, misses assigned / returned / annotation strings). Stdlib, zero dep cost, "does what Python does" by definition.
- Placeholder allowlists should check the matched span, not the surrounding line. A line-global allowlist is a security bug wearing a UX-friendly disguise.
- Alias tracking: when a rule resolves dotted call names, build the import-alias map BEFORE the call walk, not during it. One pass, one data structure, obvious control flow.

**Phase 2 flags for 10T:**
- Consider retrofitting Rule #11 (HCP line regex) with the `_python_string_literal_lines` helper if MTM pilot produces docstring false-positives there.
- Rule #20's tightened allowlist may flag a small number of previously-silenced lines during MTM baseline sweep — feature, not regression.
- Rule #6 alias map is narrow (only `from datetime import datetime as X`). Exotic `import datetime.datetime as dtclass` would still bypass — file for Phase 2.

**Ready for:** MTM pilot baseline sweep (Helm's one-liner from Session 1d). All three Gauge-pinned bugs closed; suite is green with no xfails.

---

### Session 1g — 2026-04-22 (Kit — install.py UTF-8 encoding fix)

**Ticket:** Chris's Windows install log showed `â€"` mojibake where pre-commit hook names had em-dashes. cp1252 decode on a UTF-8 bytestream — classic Windows subprocess-capture bug surfaced during the first real MTM pilot.

**Fix:** added `encoding="utf-8", errors="replace"` to the single `capture_output=True` call in `run_baseline_sweep` (install.py lines 150-157). Other two `subprocess.run` calls don't capture output and are unaffected. Log file `write_text` was already `encoding="utf-8"` — no change.

**Tests added:** `enforcement/tests/test_install_encoding.py` — one test asserts the kwargs are wired into `run_baseline_sweep`, one proves a round-trip em-dash survives the capture. Both green.

**Verification:**
- `pytest enforcement/tests/` — 59/59 pass (57 existing + 2 new).
- Rehearsal: `git init /tmp/kit-encoding-test` → `install.py --baseline-sweep`. 6 hooks installed, exit 0, baseline log written. Byte check confirms 6 × `e2 80 94` em-dashes, 0 mojibake sequences.
- All 6 Phase 1 rules ran against modified `install.py`: clean.
- Rehearsal repo removed.

**Cross-pollination flagged in Kit's LESSONS.md:** Windows subprocess captures affect any Python CLI that shells out on Windows. Future Phase 1 AST rule candidate — becomes Proposed Standard #26 in the May 1 monthly review draft.

---

### Session 1h — 2026-04-22 (10T — MTM hook-type coverage patch)

**Ticket:** First real MTM baseline sweep returned "0 violations" — but the `.pre-commit-hooks.yaml` `types_or` filters for Rules #14 and #20 did not include `ts`, `tsx`, or `jsx`. MTM is a Next.js/TypeScript app, so the entire TypeScript surface was invisible to the scanner. "0 violations" was "0 violations on files we actually looked at," which is a different claim.

**Fix:** Added `ts, tsx, jsx` to both `types_or` lists in `.pre-commit-hooks.yaml` and `templates/pre-commit-config.template.yaml`.

**Verification:** Owner re-ran `install.py --force --baseline-sweep` on MTM. Regenerated `.pre-commit-config.yaml` correctly picked up the new types. Baseline log confirms Rule #14 and Rule #20 ran on 54 tracked files. Both **Passed**. Rules #6/#7/#11/#19 correctly skipped (no `.py` files). MTM is genuinely clean for rules that apply.

**Lesson flagged:** the hook file-type filters themselves need periodic audit — the rules can be correct and the scan coverage still incomplete. Raised in the cross-pollination map as a reminder for any future hook additions.

**MTM pilot (Task #7) CLOSED.** Ready to pilot PKA itself next — Task #26.

---

### Session 1i — 2026-04-22 (Gauge — PKA self-pilot baseline)

Ran all 6 Phase 1 rules against PKA from the sandbox — no install, no config changes, direct script invocation with file paths. Exclusions: .git, .pytest_cache, __pycache__, .venv, node_modules. File counts per rule: #6/7/11/19 scanned 96 .py files; #14 scanned 296 files; #20 scanned 304 files. Total files in scope: 334.

**Totals:** 51 violations (5 #6, 4 #7, 5 #11, 12 #14, 16 #19, 9 #20). 32 are expected hits in enforcement/tests/fixtures or the rule scripts themselves (Kit's intentional pass/fail fixtures); **19 are in real PKA code.**

**Material findings:**

1. **GENUINE LEAK — URGENT.** `sk_live_51TO2vn...` Stripe live key in `docs/superpowers/plans/2026-04-20-options-monetization.md:67` and `:2262`. Plus adjacent `OPTIONS_ADMIN_PASSWORD=3aAkRuKTQs3N129tlEdR` on `:70` (not flagged — rule gap on `*PASSWORD=*` shapes). **Owner action: rotate Stripe live key + admin password + audit dashboard activity; then redact the doc. Pre-existing git history contains the values — treat as already-compromised.**
2. **RULE #20 REGRESSION.** The Owner's expected `.mcp.json` hit on ERPNEXT_API_KEY/SECRET (15-hex values) did NOT fire. Rule's generic-hex pattern requires 32+ hex chars and `=` separator; JSON shape and short hex miss both constraints. File a rule-bug against Kit: lower hex floor, add `:` separator, add `SECRET`/`PASSWORD`/`KEY` keyword co-patterns, add regression fixture mirroring ERPNEXT key shape.
3. **RULE #14 PROSE FPs.** 8 false positives firing on STANDARDS.md, enforcement/README.md, COVERAGE.md, PROGRESS.md, Kit's LESSONS.md when they mention HACK/WORKAROUND/FIXME as prose. Markdown has no comment syntax, so the rule is currently unusable on docs. Needs comment-marker context or an inline `<!-- noqa: workaround -->` marker.
4. **RULE #19 SHORT-LOOP FPs.** 7 false positives on short/bounded loops (pptx builder, thread pools, perf harnesses). Noqa-able but CHECKPOINT_NAMES should probably absorb `start`, `join`, `assert` and similar test-idiom calls.
5. **RULE #11 SELF-MATCH.** Rule script matches itself (`check_hcp_customer_fields.py:16,18`). Needs self-whitelist or inline noqa.
6. **Rules #6 and #7** are clean against real PKA code — all hits are intentional fixtures.

**Baseline report:** `Owner's Inbox/2026-04-22-pka-enforcement-baseline.md`. Contains run command, file counts, per-rule violation detail, per-finding triage, and exclusion set.

**Next actions:**
- **Owner (URGENT):** rotate Stripe live key + OPTIONS_ADMIN_PASSWORD + confirm ERPNEXT rotation plan; audit Stripe dashboard; redact `options-monetization.md`.
- **Kit (Session 1j):** tighten Rule #20 for short-hex JSON + SECRET/PASSWORD shapes; whitelist enforcement/rules/*.py from Rule #11; add comment-marker / markdown `noqa` handling to Rule #14; extend Rule #19 CHECKPOINT_NAMES.
- **Gauge:** add regression fixture covering the `.mcp.json` ERPNEXT shape before Kit's rule #20 patch lands.

**Resume point:** Owner rotation + Kit rule tightening before Task #8 (rollout to remaining repos).

---

### Session 1j — 2026-04-22 (Kit — rule tightening from PKA baseline findings)

**Done:**
- **Rule #20:** rewrote generic-secret detection. Key-indicator pattern (KEY/SECRET/TOKEN/PASSWORD/API_KEY/AUTH/CREDENTIAL/PRIVATE) with broad separator (`=` / `:` / quoted variants) and 15-char floor. Entropy-lite filter (require digit or mixed-case). Placeholder regex and UUID regex screen out non-secrets on the value.
- **Rule #11:** path-based self-skip (`if path.name == "check_hcp_customer_fields.py": return []`).
- **Rule #14:** added `<!-- noqa: workaround -->` inline escape for markdown.
- **Rule #19:** expanded CHECKPOINT_NAMES to include `start` + `join`. Extended `_body_has_checkpoint` to recognize `assert` / `yield` / `yield from`. Did NOT add `append` (would break accumulation-detection semantics).
- **6 new regression fixtures:** `fail_secrets_short_hex_json.json` (ERPNEXT-shape), `fail_secrets_password_equals.md` (PASSWORD=), `fail_secrets_stripe_live.md` (regression guard), `pass_secrets_placeholder_short.json`, `pass_secrets_uuid.yaml`, `pass_workaround_md_noqa.md`.
- `tests/test_rules.py` updated.
- 2 new lessons in `Team/Kit (Developer)/LESSONS.md`: secret-detection adversarial-testing; inline `<!-- noqa -->` HTML comment pattern.

**Verification:**
- `pytest enforcement/tests/` → **63/63 passing** (was 48; +15 cases).
- Self-scan: all 6 rules exit 0 on their own source.
- **Live verification:** running the tightened Rule #20 against `.mcp.json` + `options-monetization.md` now fires on both ERPNEXT keys AND the original Stripe/admin leaks:
  ```
  .mcp.json:8 — ERPNEXT_API_KEY
  .mcp.json:9 — ERPNEXT_API_SECRET
  options-monetization.md:67 — Stripe live key
  options-monetization.md:68 — NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
  options-monetization.md:70 — OPTIONS_ADMIN_PASSWORD
  options-monetization.md:2262 — Stripe live key (duplicate reference)
  ```

**Known remaining items (deferred intentionally):**
- 5 Rule #19 FPs in real PKA code (`generate_providence_pptx.py:79`, `watchdog/tests/test_performance.py:75/95/113/145`) need per-line `# noqa: long-compute` annotations in a separate sweep — NOT universal CHECKPOINT_NAMES expansion.
- Rule #14 code-fence-aware context detection in markdown deferred to Phase 2 — inline HTML noqa covers today.
- Rule #20 could still miss secrets NOT preceded by a recognized indicator word (bare hex blobs assigned to `foo`). Intentional trade-off — entropy floor alone would FP-storm on commit hashes.

**Resume point:** Session 1j closes the rule-quality gaps surfaced by PKA baseline. Owner rotation of Stripe + admin + ERPNEXT credentials is still the blocking Owner action. After rotation and redaction, next natural step is Task #8 (rollout to remaining repos) — but only once Owner approves the rollout order.

---

## Archive / older sessions
*(None yet.)*
