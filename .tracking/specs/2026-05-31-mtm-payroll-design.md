# Design: mtm_payroll — Phased Payroll Module

**Date:** 2026-05-31
**Authors:** Claude (10Tc) + Grok (10Tg) + Chris (Owner)
**Status:** Design approved — awaiting implementation planning
**Builds on:** mtm-payroll-module-spec.md (phased roadmap), mtm-platform-architecture.md (multi-instance vision)

---

## Purpose

Define a phased, low-risk path to build a payroll capability that starts with the Everding family businesses and scales into a multi-tenant platform module, while maintaining strong liability separation through a dedicated legal entity.

---

## Core Architecture Principles

1. **Liability Isolation First.** Business operations run through a separate legal entity (Everding Payroll Services LLC). The software lives in its own Frappe app (`mtm_payroll`). If the payroll service fails catastrophically, MTM and other entities are firewalled.

2. **Parallel Validation Before Control.** No function (calculation, payments, or filings) goes live until it has run in shadow mode against Gusto with zero material discrepancies for a defined period. The system earns trust through math, not promises.

3. **Replace One Dependency at a Time.** Each phase removes exactly one piece of reliance on Gusto and replaces it with internal capability. Never swap multiple dependencies simultaneously.

4. **Multi-Tenant from the Start.** The app runs on each client's ERPNext instance (per the multi-instance platform architecture). The LLC provides compliance, tax table updates, and insurance centrally. Architecture supports family businesses today and external MTM clients later with config changes, not rewrites.

5. **Human-in-the-Loop Gates.** Maddie (or designated admin) always has final approval on any live payroll run or payment batch. No fully autonomous payroll actions until the system has proven itself over a full tax year.

---

## Legal & Entity Structure

### Everding Payroll Services LLC (New LLC)

- Owns and operates the payroll service
- Carries its own E&O / Professional Liability insurance (required before Phase 3 at latest)
- Licenses the `mtm_payroll` software from MTM under a formal agreement
- Has its own bank account, contracts, and client relationships
- Transferable to Everding Family Trust / business trust once it has meaningful cash flow

### Licensing Relationship

- MTM (Many Talents More entity) owns the `mtm_payroll` codebase
- The LLC signs a software license agreement with MTM to use the app
- Revenue from payroll services flows to the LLC, licensing fees flow to MTM
- Clean separation if the payroll business ever has legal issues

### Data Architecture

- The `mtm_payroll` app installs on each client's ERPNext instance (where employee data already lives)
- Payroll calculations happen locally on the client's instance
- The LLC manages centrally: tax table updates (pushed to all instances), compliance monitoring, insurance, regulatory filings
- No payroll data leaves the client's instance — the LLC provides the engine and compliance layer, not a data warehouse

### Insurance Timeline

| Phase | Insurance Needed |
|-------|-----------------|
| 0-1 | General Liability on the LLC (basic) |
| 2 | Add E&O / Professional Liability (before handling live calculations) |
| 3+ | Increase E&O limits (handling real money) |
| 5 | Commercial coverage scaled to client count |

### Professional Advice Required

This is structural thinking, not legal advice. CPA and attorney must review:
- LLC formation and operating agreement
- Software license agreement between MTM and LLC
- Inter-company service agreements (LLC ↔ AllTec, LLC ↔ Providence)
- Insurance requirements per phase
- Trust transfer mechanics when ready

---

## Technical Architecture

### Frappe App: `mtm_payroll`

Separate repository. Own release cycle. Installable on any ERPNext instance alongside `mtm_property`, `mtm_service`, or standalone.

### Core DocTypes

| DocType | Purpose | Phase |
|---------|---------|-------|
| **Payroll Run** | Record of a completed payroll cycle (date, company, status, source) | 0 |
| **Payroll Run Detail** | Per-employee line items (gross, deductions, taxes, net) | 0 |
| **Payroll Journal Mapping** | Rules for mapping payroll line items to GL accounts | 0 |
| **Entity Allocation Rule** | Rules for splitting payroll across companies/cost centers | 0 |
| **Payroll Comparison Log** | Shadow calculator results: internal vs Gusto, per employee, per line | 1 |
| **Tax Table** | Federal/state withholding brackets, FICA/FUTA/SUTA rates, effective dates | 1 |
| **Tax Table Update Log** | AI agent's record of checking IRS/state publications | 1 |
| **Employee Payroll Profile** | W-4 data, pay rate, deductions, direct deposit info (extends HR Employee) | 2 |
| **Payment Batch** | ACH batch for direct deposit — requires human approval before sending | 3 |
| **Tax Deposit** | Record of tax payment to IRS/state with confirmation | 3 |
| **Tax Filing** | W-2, 1099, 941, state filings — status tracking | 4 |

### Integration Points

| System | Direction | Method | Phase |
|--------|-----------|--------|-------|
| **Gusto** | Pull | API (read payroll runs, employees, tax data) | 0 |
| **ERPNext Accounting** | Push | Journal Entry creation (automated) | 0 |
| **ERPNext HR** | Read | Employee records, timesheets | 0 |
| **IRS.gov** | Pull | AI agent scrapes Pub 15-T, rate publications | 1 |
| **Louisiana Revenue** | Pull | AI agent monitors state withholding updates | 1 |
| **BaaS (Moov/Column/Dwolla)** | Push | ACH direct deposit, tax deposits | 3 |
| **Bank ACH Portal** | Push (alt) | Batch file upload — pluggable alternative to BaaS | 3 |
| **SSA BSO** | Push | Electronic W-2 filing | 4 |
| **IRS EFTPS** | Push | Federal tax deposits | 3 |
| **LaTAP** | Push | Louisiana state tax deposits/filings | 3-4 |

### Payment Interface Abstraction

```
PaymentProvider (abstract interface)
├── MoovProvider (BaaS — Phase 3 primary)
├── DwollaProvider (BaaS — alternative)
├── ColumnProvider (BaaS — alternative)
└── BankACHProvider (direct bank batch files — option B)
```

Each provider implements: `send_payment_batch()`, `check_batch_status()`, `handle_returns()`. The admin UI selects which provider is active. Switching providers is a config change, not a code change.

---

## Phase 0: Gusto Migration + Integration Shell

### Objective
Move family businesses from QB payroll to Gusto. Build the `mtm_payroll` app shell. Automated, entity-aware Journal Entries flow into ERPNext after every payroll run.

### Agent-Executable Tasks

#### Task 0.1: Data Preparation & QB Export
- Export current employee data from QuickBooks (names, SSNs, pay rates, deductions, tax settings)
- Export pay history for current tax year (YTD earnings/withholdings for mid-year migration)
- Map current pay types and deductions to Gusto equivalents
- Document any custom pay rules (shift differentials, per-job rates, etc.)
- **Output:** CSV files + mapping document ready for Gusto import

#### Task 0.2: Gusto Account Setup
- Create Gusto account with two companies (AllTec Plumbing LLC + Providence Real Estate LLC)
- Import employees to correct companies
- Configure weekly pay schedule for both companies
- Set up federal tax settings (EINs, deposit schedule)
- Configure Louisiana state withholding
- Set up 1099 contractor tracking (AllTec subs)
- Import YTD payroll data so withholdings are correct for remainder of year
- Run first test payroll in Gusto preview mode
- **Exit:** Maddie confirms Gusto is ready for live payroll

#### Task 0.3: Build mtm_payroll Frappe App Shell
- Create new Frappe app: `mtm_payroll`
- New GitHub repo: `manyTalents/mtm-payroll`
- Create core DocTypes: Payroll Run, Payroll Run Detail, Payroll Journal Mapping, Entity Allocation Rule
- Set up permissions aligned with existing MTM roles (Chris = all, Maddie = AllTec payroll, Erica = Providence payroll)
- Basic hooks.py with app metadata
- **Output:** Installable Frappe app with empty DocTypes, ready for integration code

#### Task 0.4: Gusto API Integration (Read-Only)
- Register for Gusto API access (partner application)
- Implement OAuth connection to Gusto
- Build scheduled job that polls for completed payroll runs (or webhook handler if Gusto supports it)
- Pull detailed payroll data per run: earnings breakdown, deductions, employer taxes, employee taxes, net pay, check date
- Store in Payroll Run + Payroll Run Detail DocTypes
- **Output:** After every Gusto run, detailed payroll data appears in ERPNext automatically

#### Task 0.5: Automated Journal Entry Generation
- Create Entity Allocation Rules: employee → company mapping (AllTec employees → AllTec books, Providence → Providence)
- Create Payroll Journal Mapping rules: gross wages → Salary Expense account, FICA employer → Payroll Tax Expense, federal withholding → Federal Withholding Payable, etc.
- Build the JE generator: reads Payroll Run Detail, applies mapping + allocation, creates multi-line Journal Entry
- Support Cost Center allocation (by department, job, or employee group)
- Support custom field tagging (Principal vs Income for trust entities)
- Human approval gate: JE created in Draft, Maddie reviews and submits
- **Output:** Clean, entity-aware Journal Entries in ERPNext after every payroll

#### Task 0.6: Validation & Go-Live
- Run 2-3 parallel payroll cycles (Gusto runs payroll, integration creates JEs, compare against manually created JEs)
- Verify: correct amounts, correct accounts, correct companies, correct cost centers
- Fix any discrepancies
- Remove manual JE creation — integration is the sole source
- **Exit criteria:** Payroll JEs appear automatically with correct entity + cost center allocation, zero manual intervention after Gusto run completes

---

## Phase 1: Shadow Calculator (Parallel Validation)

### Objective
Build an internal tax calculation engine. Validate it matches Gusto exactly over 90 days before ever trusting it for live payroll.

### Agent-Executable Tasks

#### Task 1.1: Tax Table Infrastructure
- Create Tax Table DocType with fields: jurisdiction (Federal/State), tax type (Income/FICA/FUTA/SUTA), effective date, brackets (child table with min/max/rate/flat amount)
- Seed federal withholding tables from IRS Publication 15-T (2026 edition)
- Seed FICA rates: Social Security 6.2% (wage base $168,600 for 2026), Medicare 1.45% (no cap), Additional Medicare 0.9% above $200K
- Seed FUTA: 6.0% on first $7,000, effective rate 0.6% after state credit
- Seed Louisiana SUTA: rate varies by employer experience rating (get AllTec's rate from current QB/state records)
- Seed Louisiana state income tax withholding tables
- Create Tax Table Update Log DocType for audit trail
- **Output:** All current tax tables loaded and queryable

#### Task 1.2: AI Tax Table Monitor
- Build an AI agent task that periodically checks:
  - IRS.gov for Publication 15-T updates
  - IRS.gov for FICA/FUTA rate changes
  - Louisiana Workforce Commission for SUTA rate updates
  - Louisiana Department of Revenue for withholding table changes
- On detection of new publication: alert the admin, prepare updated table entries for human review
- Agent does NOT auto-update tables — human reviews and approves every change
- Log every check (found update / no update) in Tax Table Update Log
- **Output:** Tax tables stay current with minimal human effort

#### Task 1.3: Core Calculation Engine
- Implement federal income tax withholding (Percentage Method from Pub 15-T)
  - Handle: filing status, pay frequency, W-4 adjustments (Step 2-4), multiple jobs
  - Handle: supplemental wages (bonuses) — flat 22% or aggregate method
  - Handle: YTD reconciliation for accuracy
- Implement FICA calculation (Social Security + Medicare + Additional Medicare)
  - Track YTD wages against Social Security wage base
- Implement FUTA calculation (employer-only, first $7,000 per employee per year)
- Implement Louisiana state withholding
  - Handle: state-specific exemptions, filing status
- Implement SUTA calculation (employer-only, state-assigned rate, wage base)
- **Output:** Given employee profile + gross pay → returns complete tax breakdown

#### Task 1.4: Shadow Mode Runner
- After every Gusto payroll run is pulled (Task 0.4), automatically:
  1. Take the same gross pay inputs per employee
  2. Run them through the internal calculation engine
  3. Compare every line item: federal withholding, state withholding, SS, Medicare, FUTA, SUTA, net pay
  4. Store both sets of numbers in Payroll Comparison Log
- Comparison is fully automated — no human trigger needed
- **Output:** Side-by-side comparison data for every payroll run

#### Task 1.5: Discrepancy Detection & Dashboard
- Build comparison logic: flag any line item where |internal - gusto| > $0.01
- Create a dashboard/report showing:
  - Per-employee match/mismatch status
  - Per-pay-period summary (total matches, total discrepancies, worst discrepancy)
  - Trend over time (are discrepancies decreasing?)
  - Detail drill-down: exact values from both systems for any flagged item
- Email alert to admin on any discrepancy
- **Output:** At-a-glance view of calculation accuracy

#### Task 1.6: Edge Case Catalog & Regression Tests
- Document and test every known edge case:
  - New hire mid-pay-period (prorated)
  - Termination mid-pay-period
  - Bonus / supplemental pay (flat vs aggregate method)
  - Multiple pay rates in one period
  - Overtime calculations
  - Pre-tax deductions (401k, health insurance) affecting taxable wages
  - Garnishments (child support, tax levy, creditor — different priority rules)
  - Employee hits Social Security wage base mid-year
  - W-4 change mid-period
  - Negative adjustments / corrections
- Build regression test suite that runs all edge cases against the engine
- **Output:** Test suite that validates the engine on every code change

#### Task 1.7: Validation Period
- Run shadow mode for minimum 90 consecutive days (13+ weekly payroll cycles)
- Track: total comparisons, total discrepancies, discrepancy resolution rate
- Any discrepancy must be investigated, root-caused, and fixed
- Only proceed to Phase 2 when: zero unexplained discrepancies for 90 days across ALL employees and ALL pay types
- Document the validation results for insurance/compliance purposes
- **Exit criteria:** 90+ days clean. Engine is trusted.

---

## Phase 2: Admin Interface + Employee Self-Service

### Objective
Maddie runs payroll from MTM instead of Gusto. Employees see their info in the portal. Shadow validation continues.

### Agent-Executable Tasks

#### Task 2.1: Employee Payroll Profile
- Extend ERPNext Employee DocType (or create linked Employee Payroll Profile)
- Fields: W-4 data (filing status, multiple jobs, dependents, extra withholding), pay rate(s), pay frequency, direct deposit info (bank, routing, account — encrypted), deductions (health, 401k, etc.), garnishments
- Import current data from Gusto
- **Output:** All employee payroll data in ERPNext

#### Task 2.2: Payroll Admin Interface
- Build a "Run Payroll" workflow inside ERPNext:
  1. Select company + pay period
  2. System pulls timesheets / hours (or uses salary amounts)
  3. System calculates gross → deductions → taxes → net using internal engine
  4. Displays preview with per-employee breakdown
  5. Maddie reviews, adjusts if needed, approves
  6. System creates Payroll Run + Detail records
  7. Journal Entries generated automatically
- Still runs Gusto in parallel for validation during this phase
- **Output:** Maddie can do everything from MTM that she currently does in Gusto

#### Task 2.3: Employee Self-Service Portal
- Employee login (via MTM portal, email-based auth)
- View: current and historical pay stubs
- View: YTD earnings and tax summaries
- Manage: W-4 elections (changes go to admin for approval)
- View: PTO/leave balances (from ERPNext HR)
- Download: tax documents (W-2 when available)
- **Output:** Employees have self-service access to their payroll info

#### Task 2.4: Advanced Calculations
- Garnishment handling (priority rules: child support > tax levy > creditor)
- Multiple pay rates per employee (regular + overtime + job-specific)
- Time import from ERPNext Timesheets (AllTec techs already tracked via geofencing)
- PTO accrual calculations
- Benefits deduction management (pre-tax vs post-tax)
- **Output:** Engine handles real-world complexity beyond basic salary

#### Exit Criteria
- Maddie prefers running payroll from MTM over Gusto
- Shadow validation still running — zero discrepancies for the entire phase
- Employee self-service tested and functional

---

## Phase 3: Payments & Deposits

### Objective
Own direct deposit and tax deposits. Real money moves through the system. Gusto becomes backup only.

### Agent-Executable Tasks

#### Task 3.1: Payment Provider Integration
- Implement the PaymentProvider abstract interface
- Build MoovProvider (or Column/Dwolla — evaluate based on pricing and API quality at the time)
- Implement: `send_payment_batch()`, `check_batch_status()`, `handle_returns()`
- Build BankACHProvider as fallback (NACHA file generation for direct bank upload)
- Provider selection is per-company configuration
- **Output:** ACH payments can be sent programmatically

#### Task 3.2: Direct Deposit Workflow
- After payroll approval (Task 2.2 workflow), generate Payment Batch
- Payment Batch shows: each employee, bank info (masked), net pay amount
- **Human approval gate:** Maddie reviews the batch, clicks "Approve & Send"
- System sends ACH via the configured provider
- Track: sent, processing, completed, returned/failed
- Handle returns: notification + re-queue or manual resolution
- Pre-notification for new bank accounts (NACHA requirement)
- **Output:** Employees get paid via direct deposit through MTM

#### Task 3.3: Tax Deposit Automation
- Calculate total federal deposits due (income tax withheld + employer + employee FICA)
- Determine deposit schedule (semi-weekly or monthly based on IRS lookback period)
- Generate EFTPS payment record
- **Human approval gate:** Admin reviews and approves each tax deposit
- Submit to EFTPS (initially manual submission with MTM-generated amounts, automate later if EFTPS API access is obtained)
- Louisiana state deposits via LaTAP (same pattern: calculate, approve, submit)
- Track all deposits with confirmation numbers
- **Output:** Tax deposits happen on time with audit trail

#### Task 3.4: Transition from Gusto
- First live payroll: run through MTM, Gusto as backup (don't process in Gusto, but verify you could)
- Monitor for 90 days (13 weekly cycles) with live payments
- After 90 days clean: cancel Gusto subscription
- Keep Gusto data export archived for reference
- **Exit criteria:** Full live payroll paid through MTM for 90 days, Gusto cancelled

---

## Phase 4: Tax Filing & Compliance

### Objective
Own W-2s, 1099s, quarterly and annual filings. Complete one full calendar year.

### Agent-Executable Tasks

#### Task 4.1: W-2 Generation
- Build W-2 data assembly from YTD payroll records (wages, federal/state withholding, SS/Medicare wages and taxes, benefits)
- Generate W-2 PDFs (IRS-compliant format)
- Electronic filing via SSA's Business Services Online (BSO) — W-2 electronic filing is free
- Generate W-3 transmittal summary
- Employee delivery: available in self-service portal + email/mail option
- Deadline handling: W-2s due to employees by January 31, e-file to SSA by January 31
- **Output:** W-2s generated, delivered, and filed without external service

#### Task 4.2: 1099-NEC Generation
- Pull 1099-eligible contractors from ERPNext Supplier records (Tax ID + total payments >= $600)
- Generate 1099-NEC PDFs
- Electronic filing via IRS FIRE system
- Deadline: January 31 to recipients and IRS
- **Output:** 1099s for AllTec's subcontractors generated and filed

#### Task 4.3: Quarterly Filings
- Form 941 (Employer's Quarterly Federal Tax Return): generate from quarterly payroll totals
- Louisiana quarterly withholding return: generate from state withholding totals
- SUTA quarterly report: generate from state unemployment data
- **Human review gate:** Admin reviews generated forms before filing
- Initially: generate the forms, admin files manually. Later: automate electronic filing.
- **Output:** Quarterly compliance on autopilot (with human QC)

#### Task 4.4: Annual Filings & Reconciliation
- Annual Form 940 (FUTA)
- Louisiana annual reconciliation
- Year-end payroll reconciliation: verify YTD totals match quarterly filings match W-2 totals
- Archive full year's payroll data
- **Output:** Clean year-end close

#### Task 4.5: AI Compliance Monitor
- Extend the Tax Table Monitor (Task 1.2) to also watch for:
  - New filing requirements or form changes
  - Deposit schedule changes (based on lookback period)
  - State-specific regulatory updates
- Monthly compliance health check: are all filings on time? Any upcoming deadlines?
- **Output:** Proactive compliance, not reactive scrambling

#### Exit Criteria
- One full calendar year completed: all quarterly filings + annual filings + W-2s + 1099s
- Zero penalties or correction notices
- System is the sole source — no external payroll service

---

## Phase 5: Multi-Tenant Platform Module

### Objective
Offer `mtm_payroll` as a paid add-on to external MTM platform clients.

### Agent-Executable Tasks

#### Task 5.1: Multi-State Tax Support
- Extend Tax Table infrastructure to support all 50 states + DC
- Implement state-specific withholding calculators (each state has different rules)
- Handle multi-state employees (work in one state, live in another — reciprocity agreements)
- **Output:** Any US client can use the module regardless of state

#### Task 5.2: Client Onboarding Flow
- AI-guided setup: "Tell me about your payroll" → configures pay schedules, tax jurisdictions, employee import
- Import from Gusto/QB/ADP (CSV-based, with guided mapping)
- First payroll run with shadow validation against client's existing provider
- **Output:** New client from signup to first payroll in < 1 day

#### Task 5.3: White-Label Configuration
- Per-client branding on pay stubs, tax documents, employee portal
- Client's company name, logo, colors on all employee-facing materials
- **Output:** Employees see their employer's brand, not MTM

#### Task 5.4: Billing Integration
- Payroll add-on subscription: $15-25/mo per client (or per-employee pricing)
- Billing through MTM's Stripe integration
- Usage tracking for AI features (20% markup on API costs)
- **Output:** Revenue flows to Everding Payroll Services LLC

#### Task 5.5: Scale Operations
- Monitoring dashboard: client count, payroll runs this week, error rate, support tickets
- Automated health checks per client instance
- Playbook for common issues (Maddie-level, not engineer-level)
- Contract DevOps for instance management (per the multi-instance platform model)
- **Output:** Operations scale without Chris being the bottleneck

#### Exit Criteria
- 5-10 external paying clients running live payroll through the module
- Zero compliance issues across all clients
- Revenue exceeds LLC operating costs (insurance + infrastructure + support)

---

## Risk Register

| Risk | Phase | Likelihood | Impact | Mitigation |
|------|-------|-----------|--------|------------|
| Tax calculation errors | 1-2 | Medium | High | 90-day shadow validation. Never go live until clean. |
| IRS/state penalties to clients | 3+ | Medium | Very High | E&O insurance. Human approval gates. Clear client contracts with liability limits. |
| ACH returns / failed deposits | 3 | Medium | Medium | Pre-notification. Return handling workflow. Manual fallback. |
| Gusto API changes / deprecation | 0-1 | Low | Medium | Abstract the integration. CSV import as fallback. |
| Employee data breach | All | Low | Very High | Data stays on client's instance (never centralized). Encrypted sensitive fields. SOC 2 practices. |
| Support burden exceeds capacity | 5 | High | High | Self-serve first. Playbooks for common issues. Hire support before it's urgent. |
| Multi-state complexity explosion | 5 | High | Medium | Start with Louisiana only. Add states one at a time based on client demand. |
| LLC gets sued / insurance claim | 3+ | Low | High | LLC firewall isolates from MTM. Adequate E&O coverage. Clear contracts. |
| Scope creep / over-building | All | High | Medium | Strict phase gates. Only advance when exit criteria are met. |

---

## Open Decisions (Need Chris's Input)

1. **LLC formation timing:** Form Everding Payroll Services LLC now (during Phase 0) or wait until Phase 2 when calculations go internal?
2. **Gusto migration timing:** Move from QB payroll to Gusto immediately (June 2026) or wait for QB → ERPNext cutover (Jan 2027)?
3. **E&O insurance quotes:** When to get them? Recommend: get quotes during Phase 1 so coverage is ready for Phase 3.
4. **Attorney for LLC + licensing agreement:** Who handles this? Existing business attorney or new?
5. **BaaS provider evaluation:** Moov vs Column vs Dwolla — evaluate during Phase 2 for Phase 3 deployment?
6. **Phase 1 start trigger:** Begin shadow calculator immediately after Phase 0 is stable, or wait for specific client volume?

---

## Success Metrics (Full Product)

| Metric | Target |
|--------|--------|
| Shadow validation accuracy | Zero discrepancies > $0.01 for 90+ days |
| Payroll processing time | < 15 minutes from "Run Payroll" to approved JEs |
| Direct deposit delivery | Funds in employee accounts by Friday AM for weekly payroll |
| Tax filing compliance | Zero late filings, zero penalties |
| Employee self-service adoption | 80%+ employees using portal for pay stub access |
| Platform client satisfaction | < 2 support tickets per client per month |
| Revenue per client | $15-25/mo payroll add-on + 20% AI API markup |

---

## Decisions Resolved (2026-05-31)

| # | Decision | Answer | When | Rationale |
|---|----------|--------|------|-----------|
| 1 | LLC formation timing | **Form now** | This month (June 2026) | $100-200 in LA, takes a week. Get bank account, licensing agreement, and insurance pipeline started before you need them. |
| 2 | Gusto migration timing | **June/July 2026** | Next few weeks | Payroll cutover is independent from accounting cutover. Gusto handles mid-year YTD import. Don't wait for January. |
| 3 | E&O insurance quotes | **During Phase 1** | ~3 months from now | Coverage needed by Phase 3. Quotes take time. Get them while shadow calculator is running so you can budget before committing to go live. |
| 4 | Attorney | **Existing business attorney** | With LLC formation | Standard LLC + licensing agreement. Only go specialized for Phase 5 SaaS client contracts. |
| 5 | BaaS provider evaluation | **Wait until Phase 2** | ~6-9 months from now | Landscape changes fast. Build the abstract payment interface now, evaluate providers when 60 days from needing one. |
| 6 | Phase 1 start trigger | **Immediately after Phase 0 stable** | ~2 months from now | Shadow calculator costs nothing to run. Start the 90-day validation clock ASAP. |

## Refinements from Review (Grok, 2026-05-31)

### 1. Phase 0 Boundary Split

Phase 0 is split into two sub-phases to reduce risk of doing too much at once:

- **Phase 0A: Gusto Migration** — Move AllTec + Providence from QB payroll to Gusto. Maddie runs payroll from Gusto. Confirm stable for 2-3 cycles before building integration.
- **Phase 0B: Integration Shell** — Build `mtm_payroll` app, Gusto API connection, automated Journal Entries. Only starts after 0A is confirmed stable.

### 2. Tax Table Distribution Model

Tax table updates are pushed from a central compliance service to client instances:

- The LLC maintains a "Tax Table Registry" — a lightweight service (or even a GitHub repo with versioned JSON files) containing current federal + all-state tax tables
- Each client's `mtm_payroll` instance checks the registry on a schedule (daily) or on payroll run
- Updates are pulled, staged for human review, then applied
- AI agent monitors IRS/state publications and updates the registry — not individual instances
- This means one update propagates to all clients automatically after registry approval

### 3. YTD Accuracy for Mid-Year Shadow Start

Task 1.3 (Core Calculation Engine) must handle YTD data when starting shadow mode mid-year:

- On shadow calculator activation, pull YTD wage totals per employee from Gusto API (earnings, SS wages, Medicare wages, federal/state withholding YTD)
- Seed the internal engine with these YTD baselines so Social Security wage base tracking, FUTA caps, and progressive withholding are accurate
- First shadow comparison should verify the YTD seed matches Gusto's records before running forward calculations
- Document any YTD discrepancies as known baseline offsets (not engine errors)
