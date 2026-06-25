# Kit — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

### Pre-commit rule authoring — AST > regex for structure, regex for text
**Date:** 2026-04-22
**Context:** Phase 1 of the PKA enforcement system. Six rules, six Standards.

**What worked:**
- For rules that care about *structure* (is this a function call? does this kwarg exist? is this a `for` loop?), walk the AST. `ast.walk(tree)` + `isinstance(node, ast.Call)` gave me exact, false-positive-free detection on Standards #6, #7, and #19. Getting a dotted callee name cleanly:
  ```python
  def _call_name(node: ast.Call) -> str:
      parts = []
      cur = node.func
      while isinstance(cur, ast.Attribute):
          parts.append(cur.attr)
          cur = cur.value
      if isinstance(cur, ast.Name):
          parts.append(cur.id)
      return ".".join(reversed(parts))
  ```
  This collapses `frappe.utils.datetime.now` → `"frappe.utils.datetime.now"` and lets me do simple `endswith("datetime.now")` checks.
- For rules that care about *text* (comments, secret patterns), regex is the right tool. AST strips comments entirely — you literally cannot see `# HACK:` from an AST node. <!-- noqa: workaround -->
- Every rule defends against its own blast radius:
  1. skip the wrong extension
  2. swallow `OSError` / `UnicodeDecodeError`
  3. swallow `SyntaxError` from `ast.parse`
  
  A linter that crashes blocks the commit for the wrong reason. Silent skip is the right answer.
- Tests invoke each rule as a subprocess (`subprocess.run([sys.executable, rule, fixture])`) rather than importing and calling `main()`. This exercises the real code path pre-commit uses, including argv parsing, exit codes, and stderr writes. Catches bugs that a direct import would hide.
- **Every violation message quotes the Standard.** Devs get the "why" inline without Slack pings. Cost: one extra string per rule. Payoff: no "what does this mean?" follow-ups.
- **`# noqa: <slug>` escape hatches per rule** (except #7 and #14 — if those fire, fixing the code is the only right move). Gives heuristic rules like #19 room to breathe without eroding trust.

**Cross-pollinate to:** Swift, Forge, Glass, Echo, Onyx, Arrow, Sage — anyone writing Python or reviewing commits. The AST-vs-regex split and the subprocess-test-as-production-surface pattern both carry.

### `tokenize` is the right tool when a text rule needs to know "is this line inside a string literal?"
**Date:** 2026-04-22
**Context:** Phase 1 Session 1f — fixing Gauge's bug report that Rule #14 (`check_no_workaround.py`) flagged `# HACK` trigger tokens *inside* a triple-quoted docstring. Line-level regex has no concept of string context; AST strips the text. Both tools failed for different reasons.

**What worked:** The stdlib `tokenize` module reads Python source and emits token tuples including `type == token.STRING` for every string literal — single-line `'foo'`, triple-quoted `"""..."""`, `f"..."`, raw, byte — with `start`/`end` positions as `(row, col)` tuples. Build a set of line numbers occupied by STRING tokens, then have the line-regex loop skip any line in that set.

```python
import io, token, tokenize

def _python_string_literal_lines(source: str) -> set[int]:
    literal_lines: set[int] = set()
    try:
        for tok in tokenize.generate_tokens(io.StringIO(source).readline):
            if tok.type == token.STRING:
                for lineno in range(tok.start[0], tok.end[0] + 1):
                    literal_lines.add(lineno)
    except (tokenize.TokenizeError, IndentationError, SyntaxError):
        return set()
    return literal_lines
```

**Why this beats the alternatives:**
- **Regex state machines** that try to track triple-quote open/close get subtly wrong on escaped quotes, nested quote styles, and f-strings. I would have spent a day and shipped bugs.
- **AST `ast.Expr(value=Constant(str))`** only finds expression-statement docstrings — it misses string constants assigned to variables, passed as arguments, used in annotations, returned, etc. `tokenize` sees every string literal regardless of syntactic role.
- `tokenize` is stdlib, no dep cost, and "does what Python does" by definition. The failure mode (malformed source → TokenizeError) is the same failure mode `ast.parse` already handles, so the error handling matches.

**Cost:** About +0.13s on a 5000-line file vs. pure regex (~0.05 → ~0.18s). Still 5× inside the per-rule budget. Acceptable.

**Cross-pollinate to:** any future Python linter / source-text rule that needs to distinguish "text in a comment" from "text inside a string". Rule #20 (secrets) could benefit too if we ever decide to differentiate secrets in docstrings from secrets in live code — but for now Standard #20 intentionally flags both.

### Persistent cooldown state is just as important as the cooldown itself
**Date:** 2026-04-22
**Context:** Phase 2a Session 2a-1 — watchdog core build. The Owner explicitly flagged SOLUTIONS_LOG #8 (restart-storm email spam) AND #9 (RAM-only state that disappears on restart) as things to avoid. They look like unrelated bugs until you combine them — then they're the same bug.

**The combined failure mode:** Add a 30-minute cooldown to a watchdog, but keep `last_sent_ts` only in `self._last_sent`. Cron restarts the daemon every minute. The in-memory dict is empty on boot, so every cron cycle happily fires alerts again. You shipped a "cooldown" that never cools down because you reset the clock before it ever runs.

**What worked:**
- Persist cooldown state to disk at exactly the moments it changes (after each send / after each mark-sent). JSON file, atomic write (tempfile + `os.replace`), same pattern as the heartbeat client. One file per watchdog installation, not one per service — avoids N writes on a multi-service alert.
- **Load state in the constructor, not lazily.** `AlertSender.__init__` reads the state file. This means a single instance is always in sync with disk, and a fresh instance at next cron tick picks up right where the last one left off.
- **Corrupt state file ≠ drop alerts.** If the JSON is malformed, surface a stderr warning and start fresh (empty cooldown dict). The alternative — raise and block alerts — trades a cosmetic cooldown bug for a real missed-alert bug, which is worse. Standard #14 says "don't silently swallow," not "die loudly"; we surface the corruption AND keep the alerting path alive.
- **Per-service cooldown, not global.** If veoe fires and you put the whole mailer on cooldown, a simultaneous the-machine outage waits 30 min for its first alert. Keep `last_sent: {service: ts}` indexed by service; on each send, mark ONLY the services that went out.
- **Dry-run also writes state.** Otherwise repeated dry-runs (tests, Helm's first deployment rehearsal) don't exercise the persistence path at all. Tests that want a pristine state use a fresh tmp_path.

**Cross-pollinate to:** any future monitor / retry / rate-limit code that maintains windowed state — anything with a "don't do X more often than every N seconds" clause. Specifically the crypto bot's alerts.py (SOLUTIONS_LOG #8 itself — it's currently RAM-only), any future MTM notification throttles, and anything Gauge writes for the alert-format regression tests.

**Related pattern — atomic JSON state files:** The same `tempfile.mkstemp(dir=target_parent) + fsync + os.replace` dance works for cooldown state AND heartbeats AND any other "tiny JSON file updated frequently where a reader must never see half a file." Worth extracting into a tiny helper if a third consumer appears.

### Monitoring code defaults to fail-CLOSED, never fail-open
**Date:** 2026-04-22
**Context:** Phase 2a Session 2a-4 — Gauge's regression pass pinned a strict xfail on `_assess_service` in `watchdog.py`. The function parsed the heartbeat `ts`; if the result was naive (no `tzinfo`), the code said `parsed = parsed.replace(tzinfo=timezone.utc)` and carried on as if the bot was healthy. That is fail-OPEN: a bot that regressed to `datetime.now()` (Standard #6 violation) would look fresh to the watchdog and escape monitoring. The fix was three lines: replace the silent upgrade with a `return {"reason": "malformed-ts ...}` so the bad ts gets surfaced as an alert.

**The rule — for any monitoring, validation, alerting, or health-check code:**
- When you hit an input that "shouldn't happen" (naive datetime, unexpected null, missing field, schema violation), the default must be **reject and surface**, not **normalize and proceed**.
- Ask: "If this input shape is produced by a bug in the system I'm watching, should the watcher catch the bug or hide the bug?" Watchers that hide bugs are useless.
- "Silently normalize" is the wrong pattern for a watcher. It's the right pattern for an adapter, but a watcher is not an adapter.
- Write the error message to point at the root cause so the on-call sees the remediation, not just the symptom. Mine says: *"naive timestamp — Standard #6 violation: update bot heartbeat to datetime.now(timezone.utc)"*. The fixer reads the alert body and knows exactly which file to edit.

**The failure mode it prevents:** A monitored service regresses (bad refactor, accidental import change, copy-paste from a pre-standard codebase). The regression produces subtly-wrong-but-parseable output. The monitor normalizes the badness away. The alert never fires. The bug lives in production until it causes a real outage — at which point the watchdog looks like it was broken the whole time. Gauge is right to call this a "prevention defect" — the monitor exists to prevent silent regressions, and fail-open IS a silent regression of the monitor itself.

**Related — parse errors vs. naive values are the same class:** `_parse_iso_ts` already returned `None` for unparseable ts (fail-closed). A naive-but-parseable ts is the same shape of problem — schema-lenient parser accepted it, but semantic check rejects it. Treating the two paths symmetrically (both return a malformed assessment) is more defensible than "unparseable = alert, semantically wrong = accept."

**Cross-pollinate to:** any team member writing alerting, validation, health-check, or guardrail code. Specifically:
- Echo / Sage / Forge when they write any bot monitor or position-check.
- Gauge when she writes assertion helpers that "normalize" test inputs — same footgun in test code (a normalizer that hides the bug the test was supposed to catch).
- Link on webhook validators — missing field should reject, not default.
- Ohm on NEC table validators — an out-of-range value should reject, not clamp.
- Any future watchdog, linter, schema validator, or pre-commit rule I write.

**Symmetry with Phase 1 enforcement:** The enforcement rules I built for Standards #6/#7/#19/#11/#14/#20 all exit non-zero on violation — they fail-closed by construction. A runtime watchdog should follow the same contract. Same discipline, different layer.

---

### Regression fixtures should point at the REAL corpus, not just synthetic fixtures
**Date:** 2026-04-22
**Context:** Phase 3a Session 3a-1 — incident-memory search. Every scoring knob (keyword density, priority multiplier, recency decay) has a plausible-sounding rationale but a thousand ways to be subtly wrong. Unit tests on a 5-file synthetic corpus prove the *math* works; they do NOT prove the tool will actually surface the right SOLUTIONS_LOG entry when a future Kit greps for the bug he's about to re-discover. Those are different claims.

**What worked:**
- A `real_pka_root` fixture that walks upward from the test file until it finds `.10T/SOLUTIONS_LOG.md`. Skips with a clear message if it's not reachable (so CI running from an extracted tarball doesn't crash — it just loses regression coverage, which is the right trade).
- A parametrised test over 3 representative SOLUTIONS_LOG issues (#1 enqueue, #9 orphan inventory, #12 recency weighting — deliberate variety in failure-mode shape) querying with the error message from the issue and asserting SOLUTIONS_LOG appears in the top-3 results. This is the thing that would actually break if someone turned recency weight too low, or dropped the priority multiplier, or changed AND semantics to OR and let noise win.
- The test uses top-3, not top-1. Top-1 would be brittle to legitimate rank changes (a fresh PROGRESS entry mentioning the same error legitimately beats a 3-week-old SOLUTIONS_LOG). Top-3 says "the tool surfaced the institutional memory within the first screenful", which is the property I actually care about.
- Three issues, not twelve. Testing every SOLUTIONS_LOG entry turns every future log update into a test maintenance chore; three representative cases catches systemic scoring regressions without the bookkeeping.

**Why this beats "just write more unit tests":**
- Scoring is a ranking problem; unit tests check individual weight functions in isolation but can't see interaction effects. The real corpus has real mtimes, real file sizes, real keyword noise from adjacent LESSONS files — the exact conditions the tool will run under in production. A synthetic fixture cannot reproduce "does Issue #12's paragraph beat the three PROGRESS mentions of the same phrase" because that requires the real PROGRESS files.
- If a future refactor changes the tokenizer and `"job_id"` starts matching `"_id"` everywhere, the synthetic tests pass (they don't have that noise); the real-corpus regression fails instantly.

**Cost:** Two tests become parametrised-3 = 3 test cases, still fast (<100 ms combined). Worth it.

**Cross-pollinate to:** any tool whose job is ranking / retrieval / scoring against an institutional corpus. Gauge when she writes QA on search/retrieval systems. Echo / Pulse when they write model-evaluation harnesses — the "test against the real production-shape corpus, not just a toy fixture" principle is the same.

---

### Alert email bodies should carry both human-readable AND raw machine-parseable values
**Date:** 2026-04-22
**Context:** Phase 2a Session 2b-1 — closing Gauge's Bug #3 (body shows `age_seconds: 252` instead of `4m 12s ago`). The obvious fix is to replace the raw integer with the humanised string. The less-obvious right call is to keep BOTH: `last_seen: 4m 12s ago (raw: 252 seconds)`. Humans read the first half; future log-shippers, alert-dashboards, or regex-based post-processors read the second. Dropping the raw integer to pretty up the email body would have cost us machine-parseability for no real gain — the line is already one line long. Same principle applies to any alert/log line that's read by both humans AND scripts: include both forms. The cost is a few bytes; the benefit is you never have to re-parse `"1d 1h 1m 40s"` back into 90100 seconds downstream. **Cross-pollinate to:** any future alert, notification, dashboard string, or log-line that's both human-read and script-parsed.

---

### Debounced writes need BOTH a min-interval AND a max-delay ceiling
**Date:** 2026-04-22
**Context:** Phase 4a Session 4a-1 — building `PersistentDict` (the helper whose whole job is to make SOLUTIONS_LOG #9's RAM-only `_inventory` failure impossible to reproduce accidentally). Debounce was the obvious feature on the spec ("don't thrash disk if a bot mutates state 1000×/sec"). The less-obvious feature was the ceiling.

**The failure I almost shipped:** A pure debounce-only implementation looks like this:
```
if (now - last_write) >= debounce_seconds: write()
else: just-mark-dirty()
```
It seems reasonable. It's broken under sustained load. If mutations arrive faster than `debounce_seconds`, `(now - last_write)` never grows past the interval — every mutation resets the comparison baseline via the dirty-flag path, and no write EVER fires. All N mutations live in RAM until a crash wipes them. That is the exact SOLUTIONS_LOG #9 failure mode the library is supposed to prevent. A debounce-only library would ADD the bug class while appearing to fix it.

**What worked — two guards, not one:**
1. **Debounce window** (`debounce_seconds`): "don't write MORE OFTEN than this" — throttles bursty mutation.
2. **Max-delay ceiling** (`max_delay_seconds`): "dirty this long? next mutation WRITES, debounce or no" — caps worst-case data loss at `max_delay_seconds` regardless of mutation rate.

Track `_last_write_ts` (for debounce math) AND `_first_dirty_ts` (for max-delay math). Reset `_first_dirty_ts = None` after every write; set it lazily on clean → dirty transition. Decision becomes a one-line disjunction:
```python
if (now - _first_dirty_ts) >= _max_delay: write()
elif (now - _last_write_ts) >= _debounce: write()
else: stay dirty
```

**The test that proves the bug is gone:** fake-clock simulation of constant mutation, assert a write occurs within `max_delay_seconds`. Concrete: `debounce=10s`, `max_delay=0.5s`, mutate every 0.1s, assert the file exists within 10 iterations. Without `max_delay`, that test never passes. With it, the write lands on iteration 5-6.

**The `__del__` trap — narrow noqa justified:** `PersistentDict.__del__` calls `close()` → `flush()` → `Checkpoint.save()` → `tempfile.mkstemp` / `os.fsync` / `os.replace`. During interpreter shutdown any of those can raise or misbehave. I wrapped the whole `__del__` body in `try/except Exception: pass` with a `# noqa: broad-except` comment explaining why: GC-time exceptions can't propagate anywhere useful, and "always call `close()` / `flush()` explicitly; `__del__` is only the safety net" is the documented discipline. Standard #14 (no silent swallow) has this narrow exception class; the code explains it inline so the next reviewer doesn't have to re-derive the reasoning.

**Cross-pollinate to:** any library that batches I/O under user-driven mutation — log flushers, autocomplete indexers, undo-stack writers, watchdog alert buffers, and Phase 3 incident-memory bulk ingest. Same two-guard pattern. Don't ship debounce-only.

---

### AST audit scanners are advisory — design the false-positive economy before the detection logic
**Date:** 2026-04-22
**Context:** Phase 4a Session 4a-1 — `run_audit` scanner for RAM-only state. The original DESIGN.md framing was "find everything that could be SOLUTIONS_LOG #9." The right framing is "find the shape cheaply, hand it to a human, don't block anything." That frame changes which knobs matter.

**What the right framing forced me to decide BEFORE writing detection logic:**
1. **Confidence levels in the finding, not just "flagged vs clean"**: `high` / `medium` / `low` gives the reviewer a natural triage order. Without it, a 50-finding report is a pile; with it, reviewers read `high` first and most `medium` ones get quick-ignored. I ended up with the rubric `private + dict + no persist-import anywhere = high`, `anything else suspicious = medium`. The `#9` shape is exactly `high`.
2. **"Never-mutated" as its own opt-out class**: if `__init__` has `self._inventory = {}` but no other method ever writes to it, that's almost always a default-value placeholder that gets overwritten wholesale elsewhere, not a mutable state store. Filtering it out drops ~30% of false positives on typical Python code without weakening true-positive detection. Test it: a class with `self._inventory = {}` and no mutation → not flagged. A class that then does `self._inventory[k] = v` → flagged.
3. **Module-level `import pickle` / `import sqlite3` DOWNGRADES confidence but does not SKIP**: if the module imports a persistence backend somewhere, the author thought about durability — but maybe they thought about it for a DIFFERENT class. Downgrade high→medium, don't hide. The reviewer gets to see the tension.
4. **Opt-in signals via names the library itself exports**: if a class mentions `Checkpoint` or `PersistentDict` anywhere, skip entirely. That way the fix-pattern (convert to `PersistentDict`) immediately stops re-flagging after the fix — the feedback loop closes cleanly. Same idea as Phase 1's `# noqa: tz-aware` escape hatch.
5. **Tests dir is a hard skip, no knob, no config**: `tests/`, `test_*.py`, `*_test.py`, `conftest.py` excluded by default regex list. Test classes ALWAYS look like suspicious state (mock services with in-memory dicts); flagging them is 100% false-positive-by-construction. A user who genuinely wants to audit test code can pass `--exclude ''` or similar, but the default saves them from N thousand useless findings.

**Why "advisory, not blocking" leaks into every design decision:**
- Exit code 0 even when findings exist. Pre-commit integration (should we add it) would be a separate, stricter check, not this.
- Output mode `--json` for consumption by another tool (the audit template, Onyx/Arrow's review workflow). No interactive prompts.
- Findings are `@dataclass(frozen=True)` so they round-trip through `json.dumps(asdict(f))` without surprises. Freezing prevents callers from mutating findings post-collection, which would wreck deterministic diff-against-prior-audit workflows.

**Cross-pollinate to:** any future static-analysis / audit / review-generator tool. The "choose false-positive economy before detection rules" discipline applies to every scanner. Specifically: if/when we build a secrets-sweep rule that goes beyond Phase 1's commit-time check (e.g. a periodic full-repo scan), this framing is more important than the detection regex.

### Windows subprocess captures need `encoding='utf-8', errors='replace'` pinned explicitly
**Date:** 2026-04-23
**Context:** Session 1g. Chris ran `install.py --baseline-sweep` on his Windows box. The baseline log came back with `â€"` mojibake everywhere the pre-commit hook names had em-dashes (`—`).

**Root cause:** `subprocess.run(..., capture_output=True, text=True)` on Windows defaults to the system codepage — cp1252 on a US-locale box — NOT UTF-8. Modern CLI tools (pre-commit, ruff, black, mypy, most Python 3 tools) write UTF-8 to stdout regardless of OS. Result: UTF-8 bytes on the wire → cp1252 decoder on capture → mojibake in the captured string. This has nothing to do with `locale` or `PYTHONIOENCODING` on the child's side; it's a decoding choice on the *parent's* side.

**Fix (one-line):** every `subprocess.run` that captures output needs two extra kwargs pinned:
```python
subprocess.run(
    cmd,
    capture_output=True,
    text=True,
    encoding="utf-8",     # don't let Python guess
    errors="replace",     # one bad byte must not crash us
    check=False,
)
```
`errors="replace"` matters: `errors="strict"` (the default) will raise `UnicodeDecodeError` mid-run if the child ever emits a stray non-UTF-8 byte (e.g. a wrapped tool that prints Latin-1 in its error path). A bootstrap installer must never crash on a display bug — substitute the character and keep going.

**Also pin the log write:** `open(path, "w", encoding="utf-8")` / `path.write_text(..., encoding="utf-8")`. Default text-mode open on Windows is *also* cp1252. Same class of bug, different call site.

**Detection in code review:** grep for `subprocess.run.*capture_output` and for `.write_text(` without `encoding=`. Both need the explicit UTF-8 pin if the code ever runs on Windows. The sandbox (Linux, UTF-8 locale) will happily pass tests that Windows will fail — only way to catch it is to grep.

**Cross-pollinate to:** anyone who writes Python that shells out AND ships to Windows — Swift (mobile toolchain CLI wrappers), Forge (backend deploy scripts calling helm/kubectl), Helm (every DevOps script), Edge (execution adapters), Echo (ML pipeline orchestrators), Glass (frontend build-tool wrappers), Link (integration CLIs). This is a silent-corruption bug that only surfaces when a human reads the output and notices mojibake. Code that "works" in CI (Linux) will produce garbage logs on a Windows dev box and nobody will see it until a log is attached to a ticket.

**Standards nomination:** worth proposing a "Standard: all Python `subprocess.run` captures pin `encoding='utf-8', errors='replace'` when the code may run on Windows." Simple enough to enforce as a pre-commit rule — AST-walk for `subprocess.run` calls with `capture_output=True` or `stdout=PIPE` and no `encoding=` kwarg. Flagging to 10T for the next monthly review.

---

### Secret-detection rules need adversarial-testing against the team's actual historical leaks
**Date:** 2026-04-23
**Context:** Session 1j — Rule #20 (`check_plaintext_secrets.py`). My original Phase 1 rule had a generic-hex pattern that required 32+ hex chars AND a literal `=` separator. It caught the `sk_live_...` leak in the options-monetization plan (pattern worked). It MISSED the `"ERPNEXT_API_KEY": "<redacted 15-hex>"` in `.mcp.json` because the real leak was 15 hex chars in a JSON `"K": "v"` shape. Two independent gaps — length floor AND separator regex — both invisible under fixture-only testing because every fixture I wrote happened to use the shapes my regex handled.

**The failure mode:** I tested the rule against plausible synthetic secrets that matched the pattern I was writing. That is a tautology, not a test. It proves the regex parses what I typed; it proves nothing about what real leaks in this team's repos look like.

**What would have caught it pre-deploy:** a test fixture derived from the actual shape of secrets historically leaked in team repos. `.mcp.json` was already in PKA at authoring time. A fixture mirroring its `"ERPNEXT_API_KEY": "<15 hex>"` shape would have failed immediately and told me to widen the separator regex AND lower the length floor — before Gauge had to run a self-pilot to discover it.

**What worked to fix it:**
1. Key-indicator-driven pattern (`KEY|SECRET|TOKEN|PASSWORD|API_KEY|AUTH|CREDENTIAL|PRIVATE`) + broad separator (`[:=]` plus optional surrounding quotes on BOTH name and value). Catches `K=v`, `K: v`, `"K": "v"`, `K = "v"` in one regex.
2. 15-char floor on the value (the ERPNEXT shape). Lower floor + entropy-lite filter (require digit OR mixed-case; reject UUIDs, all-same-char, all-lowercase-with-underscores) keeps the FP rate tolerable.
3. Regression fixtures mirror the exact shape of the 2026-04-22 leaks:
   - `fail_secrets_short_hex_json.json` — the `.mcp.json` miss
   - `fail_secrets_password_equals.md` — the `OPTIONS_ADMIN_PASSWORD=` miss (Rule #20 had no PASSWORD= coverage at all)
   - `fail_secrets_stripe_live.md` — regression guard on the find we DID catch
   - `pass_secrets_placeholder_short.json` and `pass_secrets_uuid.yaml` — pin the FP boundaries at the new short-length floor

**The rule I'll apply going forward for any detection / guard / validator I build:** before shipping, build a fixture derived from the team's real past incidents (SOLUTIONS_LOG, OWNER_CONTEXT, historical LEAKS folder, anything). If the rule misses even one real historical shape, the fixture coverage is incomplete — regardless of how many synthetic fixtures pass. Doubly true for secret-detection, where "clever regex passes all my examples" is the default sensation and "real leak shapes in this codebase" is the actual problem.

**Cross-pollinate to:** Gauge (fixture-derivation methodology on all detection rules), Glass (XSS / input-validation rules), Onyx (NEC violation detection), any future rule author. Specifically propose: every new enforcement rule must be paired with at least one fixture derived from a real past incident, not only from the rule author's synthesised examples.

**Standards nomination:** "Detection rules must be fixture-tested against at least one real past incident from team logs before going live." Flagging to 10T.

---

### Inline `<!-- noqa: ... -->` HTML comments are the right silencer for markdown rules
**Date:** 2026-04-23
**Context:** Session 1j — Rule #14 (`check_no_workaround.py`) fired on 8 markdown prose lines that legitimately mention HACK / WORKAROUND / FIXME as rule-describing text (STANDARDS.md title, enforcement/README.md feature table, COVERAGE.md, a Kit LESSONS entry). Markdown has no comment syntax — the `# noqa: workaround` convention from Python lines would render visibly in the docs. Python `#` is a code comment; in markdown it's a heading.

**What worked:** HTML comments. `<!-- noqa: workaround -->` is ignored by every markdown renderer (GitHub, pandoc, VSCode preview) and is on the same line as the trigger, so the rule's line-level noqa check sees it without needing any syntax change. Add the `NOQA_MARKER = "noqa: workaround"` constant to the rule, and a `if NOQA_MARKER in line: continue` branch inside the scan loop. Kit's standard escape-hatch pattern — unchanged — with markdown compatibility for free.

**The better version (not shipped):** context-aware rule that only fires on HACK/WORKAROUND/FIXME tokens INSIDE fenced code blocks (```) in markdown. That's the right long-term solution for Rule #14 specifically — prose descriptions will never be false-flagged — but the inline HTML-comment silencer is the universal escape hatch and ships in 3 lines of code. Doing both (context-awareness AND an inline silencer) gives you a rule that rarely needs silencing AND a clean escape hatch for the residual cases. I shipped only the inline marker in 1j and left context-awareness as a Phase 2 tightening task.

**Why this matters generally:** every text-based rule that scans docs / READMEs / markdown needs an escape hatch that doesn't corrupt the rendered output. `#`-comment won't do. Python `# noqa` conventions force rule authors to either skip markdown entirely or accept ugly visible markers. HTML comments sit at the intersection of "on the line the rule scans" and "invisible in the rendered doc." Same technique applies to any future rule that scans `.html`, `.xml`, `.svg`, or any other format with `<!-- ... -->` comments.

**Cross-pollinate to:** anyone writing text/doc-scanning rules. Specifically Gauge (regression rule authoring), Glass (HTML/JSX lint rules — same comment syntax applies), Onyx (if NEC docs ever get auto-checked), any future enforcement rule that targets markdown.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Lessons

### 2026-04-23: Windows subprocess encoding — cp1252 vs UTF-8
- **Category:** developer
- **Lesson:** Every Python `subprocess.run` that captures output on Windows must pin `encoding='utf-8', errors='replace'` — the default cp1252 decoding silently corrupts UTF-8 output from modern CLI tools.
- **Context:** SOLUTIONS_LOG #14. `install.py --baseline-sweep` on Windows produced mojibake (`a]"` instead of em-dashes) in the baseline log. Root cause: `text=True` defaults to system codepage (cp1252), not UTF-8. Fix: add `encoding="utf-8", errors="replace"` to subprocess captures AND to file writes.
- **Keywords:** subprocess, encoding, utf-8, cp1252, Windows, mojibake, text, capture_output

### 2026-04-10: RAM-only state loses real money on restart
- **Category:** developer
- **Lesson:** Any in-memory state that tracks real assets or money must be persisted to disk — restart-resilience means recovering state, not just reconnecting to APIs.
- **Context:** SOLUTIONS_LOG #9. Crypto bot `strategy_mm.py` kept `_inventory` dict in RAM only. On restart, the dict was empty but coins remained on Kraken. Over many restart cycles, $86 of capital became orphaned. Standard #19 checkpoint rule and the PersistentDict library were created to prevent this class of bug.
- **Keywords:** RAM, persistence, state, restart, inventory, orphan, PersistentDict, checkpoint

### 2026-04-10: Recursive error handlers cause infinite loops
- **Category:** developer
- **Lesson:** Error handlers that can trigger themselves (e.g., a send-alert function that catches its own exception and retries) must have a max-retry counter and cooldown to prevent infinite recursion or self-DOS.
- **Context:** SOLUTIONS_LOG #8 and the 2026-05-11 self-DOS incident. Bot restart loops triggered flush_digest on each shutdown, which triggered emails, which could fail and retrigger. Fix: add cooldown timers, empty-buffer checks, and max-retry limits to any function that fires on shutdown or error paths.
- **Keywords:** recursive, error handler, infinite loop, cooldown, retry, self-DOS, shutdown

### 2026-04-22: Secret detection must test against real past leaks
- **Category:** developer
- **Lesson:** Detection rules (secrets, lint, validation) must be fixture-tested against at least one real past incident from team logs — synthetic-only fixtures prove the regex matches what you typed, not what real leaks look like.
- **Context:** SOLUTIONS_LOG #15. Rule #20 caught `sk_live_...` but missed the 15-char `ERPNEXT_API_KEY` in `.mcp.json` because the test fixtures only used shapes the regex already handled. Fix: derive fixtures from real historical leaks (`.mcp.json` shape, `OPTIONS_ADMIN_PASSWORD=` shape) and lower detection thresholds.
- **Keywords:** secret detection, fixture, real incidents, regex, false negative, enforcement, pre-commit

### 2026-04-02: Long compute without checkpoints wastes days
- **Category:** developer
- **Lesson:** Any process >5 minutes must have early validation (test 1 iteration first), checkpoint saves, progress logging, and resumability — or you risk losing hours of compute silently.
- **Context:** Standard #19. `massive_sweep.py` ran 303 configs that ALL timed out at 600s with no progress logging — nobody knew for days. Neural trainer could crash silently mid-training. `download_full_history.py` had no incremental save on network errors. Rule: validate first iteration, checkpoint every N, log progress, persist resume points.
- **Keywords:** checkpoint, long compute, progress, resumability, early validation, sweep, timeout

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

