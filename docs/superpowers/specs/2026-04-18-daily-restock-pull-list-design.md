# Daily Restock Pull List — Design Spec

## Goal

Replace Zack's handwritten parts sheets with a live digital pull list system. Techs use parts on jobs → system auto-generates what each truck needs restocked → Zack pulls from office → techs confirm or reject items → everything tracked, no paper.

## Users

- **Zack (office)** — sees all truck pull lists on web dashboard, checks off items as he pulls them, handles rejects, adjusts inventory
- **Techs (field)** — see their own pull list on mobile app, accept all with one click, reject individual items with a note
- **Chris (owner)** — sees everything on both web and app

## The Daily Flow

```
Jobs run → materials consumed → truck stock decreases
                    ↓
System generates pull list per truck (LIVE, auto-updating)
                    ↓
Zack sees pull lists on web → pulls items from office → checks off
                    ↓
Items go into tech's crate (physical) + marked "pulled" in system
                    ↓
Tech sees pull list on app next morning
   ├── Accept All (one click) → items confirmed, stock transferred
   └── Reject item (with note) → "got 3/4x3/4x1/2 tee but needed 3/4x1/2x3/4"
                    ↓
Zack sees rejections → adjusts inventory → adds correct item to pull list
                    ↓
Items out of stock → stay on list until stocked or marked "ignore"
```

## Backend — Pull List Data Model

### Option: Use existing ERPNext Stock Entry + custom tracking

No new doctype needed. The pull list is a **computed view** from:
- Materials consumed today (from HCP Job materials / stock entries)
- Current truck stock levels (from ERPNext Bin)
- Reorder levels per item per truck (from ERPNext Reorder Level)

### New Doctype: `MTM Pull List Item`

Tracks the state of each item in the pull process.

| Field | Type | Description |
|-------|------|-------------|
| truck_warehouse | Link (Warehouse) | Which truck |
| item_code | Link (Item) | Which item |
| item_name | Data | Denormalized display name |
| required_qty | Float | How many the truck needs |
| pulled_qty | Float | How many Zack pulled |
| status | Select | `Pending`, `Pulled`, `Accepted`, `Rejected`, `Ignored` |
| pulled_by | Link (User) | Who pulled it (Zack) |
| pulled_at | Datetime | When pulled |
| confirmed_by | Link (User) | Tech who accepted/rejected |
| confirmed_at | Datetime | When confirmed |
| reject_note | Small Text | Why rejected |
| source_job | Link (HCP Job) | Job that consumed the item (if from daily usage) |
| date | Date | Pull list date |

### API Endpoints

```python
# Generate/refresh pull list for a truck (or all trucks)
get_pull_list(truck_warehouse=None, date=None)
# → returns { trucks: [{ warehouse, label, items: [...] }] }

# Zack marks items as pulled
mark_pulled(items: [{name, pulled_qty}])

# Tech accepts all items
accept_pull_list(truck_warehouse, date)

# Tech rejects an item
reject_pull_item(name, reject_note)

# Zack handles rejection — swap item
resolve_rejection(name, new_item_code, new_qty)

# Mark item as ignored (won't restock)
ignore_pull_item(name)

# Get pull list summary for badges
get_pull_summary()
# → { total_pending, total_pulled, total_rejected, by_truck: [...] }
```

### Pull List Generation Logic

```python
def generate_pull_list(truck_warehouse, date=None):
    """
    For each item with a reorder level on this truck:
    1. Get current actual_qty from Bin
    2. Get reorder_level for this item+warehouse
    3. If actual_qty < reorder_level: need (reorder_level - actual_qty)
    4. Also check materials consumed today from jobs assigned to this truck's tech
    5. Create/update MTM Pull List Item entries
    """
```

### Scheduler

- Every 15 minutes: refresh pull lists for all trucks (same frequency as HCP sync)
- This keeps lists live as jobs complete throughout the day

## Frontend — Web (Zack's View)

### Location

New sub-tab in `/manager/inventory`: RECEIPTS | WAREHOUSES | LIMBO | **RESTOCK**

### Restock Tab Layout

```
┌─────────────────────────────────────────────────┐
│ RESTOCK                          [Refresh Now]  │
│ Pull lists for today · 23 items across 7 trucks │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─ CHRIS'S TRUCK ─────────── 5 items ────────┐  │
│ │ ☐ 3/4" Copper Coupling      x4    [PULL]   │  │
│ │ ☐ 1/2" PEX Tubing 10ft     x2    [PULL]   │  │
│ │ ☑ Teflon Tape 1/2"         x3    PULLED ✓  │  │
│ │ ☐ SharkBite 1/2" Elbow     x1    [PULL]   │  │
│ │ ⚠ Pipe Dope 8oz            x1    OUT OF    │  │
│ │                                   STOCK     │  │
│ │                        [PULL ALL AVAILABLE] │  │
│ └─────────────────────────────────────────────┘  │
│                                                 │
│ ┌─ WARREN'S TRUCK ────────── 3 items ────────┐  │
│ │ ...                                         │  │
│ └─────────────────────────────────────────────┘  │
│                                                 │
│ ── REJECTIONS (1) ─────────────────────────────  │
│ │ ✗ Adam rejected: 3/4x3/4x1/2 PEX Tee       │  │
│ │   "needed 3/4x1/2x3/4 tee"                  │  │
│ │   [SWAP ITEM] [IGNORE]                       │  │
│ └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Features
- Trucks listed as collapsible sections, sorted by most items needed
- Each item: checkbox, name, qty needed, PULL button (or PULLED status)
- PULL ALL AVAILABLE per truck — marks all in-stock items as pulled
- Out-of-stock items flagged with warning, can't be pulled
- Rejections section at bottom — shows rejected items with tech's note
- SWAP ITEM button → opens item search to replace with correct item
- Refresh Now button → re-generates pull lists from latest data
- Live polling every 60 seconds for new job completions

## Frontend — Mobile (Tech's View)

### Location

New section on mobile HomeScreen or accessible from a notification.

### Tech Pull List View

```
┌─────────────────────────────────────┐
│ YOUR RESTOCK                        │
│ 5 items ready for pickup            │
│                                     │
│ ┌─ 3/4" Copper Coupling ────── x4 ┐│
│ │ Pulled by Zack · 3:45 PM        ││
│ │              [ACCEPT] [REJECT]   ││
│ └──────────────────────────────────┘│
│                                     │
│ [ACCEPT ALL]                        │
│                                     │
│ ── WAITING (out of stock) ────────  │
│ │ Pipe Dope 8oz · x1              ││
│ │ Will be added when available     ││
│ └──────────────────────────────────┘│
└─────────────────────────────────────┘
```

### Features
- Shows only the current tech's truck
- Items grouped: Ready (pulled by Zack) | Waiting (out of stock)
- ACCEPT ALL button — one click confirms everything
- REJECT per item — opens note input, sends back to Zack
- Accept creates the actual Stock Entry (Material Transfer: Office → Truck)

## Stock Movement

- **On Accept:** Stock Entry (Material Transfer) from Office warehouse to Truck warehouse. This is the actual inventory movement.
- **On Reject:** Item goes back to "pending" with note. Zack handles.
- **On Ignore:** Item removed from pull list, no stock movement.

## What's NOT in This Spec

- Supplier ordering (separate spec)
- Job-specific ordering (separate spec)
- Parts usage analytics / recommended levels (separate spec)
- Reorder level auto-adjustment (future, needs data)
- PLY integration (future)
