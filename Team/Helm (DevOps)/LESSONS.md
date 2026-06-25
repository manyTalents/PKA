# Helm — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

### 2026-04-22 — Installer fallback when `pre-commit` is not on PATH

**Pattern:** `pip install --user <tool>` drops the console script into
`~/.local/bin` (Linux/Mac) or `%APPDATA%\Python\Scripts` (Windows), which
is **not** on PATH by default on a fresh machine. Calling `pre-commit` by
name then fails even though the package is installed.

**Fix:** Detect the PATH miss and fall back to invoking the module
directly: `python -m pre_commit install` / `python -m pre_commit run`.
Same binary, same behavior, zero PATH engineering required from the user.
This turns "you need to fix your PATH" into a non-event.

**Cross-pollinate:** Any Python-based CLI we install via `pip install
--user` should have this fallback baked into the wrapper. Applies to
future installers for ruff, black, mypy, pytest, etc. When you can run it
as `python -m <pkg>`, do — it is strictly more portable than trusting the
console script to be on PATH.

**Referenced by:** `enforcement/install.py` `ensure_pre_commit()` +
`_pre_commit_cmd()`.

### 2026-04-22 — Secret-at-runtime wrapper > systemd EnvironmentFile for rotatable creds

**Pattern:** Two ways to inject secrets into a systemd-scheduled job:
(A) static `EnvironmentFile=/etc/foo/env` with the secret baked in, or
(B) a wrapper script that pulls the secret from the secret manager at
process start via `bw get password <item>` and execs the real binary.

Static env files look simpler — but they break Standard #20 in a subtle
way: **rotation requires touching the disk file in addition to the vault.**
One place to rotate becomes two. When the file drifts (someone updated
Bitwarden but forgot the env file), you get silent SMTP auth failures at
3 AM with no obvious root cause. This is SOLUTIONS_LOG #4's failure mode
in a different coat.

**Fix:** Wrapper script. `bw get` reads the current vault entry every run.
Rotation = update Bitwarden, done. One source of truth, matches #20's
intent exactly. Tradeoff: the Bitwarden *session token* (not the password)
does expire — so a short-lived token in `/etc/…/env` is acceptable (it's
not the secret itself, it's the unlock), and when it expires the dead-man's
switch catches it.

**Cross-pollinate:** any future droplet-side service that needs a rotatable
secret (API keys, Stripe, Twilio, Tradier) — wrapper + `bw get` beats
static env file. Only use static env for values that genuinely never
change (ports, feature flags, URLs).

**Referenced by:** `watchdog/deploy/pka-watchdog-wrapper.sh` +
`watchdog/DEPLOY.md` §5.

### 2026-04-22 — Dead-man's-switch ping AFTER the job, not BEFORE

**Pattern:** When wiring Healthchecks.io (or any heartbeat-style external
monitor) into a systemd unit, the tempting place to put the `curl
https://hc-ping.com/...` is `ExecStartPre=` — easy, runs first, always
fires. **This is wrong.** A Pre-ping means "my systemd scheduler is
alive" — which is not the question. The question is "did my actual
workload run to completion?" If ExecStart dies halfway, ExecStartPre
already pinged success and Healthchecks.io never notices.

**Fix:** Ping AFTER the real work, from inside the wrapper, conditional on
exit code. Exit 0 or 1 (work completed, possibly with findings) → ping.
Exit 2+ (work was broken before it could finish) → skip ping, let the
dead-man's switch fire. Appending `/$rc` to the ping URL lets the
Healthchecks.io dashboard distinguish "clean" runs from "silence detected"
runs — both are valid liveness, but the distinction is useful forensically.

**Cross-pollinate:** applies to every cron-replacement systemd unit we
wire to external monitoring. Pre-hooks are for setup, not for liveness
signaling.

**Referenced by:** `watchdog/deploy/pka-watchdog-wrapper.sh` trailing
`curl ... "${HEALTHCHECKS_PING_URL}/${rc}"`.


---

## Lessons

### 2026-04-04: FC worker cache — 15 min delay after deploy
- **Category:** devops
- **Lesson:** After deploying to Frappe Cloud, background workers cache Python modules for ~15 minutes — new endpoints may return "no such attribute" until workers restart.
- **Context:** SOLUTIONS_LOG #5. New whitelisted functions deployed via `git push` were not callable via API. Web process restarted but workers kept old code. Workaround: add functionality to existing functions via parameters, or wait ~15 min for automatic worker restart. Standard #8 created from this.
- **Keywords:** frappe cloud, deploy, worker cache, restart, endpoint, module cache

### 2026-04-04: No bench commands on Frappe Cloud
- **Category:** devops
- **Lesson:** Frappe Cloud provides NO `bench migrate`, `bench restart`, or `bench execute` — create doctypes via REST API with `custom=1`, use Property Setters for live field changes, and use Server Scripts as workarounds for code not loading.
- **Context:** SOLUTIONS_LOG #5. Deploys auto-run migrate but there is no manual trigger. If auto-migrate misses a doctype, create it via `POST /api/resource/DocType` with `custom=1`. Property Setters allow field modifications without bench access. Server Scripts can provide emergency function endpoints when deployed code is stuck in worker cache.
- **Keywords:** frappe cloud, bench, migrate, restart, Property Setter, Server Script, custom doctype, REST API

### 2026-04-04: Property Setters for live field changes without bench
- **Category:** devops
- **Lesson:** On Frappe Cloud, use Property Setters (`POST /api/resource/Property Setter`) to modify doctype field properties at runtime — this is the only way to change field attributes without bench access.
- **Context:** Needed to modify field properties on live doctypes but had no bench access on FC. Property Setter records override doctype JSON definitions at runtime. Create them via API: `{"doctype_or_field": "DocField", "field_name": "target_field", "property": "hidden", "value": "1", "doc_type": "Target DocType"}`.
- **Keywords:** Property Setter, frappe cloud, field, doctype, runtime, no bench

### 2026-04-22: Verify endpoints after every FC deploy
- **Category:** devops
- **Lesson:** After every Frappe Cloud deploy, hit each new/modified endpoint with a test call before updating clients (mobile app, frontend) to depend on it.
- **Context:** Standard #8. Multiple incidents where mobile app was updated to call new endpoints that workers had not yet loaded. Result: 500 errors for users until worker cache refreshed. Deploy checklist must include endpoint verification step with actual API calls, not just checking git push success.
- **Keywords:** deploy, verify, endpoint, test call, checklist, frappe cloud, worker cache

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

