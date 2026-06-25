# Glass — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Lessons

### 2026-05-18: .vercel/project.json must be at repo root
- **Category:** frontend
- **Lesson:** The `.vercel/project.json` file must live at the repository root, not inside an `app/` subdirectory — Vercel CLI and deployments will fail silently or misconfigure if it is nested.
- **Context:** Vercel deployment was failing because `.vercel/project.json` was placed inside the `app/` subdirectory instead of the repo root. Vercel expects this config at the top level of the repository. Moving it to root resolved the deployment issue.
- **Keywords:** vercel, project.json, deploy, config, repo root, directory structure

### 2026-05-04: Missing env var fallback causes build failure
- **Category:** frontend
- **Lesson:** Every environment variable referenced in API routes must have a fallback or build-time guard — a missing `RESEND_API_KEY` caused the entire Next.js build to fail on Vercel.
- **Context:** An API route imported `RESEND_API_KEY` from `process.env` without a fallback. During Vercel build, the variable was not set in the build environment, causing a TypeScript/runtime error that killed the entire build. Fix: add `?? ""` fallback or conditional initialization so builds succeed even when runtime-only env vars are absent.
- **Keywords:** env var, RESEND_API_KEY, build error, Vercel, Next.js, fallback, process.env

### 2026-04-26: Cloudflare Pages silently serves stale builds on failure
- **Category:** frontend
- **Lesson:** When Cloudflare Pages build fails (e.g., TypeScript error), it silently serves the last successful build with no notification — always check the deploy log when changes do not appear.
- **Context:** SOLUTIONS_LOG #16. A security fix removed fields from a Supabase `.select()` but the template still referenced `expected_return_pct` and `verify_url`. TypeScript caught the mismatch at build time, build exited code 1, and Cloudflare silently served stale code. Every subsequent commit also failed to deploy. Fix: run `npx next build` locally before pushing when modifying select queries.
- **Keywords:** cloudflare pages, stale build, silent failure, TypeScript, build error, deploy log, next build

### 2026-04-26: Grep for field usage before restricting DB queries
- **Category:** frontend
- **Lesson:** Before removing fields from a Supabase/DB `.select()` query (e.g., for security hardening), grep the entire file for usage of those fields — `grep -n 'rec\.' filename` catches mismatches instantly.
- **Context:** SOLUTIONS_LOG #16. Restricting a `.select()` for security removed `expected_return_pct` and `verify_url` from the query, but the template still rendered them. A simple grep would have caught both missing fields before the broken build was pushed.
- **Keywords:** supabase, select, grep, field usage, security, query restriction, TypeScript

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

