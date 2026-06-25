# Link — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

### MCP stdio servers: keep the protocol skin razor-thin, put all logic behind a pure dispatcher
**Context:** 2026-04-22, Phase 3b wrapping `pka_incident_memory.search()` as an MCP tool server.

The obvious shape for an MCP server is a single async file: import the SDK,
decorate `@server.list_tools()` / `@server.call_tool()`, stuff the business
logic inside the decorated coroutines. Do NOT do this. Structure the server
as three concentric layers:

1. **Pure-Python handlers** — dict-in / dict-out synchronous functions.
   Signature: `(arguments: dict) -> dict`. No MCP imports, no `async`, no
   stdio. One per tool. Validation raises a single custom exception type
   (`ToolInvocationError`) that distinguishes bad-input from bad-environment.
2. **Pure-Python dispatcher** — `dispatch_tool(name, arguments)` that
   normalises `None` arguments to `{}`, looks up the handler by name, and
   forwards. Also sync. Also import-clean.
3. **Async MCP shim** — tiny file-scope `_build_server()` + `run_stdio()`
   that registers the SDK decorators; each decorator's body is literally
   `return dispatch_tool(name, arguments)` wrapped in the SDK's expected
   Content/Result types.

**Why this matters:**
- **Testability.** You can unit-test every tool — happy path, every malformed
  input, every error branch — with pytest-sync assertions against
  `dispatch_tool()`. No `pytest-asyncio`, no transport mocking, no
  protocol fake. The SDK's stdio is Anthropic's test surface, not yours.
- **Error taxonomy clarity.** `ToolInvocationError` is the "bad input,
  surface to the model as an error CallToolResult" signal. Anything else
  (OSError, KeyError, bug in search) bubbles into a JSON-RPC error. Silent
  catch-all try/except in the handler layer hides bugs — Standard #14.
- **`--test` mode falls out free.** A standalone self-test that calls
  `dispatch_tool("search_incidents", {...})` and prints JSON is a 20-line
  function once the dispatcher exists. No need to fake a handshake.
- **Schema lives in data, not code.** `TOOL_DEFINITIONS: list[dict]` at
  module top. The `list_tools` handler is a one-liner
  (`[types.Tool(**t) for t in TOOL_DEFINITIONS]`), tests assert shape
  directly against the dict, and any future tool addition is a dict entry
  plus a handler — zero touching of the async shim.

**Anti-pattern seen in SDK examples:** defining the tool schema inside
the `@server.list_tools()` coroutine body. Couples the schema to the async
runtime for no reason; makes it un-importable by tests.

**Applies to:** every integration that wraps a synchronous backend in an
async transport — MCP, n8n webhook handlers, Twilio TwiML servers, any
RPC-ish protocol. Same three-layer split. The protocol layer is tiny. The
business logic is sync + testable. Do not mix them.


---

## Lessons

### 2026-04-04: HCP API keys rotated but not updated everywhere
- **Category:** integration
- **Lesson:** When API keys are rotated, ALL locations listed in `KEY_ROTATION.md` must be updated simultaneously — a partial rotation breaks sync silently with 401 errors and no alert.
- **Context:** SOLUTIONS_LOG #4. HCP API keys were rotated in Session 11 but not updated in ERPNext's `HCP Integration Settings`. All HCP sync broke silently — `sync_hcp_job` returned `pulled=True` but error logs showed 401 Unauthorized. Fix: update keys in ERPNext settings. Standard #10 created: credential rotation must update ALL locations per KEY_ROTATION.md.
- **Keywords:** API key, rotation, HCP, 401, credential, KEY_ROTATION.md, sync, silent failure

### 2026-04-04: HCP uses UUIDs, not invoice numbers
- **Category:** integration
- **Lesson:** HCP API requires the UUID format (`job_0f701d07...`) for job IDs — using invoice numbers (`40638`) returns 404 on every call.
- **Context:** SOLUTIONS_LOG #2. `pull_job_from_hcp()` passed the invoice number to the HCP API, which only accepts UUIDs. The UUID is available in webhook payloads at `job.id` but was not being stored. Fix: store HCP UUID on the HCP Job doctype and use it for all API calls. Standard #9 created from this.
- **Keywords:** HCP, UUID, invoice number, 404, API, job ID, webhook, payload

### 2026-04-26: Update Bitwarden immediately when keys are touched
- **Category:** integration
- **Lesson:** Any time a credential is used, discovered, rotated, or generated during a session, immediately update the Bitwarden entry — "I'll update BW later" never happens and the next session hits 401.
- **Context:** Standard #24. API secret rotated during magic-link login on 2026-04-26. Three stale Bitwarden entries all had different wrong secrets. Wasted 30+ minutes trying to authenticate because the key only existed in browser localStorage. Fix: update BW entry immediately with current value, add `rotated_on` date and service annotations.
- **Keywords:** Bitwarden, credential, rotation, immediate update, 401, stale key, magic link

### 2026-04-04: Silent sync failure — errors logged but status shows success
- **Category:** integration
- **Lesson:** Integration sync functions must surface errors to the caller — returning `pulled=True` while logging a 401/404 in the error log creates a false sense of success that delays diagnosis.
- **Context:** SOLUTIONS_LOG #2 and #4. Both `sync_hcp_job` issues returned success indicators while the actual API call failed. The error was only visible in Frappe's error log, which nobody checked. Fix: sync functions should return error details to the caller and surface them in the UI or alert system.
- **Keywords:** sync, silent failure, error surfacing, 401, 404, return value, error log, HCP

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

