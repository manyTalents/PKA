# PKA Team Standards

> The single source of truth for how this team works.
> Every rule here exists because something went wrong without it.
> **Monthly review:** 10T + DATA review on the **1st of every month**. Stale rules are updated or removed.

---

## Critical Rules (Violations = Immediate Correction)

### 1. ASK BEFORE ACTING
**Rule:** Every team member must ask clarifying questions until 95% confident before implementing anything.
**Why:** Corrected multiple times. Work built on assumptions gets thrown away.
**Example:** Owner says "fix the search." Don't assume which search, which fix, which screen. Ask.
**Enforcement:** 10T reviews every task delegation for clarity. Team members self-enforce.

### 2. API IS THE SOURCE OF TRUTH
**Rule:** Always pull real data from APIs. Never estimate, hardcode, or fabricate data when a live source exists.
**Why:** Hardcoded data becomes stale immediately. Users see wrong numbers. Trust erodes.
**Example:** Pricebook data comes from ERPNext API, not a cached spreadsheet. Job counts come from HCP API, not a guess.
**Enforcement:** Code review flag. Any hardcoded array that should be an API call is a bug.

### 3. NEVER PUSH TO LIVE PRICEBOOK
**Rule:** The live ERPNext pricebook is READ-ONLY. It backs real invoices. Never write to it programmatically.
**Why:** A bad write corrupts pricing on active invoices. Undoing this requires manual correction of every affected invoice.
**Example:** Testing price updates? Use a dev/staging Item Price List, never "Standard Selling."
**Enforcement:** Hard rule. No code path should call `frappe.set_value` on live Item Price records.

### 4. GENERIC PART NAMES IN TECH-FACING VIEWS
**Rule:** Tech-facing screens use simple names: "3/4 AC line set", not "3/4 in. x 1/2 in. Copper Line Set 15ft Pre-Charged."
**Why:** Techs know what parts are. Verbose manufacturer names slow them down and clutter the UI.
**Example:** Search results, truck stock lists, job materials — all show the short name.
**Enforcement:** UI review. Pixel/Stocky flag verbose names in mockups.

### 5. SHARED COMPONENTS — NO DUPLICATES
**Rule:** When functionality is shared across screens (search, part lookup, status display), use ONE shared implementation. No duplicate functions.
**Why:** Two implementations drift apart. One gets updated, the other doesn't. Users see inconsistent behavior.
**Example:** `searchParts()` is defined once, imported by Limbo matching, "add part to job," and any future search screen.
**Enforcement:** Code review. Kit/Swift flag duplicate implementations.

---

## Code Standards

### 6. Timezone-Aware Datetimes Only
**Rule:** Always use `datetime.now(timezone.utc)` or `frappe.utils.now_datetime()`. Never use naive `datetime.now()`.
**Why:** Naive datetimes caused a production crash in the trading bot. Timezone bugs are silent until they're catastrophic.
**Example:** `from datetime import datetime, timezone; now = datetime.now(timezone.utc)`
**Enforcement:** Linter rule (Kit). Gauge regression test.

### 7. frappe.enqueue() — Always Provide job_id with deduplicate
**Rule:** When calling `frappe.enqueue(..., deduplicate=True)`, always provide a `job_id` parameter.
**Why:** SOLUTIONS_LOG Issue #1 — blocked ALL HCP Job operations. Frappe requires it silently.
**Example:** `frappe.enqueue(push_job_to_hcp, deduplicate=True, job_id=f"push_hcp_job_{doc.name}")`
**Enforcement:** Grep for `deduplicate=True` without `job_id`. Gauge test.

### 8. Verify New Endpoints After Frappe Cloud Deploy
**Rule:** After deploying new whitelisted functions, verify they're callable before depending on them.
**Why:** SOLUTIONS_LOG Issue #5 — Frappe Cloud workers cache Python modules. New code may not be visible for minutes/hours.
**Example:** Hit the endpoint with a test call before updating the mobile app to use it.
**Enforcement:** Helm deploy checklist step.

### 9. HCP Uses UUIDs, Not Invoice Numbers
**Rule:** When calling HCP API, use the UUID (`job_0f701d07...`), never the invoice number (`40638`).
**Why:** SOLUTIONS_LOG Issue #2 — 404 errors on all API calls using invoice numbers.
**Example:** Store the UUID from webhook payload `job.id` and use it for all API calls.
**Enforcement:** Code review. Link/Forge flag incorrect ID usage.

### 10. Credential Rotation — Update ALL Locations
**Rule:** When API keys are rotated, update ALL locations listed in `KEY_ROTATION.md`. Log the rotation with date.
**Why:** SOLUTIONS_LOG Issue #4 — HCP sync broke silently because keys were rotated but not updated in ERPNext.
**Example:** Check `AllTecPro/KEY_ROTATION.md` for every key storage location before rotating.
**Enforcement:** Link maintains credential lifecycle. Checklist required for every rotation.

### 11. Customer Data Mapping — Read the Right Fields
**Rule:** HCP customer data comes from `customer.first_name` / `customer.last_name` / `customer.company`, NOT from `job.company_name` (which is AllTec's own company name).
**Why:** SOLUTIONS_LOG Issue #3 — every job showed "AllTec" as customer because code read the wrong field.
**Example:** `customer_name = payload["customer"]["first_name"] + " " + payload["customer"]["last_name"]`
**Enforcement:** Code review on any webhook processing code.

### 12. npm install Wipes Patched Binaries
**Rule:** After running `npm install` on the mobile app, re-apply the ngrok v3 binary patch if using Expo tunnel.
**Why:** SOLUTIONS_LOG Issue #6 — `@expo/ngrok` reinstalls the deprecated v2 binary on every install.
**Example:** Re-copy ngrok v3 binary to `node_modules/@expo/ngrok-bin-win32-x64/ngrok.exe` and re-patch client.js + utils.js.
**Enforcement:** Post-install script or developer checklist.

### 13. READ FULL CONTEXT — NO PARTIAL READS
**Rule:** When a project has a progress file, session log, or reference doc, read the ENTIRE document before starting work. If it's too large, compress it (archive old sections, keep resume point) — but never read only the top and assume you have the picture.
**Why:** Corrected in MTM Session 18. 10T read progress.txt top-down (newest first), stopped partway, and missed that `pull_line_items_from_hcp()` was already built in Session 3. Asked the Owner a question that was already answered. Foundational decisions, architecture, and already-built functions live deeper in context files — skipping them means rediscovering what's known or asking questions the Owner has already answered.
**Example:** progress.txt is 1,200 lines. Read all 1,200. If it grows past what fits in context, compress the oldest sessions into a summary section at the bottom and keep the recent sessions detailed. Never read 100 lines and wing it.
**Enforcement:** 10T self-enforces. Any team member who receives a context file reads the whole thing. If the file is too large, flag it for compression before starting work.

### 14. ROOT CAUSE FIRST — NEVER WORKAROUND
**Rule:** When something is broken, find and fix the root cause. Never offer a workaround as the solution. Workarounds are acceptable only as a temporary bridge WHILE actively fixing the root cause — and only if explicitly acknowledged as temporary.
**Why:** Corrected twice in MTM Session 18. (1) Login email wasn't sending — 10T suggested manually generating an invite URL instead of investigating why `frappe.sendmail` was failing. Root cause was Gmail App Password rejection. (2) API keys returning 401 — 10T suggested generating new keys instead of checking why the existing ones stopped working. The Owner's standard: "Never document a limitation and move on; find the workaround immediately" means find the REAL fix, not paper over it.
**Example BAD:** "Email isn't sending. Here's a manual URL you can use instead." **Example GOOD:** "Email isn't sending. Let me check the sendmail call... the Gmail App Password was rejected. The password needs to be updated in the Email Account settings."
**Enforcement:** 10T self-enforces. If any team member proposes a workaround, 10T asks "what's the root cause?" before approving.

---

## Process Standards

### 15. PROGRESS.md on Every Active Project
**Rule:** Every active project folder contains a `PROGRESS.md` with: description, current status, session log, and resume point.
**Why:** Sessions end unexpectedly. Without a resume point, context is lost and work is duplicated.
**Enforcement:** 10T checks at task delegation. No project work begins without PROGRESS.md.

### 16. LESSONS.md — Continuous Learning
**Rule:** Every team member maintains a `LESSONS.md` in their folder. Log: patterns found, solutions that worked, tools needed, and standards to propose.
**Why:** Without it, the same bugs recur, the same solutions are re-discovered, and the team doesn't grow.
**Enforcement:** 10T reviews during monthly SOP review.

### 17. Cross-Pollination
**Rule:** When a lesson applies to multiple team members, 10T distributes it to all affected members.
**Why:** One member finding a bug class that exists in another member's code shouldn't require independent discovery.
**Example:** Kit finds a timezone bug in Python. 10T pushes the lesson to Echo, Sage, Forge, and anyone else writing Python.
**Enforcement:** 10T protocol — triggered when lessons are logged and during monthly review.

### 18. Pre-Flight Checklists
**Rule:** Each role group maintains a short checklist for their most critical operations (deploy, PR, strategy launch, etc.).
**Why:** Checklists catch the mistakes that experience makes you complacent about.
**Enforcement:** Each member maintains their own. 10T reviews during monthly SOP review.

### 19. Long Compute — Checkpoints, Early Validation, Progress Reporting
**Rule:** Any process that runs longer than 5 minutes MUST have:
1. **Early validation** — Confirm it actually works within the first 1-2 iterations before committing to hours of compute. Run one cycle, verify output, THEN launch the full batch.
2. **Checkpoint saves** — Persist intermediate results to disk at regular intervals. If the process crashes at iteration 50/100, you keep the first 50 results.
3. **Progress logging** — Log progress at each iteration or at fixed intervals (at minimum every 5 min). Include: current iteration, total, elapsed time, estimated remaining.
4. **Resumability** — If interrupted, the process can restart from the last checkpoint rather than starting over. Use a marker file or DB record to track position.
5. **Failure alerting** — If the process goes silent (no progress log) for >2x the expected iteration time, alert. Don't let an 8-hour run sit dead for 8 hours before someone checks.

**Why:** We've been burned multiple times:
- `massive_sweep.py`: 303 configs ALL timed out at 600s — nobody knew for days (PROGRESS.txt v8.1, 2026-04-02)
- Neural trainer: hours of training that could crash silently on a bad feature matrix
- `download_full_history.py`: network errors mid-download with no incremental save
- Orphan inventory: in-memory state that disappeared on crash because it was never persisted (SOLUTIONS_LOG #9)

**Example — BAD:**
```python
for config in all_configs:  # 200 configs × 50 seconds each = 2.8 hours
    result = run_backtest(config)  # crashes on config #3, nothing saved
results = pd.DataFrame(results)  # never reached
```

**Example — GOOD:**
```python
# Early validation: test one config first
test_result = run_backtest(all_configs[0])
assert test_result is not None, "First config failed — aborting before wasting hours"

for i, config in enumerate(all_configs):
    result = run_backtest(config)
    results.append(result)

    # Checkpoint: save every 10 iterations
    if (i + 1) % 10 == 0:
        pd.DataFrame(results).to_csv(f'sweep_checkpoint_{i+1}.csv')
        logger.info(f"Sweep progress: {i+1}/{len(all_configs)} ({elapsed:.0f}s, est {remaining:.0f}s remaining)")
```

**Applies to:** `massive_sweep.py`, `neural_trainer.py`, `download_full_history.py`, `bootstrap_learner.py`, `sell_orphans.py`, `analyze_holdings.py`, any data download, any batch process, any background daemon.

**Enforcement:** Code review. Kit/Echo flag any loop >100 iterations or >5 min estimated runtime that lacks checkpointing. 10T reviews during task delegation for long-running work.

### 20. BITWARDEN IS THE SINGLE SOURCE OF TRUTH FOR ALL SECRETS
**Rule:** Every API key, credential, service account, token, and password lives in Bitwarden. No exceptions. No plaintext files on disk, in OneDrive, in git repos, in Word docs, or in progress files.
**Why:** Security audit on 2026-04-16 found 30+ secrets in plaintext across 5 projects — CSVs, .txt files, .pem files, .env files, Word docs, even progress.txt. Keys were duplicated in 5 places, rotated but not updated everywhere, and synced to OneDrive cloud. Bitwarden migration eliminated all of this.

**How secrets work now:**
1. **Create/rotate a key:** Generate in the service, store in Bitwarden with: name, folder, URI to management page, env_var_name, project, rotated_on date
2. **Use in code:** Active .env files on disk are the ONLY allowed plaintext copies. They are generated from Bitwarden via `secrets-refresh.sh` and listed in `.gitignore`
3. **Rotate a key:** Update Bitwarden entry → move old to Archive - Rotated/ folder → run `secrets-refresh.sh` → restart affected services
4. **Never:** hardcode keys in code, commit .env files, store keys in CSVs/docs/txt files, print keys in progress files or logs

**Vault structure:**
- `MTM - AllTec Pro/` — ERPNext, HCP, Google Vision, Gmail, Frappe Cloud, Vercel
- `Crypto Bot - LIVE/` — Kraken, Coinbase (archived), Gmail, X API
- `VEOE Trading - LIVE/` — Tradier live, Kraken, Gmail, Google Drive SA + OAuth
- `VEOE Trading - Paper/` — Tradier paper, Polygon
- `Shared Services/` — Anthropic, Gemini, X AI, Digital Ocean, Dashboard tokens
- `ManyTalents App/` — Android keystore
- `Archive - Rotated/` — old/revoked keys with date suffix

**Every entry includes a URI** linking directly to the service's key management page — one click to rotate.

**Enforcement:** Code review. Any plaintext secret file discovered outside of .env (which must be in .gitignore) is a critical violation. 10T flags during task delegation. Bitwarden CLI (`bw`) is installed and available for scripted access.

---

### 21. DESIGN DOC BEFORE BUILDING
**Rule:** Before any implementation work begins on a new feature, project, or significant change, a one-page design doc must exist. Minimum three sections:
1. **What does done look like?** — Concrete, testable definition of success. Not "it works" — what specifically works, for whom, and how do you verify it.
2. **Who uses it?** — The actual human (or system) that interacts with this. Name them. "Techs in the field," "Katelyn at intake," "the VEOE exit monitor." Not "users."
3. **What breaks if it's wrong?** — Consequences of a bad implementation. What data gets corrupted, what workflow stalls, what money is lost. Forces you to think about blast radius before writing line 1.

**Why:** Multiple sessions where the Owner came in with an idea, coding started immediately, and a requirement discovered midway reshaped the entire approach. Wasted hours that a 15-minute spec would have prevented. The Machine had a proper spec and its Phase 0 shipped clean. Projects without specs drift.

**Where it lives:** In the project folder as `DESIGN.md`, or in `PKA/docs/superpowers/specs/` for larger initiatives. Short is fine — one page beats no page.

**Enforcement:** 10T checks before delegating implementation work. No design doc = no code. Team members may draft the doc, but the Owner approves it before building begins.

### 22. CAPTURE THE OWNER'S REASONING
**Rule:** When applying the 95% Rule (#1), don't just ask WHAT the Owner wants — ask **WHY**. Capture the reasoning, business logic, and strategic intent behind every decision. Store it in the project's `DESIGN.md` or `PROGRESS.md` under a **Decisions** section.

**Format:**
```
### Decision: [what was decided]
**Date:** [date]
**Why:** [Owner's reasoning — the business logic, constraint, or strategic intent]
**Alternatives considered:** [what was rejected and why, if discussed]
```

**Why:** The Owner's reasoning is institutional knowledge. Without it, future sessions (or future team members) see WHAT was built but not WHY. When requirements conflict later, knowing the original reasoning lets the team make smart tradeoffs instead of guessing. The Owner has a grand strategic vision — individual decisions only make sense in that context.

**Example — BAD:** "Owner wants magic-link auth. Implementing."
**Example — GOOD:** "Owner wants magic-link auth. **Why:** Techs in the field share devices, passwords get forgotten constantly, and password resets create support tickets that pull office staff off real work. Magic-link eliminates the entire password problem."

**Enforcement:** 10T and all team members. When the Owner explains WHY during a session, capture it immediately — don't wait. If the Owner gives a directive without explaining why, ask: "Can you tell me the reasoning? I want to make sure we capture it."

### 23. NEC TABLE DATA — ABSOLUTE TRUTH ONLY
**Rule:** Every NEC table, chart, or reference value in ManyTalents Prep must be verified against the authoritative source (2023 NEC / NFPA 70) before shipping. No approximations, no "close enough," no values pulled from third-party summaries. Every number must match the official code exactly.
**Why:** This is an exam prep product. A single wrong ampacity value, demand factor, or conductor dimension means a student learns incorrect information and potentially fails a $300+ licensing exam. Wrong data destroys trust and creates legal liability. Ohm verified Table 310.16 value-by-value against NEC 2023 — that's the standard for every table.
**Example — BAD:** "I found these motor FLC values on an electrical forum — they look right." **Example — GOOD:** "Every value in nec-430-250.ts was cross-referenced against NEC 2023 Table 430.250 by Ohm. All 48 values verified. Discrepancies logged."
**Enforcement:** Ohm (Electrical Code Specialist) reviews and signs off on every electrical table data file before merge. For other trades, the designated subject-matter expert performs the same verification. No chart data file ships without a verification record.

---

## Monthly Review Protocol

| Step | Action | Owner |
|------|--------|-------|
| 1 | Review all LESSONS.md files for new patterns | 10T + DATA |
| 2 | Promote recurring lessons (2+ occurrences) to standards | 10T |
| 3 | Remove or update stale/outdated standards | 10T + DATA |
| 4 | Cross-pollinate lessons to affected members | 10T |
| 5 | Check if automated enforcement exists for each rule | Kit + Helm |
| 6 | Report to Owner: changes, additions, removals | 10T |

**Schedule:** 1st of every month. Report delivered to Owner's Inbox.

---

## How to Propose a New Standard

1. Log the pattern in your `LESSONS.md` under "Standards to Propose"
2. Include: what the rule is, why it matters, and an example
3. 10T reviews during the monthly cycle (or sooner if flagged as urgent)
4. If the pattern has occurred 2+ times OR has high blast radius, it becomes a standard
5. 10T adds it to this file and notifies affected members

---

## Version Log

| Date | Change | By |
|------|--------|----|
| 2026-04-06 | Initial creation — 16 standards from real incidents + team consultation | 10T + Full Team |
| 2026-04-12 | Added #17: Long Compute checkpoints/early-validation/progress — Owner directive after sweep failures | Owner + 10T |
| 2026-04-16 | Added #13: Read Full Context — no partial reads. Added #14: Root Cause First — never workaround. Renumbered #15-19. Both from MTM Session 18 corrections. | Owner + 10T |
| 2026-04-16 | Added #20: Bitwarden is single source of truth for all secrets. Vault structure, rotation protocol, enforcement rules. From secrets migration. | Owner + 10T |
| 2026-04-17 | Added #21: Design Doc Before Building — one-page spec required before implementation. Added #22: Capture Owner's Reasoning — ask WHY, store decisions. Both from Owner self-assessment session. | Owner + 10T |
| 2026-04-20 | Added #23: NEC Table Data — Absolute Truth Only. Every chart/table value must be verified against authoritative NEC source before shipping. From chart reference system buildout. | Owner + 10T |
