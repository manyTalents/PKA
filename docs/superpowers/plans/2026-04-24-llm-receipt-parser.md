# LLM Receipt Parser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the regex receipt parser with Claude API to accurately extract line items from OCR text, permanently learning supplier-code-to-pricebook mappings so the LLM becomes unnecessary over time.

**Architecture:** After OCR runs, check how many product codes already have learned mappings. If coverage is below the configured threshold, send OCR text to Claude for structured parsing. Every successful parse saves the mapping permanently. Regex parser stays as free fallback.

**Tech Stack:** Anthropic Python SDK, Frappe/ERPNext, existing OCR engine (Tesseract/Google Vision)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `core/llm_parser.py` | Create | Claude API call, prompt, JSON response parsing |
| `core/ocr_engine.py` | Modify | Insert LLM decision logic in `_parse_and_finalize()` |
| `core/sku_matcher.py` | Modify | Filter fuzzy search to `pbmat_%` items, wire in `item_classifier` as Layer 2 |
| `api/match_review.py` | Modify | Add `pbmat_%` filter to `search_pricebook()` |
| `doctype/hcp_replacement_settings/hcp_replacement_settings.json` | Modify | Add LLM settings fields |
| `tests/test_llm_parser.py` | Create | Unit tests for LLM parser |
| `tests/test_sku_matcher_pbmat.py` | Create | Tests for pbmat filter + classifier integration |

All paths relative to: `C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement/hcp_replacement/hcp_replacement/`

---

### Task 1: Add LLM Settings Fields to HCP Replacement Settings

**Files:**
- Modify: `doctype/hcp_replacement_settings/hcp_replacement_settings.json`

- [ ] **Step 1: Read the current settings JSON**

Open `doctype/hcp_replacement_settings/hcp_replacement_settings.json` and locate the `fields` array. The new LLM section goes after the `dedup_section`.

- [ ] **Step 2: Add LLM fields to the JSON**

Append these field definitions to the `fields` array, after the last existing field:

```json
{
    "fieldname": "llm_section",
    "fieldtype": "Section Break",
    "label": "LLM Receipt Parser"
},
{
    "fieldname": "llm_enabled",
    "fieldtype": "Check",
    "label": "Enable LLM Parsing",
    "default": "0",
    "description": "Use Claude API to parse receipts when existing mappings are insufficient"
},
{
    "fieldname": "llm_model",
    "fieldtype": "Select",
    "label": "LLM Model",
    "options": "claude-sonnet-4-20250514\nclaude-haiku-4-5-20251001",
    "default": "claude-sonnet-4-20250514",
    "depends_on": "eval:doc.llm_enabled"
},
{
    "fieldname": "col_break_llm",
    "fieldtype": "Column Break"
},
{
    "fieldname": "llm_api_key",
    "fieldtype": "Password",
    "label": "Anthropic API Key",
    "depends_on": "eval:doc.llm_enabled"
},
{
    "fieldname": "llm_match_threshold",
    "fieldtype": "Percent",
    "label": "Skip LLM When Mapping Coverage Above (%)",
    "default": "80",
    "description": "If this % of product codes already have learned mappings, skip the LLM call (free)",
    "depends_on": "eval:doc.llm_enabled"
}
```

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add hcp_replacement/hcp_replacement/doctype/hcp_replacement_settings/hcp_replacement_settings.json
git commit -m "feat: add LLM receipt parser settings fields"
```

---

### Task 2: Create llm_parser.py — Claude API Integration

**Files:**
- Create: `core/llm_parser.py`
- Create: `tests/test_llm_parser.py`

- [ ] **Step 1: Write the test file**

Create `tests/test_llm_parser.py`:

```python
"""Tests for LLM receipt parser — prompt construction and response parsing."""

import json
import unittest
from unittest.mock import patch, MagicMock


class TestBuildPrompt(unittest.TestCase):
    """Test that the prompt is constructed correctly from OCR text."""

    def test_prompt_contains_ocr_text(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _build_messages

        ocr_text = "COBURN'S\nINVOICE 12345\n3/4 copper 90 elbow  2  $4.37  $8.74"
        messages = _build_messages(ocr_text)

        # System message exists
        self.assertEqual(messages[0]["role"], "system")
        self.assertIn("receipt parser", messages[0]["content"].lower())

        # User message contains OCR text
        self.assertEqual(messages[1]["role"], "user")
        self.assertIn("COBURN'S", messages[1]["content"])
        self.assertIn("INVOICE 12345", messages[1]["content"])

    def test_prompt_requests_json_format(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _build_messages

        messages = _build_messages("some text")
        user_content = messages[1]["content"]
        self.assertIn("line_items", user_content)
        self.assertIn("product_code", user_content)
        self.assertIn("unit_price", user_content)


class TestParseResponse(unittest.TestCase):
    """Test that Claude's JSON response is parsed into the expected dict."""

    def test_valid_json_response(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _parse_llm_response

        raw = json.dumps({
            "supplier": "Coburn's",
            "receipt_number": "INV-12345",
            "receipt_date": "2026-04-20",
            "job_number": "J-100",
            "line_items": [
                {
                    "description": "3/4 copper 90 elbow",
                    "product_code": "45005808",
                    "quantity": 2,
                    "unit_price": 4.37,
                    "extended_price": 8.74,
                    "uom": "EA",
                }
            ],
            "subtotal": 8.74,
            "tax": 0.78,
            "total": 9.52,
        })
        result = _parse_llm_response(raw)
        self.assertEqual(result["supplier"], "Coburn's")
        self.assertEqual(len(result["line_items"]), 1)
        self.assertEqual(result["line_items"][0]["product_code"], "45005808")
        self.assertEqual(result["line_items"][0]["quantity"], 2)

    def test_json_wrapped_in_markdown_code_block(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _parse_llm_response

        raw = '```json\n{"supplier":"Test","line_items":[],"subtotal":0,"tax":0,"total":0}\n```'
        result = _parse_llm_response(raw)
        self.assertEqual(result["supplier"], "Test")

    def test_invalid_json_returns_none(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _parse_llm_response

        result = _parse_llm_response("this is not json at all")
        self.assertIsNone(result)

    def test_missing_line_items_returns_none(self):
        from hcp_replacement.hcp_replacement.core.llm_parser import _parse_llm_response

        raw = json.dumps({"supplier": "Test"})
        result = _parse_llm_response(raw)
        self.assertIsNone(result)


class TestShouldUseLlm(unittest.TestCase):
    """Test the decision logic for when to call the LLM."""

    @patch("hcp_replacement.hcp_replacement.core.llm_parser.frappe")
    def test_disabled_returns_false(self, mock_frappe):
        from hcp_replacement.hcp_replacement.core.llm_parser import should_use_llm

        settings = MagicMock()
        settings.llm_enabled = False
        result = should_use_llm("some ocr text", "Coburn's", settings)
        self.assertFalse(result)

    @patch("hcp_replacement.hcp_replacement.core.llm_parser.frappe")
    def test_enabled_no_codes_returns_true(self, mock_frappe):
        from hcp_replacement.hcp_replacement.core.llm_parser import should_use_llm

        settings = MagicMock()
        settings.llm_enabled = True
        settings.llm_match_threshold = 80
        # OCR text with no recognizable product codes
        result = should_use_llm("just some random text", "Coburn's", settings)
        self.assertTrue(result)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
python -m pytest hcp_replacement/hcp_replacement/tests/test_llm_parser.py -v 2>&1 | head -30
```

Expected: FAIL — `ModuleNotFoundError` because `llm_parser` doesn't exist yet.

- [ ] **Step 3: Create llm_parser.py**

Create `core/llm_parser.py`:

```python
"""
LLM Receipt Parser — uses Claude API to parse OCR text into structured line items.

This module is a TRAINING TOOL, not a permanent dependency:
  - Month 1: Sonnet parses every receipt, builds supplier-code mappings
  - Month 2+: Learned mappings handle 90%+, LLM fires only for unknowns
  - Fallback: If LLM fails, caller falls back to regex parser

Called from ocr_engine._parse_and_finalize() when existing mappings
don't cover enough of the receipt's product codes.
"""

import json
import re

import frappe


def should_use_llm(ocr_text, supplier, settings):
    """
    Decide whether to call the LLM for this receipt.

    Returns True if LLM parsing is needed (existing mappings insufficient).
    Returns False if LLM is disabled or existing mappings cover enough items.
    """
    if not settings.llm_enabled:
        return False

    if not ocr_text or not ocr_text.strip():
        return False

    # Extract product codes from OCR text (lightweight regex — not a full parse)
    codes = _extract_product_codes(ocr_text)
    if not codes:
        return True  # Can't identify codes, need LLM to parse

    # Check how many codes already have learned mappings
    matched = _count_existing_mappings(codes, supplier)
    coverage = (matched / len(codes)) * 100 if codes else 0
    threshold = float(settings.llm_match_threshold or 80)

    return coverage < threshold


def parse_receipt(ocr_text, settings):
    """
    Send OCR text to Claude API and return structured receipt data.

    Returns dict with keys: supplier, receipt_number, receipt_date, job_number,
    line_items, subtotal, tax, total.
    Returns None if the LLM call fails or returns unparseable data.
    """
    api_key = settings.get_password("llm_api_key")
    if not api_key:
        frappe.log_error("LLM API key not configured", title="LLM Parser")
        return None

    model = settings.llm_model or "claude-sonnet-4-20250514"
    messages = _build_messages(ocr_text)

    try:
        import anthropic

        client = anthropic.Anthropic(api_key=api_key)
        response = client.messages.create(
            model=model,
            max_tokens=4096,
            messages=messages,
        )

        raw_text = response.content[0].text
        return _parse_llm_response(raw_text)

    except ImportError:
        frappe.log_error(
            "anthropic package not installed. Run: pip install anthropic",
            title="LLM Parser Import Error",
        )
        return None
    except Exception as e:
        frappe.log_error(
            message=f"LLM receipt parse failed: {e}",
            title="LLM Parser Error",
        )
        return None


def _build_messages(ocr_text):
    """Build the Claude API messages array."""
    system_content = (
        "You are a receipt parser for a plumbing, electrical, and HVAC company. "
        "Extract structured line items from receipt OCR text. "
        "Return valid JSON only, no commentary or explanation."
    )

    user_content = f"""Parse this receipt OCR text into structured data.

OCR TEXT:
{ocr_text}

Return JSON in this exact format:
{{
  "supplier": "string",
  "receipt_number": "string or null",
  "receipt_date": "YYYY-MM-DD or null",
  "job_number": "string or null",
  "line_items": [
    {{
      "description": "cleaned item description",
      "product_code": "supplier SKU/part number or null",
      "quantity": number,
      "unit_price": number,
      "extended_price": number,
      "uom": "EA or FT or BOX or ROLL or other unit"
    }}
  ],
  "subtotal": number or null,
  "tax": number or null,
  "total": number or null
}}

Rules:
- description should be a clean, readable item name (e.g. "3/4 copper 90 elbow")
- product_code is the supplier's SKU, part number, or catalog code
- If a field is unreadable or missing, use null
- Do not invent data that is not in the text
- Prices are in USD
- quantity defaults to 1 if not specified"""

    return [
        {"role": "user", "content": user_content},
    ]


def _parse_llm_response(raw_text):
    """
    Parse Claude's response text into a structured dict.
    Handles raw JSON or JSON wrapped in markdown code blocks.
    Returns None if parsing fails or required fields are missing.
    """
    if not raw_text:
        return None

    text = raw_text.strip()

    # Strip markdown code block wrapper if present
    md_match = re.match(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if md_match:
        text = md_match.group(1).strip()

    try:
        data = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return None

    # Validate required structure
    if not isinstance(data, dict):
        return None
    if "line_items" not in data:
        return None
    if not isinstance(data["line_items"], list):
        return None

    return data


def _extract_product_codes(ocr_text):
    """
    Extract likely product codes from OCR text using lightweight regex.

    Looks for patterns like:
      - Alphanumeric codes 5+ chars (e.g., "45005808", "LF4090COP")
      - Codes at start of lines or after whitespace
    Returns a list of unique codes found.
    """
    # Match sequences of 5+ alphanumeric chars that look like SKUs
    # Exclude pure numbers that look like prices (contain . or ,)
    pattern = r'\b([A-Z0-9][A-Z0-9-]{4,}[A-Z0-9])\b'
    matches = re.findall(pattern, ocr_text.upper())

    # Filter out common false positives
    filtered = set()
    for code in matches:
        # Skip if it looks like a date, phone, or price
        if re.match(r'^\d{1,2}/\d{1,2}', code):
            continue
        if re.match(r'^\d{3}-\d{3}', code):
            continue
        if len(code) > 30:
            continue
        filtered.add(code)

    return list(filtered)


def _count_existing_mappings(codes, supplier):
    """Count how many product codes have existing supplier mappings in ERPNext."""
    if not codes or not supplier:
        return 0

    placeholders = ", ".join(["%s"] * len(codes))
    like_supplier = f"%{supplier}%"

    count = frappe.db.sql(f"""
        SELECT COUNT(DISTINCT isup.supplier_part_no)
        FROM `tabItem Supplier` isup
        WHERE isup.supplier LIKE %s
          AND isup.supplier_part_no IN ({placeholders})
          AND isup.match_count >= 1
    """, [like_supplier] + codes)[0][0]

    return count or 0
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
python -m pytest hcp_replacement/hcp_replacement/tests/test_llm_parser.py -v
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add hcp_replacement/hcp_replacement/core/llm_parser.py hcp_replacement/hcp_replacement/tests/test_llm_parser.py
git commit -m "feat: add LLM receipt parser module with Claude API integration"
```

---

### Task 3: Wire LLM Parser into ocr_engine.py

**Files:**
- Modify: `core/ocr_engine.py:24-31` (imports) and `core/ocr_engine.py:182-244` (`_parse_and_finalize`)

- [ ] **Step 1: Add import for llm_parser**

In `core/ocr_engine.py`, after the existing imports (line 30), add:

```python
from hcp_replacement.hcp_replacement.core.llm_parser import should_use_llm, parse_receipt as llm_parse_receipt
```

- [ ] **Step 2: Modify _parse_and_finalize to try LLM first**

Replace the body of `_parse_and_finalize` (lines 182-265 of `core/ocr_engine.py`) with:

```python
def _parse_and_finalize(receipt, raw_text, settings):
    """
    Parse OCR text into structured data, populate receipt fields,
    run SKU matching, save, and run price checks.

    Parse priority:
      1. LLM parser (if enabled and mappings insufficient)
      2. Regex parser (fallback — always available)
    """
    parsed = None
    parse_source = "regex"

    # Try LLM parser first if enabled
    if should_use_llm(raw_text, receipt.supplier or "", settings):
        llm_result = llm_parse_receipt(raw_text, settings)
        if llm_result and llm_result.get("line_items"):
            parsed = llm_result
            parse_source = "llm"
            log_event("ocr", f"LLM parsed {len(llm_result['line_items'])} items",
                      severity="info", job=receipt.hcp_job, source="llm_parser")

    # Fall back to regex parser
    if not parsed:
        parsed = parse_receipt_text(raw_text, receipt.supplier or "")
        parse_source = "regex"

    # Auto-detect supplier if not manually set
    if not receipt.supplier and parsed.get("supplier"):
        receipt.supplier = parsed["supplier"]

    # Store tech initials if found
    if parsed.get("tech_initials"):
        receipt.tech_initials = parsed["tech_initials"]

    # PO / job reference handling
    job_ref = parsed.get("job_number") or parsed.get("job_reference")
    if job_ref:
        job_name = frappe.db.get_value(
            "HCP Job", {"hcp_job_id": job_ref}, "name"
        )
        if job_name:
            receipt.parsed_po_number = job_ref
            if not receipt.hcp_job:
                receipt.hcp_job = job_name
        else:
            receipt.parsed_po_number = f"X{job_ref}"
    elif not receipt.hcp_job:
        receipt.parsed_po_number = _generate_office_stock_po(
            parsed.get("receipt_date", ""),
            parsed.get("tech_initials", ""),
        )

    # Populate parsed_items child table
    receipt.parsed_items = []
    for item in parsed.get("line_items", []):
        receipt.append(
            "parsed_items",
            {
                "product_code": item.get("product_code", ""),
                "description": item.get("description", ""),
                "quantity": flt(item.get("quantity", 1)),
                "unit_price": flt(item.get("unit_price", 0)),
                "ext_price": flt(item.get("ext_price") or item.get("extended_price") or 0),
                "unit": item.get("unit") or item.get("uom") or "",
            },
        )

    # Validate ext_price ~ qty x unit_price for each item
    for row in (receipt.parsed_items or []):
        expected = flt(row.quantity) * flt(row.unit_price)
        actual = flt(row.ext_price)
        if expected > 0 and actual > 0 and abs(expected - actual) / expected > 0.05:
            row.price_flag = f"Price mismatch: {row.quantity} x ${row.unit_price} = ${expected:.2f} but receipt shows ${actual:.2f}"

    # Set parsed totals
    receipt.parsed_subtotal = flt(parsed.get("subtotal", 0))
    receipt.parsed_tax = flt(parsed.get("tax", 0))
    receipt.parsed_total = flt(parsed.get("total", 0))

    # Store parse source for debugging
    receipt.parse_source = parse_source

    # Fuzzy-match parsed items to ERPNext Items
    match_parsed_items_to_erp(receipt, settings)

    # Cross-source deduplication and reconciliation
    from hcp_replacement.hcp_replacement.core.receipt_dedup import run_dedup_and_reconcile
    run_dedup_and_reconcile(receipt, parsed)

    receipt.save(ignore_permissions=True)

    # Compare prices against pricebook
    try:
        check_receipt_prices(receipt.name)
    except Exception as e:
        frappe.log_error(
            message=f"Price check failed for {receipt.name}: {e}",
            title="HCP Receipt Price Check Error",
        )

    frappe.publish_realtime(
        "ocr_complete",
        {
            "receipt_name": receipt.name,
            "supplier": receipt.supplier,
            "item_count": len(receipt.parsed_items or []),
            "total": receipt.parsed_total,
            "parse_source": parse_source,
        },
        doctype="HCP Receipt",
        docname=receipt.name,
    )
```

Note: `parse_source` field may not exist on the doctype yet. If the `receipt.parse_source = parse_source` line throws an error during testing, remove it — it's a nice-to-have debug field, not essential.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add hcp_replacement/hcp_replacement/core/ocr_engine.py
git commit -m "feat: wire LLM parser into OCR pipeline with regex fallback"
```

---

### Task 4: Filter sku_matcher Fuzzy Search to pbmat_ Items + Wire in Item Classifier

**Files:**
- Modify: `core/sku_matcher.py:75-176` (`match_parsed_items_to_erp`)
- Create: `tests/test_sku_matcher_pbmat.py`

- [ ] **Step 1: Write the test**

Create `tests/test_sku_matcher_pbmat.py`:

```python
"""Tests for sku_matcher pbmat_ filtering and item_classifier integration."""

import unittest
from unittest.mock import patch, MagicMock


class TestClassifierScoring(unittest.TestCase):
    """Test that item_classifier scoring works for structured matching."""

    def test_classify_copper_elbow(self):
        from hcp_replacement.hcp_replacement.core.item_classifier import classify

        attrs = classify("3/4 copper 90 elbow")
        self.assertEqual(attrs.item_type, "elbow")
        self.assertEqual(attrs.material, "copper")
        self.assertIn("3/4", attrs.primary_size or "")

    def test_classify_abbreviations(self):
        from hcp_replacement.hcp_replacement.core.item_classifier import classify

        attrs = classify("3/4 cu 90 ell")
        self.assertEqual(attrs.item_type, "elbow")
        self.assertEqual(attrs.material, "copper")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it passes** (item_classifier already exists)

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
python -m pytest hcp_replacement/hcp_replacement/tests/test_sku_matcher_pbmat.py -v
```

- [ ] **Step 3: Modify sku_matcher.py — filter items to pbmat_ and add classifier Layer 2**

In `match_parsed_items_to_erp` (line 94-100 of `sku_matcher.py`), change the item cache to only load pbmat_ items:

Replace:
```python
    # Step 2: Build item cache for fuzzy matching
    items = frappe.get_all(
        "Item",
        filters={"disabled": 0},
        fields=["name", "item_name", "description", "item_group"],
        limit_page_length=0,
    )
```

With:
```python
    # Step 2: Build item cache for fuzzy matching (HCP pricebook only)
    items = frappe.get_all(
        "Item",
        filters={"disabled": 0, "name": ["like", "pbmat_%"]},
        fields=["name", "item_name", "description", "item_group"],
        limit_page_length=0,
    )
```

Then, after the barcode lookup block (after line 135, before the fuzzy match block), insert the classifier as Layer 2.5:

```python
        # ── Priority 2.5: Structured attribute matching (item_classifier) ──
        try:
            from hcp_replacement.hcp_replacement.core.item_classifier import classify, score_match
            search_attrs = classify(row.description or "")
            if search_attrs.item_type:  # Only if classifier found a type
                classifier_best_score = 0
                classifier_best_match = None
                for item in items:
                    if not _item_matches_supplier_trade(item.item_group, supplier_trades):
                        continue
                    item_attrs = classify(item.item_name or "")
                    cscore = score_match(search_attrs, item_attrs)
                    if cscore > classifier_best_score:
                        classifier_best_score = cscore
                        classifier_best_match = item
                if classifier_best_score >= 70 and classifier_best_match:
                    row.matched_item = classifier_best_match.name
                    row.match_score = classifier_best_score
                    row.mapping_status = "Matched"
                    if supplier and product_code:
                        save_supplier_match(supplier, product_code, classifier_best_match.name)
                    continue
        except Exception:
            pass  # Classifier is optional, fall through to fuzzy match
```

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add hcp_replacement/hcp_replacement/core/sku_matcher.py hcp_replacement/hcp_replacement/tests/test_sku_matcher_pbmat.py
git commit -m "feat: filter fuzzy search to pbmat_ items, wire in item_classifier as Layer 2.5"
```

---

### Task 5: Fix match_review.search_pricebook to Filter pbmat_ Only

**Files:**
- Modify: `api/match_review.py:54-69` (`search_pricebook`)

- [ ] **Step 1: Add pbmat_ filter**

In `api/match_review.py`, replace the `search_pricebook` function (lines 54-69):

```python
@frappe.whitelist()
def search_pricebook(query, limit=20):
    """Search the HCP pricebook for items to match against."""
    if not query or len(query) < 2:
        return []

    return frappe.get_all(
        "Item",
        filters=[
            ["item_name", "like", f"%{query}%"],
            ["disabled", "=", 0],
            ["name", "like", "pbmat_%"],
        ],
        fields=["name", "item_name", "item_group", "standard_rate"],
        order_by="item_name asc",
        limit_page_length=int(limit),
        ignore_permissions=True,
    )
```

- [ ] **Step 2: Verify via API call**

```bash
curl -s -X POST "https://manytalentsmore.v.frappe.cloud/api/method/hcp_replacement.hcp_replacement.api.match_review.search_pricebook" \
  -H "Authorization: token 3ac4c8f5530ec6b:57394de8aa94140" \
  -H "Content-Type: application/json" \
  -d '{"query":"ball valve","limit":3}'
```

Expected: Only `pbmat_` items returned (after deploy).

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add hcp_replacement/hcp_replacement/api/match_review.py
git commit -m "fix: restrict match_review.search_pricebook to HCP pricebook (pbmat_) items"
```

---

### Task 6: Install anthropic SDK on Frappe Cloud

**Files:** None (runtime dependency)

- [ ] **Step 1: Add anthropic to requirements**

Check if a `requirements.txt` or `pyproject.toml` exists at the app root. Add `anthropic` to it:

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
echo "anthropic" >> requirements.txt
```

If the file doesn't exist yet, create it with:

```
frappe
anthropic
```

- [ ] **Step 2: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add requirements.txt
git commit -m "chore: add anthropic SDK dependency"
```

---

### Task 7: Deploy and Configure

**Files:** None (operational)

- [ ] **Step 1: Push all commits**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git push origin main
```

- [ ] **Step 2: Trigger Frappe Cloud deploy**

Go to frappecloud.com → site → Deploy/Update.

- [ ] **Step 3: Run bench migrate** (adds new settings fields)

This happens automatically on Frappe Cloud deploy. Verify by visiting:
`https://manytalentsmore.v.frappe.cloud/app/hcp-replacement-settings`

The "LLM Receipt Parser" section should appear with:
- Enable LLM Parsing (checkbox)
- LLM Model (dropdown)
- Anthropic API Key (password field)
- Skip LLM When Mapping Coverage Above (%)

- [ ] **Step 4: Configure settings**

In HCP Replacement Settings:
1. Check "Enable LLM Parsing"
2. Set Model to `claude-sonnet-4-20250514`
3. Enter Anthropic API key
4. Set threshold to `80`

- [ ] **Step 5: Test with a real receipt**

Scan a receipt from the mobile app and verify:
- OCR text is captured (existing behavior)
- LLM parses the receipt (check event log for "LLM parsed X items")
- Parsed items show on receipt detail with correct descriptions, prices, quantities
- Manual MATCH button searches only pbmat_ items
- Corrections save learned mappings

---

### Task 8: Verify Learning Loop

**Files:** None (validation)

- [ ] **Step 1: Scan 3 receipts from the same supplier**

Use a Coburn's receipt. After each scan, check:
- Receipt 1: LLM fires, all items parsed, mappings created (match_count = 1)
- Receipt 2: LLM fires for any NEW codes, existing codes auto-match
- Receipt 3: Most codes should auto-match via mappings, LLM only for unknowns

- [ ] **Step 2: Check mapping growth**

```bash
curl -s -X POST "https://manytalentsmore.v.frappe.cloud/api/method/frappe.client.get_count" \
  -H "Authorization: token 3ac4c8f5530ec6b:57394de8aa94140" \
  -H "Content-Type: application/json" \
  -d '{"doctype":"Item Supplier","filters":[["match_count",">=",1]]}'
```

- [ ] **Step 3: After one month, switch to Haiku**

In HCP Replacement Settings:
1. Change model to `claude-haiku-4-5-20251001`
2. Raise threshold to `90`

Monitor for another week to confirm accuracy stays above 95%.
