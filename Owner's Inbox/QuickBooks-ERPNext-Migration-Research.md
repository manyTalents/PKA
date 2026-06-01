# QuickBooks to ERPNext Migration + Multi-Entity Setup
## Comprehensive Research Deliverable

**From:** DATA (Senior Researcher)
**To:** Owner (Chris)
**Date:** 2026-05-31
**Status:** Complete

---

## Executive Summary

QuickBooks is a redundant expense. AllTec Plumbing already runs Sales Invoices, Payment Entries, and Purchase Invoices on your self-hosted ERPNext instance (erp.manytalentsmore.com). The migration is primarily about (1) moving the remaining QB functions (bank reconciliation, payroll tax reporting, Chart of Accounts authority) into ERPNext, (2) importing opening balances so ERPNext becomes the single accounting authority, and (3) standing up the other family entities on the same instance.

**Bottom line: This saves $1,380-$6,900+/year in QB fees (depending on how many entities and add-ons), eliminates double-entry, and consolidates all family accounting into one system you already own.**

---

## PART 1: QuickBooks Migration Path

### 1.1 What Data Needs to Come from QB

| Data Category | Priority | Notes |
|---|---|---|
| Chart of Accounts | CRITICAL | Foundation -- must be imported first. Map QB accounts to ERPNext account types. |
| Customer List | HIGH | Already partially in ERPNext (1,023 customers). Reconcile, do not duplicate. |
| Vendor/Supplier List | HIGH | Needed for 1099 tracking. Import with Tax IDs. |
| Open (Unpaid) Invoices | HIGH | Only unpaid AR/AP as of cutover date. Already-paid invoices stay in QB archive. |
| Opening Balances | CRITICAL | Balance Sheet snapshot as of cutover date. Single journal entry (or multiple for performance). |
| Bank Account Balances | CRITICAL | Part of opening balances. Must reconcile to bank statements. |
| Fixed Asset Register | MEDIUM | Vehicles, tools, equipment with depreciation schedules. |
| Historical Transactions | LOW | Do NOT migrate years of history. Keep QB as read-only archive. Import only current fiscal year if needed for P&L continuity. |
| Payroll History | LOW | Keep in QB for W-2/tax reference. Start fresh payroll in new system (see Section 1.5). |
| Sales Tax Rates | MEDIUM | Recreate as ERPNext tax templates (see Section 1.7). |

### 1.2 QB Export Formats and ERPNext Compatibility

| Format | What It Contains | ERPNext Compatible? | Notes |
|---|---|---|---|
| **CSV / Excel** | Lists and reports | YES -- primary import method | Export via Reports > Export to Excel. Truncates at 32,770 rows (CSV) or 65,536 rows (XLS). |
| **IIF (Intuit Interchange Format)** | Lists only (NOT transactions) | NO -- must convert to CSV first | Silently drops statement payments, custom fields, price levels. Cannot export invoices/bills/payments. Avoid. |
| **QBX (Accountant's Copy)** | Full company snapshot | NO | Proprietary Intuit format. Only useful for accountant handoff. |
| **QBW / QBB** | Company file / backup | NO | Proprietary. Not importable anywhere except QB. |

**Recommended export method:** Run QB reports and export each as CSV/Excel. The rtcamp migration handbook (most comprehensive QB-to-ERPNext guide available) recommends this approach.

**What to export from QB as CSV:**

1. **Chart of Accounts** -- Lists > Chart of Accounts > Export
2. **Customer List** -- Reports > Customer Contact List > Export
3. **Vendor List** -- Reports > Vendor Contact List > Export
4. **Item/Service List** -- Reports > Item Listing (if applicable)
5. **Open Invoices** -- Reports > Open Invoices > Export
6. **Unpaid Bills** -- Reports > Unpaid Bills Detail > Export
7. **Trial Balance** -- Reports > Trial Balance (as of cutover date)
8. **Balance Sheet** -- Reports > Balance Sheet (as of cutover date)
9. **Bank Statements** -- Download from bank directly (not QB) as CSV or OFX

### 1.3 Step-by-Step Migration Procedure

**Order matters.** ERPNext requires parent records before child records.

| Step | Action | Tool | Timing |
|---|---|---|---|
| 1 | **Clean QB data** -- merge duplicates, delete unused accounts, reconcile all bank accounts through cutover date | QB | Week 1 |
| 2 | **Set cutover date** -- recommend January 1, 2027 (fiscal year boundary) or July 1, 2026 (mid-year, but clean month boundary) | Decision | Week 1 |
| 3 | **Export all data from QB** as CSV (see 1.2 above) | QB | Week 1 |
| 4 | **Import Chart of Accounts** into ERPNext using Chart of Accounts Importer tool. Map QB account types to ERPNext account types (Asset, Liability, Equity, Income, Expense). | ERPNext UI (Setup > Chart of Accounts Importer) | Week 2 |
| 5 | **Import Customers** -- reconcile against existing 1,023 customers. Update existing records, add new ones only. Use Data Import Tool. | ERPNext UI (Customer List > Menu > Import) | Week 2 |
| 6 | **Import Suppliers/Vendors** -- include Tax ID field for 1099 reporting. | ERPNext UI (Supplier List > Menu > Import) | Week 2 |
| 7 | **Import Items/Services** -- if any are not already in ERPNext. Requires Item Group and Default UOM to exist first. | ERPNext UI | Week 2 |
| 8 | **Create Opening Balance Journal Entry** -- Balance Sheet accounts only (not P&L). Type = "Opening Entry". Is Opening = Yes. Posting date = cutover date. Total debits must equal total credits. | ERPNext UI (Accounts > Journal Entry > New) | Week 3 |
| 9 | **Import Open Invoices** -- unpaid AR as Sales Invoices, unpaid AP as Purchase Invoices. Mark "Is Opening" = Yes. | ERPNext Data Import | Week 3 |
| 10 | **Set up Bank Accounts** in ERPNext, connect Plaid or prepare CSV import workflow | ERPNext UI | Week 3 |
| 11 | **Parallel run** -- enter all new transactions in BOTH systems for 30 days minimum | Manual | Weeks 4-7 |
| 12 | **Reconcile** -- compare Balance Sheet, P&L, Trial Balance, open invoices, bank balances between QB and ERPNext | Manual | Week 8 |
| 13 | **Hard cutover** -- stop entering into QB, ERPNext is sole system of record | Decision | Week 8+ |
| 14 | **Archive QB** -- keep accessible for 7 years (tax audit requirement) but stop paying subscription | QB | Post-cutover |

### 1.4 Bank Feed Options Post-Migration

| Option | How It Works | Cost | Complexity | Recommendation |
|---|---|---|---|---|
| **Plaid Integration** (built-in) | ERPNext has native Plaid support. Automatically syncs bank transactions. Configure in Plaid Settings DocType. Requires Plaid API keys (client_id, secret, env) in site_config.json. | Plaid Production: $0 for first 100 items/mo (Development free) | MEDIUM -- requires Plaid account setup, API keys, SSL | RECOMMENDED for ongoing use |
| **CSV Import** | Download CSV from bank website, upload via Bank Statement Import in ERPNext. Map columns: Date, Deposit, Withdrawal, Description, Currency. | Free | LOW | Good fallback / initial setup |
| **OFX Import** | Banks offer OFX/QFX downloads. ERPNext has a GitHub issue requesting native OFX support but it is not built-in as of v15. Third-party apps exist. | Free (if supported) | MEDIUM | Not natively supported -- use CSV instead |

**Plaid setup for self-hosted ERPNext:**
1. Create Plaid account at plaid.com
2. Get API credentials (client_id, secret)
3. Add to site_config.json: `plaid_client_id`, `plaid_secret`, `plaid_env` (sandbox/development/production)
4. Enable in ERPNext: Plaid Settings > Enable
5. Link bank accounts via Bank Reconciliation dashboard
6. Synchronization is incremental based on "Last integration date" in Bank Account doctype

### 1.5 QB Features Requiring ERPNext Equivalents

| QB Feature | ERPNext Equivalent | Status | Gap? |
|---|---|---|---|
| **Invoicing** | Sales Invoice | ALREADY IN USE | No gap |
| **Payments** | Payment Entry | ALREADY IN USE | No gap |
| **Purchase tracking** | Purchase Invoice | ALREADY IN USE (receipt pipeline) | No gap |
| **Chart of Accounts** | Chart of Accounts | EXISTS -- needs QB data imported | No gap |
| **Bank Reconciliation** | Bank Reconciliation Tool + Plaid | EXISTS -- needs setup | No gap |
| **Job Costing** | Project + Cost Center tracking | EXISTS -- needs configuration | No gap -- use Projects for jobs, Cost Centers for departments |
| **Estimates/Quotes** | Quotation doctype | EXISTS | No gap |
| **Sales Tax** | Sales Taxes and Charges Template | EXISTS -- needs LA tax rates configured | No gap |
| **Expense Tracking** | Expense Claim + Purchase Invoice | EXISTS | No gap |
| **P&L / Balance Sheet Reports** | Financial Statements module | EXISTS -- built in | No gap |
| **1099 Reporting** | US Regional Module (IRS 1099-MISC) | EXISTS -- built into ERPNext US localization | No gap |
| **Payroll** | HR Module + Payroll Entry | EXISTS but LIMITED for US | **SIGNIFICANT GAP** (see below) |
| **Direct Deposit** | Not native | NOT BUILT-IN | **GAP** -- needs third-party integration |
| **Automated Tax Table Updates** | Manual configuration required | PARTIAL | **GAP** -- no auto-update of IRS tax tables |

**Payroll is the one genuine gap.** ERPNext's HR module can handle payroll mechanically, but it does NOT ship with pre-loaded IRS tax tables, does not auto-update federal/state withholding rates, and does not handle direct deposit natively. For a small plumbing company:

**Recommended payroll approach:** Keep a standalone payroll service (Gusto at ~$40/mo + $6/employee, or OnPay at similar pricing) and do NOT attempt to run US payroll through ERPNext. This is the industry standard for small businesses on open-source ERPs. The payroll service handles W-2s, tax deposits, direct deposit, and compliance. ERPNext records the payroll journal entries for accounting purposes.

### 1.6 Recommended Cutover Strategy

**Recommended: Clean-cut at fiscal year boundary (January 1, 2027)**

| Strategy | Pros | Cons | Verdict |
|---|---|---|---|
| **Fiscal year boundary (Jan 1)** | Cleanest opening balances, no mid-year P&L split, simplifies tax filing, accountant-friendly | 7-month wait from now | RECOMMENDED |
| **Quarter boundary (Jul 1 or Oct 1)** | Faster than year-end, still a clean break | P&L split across systems for 2026 tax year, more reconciliation work | ACCEPTABLE if urgency is high |
| **Month boundary (Jul 1, 2026)** | Fastest path to eliminating QB cost | Same mid-year issues, less prep time | ACCEPTABLE |
| **Mid-month** | None | Maximum pain, unreconciled transactions | NEVER |

**Parallel run protocol:**
- Run both systems for minimum 30 days before cutover
- Enter every transaction in BOTH systems during parallel period
- At end of parallel period, compare: Balance Sheet, P&L, Trial Balance, Open Invoices, Unpaid Bills, Bank Balances, Sales Tax Liability
- Any discrepancy must be resolved before cutover
- Do NOT cut over during: payroll processing, month-end close, or tax season (Jan-Apr)

**If cost savings are urgent:** Cut over July 1, 2026. Accept the mid-year split. Your accountant will need the QB P&L for Jan-Jun 2026 and the ERPNext P&L for Jul-Dec 2026 at tax time. This is manageable.

### 1.7 Louisiana-Specific Tax and Reporting Requirements

| Requirement | QB Handling | ERPNext Handling | Action Needed |
|---|---|---|---|
| **State Sales Tax (5.00% base)** | Auto-calculated by QB | Sales Taxes and Charges Template -- create template with 5% state rate | Create tax template |
| **Local Parish Sales Tax (0-7%)** | Auto-calculated by zip code | Separate tax template per parish or combined template | Create template for each parish AllTec operates in |
| **Combined Filing (new Jan 2026)** | QB handles automatically | Manual filing via LaTAP portal, but ERPNext tracks the tax collected | No gap -- file via LaTAP, use ERPNext tax reports for amounts |
| **State Income Tax** | QB Payroll handles | Standalone payroll service handles | Covered by payroll service (Gusto/OnPay) |
| **Plumbing services are EXEMPT from LA sales tax** | Configured in QB | Do NOT apply sales tax to service invoices in ERPNext | Verify: plumbing labor is exempt; materials sold separately may be taxable |
| **Annual filing** | QB generates reports | ERPNext P&L and Balance Sheet reports | No gap |
| **1099 reporting** | QB generates 1099s | ERPNext US Regional Module generates 1099-MISC | No gap |

**Louisiana sales tax note:** As of January 1, 2026, Louisiana launched a new Combined State and Local Sales Tax Return system. Businesses file through the Louisiana Taxpayer Access Point (LaTAP). ERPNext will track the tax amounts; filing is done manually on the LaTAP portal regardless of accounting software.

**Critical: Plumbing labor is generally exempt from Louisiana sales tax.** However, materials sold separately ARE taxable. Your ERPNext tax templates must distinguish between service-only invoices (no tax) and materials invoices (taxable). This is configurable via Item Tax Templates in ERPNext.

---

## PART 2: Multi-Entity ERPNext Setup

### 2.1 Company Record Configuration

ERPNext supports unlimited companies on a single instance. Each Company is a separate legal entity with its own Chart of Accounts, fiscal year, and bank accounts.

**Recommended structure: Use a parent-child company hierarchy.**

```
Everding Family Trust (PARENT -- holding entity)
  |-- AllTec Plumbing LLC (CHILD)
  |-- Providence Real Estate LLC (CHILD)
  |-- [TBD] 501(c)(3) Nonprofit (CHILD)
  |-- RE Holding LLC #1 (CHILD)
  |-- RE Holding LLC #2 (CHILD)
  |-- ... additional holding LLCs as needed
```

**Why the Trust as parent:** The Trust is the ultimate economic owner. Making it the parent company means consolidated financial statements roll up naturally. The Chart of Accounts for child companies can inherit from the parent, ensuring consistency while allowing entity-specific extensions.

| Entity | ERPNext Company Type | Chart of Accounts | Special Configuration |
|---|---|---|---|
| **AllTec Plumbing LLC** | Standard (already exists) | Standard US COA -- already configured | Tax ID/EIN in Company record. Sales Tax templates for LA. |
| **Providence Real Estate LLC** | Standard | Inherit from parent + RE-specific accounts (Rental Income, Property Expenses, Maintenance, Insurance, Depreciation) | Property management accounts. Providence_pm app integration when deployed. |
| **Everding Family Trust** | Standard (used as parent/holding) | Simplified: Trust Corpus (assets), Trust Income, Distributions, Trustee Fees | See Section 2.1.1 below |
| **501(c)(3) Nonprofit** | Standard | Nonprofit COA: Revenue = Contributions/Grants/Program Revenue. Expenses by functional category (Program, Management, Fundraising) | See Section 2.1.2 below |
| **RE Holding LLC(s)** | Standard | Inherit from parent + Property asset accounts, Mortgage Liability, Rental Income, Depreciation | One Company per LLC. Asset module for property depreciation. |

#### 2.1.1 Trust Accounting in ERPNext

ERPNext does not have a dedicated "Trust" company type, but a trust's accounting needs map cleanly to standard ERPNext:

**Key Chart of Accounts modifications for the Trust:**

| Account | Type | Purpose |
|---|---|---|
| Trust Corpus - Principal | Asset (Group) | Original trust assets and additions |
| Trust Corpus - Real Property | Asset | Real estate held by trust |
| Trust Corpus - Financial Assets | Asset | Cash, investments, securities |
| Trust Income | Income (Group) | Income earned by trust assets |
| Distributions to Beneficiaries | Expense | Distributions from trust to beneficiaries/entities |
| Trustee Fees | Expense | Administrative costs |
| Trust Liabilities | Liability (Group) | Any trust obligations |

**Trust-specific tracking:** Use a custom field on Journal Entries to tag transactions as "Principal" vs "Income" -- this is the key trust accounting distinction (what the trust owns vs what it earns). Cost Centers can track by beneficiary if distributions vary.

**Tax filing:** Trusts file Form 1041 (US Income Tax Return for Estates and Trusts). ERPNext generates the P&L and Balance Sheet; your CPA uses those to prepare the 1041. No special ERPNext module is needed.

#### 2.1.2 501(c)(3) Nonprofit Accounting in ERPNext

ERPNext does not have a built-in "Nonprofit" mode, but fund accounting maps to existing ERPNext features:

**Fund accounting via Cost Centers:**

| Fund Type | ERPNext Mechanism | How It Works |
|---|---|---|
| **Unrestricted Funds** | Default Cost Center ("General") | All general donations and unrestricted revenue post here |
| **Temporarily Restricted Funds** | Dedicated Cost Center per restriction (e.g., "Building Fund", "Youth Program") | Tag every transaction to its fund. When restriction is met, journal entry releases from restricted to unrestricted. |
| **Permanently Restricted Funds** | Dedicated Cost Center ("Endowment") | Principal never spent; only income is used |

**Chart of Accounts structure for the 501(c)(3):**

| Account | Type | Purpose |
|---|---|---|
| Contributions - Unrestricted | Income | General donations |
| Contributions - Temporarily Restricted | Income | Donor-restricted gifts |
| Contributions - Permanently Restricted | Income | Endowment gifts |
| Grants Revenue | Income | Government/foundation grants |
| Program Revenue | Income | Fees for services |
| Program Expenses | Expense (Group) | Direct mission-related spending |
| Management & General Expenses | Expense (Group) | Admin, office, accounting |
| Fundraising Expenses | Expense (Group) | Costs of raising money |
| Net Assets - Unrestricted | Equity | Accumulated unrestricted surplus |
| Net Assets - With Donor Restrictions | Equity | Restricted fund balances |

**Form 990 reporting:** ERPNext does NOT generate Form 990 automatically. However:
- Form 990-N (e-Postcard): For gross receipts under $50,000. Filed online at IRS.gov. No accounting software needed.
- Form 990-EZ: For gross receipts under $200,000 and assets under $500,000. CPA prepares from ERPNext P&L and Balance Sheet.
- Form 990 (full): For larger organizations. CPA prepares from ERPNext financial statements.

**For a new/small 501(c)(3), Form 990-N or 990-EZ is almost certain.** ERPNext provides all the underlying financial data; the CPA handles the IRS form.

**Donor tracking:** ERPNext's CRM module (Contact + custom fields) can track donors. For serious donor management with acknowledgment letters and campaign tracking, consider a lightweight integration with a free tool like CiviCRM or simply use ERPNext's built-in Address and Contact doctypes with custom fields for "Donor Level" and "Acknowledgment Sent."

### 2.2 Chart of Accounts Strategy

**Recommended: Unified parent COA with entity-specific extensions.**

| Approach | Description | Pros | Cons | Verdict |
|---|---|---|---|---|
| **Unified parent COA** | Define master COA on Trust (parent). Child companies inherit it and add entity-specific accounts. | Consistent structure, easy consolidation, one maintenance point | Less flexibility for very different entity types | RECOMMENDED |
| **Separate COAs per entity** | Each company has its own independent COA | Maximum flexibility | Consolidation nightmare, inconsistent naming, audit risk | NOT RECOMMENDED |
| **ERPNext US Standard template** | Use the built-in US template for each company | Quick setup | May not match QB accounts, miss entity-specific needs | OK as starting point, then customize |

**Implementation:**
1. Create the Trust company first with a comprehensive US COA
2. Create each child company with "Parent Company" = Trust
3. ERPNext automatically copies the parent's COA to each child
4. Add entity-specific accounts to each child (e.g., Rental Income for Providence, Contributions for 501(c)(3))

### 2.3 Inter-Company Transactions

ERPNext has TWO mechanisms for inter-company transactions:

#### Mechanism 1: Inter-Company Invoices (for goods/services between entities)

**Example:** AllTec does plumbing work for a Providence property.

Setup:
1. Create AllTec as an "Internal Supplier" in Providence's supplier list (tick "Is Internal Supplier", set "Represents Company" = AllTec Plumbing LLC)
2. Create Providence as an "Internal Customer" in AllTec's customer list (tick "Is Internal Customer", set "Represents Company" = Providence Real Estate LLC)
3. Create a shared Price List (tick both Selling and Buying)
4. When AllTec creates a Sales Invoice to Providence, ERPNext auto-generates the corresponding Purchase Invoice in Providence's books

**Key rule:** Only ONE internal supplier/customer pair per company pair. Inter-company invoices affect only the accounting ledger (no stock movement).

#### Mechanism 2: Inter-Company Journal Entries (for transfers, distributions, loans)

**Example:** Trust distributes funds to AllTec, or AllTec pays an expense on behalf of Providence.

Setup:
1. Navigate to Journal Entry > New > Type = "Inter Company Journal Entry"
2. Select the originating company
3. Enter debits/credits against inter-company accounts
4. Submit, then click "Make Inter Company Journal Entry" to auto-generate the corresponding entry in the other company's books
5. The second entry has reversed debits/credits

**Recommended inter-company account structure:**

Each company should have:
- `Due from [Other Entity]` (Asset -- Receivable)
- `Due to [Other Entity]` (Liability -- Payable)

These accounts are used for inter-company balances and must be eliminated in consolidated reporting.

#### Common Inter-Company Scenarios

| Scenario | Mechanism | How |
|---|---|---|
| AllTec does plumbing for Providence property | Inter-Company Invoice | AllTec creates Sales Invoice to Providence (internal customer) |
| Trust distributes cash to AllTec | Inter-Company Journal Entry | Trust debits Distributions, credits Cash; AllTec debits Cash, credits Capital Contribution |
| AllTec pays an expense on behalf of 501(c)(3) | Inter-Company Journal Entry | AllTec debits Due From 501(c)(3), credits Cash; 501(c)(3) debits Expense, credits Due To AllTec |
| Providence pays insurance on RE Holding LLC property | Inter-Company Journal Entry | Same pattern as above |
| RE Holding LLC transfers rental income to Trust | Inter-Company Journal Entry | Holding debits Distribution, credits Cash; Trust debits Cash, credits Trust Income |

### 2.4 Consolidated Reporting

ERPNext supports consolidated financial statements out of the box when using parent-child company structures.

**Available consolidated reports:**
- Consolidated Balance Sheet
- Consolidated Profit & Loss (Income Statement)
- Consolidated Cash Flow Statement

**How it works:**
- Navigate to Accounts > Financial Statements
- Select the parent company (Everding Family Trust)
- Check "Consolidated" option
- The report aggregates all child company data
- Inter-company balances should be eliminated (ERPNext handles basic elimination; complex eliminations may need manual journal entries)

**Chris's dashboard:** He can view:
- Individual company financials (select any company)
- Consolidated family financials (select Trust + Consolidated)
- Side-by-side comparison of subsidiaries

### 2.5 User Permissions

ERPNext's permission system supports exactly what you need:

| User | Access Level | Configuration |
|---|---|---|
| **Chris** | ALL companies, ALL data | System Manager role. No company restriction. |
| **Erica** | Providence Real Estate LLC only | User Permission: Company = "Providence Real Estate LLC". Role Profile = "Property Manager" (Accounts User, Stock User, etc.) |
| **Maddie** | AllTec Plumbing LLC -- payroll/HR only | User Permission: Company = "AllTec Plumbing LLC". Role Profile = "Payroll Clerk" (HR User, limited Accounts access) |
| **CPA/Accountant** | Read-only across all entities | Role Profile = "Auditor" (read-only on all accounting doctypes). No company restriction. |
| **Future staff** | Per-entity, per-role | Assign Role Profile + User Permission on Company |

**Setup steps:**
1. Enable "Apply Strict User Permissions" in System Settings (ensures users without explicit company permission see NO company data)
2. Create Role Profiles for each access pattern
3. For each user, add User Permissions restricting them to specific Company records
4. Test by logging in as each user to verify they only see their entity's data

### 2.6 Tax ID / EIN Management

Each ERPNext Company record has a **Tax ID** field. Store the EIN there.

| Entity | EIN | ERPNext Field |
|---|---|---|
| AllTec Plumbing LLC | [existing EIN] | Company > Tax ID |
| Providence Real Estate LLC | [existing EIN] | Company > Tax ID |
| Everding Family Trust | [trust TIN] | Company > Tax ID |
| 501(c)(3) | [will get EIN with IRS determination letter] | Company > Tax ID |
| RE Holding LLC(s) | [EIN per LLC] | Company > Tax ID |

**Limitation:** ERPNext has a single Tax ID field per company. If an entity needs multiple tax identifiers (e.g., state tax ID separate from federal EIN), add a Custom Field (e.g., "State Tax ID") to the Company doctype. This is a 2-minute UI operation in ERPNext's Customize Form tool.

### 2.7 1099 Generation

ERPNext's US Regional Module includes IRS 1099-MISC reporting.

**Setup:**
1. For each Supplier/Vendor who should receive a 1099, set the "Tax ID" field on their Supplier record
2. Mark suppliers as 1099-eligible (custom checkbox or use the built-in field in US localization)
3. At year-end, run the 1099 report from Accounts > 1099 Report
4. The report aggregates all payments to each 1099-eligible supplier for the tax year
5. Generate print-format 1099-MISC forms

**Multi-entity 1099:** If AllTec and Providence both pay the same vendor, they issue SEPARATE 1099s (each entity is a separate payer with its own EIN). ERPNext handles this correctly because each Purchase Invoice belongs to a specific Company.

---

## PART 3: Cost/Risk Analysis

### 3.1 Current QuickBooks Cost Estimate

Based on 2026 pricing research (post-May 1 increases):

| Item | Plan/Tier | Monthly Cost | Annual Cost |
|---|---|---|---|
| **QB Online Plus (AllTec)** | Plus (job costing, 5 users) | $115/mo | $1,380/yr |
| **QB Online (Providence)** | Simple Start or Plus | $38-$115/mo | $456-$1,380/yr |
| **QB Payroll (if bundled)** | Enhanced or Full Service | $50-$130/mo | $600-$1,560/yr |
| **Additional entities (Trust, 501c3, Holdings)** | Each needs its own subscription | $38-$115/mo each | $456-$1,380/yr each |

**Conservative estimate (AllTec only):** $115/mo = **$1,380/year**
**Realistic estimate (AllTec + Providence + payroll):** ~$300-$360/mo = **$3,600-$4,320/year**
**Full family (5 entities + payroll):** ~$500-$575+/mo = **$6,000-$6,900+/year**

**ERPNext cost: $28/mo for the DigitalOcean droplet = $336/year.** You already pay this. Adding companies to the existing instance costs $0 additional.

**Net savings: $1,044 to $6,564+/year**, growing each year as QB prices increase 13-17% annually.

### 3.2 QB Features ERPNext Cannot Replace (and Workarounds)

| QB Feature | ERPNext Gap | Workaround | Risk Level |
|---|---|---|---|
| **US Payroll (tax tables, direct deposit, W-2, state filings)** | ERPNext has no pre-loaded IRS tax tables, no auto-update, no direct deposit | Use standalone payroll service: Gusto ($40/mo + $6/employee) or OnPay (similar). Record payroll journal entries in ERPNext. | LOW -- this is industry standard |
| **Automatic sales tax rate lookup by address** | ERPNext does not auto-detect parish tax rates | Create tax templates for each parish. For AllTec (service company), most plumbing labor is tax-exempt anyway. | LOW |
| **Bank feed auto-categorization (AI)** | ERPNext's bank reconciliation is manual matching | Plaid pulls transactions automatically; matching is semi-manual but functional. ERPNext does suggest matches. | LOW |
| **Form 990 generation** | ERPNext does not generate Form 990 | CPA prepares from ERPNext financial statements. For small 501(c)(3), likely just 990-N e-Postcard (online, 5 minutes). | NONE |
| **Mobile receipt scanning** | ERPNext does not have built-in receipt OCR | Already solved -- you have the receipt pipeline with tiered LLM parser. | NONE (already better) |

**Verdict: No show-stoppers.** Payroll is the only significant gap, and the workaround (standalone payroll service) is what most small businesses on any ERP do. The remaining gaps are minor.

### 3.3 Migration Risks and Rollback Plan

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Opening balance mismatch** | MEDIUM | HIGH -- incorrect financials | Compare Trial Balance QB vs ERPNext on cutover date. Reconcile to the penny before going live. |
| **Missing transactions during parallel run** | MEDIUM | MEDIUM -- data gaps | Assign one person (Maddie?) to enter all transactions in both systems during parallel period. |
| **Customer/Vendor duplicates** | LOW | LOW -- cleanup work | Deduplicate QB export before import. Match against existing 1,023 ERPNext customers by name/phone. |
| **Tax template misconfiguration** | LOW | MEDIUM -- incorrect tax collection | Test with sample invoices. Verify against QB's tax calculations. |
| **Plaid integration issues on self-hosted** | MEDIUM | LOW -- can fall back to CSV | Set up Plaid early. If it fails, CSV import from bank is always available. |
| **CPA unfamiliar with ERPNext reports** | LOW | MEDIUM -- tax filing delays | Export ERPNext reports to Excel/PDF. They look like standard financial statements. |

**Rollback plan:**
1. Keep QB subscription active during parallel run (30-60 days)
2. Do NOT cancel QB until ERPNext has been sole system for at least one full month-end close
3. QB data remains accessible even after cancellation (Intuit retains data for 1 year after cancellation)
4. If ERPNext fails catastrophically, re-enter the delta transactions into QB (painful but possible)
5. Keep QB backup files (.QBB) indefinitely

### 3.4 Timeline Estimate

| Phase | Duration | Key Activities |
|---|---|---|
| **Phase 0: Decision** | 1 day | Owner approves plan, sets cutover date |
| **Phase 1: Data Cleanup** | 1 week | Clean QB data, reconcile all accounts, export CSVs |
| **Phase 2: ERPNext Setup** | 1 week | Import COA, customers, vendors. Create tax templates. Set up bank accounts. Stand up new Company records for family entities. |
| **Phase 3: Opening Balances** | 2-3 days | Create opening balance journal entries. Import open invoices. Verify Trial Balance. |
| **Phase 4: Parallel Run** | 30-60 days | Run both systems. Enter all transactions in both. Compare reports weekly. |
| **Phase 5: Cutover** | 1 day | Final reconciliation. Stop QB entry. ERPNext is authoritative. |
| **Phase 6: Stabilization** | 30 days | First full month on ERPNext only. Resolve any issues. |
| **Phase 7: QB Cancellation** | 1 day | Cancel QB subscription after successful stabilization. |

**Total: 10-14 weeks from decision to QB cancellation.**

If targeting January 1, 2027 cutover: Start Phase 1 in October 2026.
If targeting July 1, 2026 cutover: Start Phase 1 immediately (June 2026).

---

## PART 4: Implementation Checklist for AI Team

This is what the AI team (10T, DATA, future members) needs to execute. Chris makes decisions; the team does the work via ERPNext UI or API scripts.

### Phase 2 Tasks (AI Team Executable)

- [ ] Create Company records for: Everding Family Trust (parent), Providence Real Estate LLC, 501(c)(3), RE Holding LLC(s)
- [ ] Import/map Chart of Accounts from QB CSV to ERPNext (Chart of Accounts Importer)
- [ ] Reconcile existing 1,023 AllTec customers against QB customer list
- [ ] Import Supplier/Vendor list with Tax IDs
- [ ] Create Sales Tax templates for Louisiana (state 5% + applicable parish rates)
- [ ] Create Item Tax Templates (service = exempt, materials = taxable)
- [ ] Set up Plaid integration (API keys in site_config.json)
- [ ] Create inter-company Customer/Supplier records (AllTec <-> Providence, etc.)
- [ ] Create inter-company accounts (Due From/Due To per entity pair)
- [ ] Set up User Permissions (Chris = all, Erica = Providence, Maddie = AllTec payroll)
- [ ] Create Role Profiles (Property Manager, Payroll Clerk, Auditor)
- [ ] Configure opening balance journal entries
- [ ] Create Cost Centers for nonprofit fund tracking (when 501(c)(3) is active)

### Decisions for Chris

- [ ] **Cutover date:** January 1, 2027 (recommended) or July 1, 2026 (faster)?
- [ ] **Payroll service:** Gusto, OnPay, or another? (Recommendation: Gusto for simplicity)
- [ ] **Trust as parent company:** Approve the family hierarchy structure?
- [ ] **Which QB plan are you currently on?** (Need exact plan name to calculate precise savings)
- [ ] **How many entities currently have QB subscriptions?**
- [ ] **Does the 501(c)(3) exist yet, or is it still in formation?**
- [ ] **How many RE Holding LLCs exist or are planned?**

---

## Sources

### QuickBooks Migration
- [rtcamp: QuickBooks to ERPNext Migration (Complete Guide)](https://rtcamp.com/handbook/quickbooks-to-erpnext-migration/)
- [rtcamp: QuickBooks Data Export](https://rtcamp.com/handbook/quickbooks-to-erpnext-migration/quickbooks-data-export/)
- [rtcamp: Importing Master Data to ERPNext](https://rtcamp.com/handbook/quickbooks-to-erpnext-migration/importing-master-data/)
- [rtcamp: Importing Transactions and Opening Balances](https://rtcamp.com/handbook/quickbooks-to-erpnext-migration/importing-transactions/)
- [ClonePartner: QuickBooks Migration Guide 2026](https://clonepartner.com/blog/quickbooks-migration-guide-2026-desktop-sunsets-erp-paths)
- [Infintrix: QuickBooks to ERPNext Migration Step-by-Step](https://infintrixtech.com/blog/quickbooks-to-erpnext-migration)
- [Beancount.io: Switching from QuickBooks Migration Guide](https://beancount.io/blog/2026/04/25/switching-from-quickbooks-migration-guide-small-business)

### QuickBooks Pricing
- [Steph's Books: QuickBooks Online Hikes Prices 15-25%](https://stephsbooks.com/news/quickbooks-online-price-increase-2026)
- [NerdWallet: QuickBooks Pricing 2026](https://www.nerdwallet.com/business/software/learn/quickbooks-pricing)
- [CostBench: QuickBooks Online Pricing $20-$275/mo](https://costbench.com/software/accounting/quickbooks-online/)
- [VisiBooks: QuickBooks Multiple Companies Pricing](https://visibooks.app/quickbooks-multiple-companies-pricing)

### ERPNext Multi-Company and Accounting
- [Frappe Docs: Company Setup](https://docs.frappe.io/erpnext/company-setup)
- [Frappe Docs: Inter-Company Journal Entry](https://docs.frappe.io/erpnext/inter-company-journal-entry)
- [Frappe Docs: Inter-Company Invoices](https://docs.frappe.io/erpnext/user/manual/en/inter-company-invoices)
- [Frappe Docs: Plaid Integration](https://docs.frappe.io/erpnext/plaid_integration)
- [Frappe Docs: Bank Reconciliation](https://docs.frappe.io/erpnext/bank-reconciliation)
- [Frappe Docs: Opening Balance](https://docs.frappe.io/erpnext/opening-balance)
- [Frappe Docs: Sales Taxes and Charges Template](https://docs.frappe.io/erpnext/sales-taxes-and-charges-template)
- [Frappe Docs: User Permissions](https://docs.erpnext.com/docs/user/manual/en/role-based-permissions)
- [Frappe Docs: Cost Center](https://docs.erpnext.com/docs/user/manual/en/cost-center)
- [Frappe Docs: Asset Depreciation](https://docs.frappe.io/erpnext/asset-depreciation)
- [TridotsTech: How ERPNext Handles Multi-Company Accounting](https://www.tridotstech.com/blog/erpnext-implementation/how-erpnext-handles-multi-company-accounting)
- [GreyCube: Managing Multi-Companies with ERPNext](https://greycube.in/blog/general/streamlining-business-operations-managing-multi-companies-with-erpnext)
- [Nexeves: Ultimate Guide to Chart of Accounts in ERPNext](https://nexeves.com/blog/ERPNext/the-ultimate-guide-to-the-chart-of-accounts-coa-in-erpnext)

### ERPNext US Localization and 1099
- [Frappe: ERPNext for United States](https://frappe.io/erpnext/usa)
- [Solufy: US Localization with ERPNext](https://www.solufyerp.com/erp-blog/us-localization-erpnext-guide/)
- [GitHub: US Regional Module with IRS 1099 reporting (PR #16421)](https://github.com/frappe/erpnext/pull/16421/files)
- [AppCloneScript: ERPNext Payroll Setup for US Businesses](https://www.appclonescript.com/erpnext-payroll-setup-us-businesses-tax-compliance/)

### ERPNext Real Estate and Property Management
- [Sigzen: ERPNext for Real Estate Management](https://www.sigzen.com/blog/streamline-real-estate-management-with-erpnext/)
- [Frappe Cloud Marketplace: Property Management App](https://cloud.frappe.io/marketplace/apps/property_management)
- [ClefinCode: Blueprint for Real Estate ERP Solution](https://clefincode.com/blog/global-digital-vibes/en/blueprint-for-a-real-estate-erp-solution-using-erpnext)

### Nonprofit and Trust Accounting
- [National Council of Nonprofits: Federal Filing Requirements](https://www.councilofnonprofits.org/running-nonprofit/administration-and-financial-management/federal-filing-requirements-nonprofits)
- [IRS: Form 990 Instructions (2025)](https://www.irs.gov/instructions/i990)
- [501c3.org: How to File Form 990](https://www.501c3.org/how-to-file-a-form-990/)
- [BT CPA: Trust Accounting Essentials](https://www.btcpa.net/insights/trusts-accounting-essential-practices-for-managing-and-reporting-on-trusts-and-estates)

### Louisiana Tax
- [Louisiana Department of Revenue: General Sales & Use Tax](https://revenue.louisiana.gov/businesses/sales-taxes/general-sales-use-tax/)
- [Louisiana Uniform Local Sales Tax Board: Parish E-File](https://lulstb.com/resources/online-sales-tax-filing-information/)
- [Gusto: Louisiana Small Business Taxes 2025](https://gusto.com/resources/articles/taxes/louisiana-small-business-taxes)
- [Sales Tax Institute: Louisiana Combined Filing System](https://www.salestaxinstitute.com/resources/louisiana-combined-state-local-sales-tax-filing-system)

### QuickBooks Desktop End of Life
- [Certum Solutions: QuickBooks Desktop 2023 Ending May 31, 2026](https://www.certumsolutions.com/library/quickbooks-desktop-2023-service-ending-may-2026)
- [SunsetProof: QuickBooks Desktop End of Life Migration Guide](https://sunsetproof.com/quickbooks-desktop/)
