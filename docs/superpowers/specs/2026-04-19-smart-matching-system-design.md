# Smart Matching System — Design Spec

## Goal

A learning receipt-to-pricebook matching system that gets smarter with every correction. Auto-matches supplier items to AllTec's 975-item pricebook, handles unit conversions (box→each), applies markup, and provides a confidence-based UX that guides users to items needing attention.

## Architecture

```
Receipt scanned (phone/scanner/email)
       ↓
OCR parses items (existing pipeline)
       ↓
Auto-Matcher runs 3 layers:
  1. Exact supplier code lookup (instant, full confidence)
  2. Classification match (type + material + size within class)
  3. Unmatched → flagged for human review
       ↓
Items shown with confidence colors:
  White    → unmatched, needs attention
  Sky blue → first match, needs confirmation
  Cobalt   → 5+ consistent matches, locked in
       ↓
Human corrects/confirms → system learns
  - Supplier code → pricebook item mapping saved
  - Unit conversion factor saved
  - Confidence count increments
```

## Confidence Visual System

Three tiers (per Pixel's recommendation — 4 tiers are indistinguishable on phone screens in bright light):

| Tier | Color | Condition | UX |
|------|-------|-----------|-----|
| Unmatched | White `#FFFFFF` | No match found | Full card, search field, demands attention |
| First match | Sky blue `#E3F2FD` with subtle border | 1-4 confirmed matches | Full card, confirm/correct buttons |
| Locked in | Dark cobalt `#1565C0` | 5+ consistent matches | Collapsed single-line row (name + qty + price) |

High-confidence items collapse to single-line rows. Unmatched items are full cards with action buttons. Visual hierarchy = the eye goes to what needs work.

## Auto-Matcher Layers

### Layer 1: Exact Supplier Code Lookup
- Check `Item Supplier` child table: does this supplier + part number already map to an Item?
- If yes: instant match, increment `match_count` on the mapping
- This is the "learned" layer — every human correction feeds this

### Layer 2: Classification Match
Structured attribute parser extracts from supplier description:
- **Type**: elbow, tee, coupling, nipple, valve (subtype: T&P, gas, ball, angle stop), pipe, tubing, wire, breaker, etc.
- **Material**: copper, PVC, PEX (crimp/expansion/SharkBite), black iron, galvanized, brass, EMT, etc.
- **Size**: primary diameter, secondary dimension (length for nipples, second diameter for reducers/bushings)
- **Variant**: street vs regular, swage vs standard

Match within the same (type, material, size) class against the 975 pricebook items. Score based on attribute match completeness.

Trade-specific synonym table:
```
CU = copper, BRS = brass, GI/GALV = galvanized, BLK = black
STR = street, FIP = female iron pipe, MIP = male iron pipe
EMT = electrical metallic tubing, MC = metal clad
LF = lead free, NOM = nominal
```

### Layer 3: Unmatched
Items that don't match in Layer 1 or 2 → flagged for human review. Shown in white on the receipt.

## Unit Conversion & Pricing

### Auto-Unit Conversion
When a receipt item's unit (BOX, PACK, ROLL, 100FT) differs from the pricebook unit (EACH, FT):
- Check `Unit Conversion` table: has this supplier + item been converted before?
- If yes: auto-convert (1 BOX = 50 EACH → $25.00/box = $0.50/ea)
- If no: flag with amber warning badge, ask user to enter conversion factor
- Conversion factor saved for future auto-conversion

### Auto-Markup
- Markup percentage stored in `AllTec Company Settings` (e.g., 35%)
- Per-item override possible
- When cost price comes from receipt: `customer_price = cost × (1 + markup%)`
- When cost price updates from new receipt: customer price auto-recalculates
- Office can see both cost and customer price; tech sees only customer price

## Backend Changes

### Modified DocTypes

**Item Supplier (child table on Item)**
- Add custom field: `match_count` (Int, default 0) — incremented each time this mapping is confirmed
- Add custom field: `unit_conversion` (Float) — e.g., 50 means 1 supplier unit = 50 pricebook units
- Add custom field: `supplier_unit` (Data) — e.g., "BOX", "PACK", "ROLL"

**HCP Receipt Parsed Item**
- Add field: `match_count` (Int, read_only) — populated from Item Supplier on match
- Add field: `confidence_tier` (Select: unmatched/first_match/locked_in, read_only) — computed from match_count

### New DocType: `HCP Pricebook Request`

For techs adding parts not in the pricebook.

| Field | Type | Description |
|-------|------|-------------|
| part_name | Data | Plain language name ("3/4 brass ball valve") |
| trade | Select | Plumbing / Electrical / HVAC / General |
| size | Data | Optional ("3/4", "1/2 x 6") |
| supplier_code | Data | From the receipt scan if available |
| supplier | Data | Which supplier |
| submitted_by | Link (Employee) | Tech who submitted |
| receipt_item | Link (HCP Receipt Parsed Item) | Original parsed item |
| status | Select | Pending / Approved / Rejected |
| approved_item | Link (Item) | Set when Zack approves |
| rejection_reason | Small Text | Why rejected |

Workflow: Tech creates → Zack reviews → Approve (creates Item + supplier mapping) or Reject (with reason, tech notified)

### Modified API

**sku_matcher.py — `save_supplier_match()`**
- Increment `match_count` on existing mapping (not just create/overwrite)
- Save `unit_conversion` and `supplier_unit` if provided

**match_review.py — `bulk_approve()`**
- Call `save_supplier_match` for each approved item (currently doesn't learn)
- Increment `match_count`

**match_review.py — `correct_match()`**
- Accept optional `unit_conversion` and `supplier_unit` params
- Pass to `save_supplier_match`

**New: match_review.py — `submit_new_part()`**
- Creates `HCP Pricebook Request` doc
- Returns the request name

**New: match_review.py — `review_new_parts()`**
- List pending pricebook requests for Zack

**New: match_review.py — `approve_new_part()`**
- Creates Item in ERPNext from the request
- Saves supplier code mapping
- Updates original receipt parsed item with the new match

**New: match_review.py — `reject_new_part()`**
- Sets status to Rejected with reason

### Remove Technical Debt
- Remove all `ignore_permissions=True` — create "Receipt Reviewer" role
- Remove all manual `frappe.db.commit()` from whitelisted methods
- Fix `bulk_approve` to actually save supplier mappings

## Frontend — Mobile (Tech's View)

### Receipt Item Cards
- **White card (unmatched)**: Full card with search button, "ADD NEW PART" button (amber)
- **Sky blue card (first match)**: Full card showing matched item, CONFIRM and CORRECT buttons
- **Dark cobalt row (locked in)**: Single-line collapsed row — item name, qty, price. Tap to expand.

### Search (shared modal per Glass's recommendation)
- Tap "Match" on an item → bottom sheet slides up
- Search input with 975-item pricebook (cached locally in AsyncStorage, under 100KB)
- Results show: item name, item group, price
- Tap result → match saved, supplier code learned
- Works offline from cache

### Add New Part (amber button per Pixel's recommendation)
- Opens half-sheet modal
- 4 fields: Name, Trade (dropdown), Size (optional), Stock item? (toggle)
- "This will be sent to Zack for review"
- Submitted via `submit_new_part` API
- Item stays on receipt as "Pending Approval" state

### "Dispatch matched, hold unmatched" button (Stocky's recommendation)
- One tap: all locked-in + confirmed items dispatch to destination
- Unmatched items stay in limbo
- Tech doesn't have to touch items the system already knows

### Unit conversion prompt
- When receipt unit ≠ pricebook unit, amber badge appears
- Tech taps → enters conversion: "1 BOX = ___ EACH"
- Saved for future auto-conversion

## Frontend — Web (Zack's View)

### MATCHES Tab (enhanced)
Two-panel layout on desktop:
- **Left panel**: Receipt list with badge counts (3 unmatched, 2 first match)
- **Right panel**: Selected receipt's items

Keyboard shortcuts:
- J/K: move through items
- Enter: approve match
- S: skip
- N: mark "not an item"
- Tab: jump to search field

### Pricebook Requests Queue
- New sub-section in MATCHES tab or separate tab
- Shows all pending `HCP Pricebook Request` entries
- Zack can: Approve (creates item), Reject (with reason), Discard
- Bulk approve for obvious items

### Unit Conversion Manager
- Shows all items with unit mismatches
- Zack enters conversion factors
- Saved to Item Supplier for future auto-conversion

## What's NOT in This Spec
- AI/LLM-powered matching (Claude API calls from backend)
- PLY inventory system integration
- Supplier-specific API ordering
- Price history tracking / price alert system
- Per-item markup overrides (uses global markup for v1)
