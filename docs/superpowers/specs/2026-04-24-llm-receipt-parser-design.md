# LLM Receipt Parser — Design Spec

**Date:** 2026-04-24
**Status:** Approved
**Owner:** Forge (backend), Swift (mobile)

## Problem

The current receipt parser uses regex-based, supplier-specific parsers to extract line items from OCR text. This causes:

- Prices read as item descriptions (and vice versa)
- Wrong price paired with wrong item (~10-15% error rate on Coburn's)
- Quantities misattributed across lines
- Every new supplier format needs a custom regex parser

Techs spend time manually correcting matches that should have been right from the start.

## Solution

Replace the regex parser with Claude API as a **knowledge-base builder**. The LLM parses OCR text into structured line items accurately, and every successful parse permanently teaches the system a supplier-code-to-pricebook-item mapping. After a month, learned mappings handle 90%+ of receipts and the LLM only fires for genuinely new items.

## Architecture

### Flow (after change)

```
Receipt photo
  |
  v
OCR Engine (Tesseract / Google Vision) -- unchanged
  |
  v
Raw OCR text stored on HCP Receipt
  |
  v
Supplier Code Lookup (existing Item Supplier table)
  |
  +--> ALL items matched? --> YES --> done (free, no LLM call)
  |
  +--> NO (unmatched items exist)
         |
         v
       Claude API parses FULL OCR text --> structured JSON
         |
         v
       Match each parsed item to pbmat_ pricebook (976 items)
         |
         v
       Save supplier-code --> pricebook-item mapping (learns permanently)
         |
         v
       Items appear on receipt detail for tech review/dispatch
```

### Key Principle: LLM as Training Tool

- **Month 1:** Sonnet processes every receipt with unmatched items. Accuracy priority. ~$0.50-1.00/day at 5 receipts/day.
- **Month 2+:** Learned mappings handle most items. LLM fires only for unknown supplier codes. Cost drops toward zero.
- **New suppliers:** LLM fires on first few receipts, learns codes, then stops.
- **Fallback:** If LLM call fails (network, quota), fall back to existing regex parser. Never block receipt intake.

## LLM Integration Point

### Location

New module: `hcp_replacement/hcp_replacement/core/llm_parser.py`

Called from `ocr_engine.py` AFTER OCR completes, BEFORE the existing `receipt_parser.py` regex parsing.

### Decision Logic (in ocr_engine.py)

```python
# After OCR text is stored:
# 1. Try supplier code lookup on extracted product codes
# 2. If all items matched via existing mappings -> skip LLM (free)
# 3. If unmatched items remain -> call llm_parser.parse_receipt()
# 4. If LLM fails -> fall back to regex parser (existing behavior)
```

### LLM Prompt Design

Send the full OCR text to Claude with a structured prompt:

**System prompt:**
```
You are a receipt parser for a plumbing/electrical/HVAC company.
Extract structured line items from receipt OCR text.
Return valid JSON only, no commentary.
```

**User prompt:**
```
Parse this receipt OCR text into structured data.

OCR TEXT:
{ocr_raw_text}

Return JSON in this exact format:
{
  "supplier": "string",
  "receipt_number": "string or null",
  "receipt_date": "YYYY-MM-DD or null",
  "job_number": "string or null",
  "line_items": [
    {
      "description": "cleaned item description",
      "product_code": "supplier SKU/part number or null",
      "quantity": number,
      "unit_price": number,
      "extended_price": number,
      "uom": "EA|FT|BOX|ROLL|etc"
    }
  ],
  "subtotal": number or null,
  "tax": number or null,
  "total": number or null
}

Rules:
- description should be a clean, readable item name
- product_code is the supplier's SKU, part number, or catalog code
- If a field is unreadable or missing, use null
- Do not invent data that isn't in the text
- Prices are in USD
```

### Model Selection

```python
# In HCP Replacement Settings (Frappe doctype):
# - llm_model: "claude-sonnet-4-20250514" (default Month 1)
#              "claude-haiku-4-5-20251001" (switch after Month 1)
# - llm_enabled: checkbox (default ON)
# - llm_match_threshold: int (default 80) -- min existing mapping coverage % to skip LLM
```

Configurable in ERPNext settings so Chris can flip from Sonnet to Haiku (or disable entirely) without a code deploy.

### API Key Storage

Anthropic API key stored in `HCP Replacement Settings` doctype as a Password field (`llm_api_key`). Never logged, never exposed via REST API.

## Mapping Learning

When the LLM successfully parses a line item:

1. Match parsed `description` against the 976 `pbmat_` pricebook items using `sku_matcher.py`
2. If match found (score >= threshold):
   - Call `save_supplier_match(supplier, product_code, matched_item, unit_conversion)`
   - This creates/updates an `Item Supplier` row linking the supplier code to the pricebook item
   - Increments `match_count` on the mapping
3. If `match_count >= 5`: mapping is "locked in" — future receipts with this supplier code skip LLM entirely
4. If no match found: item goes to tech review as "Unmatched" with MATCH + NEW PART buttons

### Coverage Check (Skip LLM Decision)

Before calling the LLM, check how many product codes from the OCR text already have locked-in mappings:

```python
def should_use_llm(receipt):
    """Return True if LLM parsing is needed."""
    if not settings.llm_enabled:
        return False

    # Extract product codes from OCR text (lightweight regex, not full parse)
    codes = extract_product_codes(receipt.ocr_raw_text)
    if not codes:
        return True  # Can't extract codes, need LLM

    # Check how many have existing mappings
    matched = count_existing_mappings(codes, receipt.supplier)
    coverage = matched / len(codes) if codes else 0

    # If coverage >= threshold (default 80%), skip LLM
    return coverage < (settings.llm_match_threshold / 100)
```

## Search Alignment

### Fix: match_review.search_pricebook

The `PricebookSearchModal` (receipt matching UI) calls `match_review.search_pricebook`. This endpoint must also filter to `pbmat_%` items only, matching today's fix to `tech_utils.search_pricebook`.

Both searches return the same 976 HCP pricebook items with simple, tech-friendly names.

## Existing UI — No Changes Needed

The mobile app receipt flow already handles everything:

- **ScannerScreen** — snap photo, enter job #
- **QueueScreen** — upload/OCR progress
- **ReceiptDetailScreen** — review parsed items, dispatch
- **DispatchItemCard** — confidence tiers (locked/first-match/unmatched)
- **PricebookSearchModal** — manual MATCH button (searches 976 pbmat_ items)
- **AddNewPartModal** — NEW PART button for unknown items
- **Destination picker** — This Job / Truck / Office / Limbo / etc.
- **Bulk dispatch** — "DISPATCH ALL TO THIS JOB" / "DISPATCH MATCHED"
- **LimboSection** on job detail — undispatched items
- **LimboTab** on inventory — global limbo view

No mobile code changes needed beyond the `match_review.search_pricebook` alignment.

## Implementation Scope

### New Files
1. `core/llm_parser.py` — Claude API integration, prompt construction, response parsing, error handling

### Modified Files
2. `core/ocr_engine.py` — Add LLM decision logic after OCR, before regex parser
3. `core/sku_matcher.py` — Wire in `item_classifier.py` as Layer 2 (between supplier code lookup and fuzzy match)
4. `api/match_review.py` — Add `pbmat_%` filter to `search_pricebook`
5. `HCP Replacement Settings` doctype — Add fields: `llm_enabled`, `llm_model`, `llm_api_key`, `llm_match_threshold`

### Not Changed
- Mobile app (existing UI is sufficient)
- `receipt_parser.py` (kept as fallback)
- `receipt_dedup.py` (unchanged)
- `price_monitor.py` (unchanged)

## Rollout Plan

1. **Deploy code** with `llm_enabled = False` (safe, no behavior change)
2. **Set API key** in HCP Replacement Settings
3. **Enable with Sonnet** — flip `llm_enabled = True`, model = `claude-sonnet-4-20250514`
4. **Monitor for 1 month** — watch match_count growth, check accuracy
5. **Switch to Haiku** — change model to `claude-haiku-4-5-20251001`
6. **Raise threshold** — increase `llm_match_threshold` to 90% or 95% as mappings mature
7. **Eventually** — most receipts skip LLM entirely, near-zero ongoing cost

## Success Criteria

- Receipt parsing error rate drops from ~15% to <5% in month 1
- After month 1, 90%+ of line items matched via learned mappings (no LLM call)
- Techs spend less time on manual matching in receipt review
- No increase in receipt processing time (LLM adds <3s per receipt)
- Regex parser still works as fallback if LLM is disabled/fails

## Cost Estimate

| Period | Model | Receipts/day | Est. cost/day | Monthly |
|--------|-------|-------------|---------------|---------|
| Month 1 | Sonnet | 5 avg | $0.50-1.00 | ~$15-30 |
| Month 2-3 | Haiku | 1-2 (unknowns only) | $0.02-0.05 | ~$1-2 |
| Month 4+ | Haiku | <1 (new items only) | ~$0 | ~$0 |
