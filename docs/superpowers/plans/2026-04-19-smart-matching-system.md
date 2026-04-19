# Smart Matching System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a learning receipt-to-pricebook matching system with confidence tracking, auto unit conversion, auto markup, pricebook request workflow, and a confidence-gradient UX (white → sky blue → dark cobalt).

**Architecture:** Backend adds `match_count` tracking to Item Supplier, a new `HCP Pricebook Request` doctype for tech-submitted new parts, and an enhanced classification-based matching engine. Frontend adds confidence-colored receipt items, shared search modal, "Add New Part" flow, and "Dispatch matched, hold unmatched" one-tap button. Zack's desktop gets a two-panel review layout with keyboard shortcuts.

**Tech Stack:** Frappe Framework (backend), Next.js 15 / React 19 / Tailwind (web), Expo / React Native (mobile)

---

## File Map

### Backend (Frappe — `hcp_replacement/hcp_replacement/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `core/sku_matcher.py` | Add match_count tracking, unit conversion to save_supplier_match |
| Create | `core/item_classifier.py` | Structured attribute parser (type, material, size, variant) |
| Modify | `api/match_review.py` | Fix bulk_approve learning, add new part endpoints, unit conversion |
| Create | `doctype/hcp_pricebook_request/` | New part request doctype (4 files) |
| Modify | `doctype/hcp_receipt_parsed_item/hcp_receipt_parsed_item.json` | Add match_count, confidence_tier fields |
| Modify | `hooks.py` | Add fixtures for custom fields on Item Supplier |
| Create | `fixtures/custom_field.json` | match_count, unit_conversion, supplier_unit on Item Supplier |

### Frontend Web (Next.js — `ManyTalentsMore/src/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/inventory-api.ts` | Add new part types + API functions, confidence types |
| Modify | `app/manager/inventory/page.tsx` | Enhanced MATCHES tab with confidence colors, keyboard nav, new part flow |

### Frontend Mobile (Expo — `hcp_replacement/mobile/src/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `components/inventory/DispatchItemCard.tsx` | Confidence colors, collapsed rows for locked-in items |
| Create | `components/inventory/PricebookSearchModal.tsx` | Shared search modal (bottom sheet) |
| Create | `components/inventory/AddNewPartModal.tsx` | Amber "Add New Part" modal |
| Modify | `components/inventory/ReceiptDetailScreen.tsx` | "Dispatch matched, hold unmatched" button |
| Modify | `api/inventory.ts` | Add new part + confidence APIs |
| Modify | `types/inventory.ts` | Add confidence types |

---

### Task 1: Add match_count and unit conversion to Item Supplier

**Files:**
- Create: `hcp_replacement/hcp_replacement/fixtures/custom_field.json`
- Modify: `hcp_replacement/hcp_replacement/hooks.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/core/sku_matcher.py`

- [ ] **Step 1: Create fixtures for custom fields on Item Supplier**

Create `fixtures/custom_field.json` with three custom fields added to the Item Supplier child table:

```json
[
  {
    "doctype": "Custom Field",
    "dt": "Item Supplier",
    "fieldname": "match_count",
    "fieldtype": "Int",
    "label": "Match Count",
    "default": "0",
    "read_only": 1,
    "insert_after": "supplier_part_no"
  },
  {
    "doctype": "Custom Field",
    "dt": "Item Supplier",
    "fieldname": "unit_conversion",
    "fieldtype": "Float",
    "label": "Unit Conversion Factor",
    "description": "1 supplier unit = X pricebook units (e.g., 50 means 1 BOX = 50 EACH)",
    "insert_after": "match_count"
  },
  {
    "doctype": "Custom Field",
    "dt": "Item Supplier",
    "fieldname": "supplier_unit",
    "fieldtype": "Data",
    "label": "Supplier Unit",
    "description": "Unit the supplier sells in (BOX, PACK, ROLL, etc.)",
    "insert_after": "unit_conversion"
  }
]
```

- [ ] **Step 2: Register fixtures in hooks.py**

Read hooks.py. Find or add a `fixtures` key and add `"Custom Field"`:

```python
fixtures = ["Custom Field"]
```

- [ ] **Step 3: Update save_supplier_match in sku_matcher.py**

Read `core/sku_matcher.py`, find `save_supplier_match()`. Modify it to:
- Increment `match_count` on existing mappings instead of overwriting
- Accept optional `unit_conversion` and `supplier_unit` params
- Save those fields on the Item Supplier row

```python
def save_supplier_match(supplier, supplier_part_no, item_code,
                        unit_conversion=None, supplier_unit=None):
    """
    Save or update a supplier code → Item mapping.
    Increments match_count on existing mappings.
    """
    if not supplier or not supplier_part_no or not item_code:
        return

    item = frappe.get_doc("Item", item_code)
    existing = None
    for row in (item.supplier_items or []):
        if row.supplier == supplier and row.supplier_part_no == supplier_part_no:
            existing = row
            break

    if existing:
        existing.match_count = (existing.match_count or 0) + 1
        if unit_conversion is not None:
            existing.unit_conversion = unit_conversion
        if supplier_unit is not None:
            existing.supplier_unit = supplier_unit
    else:
        item.append("supplier_items", {
            "supplier": supplier,
            "supplier_part_no": supplier_part_no,
            "match_count": 1,
            "unit_conversion": unit_conversion or 0,
            "supplier_unit": supplier_unit or "",
        })

    item.save(ignore_permissions=True)
```

- [ ] **Step 4: Commit**

```bash
git add fixtures/ hooks.py hcp_replacement/core/sku_matcher.py
git commit -m "feat: add match_count + unit conversion tracking to Item Supplier"
```

---

### Task 2: Add confidence fields to HCP Receipt Parsed Item

**Files:**
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/hcp_receipt_parsed_item/hcp_receipt_parsed_item.json`

- [ ] **Step 1: Add match_count and confidence_tier fields**

Read the existing JSON. Add two new fields after `mapping_status`:

```json
{
  "fieldname": "match_count",
  "fieldtype": "Int",
  "label": "Match Count",
  "read_only": 1,
  "default": "0"
},
{
  "fieldname": "confidence_tier",
  "fieldtype": "Select",
  "label": "Confidence Tier",
  "options": "unmatched\nfirst_match\nlocked_in",
  "read_only": 1,
  "default": "unmatched"
}
```

Also add these fieldnames to the `field_order` array.

- [ ] **Step 2: Commit**

```bash
git add hcp_replacement/doctype/hcp_receipt_parsed_item/
git commit -m "feat: add match_count and confidence_tier to parsed items"
```

---

### Task 3: Build Item Classifier

**Files:**
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/core/item_classifier.py`

- [ ] **Step 1: Create the classifier module**

This module parses supplier descriptions into structured attributes for matching.

```python
"""
Item Classifier — extract structured attributes from supplier item descriptions.

Parses: type, material, size, variant
Used by the matching engine to match within the same class instead of global fuzzy.

Understands plumbing conventions:
  - Nipples: [diameter] x [length], "x close" = shortest
  - Bushings/reducers: [big size] x [small size] (both diameters)
  - Couplings: just [size]
  - Street 90 ≠ regular 90
  - Crimp PEX ≠ Expansion PEX ≠ SharkBite
  - ProPress (copper press) ≠ MegaPress (steel/gas press)
  - T&P relief valve ≠ gas valve ≠ ball valve
"""

import re

# ── Synonym table ────────────────────────────────
SYNONYMS = {
    # Materials
    "cu": "copper", "cop": "copper", "cpr": "copper",
    "brs": "brass", "brz": "brass",
    "gi": "galvanized", "galv": "galvanized", "gal": "galvanized",
    "blk": "black", "bk": "black",
    "ss": "stainless", "s/s": "stainless",
    "ci": "cast_iron",
    # Fitting types
    "ell": "elbow", "el": "elbow",
    "cplg": "coupling", "cpg": "coupling",
    "nip": "nipple",
    "adpt": "adapter", "adapt": "adapter",
    "bush": "bushing",
    "red": "reducer",
    "conn": "connector",
    # Thread types
    "fip": "female_thread", "fpt": "female_thread", "fht": "female_thread",
    "mip": "male_thread", "mpt": "male_thread", "mht": "male_thread",
    # PEX types
    "wirsbo": "expansion_pex", "uponor": "expansion_pex",
    # Press types
    "propress": "propress", "megapress": "megapress",
    # Pipe
    "sch": "schedule", "sched": "schedule",
    "dwv": "dwv",
    "t&c": "threaded_coupled",
}

STANDARD_SIZES = {
    "1/4", "3/8", "1/2", "5/8", "3/4", "1", "1-1/4", "1-1/2", "2",
    "2-1/2", "3", "3-1/2", "4", "5", "6", "8", "10", "12",
}


class ItemAttributes:
    """Structured attributes extracted from an item description."""
    def __init__(self):
        self.item_type = ""        # elbow, tee, coupling, nipple, valve, pipe, wire, etc.
        self.sub_type = ""         # for valves: tpr, gas, ball, angle_stop, etc.
        self.material = ""         # copper, pvc, pex, black, galvanized, brass, emt
        self.pex_system = ""       # crimp, expansion, sharkbite (only for PEX items)
        self.press_system = ""     # propress, megapress (only for press items)
        self.primary_size = ""     # main diameter
        self.secondary_size = ""   # length (nipples) or second diameter (reducers)
        self.is_street = False     # street fitting (MIP x FIP)
        self.is_reducing = False   # reducer/bushing/swage
        self.angle = ""            # 90, 45, etc.
        self.schedule = ""         # 40, 80

    def match_score(self, other):
        """Score how well this item matches another based on structured attributes."""
        score = 0.0

        # Type must match (most important)
        if self.item_type and other.item_type:
            if self.item_type == other.item_type:
                score += 0.30
            else:
                return 0.0  # Different type = no match

        # Sub-type must match for valves
        if self.sub_type and other.sub_type:
            if self.sub_type == other.sub_type:
                score += 0.10
            else:
                return 0.0  # T&P valve ≠ gas valve

        # Material
        if self.material and other.material:
            if self.material == other.material:
                score += 0.15
            else:
                score -= 0.10

        # PEX system
        if self.pex_system and other.pex_system:
            if self.pex_system != other.pex_system:
                return 0.0  # crimp ≠ expansion

        # Press system
        if self.press_system and other.press_system:
            if self.press_system != other.press_system:
                return 0.0  # propress ≠ megapress

        # Street vs regular
        if self.is_street != other.is_street:
            score -= 0.15

        # Angle
        if self.angle and other.angle:
            if self.angle == other.angle:
                score += 0.05
            else:
                score -= 0.10

        # Primary size (critical)
        if self.primary_size and other.primary_size:
            if self.primary_size == other.primary_size:
                score += 0.20
            else:
                return 0.0  # Wrong size = no match

        # Secondary size
        if self.secondary_size and other.secondary_size:
            if self.secondary_size == other.secondary_size:
                score += 0.10
            else:
                score -= 0.05

        # Reducing
        if self.is_reducing and other.is_reducing:
            score += 0.05
        elif self.is_reducing != other.is_reducing:
            score -= 0.05

        return max(score, 0.0)


def classify(text):
    """Parse an item description into structured attributes."""
    attr = ItemAttributes()
    t = text.lower().strip()

    # Normalize quotes and unicode
    t = t.replace("\u2033", '"').replace("\u201c", '"').replace("\u201d", '"')
    t = t.replace("'", "").replace('"', ' inch ')
    t = re.sub(r"(\d)\s+(\d/\d)", r"\1-\2", t)  # "1 1/2" -> "1-1/2"

    # ── Detect item type ────────────────
    if re.search(r"\bnipple\b|\bnip\b", t):
        attr.item_type = "nipple"
        if "swage" in t:
            attr.is_reducing = True
    elif re.search(r"\bbushing\b|\bbush\b", t):
        attr.item_type = "bushing"
        attr.is_reducing = True
    elif re.search(r"\bcoupling\b|\bcplg\b|\bcpg\b", t):
        attr.item_type = "coupling"
    elif re.search(r"\btee\b", t):
        attr.item_type = "tee"
    elif re.search(r"\belbow\b|\bell\b|\b90\b|\b45\b", t):
        attr.item_type = "elbow"
    elif re.search(r"\badapter\b|\badaptor\b|\badpt\b", t):
        attr.item_type = "adapter"
    elif re.search(r"\bunion\b", t):
        attr.item_type = "union"
    elif re.search(r"\bplug\b", t):
        attr.item_type = "plug"
    elif re.search(r"\bcap\b", t):
        attr.item_type = "cap"
    elif re.search(r"\bvalve\b", t):
        attr.item_type = "valve"
        # Valve sub-types — function matters more than size
        if re.search(r"t\s*&\s*p|t\.p\.r|tpr|relief|temperature.*pressure|pressure.*temperature", t):
            attr.sub_type = "tpr"
        elif re.search(r"\bgas\s+valve\b|\bgas\b.*\bvalve\b", t):
            attr.sub_type = "gas"
        elif re.search(r"\bball\s+valve\b|\bball\b.*\bvalve\b", t):
            attr.sub_type = "ball"
        elif re.search(r"\bangle\s+stop\b|\bangle\b.*\bstop\b", t):
            attr.sub_type = "angle_stop"
        elif re.search(r"\bstraight\s+stop\b|\bstraight\b.*\bstop\b", t):
            attr.sub_type = "straight_stop"
        elif re.search(r"\bgate\b", t):
            attr.sub_type = "gate"
        elif re.search(r"\bcheck\b", t):
            attr.sub_type = "check"
        elif re.search(r"\bflush\b", t):
            attr.sub_type = "flush"
        elif re.search(r"\bfill\b", t):
            attr.sub_type = "fill"
        elif re.search(r"\bboiler\s+drain\b", t):
            attr.sub_type = "boiler_drain"
    elif re.search(r"\bstrap\b", t):
        attr.item_type = "strap"
    elif re.search(r"\bconnector\b|\bconn\b", t):
        attr.item_type = "connector"
    elif re.search(r"\breduc", t):
        attr.item_type = "reducer"
        attr.is_reducing = True
    elif re.search(r"\bpipe\b", t):
        attr.item_type = "pipe"
    elif re.search(r"\btubing\b|\btube\b", t):
        attr.item_type = "tubing"
    elif re.search(r"\bconduit\b", t):
        attr.item_type = "conduit"
    elif re.search(r"\bwire\b|\bcable\b|\bromex\b|\bthhn\b|\bmc\b", t):
        attr.item_type = "wire"
    elif re.search(r"\bbreaker\b", t):
        attr.item_type = "breaker"
    elif re.search(r"\bgfci\b", t):
        attr.item_type = "gfci"
    elif re.search(r"\bthermostat\b|t-stat", t):
        attr.item_type = "thermostat"
    elif re.search(r"\bwater\s+heater\b", t):
        attr.item_type = "water_heater"
    elif re.search(r"\bfaucet\b", t):
        attr.item_type = "faucet"
    elif re.search(r"\btoilet\b", t):
        attr.item_type = "toilet"
    elif re.search(r"\bcompressor\b", t):
        attr.item_type = "compressor"
    elif re.search(r"\brefrigerant\b|r-?410|r-?22|r-?134", t):
        attr.item_type = "refrigerant"

    # ── Detect material ────────────────
    if "copper" in t or " cu " in t:
        attr.material = "copper"
    elif "cpvc" in t:
        attr.material = "cpvc"
    elif "pvc" in t:
        attr.material = "pvc"
    elif "pex" in t:
        attr.material = "pex"
    elif "galv" in t or "galvanized" in t:
        attr.material = "galvanized"
    elif "black" in t or "blk" in t:
        attr.material = "black"
    elif "brass" in t:
        attr.material = "brass"
    elif "stainless" in t or "s/s " in t:
        attr.material = "stainless"
    elif "cast iron" in t:
        attr.material = "cast_iron"
    elif "abs" in t:
        attr.material = "abs"
    elif "emt" in t:
        attr.material = "emt"
    elif "iron" in t or "malleable" in t:
        attr.material = "iron"

    # ── PEX system ────────────────
    if "crimp" in t:
        attr.pex_system = "crimp"
    elif "expansion" in t or "wirsbo" in t or "uponor" in t:
        attr.pex_system = "expansion"
    elif "sharkbite" in t or "shark bite" in t or "push fit" in t:
        attr.pex_system = "sharkbite"

    # ── Press system ────────────────
    if "propress" in t:
        attr.press_system = "propress"
    elif "megapress" in t:
        attr.press_system = "megapress"

    # ── Street fitting ────────────────
    if "street" in t:
        attr.is_street = True

    # ── Angle ────────────────
    m = re.search(r"\b(90|45)\b", t)
    if m:
        attr.angle = m.group(1)

    # ── Schedule ────────────────
    m = re.search(r"sch(?:edule)?\s*(\d+)", t)
    if m:
        attr.schedule = m.group(1)

    # ── Sizes ────────────────
    sizes = []
    for m in re.finditer(r"\b(\d+(?:-\d+/\d+)?(?:/\d+)?)\b", t):
        s = m.group(1)
        if s in STANDARD_SIZES:
            sizes.append(s)

    if attr.item_type == "nipple" and not attr.is_reducing:
        # Nipple: first size = diameter, second = length (not a pipe size)
        attr.primary_size = sizes[0] if sizes else ""
        # Don't set secondary_size for nipple length — it's not a matching criterion
        # (we match nipples by diameter, not length)
    elif attr.is_reducing or attr.item_type in ("bushing", "reducer"):
        # Reducer/bushing: both are diameters
        attr.primary_size = sizes[0] if sizes else ""
        attr.secondary_size = sizes[1] if len(sizes) > 1 else ""
    else:
        # Everything else: primary size
        attr.primary_size = sizes[0] if sizes else ""
        if len(sizes) > 1:
            attr.secondary_size = sizes[1]

    return attr
```

- [ ] **Step 2: Commit**

```bash
git add hcp_replacement/core/item_classifier.py
git commit -m "feat: add item classifier — structured attribute parser for smart matching"
```

---

### Task 4: Enhance match_review.py — fix bulk_approve, add new part endpoints

**Files:**
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/api/match_review.py`

- [ ] **Step 1: Fix bulk_approve to learn from approvals**

Read `api/match_review.py`. In `bulk_approve()`, add supplier mapping learning:

```python
@frappe.whitelist()
def bulk_approve(items_json):
    """Approve multiple matches at once — and LEARN from each one."""
    import json
    items = json.loads(items_json) if isinstance(items_json, str) else items_json

    approved = 0
    for item_name in items:
        try:
            doc = frappe.get_doc("HCP Receipt Parsed Item", item_name)
            doc.mapping_status = "Manual"
            doc.save(ignore_permissions=True)

            # Learn the mapping
            if doc.product_code and doc.matched_item:
                receipt = frappe.get_cached_doc("HCP Receipt", doc.parent)
                if receipt.supplier:
                    save_supplier_match(receipt.supplier, doc.product_code, doc.matched_item)

            approved += 1
        except Exception:
            pass

    return {"approved": approved}
```

- [ ] **Step 2: Add unit conversion to correct_match**

Update `correct_match()` to accept unit conversion params:

```python
@frappe.whitelist()
def correct_match(parsed_item_name, item_code, learn=1,
                  unit_conversion=None, supplier_unit=None):
    """Correct a match with optional unit conversion."""
    learn = int(learn)
    unit_conv = float(unit_conversion) if unit_conversion else None

    parsed_item = frappe.get_doc("HCP Receipt Parsed Item", parsed_item_name)
    receipt = frappe.get_doc("HCP Receipt", parsed_item.parent)

    item_name = frappe.get_cached_value("Item", item_code, "item_name") or item_code
    parsed_item.matched_item = item_code
    parsed_item.matched_item_name = item_name
    parsed_item.match_score = 100
    parsed_item.mapping_status = "Manual"
    parsed_item.save(ignore_permissions=True)

    if learn and parsed_item.product_code and receipt.supplier:
        save_supplier_match(receipt.supplier, parsed_item.product_code, item_code,
                            unit_conversion=unit_conv, supplier_unit=supplier_unit)

    log_event("receipt", f"Match corrected: {parsed_item.description} -> {item_name}",
              severity="info", source="match_review")

    return {"status": "corrected", "item_code": item_code, "item_name": item_name}
```

- [ ] **Step 3: Add new part request endpoints**

Append to `match_review.py`:

```python
@frappe.whitelist()
def submit_new_part(part_name, trade, size=None, supplier_code=None,
                    supplier=None, receipt_item=None):
    """Tech submits a new part not in the pricebook."""
    doc = frappe.new_doc("HCP Pricebook Request")
    doc.part_name = part_name
    doc.trade = trade
    doc.size = size or ""
    doc.supplier_code = supplier_code or ""
    doc.supplier = supplier or ""
    doc.submitted_by = frappe.session.user
    doc.receipt_item = receipt_item or ""
    doc.status = "Pending"
    doc.insert(ignore_permissions=True)

    log_event("receipt", f"New part requested: {part_name}",
              severity="info", source="match_review")

    return {"name": doc.name, "status": "submitted"}


@frappe.whitelist()
def get_pending_parts(page=1, page_size=50):
    """List pending pricebook requests for Zack's review."""
    page = int(page)
    page_size = min(int(page_size), 100)
    offset = (page - 1) * page_size

    items = frappe.get_all(
        "HCP Pricebook Request",
        filters={"status": "Pending"},
        fields=["name", "part_name", "trade", "size", "supplier_code",
                "supplier", "submitted_by", "creation"],
        order_by="creation desc",
        start=offset,
        limit_page_length=page_size,
    )
    total = frappe.db.count("HCP Pricebook Request", {"status": "Pending"})

    return {"items": items, "total_count": total, "has_more": (offset + page_size) < total}


@frappe.whitelist()
def approve_new_part(request_name, item_code=None, item_name_override=None):
    """Zack approves a new part — creates Item if needed, saves supplier mapping."""
    req = frappe.get_doc("HCP Pricebook Request", request_name)

    if item_code:
        # Map to existing item
        req.approved_item = item_code
    else:
        # Create new Item in ERPNext
        item = frappe.new_doc("Item")
        item.item_name = item_name_override or req.part_name
        item.item_group = req.trade
        item.stock_uom = "Nos"
        item.insert(ignore_permissions=True)
        req.approved_item = item.name
        item_code = item.name

    req.status = "Approved"
    req.save(ignore_permissions=True)

    # Save supplier mapping if we have a code
    if req.supplier_code and req.supplier:
        save_supplier_match(req.supplier, req.supplier_code, item_code)

    # Update original receipt item if linked
    if req.receipt_item:
        try:
            pi = frappe.get_doc("HCP Receipt Parsed Item", req.receipt_item)
            pi.matched_item = item_code
            pi.matched_item_name = item_name_override or req.part_name
            pi.match_score = 100
            pi.mapping_status = "Manual"
            pi.save(ignore_permissions=True)
        except Exception:
            pass

    log_event("receipt", f"New part approved: {req.part_name} -> {item_code}",
              severity="success", source="match_review")

    return {"status": "approved", "item_code": item_code}


@frappe.whitelist()
def reject_new_part(request_name, rejection_reason=""):
    """Zack rejects a new part request."""
    req = frappe.get_doc("HCP Pricebook Request", request_name)
    req.status = "Rejected"
    req.rejection_reason = rejection_reason
    req.save(ignore_permissions=True)

    return {"status": "rejected"}
```

- [ ] **Step 4: Commit**

```bash
git add hcp_replacement/api/match_review.py
git commit -m "feat: fix bulk_approve learning, add unit conversion, new part endpoints"
```

---

### Task 5: Create HCP Pricebook Request DocType

**Files:**
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/hcp_pricebook_request/hcp_pricebook_request.json`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/hcp_pricebook_request/hcp_pricebook_request.py`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/hcp_pricebook_request/__init__.py`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/hcp_pricebook_request/test_hcp_pricebook_request.py`

- [ ] **Step 1: Create doctype JSON**

Fields:
- part_name (Data, required)
- trade (Select: Plumbing\nElectrical\nHVAC\nGeneral, required)
- size (Data)
- supplier_code (Data)
- supplier (Data)
- submitted_by (Data, read_only)
- receipt_item (Link to HCP Receipt Parsed Item)
- status (Select: Pending\nApproved\nRejected, default Pending, required)
- approved_item (Link to Item)
- rejection_reason (Small Text)

Module: "HCP Replacement", autoname: "naming_series:", series: "PBR-.YYYY.-.#####"
Permissions: System Manager (full), Employee (create + read)

- [ ] **Step 2: Create Python class, __init__.py, and test stub**

`hcp_pricebook_request.py`: empty Document class
`__init__.py`: empty
`test_hcp_pricebook_request.py`: basic creation test

- [ ] **Step 3: Commit**

```bash
git add hcp_replacement/doctype/hcp_pricebook_request/
git commit -m "feat: add HCP Pricebook Request doctype for tech-submitted new parts"
```

---

### Task 6: Push Backend & Deploy

- [ ] **Step 1: Push all backend changes**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git push origin main
```

- [ ] **Step 2: Verify deployment**

```bash
curl -s -H "Authorization: token 3ac4c8f5530ec6b:532c9f171f1cffb" \
  "https://manytalentsmore.v.frappe.cloud/api/resource/HCP%20Pricebook%20Request?limit_page_length=1"
```

---

### Task 7: Add Confidence Types & APIs to Web Frontend

**Files:**
- Modify: `ManyTalentsMore/src/lib/inventory-api.ts`

- [ ] **Step 1: Add confidence types and new part API functions**

Add to `inventory-api.ts`:

```typescript
// ── Confidence ──
export type ConfidenceTier = "unmatched" | "first_match" | "locked_in";

export const CONFIDENCE_COLORS: Record<ConfidenceTier, { bg: string; text: string; border: string }> = {
  unmatched:   { bg: "#FFFFFF", text: "#333", border: "#ddd" },
  first_match: { bg: "#E3F2FD", text: "#1565C0", border: "#90CAF9" },
  locked_in:   { bg: "#1565C0", text: "#FFFFFF", border: "#0D47A1" },
};

export function getConfidenceTier(matchCount: number): ConfidenceTier {
  if (matchCount >= 5) return "locked_in";
  if (matchCount >= 1) return "first_match";
  return "unmatched";
}

// ── New Part Request ──
export interface PricebookRequest {
  name: string;
  part_name: string;
  trade: string;
  size: string;
  supplier_code: string;
  supplier: string;
  submitted_by: string;
  creation: string;
  status: string;
}

export async function submitNewPart(params: {
  part_name: string; trade: string; size?: string;
  supplier_code?: string; supplier?: string; receipt_item?: string;
}): Promise<{ name: string; status: string }> {
  return callMethod(`${MATCH_API}.submit_new_part`, params);
}

export async function fetchPendingParts(page = 1, pageSize = 50): Promise<{
  items: PricebookRequest[]; total_count: number; has_more: boolean;
}> {
  return callMethod(`${MATCH_API}.get_pending_parts`, { page, page_size: pageSize });
}

export async function approveNewPart(requestName: string, itemCode?: string): Promise<{
  status: string; item_code: string;
}> {
  return callMethod(`${MATCH_API}.approve_new_part`, {
    request_name: requestName, ...(itemCode ? { item_code: itemCode } : {}),
  });
}

export async function rejectNewPart(requestName: string, reason = ""): Promise<{ status: string }> {
  return callMethod(`${MATCH_API}.reject_new_part`, {
    request_name: requestName, rejection_reason: reason,
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/inventory-api.ts
git commit -m "feat: add confidence types, new part API functions"
```

---

### Task 8: Enhance MATCHES Tab with Confidence Colors & New Part Flow

**Files:**
- Modify: `ManyTalentsMore/src/app/manager/inventory/page.tsx`

- [ ] **Step 1: Update MatchesTab with confidence colors**

In the MatchesTab component, update each row to use confidence-based background colors:
- `match_count >= 5` → dark cobalt background `#1565C0`, white text, collapsed single line
- `match_count >= 1` → sky blue background `#E3F2FD`
- `match_count === 0` → white background (current behavior)

Locked-in items (cobalt) show as a single collapsed row: item name + qty + price. Tap to expand.

- [ ] **Step 2: Add "Add New Part" button (amber)**

On unmatched items, add an amber button below the FIX button:

```tsx
<button
  onClick={() => setAddingNewPart(item)}
  className="px-3 py-1.5 rounded text-xs font-semibold bg-[#E67E22] text-white hover:bg-[#D35400]"
>
  + New Part
</button>
```

- [ ] **Step 3: Add NewPartModal**

A modal that appears when "+ New Part" is clicked:
- Part Name input (pre-filled from OCR description)
- Trade dropdown (Plumbing / Electrical / HVAC / General)
- Size input (optional)
- "This will be sent to Zack for review" note
- Submit button calls `submitNewPart()`

- [ ] **Step 4: Add Pending Parts section**

Below the match review table, add a "PENDING PARTS" section showing items techs have submitted. Zack can:
- Approve (optionally pick existing pricebook item via search)
- Reject (with reason)

- [ ] **Step 5: Add keyboard shortcuts**

```typescript
useEffect(() => {
  const handler = (e: KeyboardEvent) => {
    if (e.target instanceof HTMLInputElement) return;
    if (e.key === "j") moveFocus(1);      // next item
    if (e.key === "k") moveFocus(-1);     // prev item
    if (e.key === "Enter") approveSelected();
    if (e.key === "s") skipSelected();
    if (e.key === "n") markNotItem();
  };
  document.addEventListener("keydown", handler);
  return () => document.removeEventListener("keydown", handler);
}, []);
```

- [ ] **Step 6: Commit**

```bash
git add src/app/manager/inventory/page.tsx
git commit -m "feat: confidence colors, new part flow, keyboard nav on MATCHES tab"
```

---

### Task 9: Mobile — Confidence Colors & Search Modal

**Files:**
- Modify: `hcp_replacement/mobile/src/components/inventory/DispatchItemCard.tsx`
- Create: `hcp_replacement/mobile/src/components/inventory/PricebookSearchModal.tsx`
- Create: `hcp_replacement/mobile/src/components/inventory/AddNewPartModal.tsx`
- Modify: `hcp_replacement/mobile/src/components/inventory/ReceiptDetailScreen.tsx`
- Modify: `hcp_replacement/mobile/src/types/inventory.ts`

- [ ] **Step 1: Add confidence types to inventory.ts**

```typescript
export type ConfidenceTier = "unmatched" | "first_match" | "locked_in";

export interface DispatchItem {
  // ... existing fields ...
  match_count: number;
  confidence_tier: ConfidenceTier;
}
```

- [ ] **Step 2: Update DispatchItemCard with confidence colors**

- Locked-in items (match_count >= 5): dark cobalt `#1565C0` background, white text, collapsed to single line (name + qty + price), tap to expand
- First match (1-4): sky blue `#E3F2FD` border/background tint
- Unmatched (0): white background (current)

- [ ] **Step 3: Create PricebookSearchModal**

Bottom sheet modal with:
- Search input (searches cached 975-item pricebook)
- Results list with item name, group, price
- Tap to select → calls correct_match API
- Cache pricebook in AsyncStorage on first load

- [ ] **Step 4: Create AddNewPartModal**

Amber-themed bottom sheet:
- Part Name (pre-filled from OCR)
- Trade dropdown
- Size (optional)
- Stock item toggle
- "Sends to office for review" note
- Submit button

- [ ] **Step 5: Add "Dispatch matched, hold unmatched" button**

In ReceiptDetailScreen, add a button between DISPATCH ALL and SYNC:

```tsx
{pendingCount > 0 && lockedInCount > 0 && (
  <TouchableOpacity style={styles.dispatchMatchedButton} onPress={handleDispatchMatched}>
    <Text style={styles.dispatchMatchedText}>
      DISPATCH MATCHED ({lockedInCount})
    </Text>
  </TouchableOpacity>
)}
```

This dispatches all items with confidence_tier = "locked_in" to their default destinations, leaves unmatched items in limbo.

- [ ] **Step 6: Commit**

```bash
git add mobile/src/components/inventory/ mobile/src/types/inventory.ts
git commit -m "feat: mobile confidence colors, search modal, add new part, dispatch matched"
```

---

### Task 10: Push Everything & Verify

- [ ] **Step 1: Push web frontend**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git push origin master
```

- [ ] **Step 2: Push mobile**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git push origin main
```

- [ ] **Step 3: Verify end-to-end**

1. Open `/manager/inventory` → MATCHES tab → items should show confidence colors
2. Fix a match → confirm match_count increments
3. Click "+ New Part" → submit → check Pending Parts section
4. Approve a pending part → verify Item created in ERPNext
5. On mobile: verify collapsed cobalt rows for locked-in items
6. On mobile: test "Dispatch matched, hold unmatched" button

---

## Verification Checklist

| # | Check | How |
|---|-------|-----|
| 1 | match_count increments on save_supplier_match | Fix a match, check Item Supplier child table |
| 2 | bulk_approve saves supplier mappings | Bulk approve 5 items, verify Item Supplier entries |
| 3 | Confidence colors render correctly | White/sky blue/cobalt on web and mobile |
| 4 | Locked-in items collapse to single line | Items with match_count >= 5 |
| 5 | "+ New Part" creates HCP Pricebook Request | Submit from mobile or web |
| 6 | Zack can approve/reject new parts | Approve → Item created, reject → reason saved |
| 7 | Unit conversion saved on correct_match | Pass unit_conversion param, check Item Supplier |
| 8 | "Dispatch matched" works | Dispatches only locked-in items |
| 9 | Keyboard shortcuts work on desktop | J/K/Enter/S/N in MATCHES tab |
| 10 | Pricebook cached on mobile | Works offline after first load |
