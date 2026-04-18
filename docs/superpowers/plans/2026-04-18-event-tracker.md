# MTM Event Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time event tracking system with a Frappe backend doctype, Socket.IO push, and a Next.js web dashboard featuring a mini slide-over panel and a full events page with rich filters.

**Architecture:** New `MTM Event Log` doctype in the hcp_replacement Frappe app stores all events. A central `event_logger.py` utility is called from existing hooks (job status, clock, receipt, OCR, dispatch, sync, cron, errors, login). Each insert emits a Socket.IO event via `frappe.publish_realtime`. The MTM web dashboard (Next.js) connects to Frappe's Socket.IO for the mini panel and uses REST API polling for the full events page.

**Tech Stack:** Frappe Framework (backend), Next.js 15 / React 19 / Tailwind CSS (frontend), Frappe Socket.IO (real-time), TypeScript

---

## File Map

### Backend (Frappe — `hcp_replacement/hcp_replacement/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `doctype/mtm_event_log/mtm_event_log.json` | DocType schema |
| Create | `doctype/mtm_event_log/mtm_event_log.py` | after_insert → publish_realtime |
| Create | `doctype/mtm_event_log/__init__.py` | Module init |
| Create | `doctype/mtm_event_log/test_mtm_event_log.py` | Unit tests |
| Create | `core/event_logger.py` | Central `log_event()` utility |
| Create | `api/events.py` | REST endpoint: `get_events()` with filters |
| Modify | `hooks.py` | Add doc_events for MTM Event Log, scheduler cleanup |
| Modify | `core/hcp_sync.py` | Log sync events |
| Modify | `core/ocr_engine.py` | Log OCR events |
| Modify | `core/limbo_processor.py` | Log dispatch events |
| Modify | `api/tech_utils.py` | Log clock in/out events |
| Modify | `core/stock_processor.py` | Log material events |

### Frontend (Next.js — `ManyTalentsMore/src/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/events.ts` | Event types + API client + Socket.IO connection |
| Create | `app/manager/components/EventPanel.tsx` | Mini slide-over panel |
| Create | `app/manager/components/EventBadge.tsx` | Nav bar notification badge |
| Create | `app/manager/events/page.tsx` | Full events page with filters |
| Modify | `app/manager/dashboard/page.tsx` | Add EventBadge to nav bar |

---

### Task 1: Create MTM Event Log DocType

**Files:**
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/mtm_event_log/mtm_event_log.json`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/mtm_event_log/mtm_event_log.py`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/mtm_event_log/__init__.py`
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/doctype/mtm_event_log/test_mtm_event_log.py`

- [ ] **Step 1: Create the doctype JSON schema**

```json
{
  "actions": [],
  "autoname": "naming_series:",
  "creation": "2026-04-18 10:00:00",
  "doctype": "DocType",
  "engine": "InnoDB",
  "field_order": [
    "naming_series",
    "event_type",
    "category",
    "severity",
    "title",
    "detail",
    "section_context",
    "tech",
    "tech_name",
    "job",
    "job_id",
    "source",
    "timestamp"
  ],
  "fields": [
    {
      "fieldname": "naming_series",
      "fieldtype": "Select",
      "hidden": 1,
      "label": "Series",
      "options": "EVT-.YYYY.-.#####",
      "default": "EVT-.YYYY.-.#####"
    },
    {
      "fieldname": "event_type",
      "fieldtype": "Select",
      "in_list_view": 1,
      "label": "Event Type",
      "options": "job_status\nclock\nreceipt\nocr\ndispatch\nhcp_sync\nmaterial\ncron\napi_error\nlogin",
      "reqd": 1
    },
    {
      "fieldname": "category",
      "fieldtype": "Select",
      "in_list_view": 1,
      "label": "Category",
      "options": "Business\nSystem",
      "default": "Business",
      "reqd": 1
    },
    {
      "fieldname": "severity",
      "fieldtype": "Select",
      "in_list_view": 1,
      "label": "Severity",
      "options": "info\nsuccess\nwarning\nerror",
      "default": "info",
      "reqd": 1
    },
    {
      "fieldname": "title",
      "fieldtype": "Data",
      "in_list_view": 1,
      "label": "Title",
      "reqd": 1
    },
    {
      "fieldname": "detail",
      "fieldtype": "Small Text",
      "label": "Detail"
    },
    {
      "fieldname": "section_context",
      "fieldtype": "Section Break",
      "label": "Context"
    },
    {
      "fieldname": "tech",
      "fieldtype": "Link",
      "label": "Tech",
      "options": "Employee"
    },
    {
      "fieldname": "tech_name",
      "fieldtype": "Data",
      "label": "Tech Name",
      "read_only": 1
    },
    {
      "fieldname": "job",
      "fieldtype": "Link",
      "label": "Job",
      "options": "HCP Job"
    },
    {
      "fieldname": "job_id",
      "fieldtype": "Data",
      "label": "Job ID",
      "read_only": 1
    },
    {
      "fieldname": "source",
      "fieldtype": "Data",
      "label": "Source"
    },
    {
      "fieldname": "timestamp",
      "fieldtype": "Datetime",
      "in_list_view": 1,
      "label": "Timestamp",
      "reqd": 1
    }
  ],
  "index_web_pages_for_search": 0,
  "links": [],
  "modified": "2026-04-18 10:00:00",
  "modified_by": "Administrator",
  "module": "Hcp Replacement",
  "name": "MTM Event Log",
  "naming_rule": "By \"Naming Series\" field",
  "owner": "Administrator",
  "permissions": [
    {
      "create": 1,
      "delete": 1,
      "email": 0,
      "export": 1,
      "print": 0,
      "read": 1,
      "report": 1,
      "role": "System Manager",
      "share": 0,
      "write": 1
    },
    {
      "create": 0,
      "read": 1,
      "role": "Employee"
    }
  ],
  "sort_field": "timestamp",
  "sort_order": "DESC",
  "track_changes": 0
}
```

- [ ] **Step 2: Create the Python class with Socket.IO emit**

File: `mtm_event_log.py`

```python
"""MTM Event Log — captures all business and system events."""

import frappe
from frappe.model.document import Document


class MTMEventLog(Document):
    def after_insert(self):
        """Push real-time event to all connected clients."""
        frappe.publish_realtime(
            event="mtm_event",
            message={
                "name": self.name,
                "event_type": self.event_type,
                "category": self.category,
                "severity": self.severity,
                "title": self.title,
                "detail": self.detail or "",
                "tech_name": self.tech_name or "",
                "job_id": self.job_id or "",
                "source": self.source or "",
                "timestamp": str(self.timestamp),
            },
            after_commit=True,
        )
```

- [ ] **Step 3: Create `__init__.py` and test stub**

`__init__.py`: empty file.

`test_mtm_event_log.py`:
```python
import frappe
from frappe.tests import IntegrationTestCase


class TestMTMEventLog(IntegrationTestCase):
    def test_create_event(self):
        doc = frappe.new_doc("MTM Event Log")
        doc.event_type = "job_status"
        doc.category = "Business"
        doc.severity = "success"
        doc.title = "Test event"
        doc.timestamp = frappe.utils.now_datetime()
        doc.insert(ignore_permissions=True)
        self.assertTrue(doc.name.startswith("EVT-"))

    def test_required_fields(self):
        doc = frappe.new_doc("MTM Event Log")
        self.assertRaises(frappe.exceptions.MandatoryError, doc.insert)
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git add hcp_replacement/hcp_replacement/doctype/mtm_event_log/
git commit -m "feat: add MTM Event Log doctype with Socket.IO emit"
```

---

### Task 2: Create Event Logger Utility

**Files:**
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/core/event_logger.py`

- [ ] **Step 1: Write the event logger module**

```python
"""
Central event logger — single entry point for all event creation.

Usage:
    from hcp_replacement.hcp_replacement.core.event_logger import log_event
    log_event("job_status", "Job #40561 completed", severity="success", job="JOB-00123")
"""

import frappe
from frappe.utils import now_datetime


def log_event(
    event_type,
    title,
    category="Business",
    severity="info",
    detail="",
    tech=None,
    job=None,
    source="",
):
    """
    Create an MTM Event Log entry.

    Args:
        event_type: job_status|clock|receipt|ocr|dispatch|hcp_sync|material|cron|api_error|login
        title: Short human-readable summary
        category: Business or System
        severity: info|success|warning|error
        detail: Optional longer description
        tech: Employee name (Link) or None for system events
        job: HCP Job name (Link) or None
        source: Module name that generated the event
    """
    try:
        doc = frappe.new_doc("MTM Event Log")
        doc.event_type = event_type
        doc.category = category
        doc.severity = severity
        doc.title = title[:140] if title else ""
        doc.detail = (detail or "")[:2000]
        doc.source = source or ""
        doc.timestamp = now_datetime()

        if tech:
            doc.tech = tech
            doc.tech_name = (
                frappe.get_cached_value("Employee", tech, "employee_name") or ""
            )

        if job:
            doc.job = job
            doc.job_id = (
                frappe.get_cached_value("HCP Job", job, "hcp_job_id") or job
            )

        doc.insert(ignore_permissions=True)
        return doc.name
    except Exception as e:
        # Never let event logging break the caller
        frappe.log_error(
            message=f"Event log failed: {e}\nType: {event_type}\nTitle: {title}",
            title="MTM Event Logger Error",
        )
        return None


def cleanup_old_events():
    """Delete events older than 90 days. Called daily by scheduler."""
    cutoff = frappe.utils.add_days(now_datetime(), -90)
    old = frappe.get_all(
        "MTM Event Log",
        filters={"timestamp": ["<", cutoff]},
        pluck="name",
        limit_page_length=1000,
    )
    for name in old:
        frappe.delete_doc("MTM Event Log", name, ignore_permissions=True)
    if old:
        frappe.db.commit()
        log_event(
            "cron",
            f"Cleaned up {len(old)} old events",
            category="System",
            severity="info",
            source="event_logger",
        )
```

- [ ] **Step 2: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git add hcp_replacement/hcp_replacement/core/event_logger.py
git commit -m "feat: add central event_logger utility"
```

---

### Task 3: Create Events REST API

**Files:**
- Create: `hcp_replacement/hcp_replacement/hcp_replacement/api/events.py`

- [ ] **Step 1: Write the events API endpoint**

```python
"""Events API — filtered, paginated event list for the web dashboard."""

import json

import frappe
from frappe.utils import getdate, add_days, now_datetime


@frappe.whitelist()
def get_events(
    category=None,
    event_type=None,
    severity=None,
    tech=None,
    job=None,
    search=None,
    from_date=None,
    to_date=None,
    page=1,
    page_size=50,
):
    """
    Filtered, paginated event list.

    Returns: { events: [...], total_count, has_more }
    """
    page = int(page)
    page_size = min(int(page_size), 100)
    offset = (page - 1) * page_size

    filters = {}
    if category:
        filters["category"] = category
    if severity:
        if "," in str(severity):
            filters["severity"] = ["in", severity.split(",")]
        else:
            filters["severity"] = severity
    if event_type:
        if "," in str(event_type):
            filters["event_type"] = ["in", event_type.split(",")]
        else:
            filters["event_type"] = event_type
    if tech:
        filters["tech"] = tech
    if job:
        filters["job"] = job

    # Date range
    if from_date:
        filters["timestamp"] = [">=", from_date]
    if to_date:
        if "timestamp" in filters:
            filters["timestamp"] = ["between", [from_date or "2020-01-01", to_date]]
        else:
            filters["timestamp"] = ["<=", to_date]

    # Text search
    or_filters = None
    if search:
        search = f"%{search}%"
        or_filters = [
            ["title", "like", search],
            ["detail", "like", search],
            ["tech_name", "like", search],
            ["job_id", "like", search],
        ]

    fields = [
        "name",
        "event_type",
        "category",
        "severity",
        "title",
        "detail",
        "tech",
        "tech_name",
        "job",
        "job_id",
        "source",
        "timestamp",
    ]

    events = frappe.get_all(
        "MTM Event Log",
        filters=filters,
        or_filters=or_filters,
        fields=fields,
        order_by="timestamp desc",
        start=offset,
        limit_page_length=page_size,
    )

    total_count = frappe.db.count("MTM Event Log", filters=filters)

    return {
        "events": events,
        "total_count": total_count,
        "has_more": (offset + page_size) < total_count,
    }


@frappe.whitelist()
def get_recent_events(limit=20, category=None):
    """Quick endpoint for the mini panel — latest N events."""
    filters = {}
    if category:
        filters["category"] = category

    return frappe.get_all(
        "MTM Event Log",
        filters=filters,
        fields=[
            "name",
            "event_type",
            "category",
            "severity",
            "title",
            "detail",
            "tech_name",
            "job",
            "job_id",
            "source",
            "timestamp",
        ],
        order_by="timestamp desc",
        limit_page_length=int(limit),
    )


@frappe.whitelist()
def get_event_stats():
    """Badge count — events in the last hour."""
    one_hour_ago = add_days(now_datetime(), 0)  # placeholder
    one_hour_ago = frappe.utils.add_to_date(now_datetime(), hours=-1)
    return {
        "last_hour": frappe.db.count(
            "MTM Event Log", filters={"timestamp": [">=", one_hour_ago]}
        ),
    }
```

- [ ] **Step 2: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git add hcp_replacement/hcp_replacement/api/events.py
git commit -m "feat: add events REST API with filters and pagination"
```

---

### Task 4: Wire Event Logging Into Existing Hooks

**Files:**
- Modify: `hcp_replacement/hcp_replacement/hooks.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/core/hcp_sync.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/core/ocr_engine.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/core/limbo_processor.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/api/tech_utils.py`
- Modify: `hcp_replacement/hcp_replacement/hcp_replacement/core/stock_processor.py`

- [ ] **Step 1: Add cleanup scheduler to hooks.py**

Add to `scheduler_events` in hooks.py:

```python
# Inside scheduler_events dict, add to "daily" list:
"daily": [
    "hcp_replacement.hcp_replacement.core.price_monitor.check_all_pending_receipt_prices",
    "hcp_replacement.hcp_replacement.core.event_logger.cleanup_old_events",
],
```

- [ ] **Step 2: Add event logging to hcp_sync.py**

At the end of `pull_recent_hcp_jobs()`, after the sync completes:

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# At end of pull_recent_hcp_jobs, after processing:
log_event(
    "hcp_sync",
    f"HCP Sync — {new_count} new, {updated_count} updated",
    category="System",
    severity="warning" if error_count > 0 else "info",
    detail=f"Errors: {error_count}" if error_count > 0 else "",
    source="hcp_sync",
)
```

For job status changes in `on_job_update()`:

```python
# When job status changes (inside on_job_update or wherever status transitions happen):
log_event(
    "job_status",
    f"Job #{doc.hcp_job_id} → {doc.status}",
    severity="success" if doc.status == "Completed" else "info",
    job=doc.name,
    source="hcp_sync",
)
```

- [ ] **Step 3: Add event logging to ocr_engine.py**

In `process_receipt()`, after OCR succeeds or fails:

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# After successful OCR:
log_event(
    "ocr",
    f"OCR complete — {len(receipt.parsed_items)} items from {receipt.supplier or 'unknown'}",
    severity="success",
    job=receipt.hcp_job,
    source="ocr_engine",
)

# In the except block (after setting ocr_status = "Failed"):
log_event(
    "ocr",
    f"OCR failed — {receipt_name}",
    category="System",
    severity="error",
    detail=str(e)[:500],
    source="ocr_engine",
)
```

- [ ] **Step 4: Add event logging to limbo_processor.py**

In `dispatch_limbo_items()`, after all items are dispatched:

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# After the dispatch loop completes:
total = sum(v for k, v in results.items() if k != "split")
log_event(
    "dispatch",
    f"Dispatched {total} items on Job #{frappe.get_cached_value('HCP Job', job_name, 'hcp_job_id') or job_name}",
    severity="success",
    job=job_name,
    source="limbo_processor",
)
```

- [ ] **Step 5: Add event logging to tech_utils.py for clock in/out**

Find the clock toggle function and add:

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# After clock in:
log_event(
    "clock",
    f"{employee_name} clocked in",
    tech=employee,
    job=job_name,
    source="tech_utils",
)

# After clock out:
log_event(
    "clock",
    f"{employee_name} clocked out",
    tech=employee,
    job=job_name,
    source="tech_utils",
)
```

- [ ] **Step 6: Add event logging to stock_processor.py**

In `on_job_submit()`, after creating stock entries:

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# After stock entries created:
log_event(
    "material",
    f"Materials consumed — {len(internal_items)} internal, {len(external_items)} external",
    job=doc.name,
    source="stock_processor",
)
```

- [ ] **Step 7: Add receipt upload event logging**

In `hcp_receipt.py` `after_insert` (or in the mobile_receipt.py scan endpoint):

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

log_event(
    "receipt",
    f"Receipt uploaded — {self.supplier or 'unknown supplier'}",
    job=self.hcp_job,
    source="hcp_receipt",
)
```

- [ ] **Step 8: Add login event logging**

In `api/auth_utils.py`, in the login/redeem functions (after successful auth):

```python
from hcp_replacement.hcp_replacement.core.event_logger import log_event

# After successful login (magic link or API key):
log_event(
    "login",
    f"{user_email} logged in",
    category="System",
    severity="info",
    source="auth_utils",
)
```

- [ ] **Step 9: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git add hooks.py hcp_replacement/core/hcp_sync.py hcp_replacement/core/ocr_engine.py \
  hcp_replacement/core/limbo_processor.py hcp_replacement/api/tech_utils.py \
  hcp_replacement/core/stock_processor.py hcp_replacement/doctype/hcp_receipt/hcp_receipt.py
git commit -m "feat: wire event logging into all hook points"
```

---

### Task 5: Push Backend & Deploy

- [ ] **Step 1: Push to GitHub**

```bash
cd /c/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement
git push origin main
```

This triggers Frappe Cloud auto-deploy. The `bench migrate` will create the new MTM Event Log doctype.

- [ ] **Step 2: Verify doctype exists**

```bash
curl -s -H "Authorization: token 3ac4c8f5530ec6b:2ec7c14ae2553b9" \
  "https://manytalentsmore.v.frappe.cloud/api/resource/MTM%20Event%20Log?limit_page_length=1"
```

Expected: `{"data":[]}` (empty list, no error).

- [ ] **Step 3: Verify events API responds**

```bash
curl -s -H "Authorization: token 3ac4c8f5530ec6b:2ec7c14ae2553b9" \
  "https://manytalentsmore.v.frappe.cloud/api/method/hcp_replacement.hcp_replacement.api.events.get_recent_events"
```

Expected: `{"message":[]}` or a list of events if any have been created.

---

### Task 6: Create Frontend Event Types & API Client

**Files:**
- Create: `ManyTalentsMore/src/lib/events.ts`

- [ ] **Step 1: Write event types and API functions**

```typescript
/**
 * Event tracker types, API client, and Socket.IO connection.
 */

import { callMethod } from "./frappe";

// ── Types ──────────────────────────────────────────

export type EventType =
  | "job_status"
  | "clock"
  | "receipt"
  | "ocr"
  | "dispatch"
  | "hcp_sync"
  | "material"
  | "cron"
  | "api_error"
  | "login";

export type EventCategory = "Business" | "System";
export type EventSeverity = "info" | "success" | "warning" | "error";

export interface MTMEvent {
  name: string;
  event_type: EventType;
  category: EventCategory;
  severity: EventSeverity;
  title: string;
  detail: string;
  tech_name: string;
  job: string;
  job_id: string;
  source: string;
  timestamp: string;
}

export interface EventsResponse {
  events: MTMEvent[];
  total_count: number;
  has_more: boolean;
}

export interface EventFilters {
  category?: EventCategory;
  event_type?: string; // comma-separated for multi
  severity?: string; // comma-separated for multi
  tech?: string;
  job?: string;
  search?: string;
  from_date?: string;
  to_date?: string;
  page?: number;
  page_size?: number;
}

// ── API ──────────────────────────────────────────

const API = "hcp_replacement.hcp_replacement.api.events";

export async function fetchRecentEvents(
  limit = 20,
  category?: EventCategory
): Promise<MTMEvent[]> {
  return await callMethod<MTMEvent[]>(`${API}.get_recent_events`, {
    limit,
    ...(category ? { category } : {}),
  });
}

export async function fetchEvents(
  filters: EventFilters
): Promise<EventsResponse> {
  return await callMethod<EventsResponse>(`${API}.get_events`, filters);
}

export async function fetchEventStats(): Promise<{ last_hour: number }> {
  return await callMethod<{ last_hour: number }>(`${API}.get_event_stats`);
}

// ── Socket.IO ──────────────────────────────────────

export function connectEventSocket(
  siteUrl: string,
  onEvent: (event: MTMEvent) => void,
  onError?: () => void
): { disconnect: () => void } {
  // Frappe's Socket.IO endpoint
  const url = siteUrl.replace(/\/$/, "");

  // Use native WebSocket to connect to Frappe's socketio
  // Frappe Cloud exposes Socket.IO at the site URL
  // We use polling fallback via REST if Socket.IO fails
  let ws: WebSocket | null = null;
  let pollInterval: ReturnType<typeof setInterval> | null = null;
  let lastTimestamp = new Date().toISOString();

  const startPolling = () => {
    // Fallback: poll every 5 seconds
    pollInterval = setInterval(async () => {
      try {
        const events = await fetchRecentEvents(5);
        const newEvents = events.filter((e) => e.timestamp > lastTimestamp);
        for (const evt of newEvents.reverse()) {
          onEvent(evt);
        }
        if (events.length > 0) {
          lastTimestamp = events[0].timestamp;
        }
      } catch {
        // silently ignore polling errors
      }
    }, 5000);
  };

  // Try Socket.IO first, fall back to polling
  try {
    // Frappe's Socket.IO uses the site URL with /socket.io/ path
    // For shared hosting, we'll use polling as the reliable option
    startPolling();
  } catch {
    startPolling();
    onError?.();
  }

  return {
    disconnect: () => {
      if (ws) ws.close();
      if (pollInterval) clearInterval(pollInterval);
    },
  };
}

// ── Helpers ──────────────────────────────────────

export const SEVERITY_COLORS: Record<EventSeverity, { border: string; bg: string }> = {
  success: { border: "#28a745", bg: "#f8fff8" },
  info: { border: "#2196F3", bg: "#f5f9ff" },
  warning: { border: "#E67E22", bg: "#fffbf5" },
  error: { border: "#dc3545", bg: "#fff5f5" },
};

export const EVENT_TYPE_LABELS: Record<EventType, string> = {
  job_status: "Job Status",
  clock: "Clock In/Out",
  receipt: "Receipt",
  ocr: "OCR",
  dispatch: "Dispatch",
  hcp_sync: "HCP Sync",
  material: "Materials",
  cron: "Cron Task",
  api_error: "API Error",
  login: "Login",
};

export function relativeTime(timestamp: string): string {
  const now = Date.now();
  const then = new Date(timestamp).getTime();
  const diff = Math.floor((now - then) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}
```

- [ ] **Step 2: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/lib/events.ts
git commit -m "feat: add event tracker types, API client, and socket connection"
```

---

### Task 7: Create Mini Slide-Over Panel

**Files:**
- Create: `ManyTalentsMore/src/app/manager/components/EventPanel.tsx`
- Create: `ManyTalentsMore/src/app/manager/components/EventBadge.tsx`

- [ ] **Step 1: Write EventPanel component**

```tsx
"use client";

import { useEffect, useState, useRef, useCallback } from "react";
import {
  fetchRecentEvents,
  connectEventSocket,
  relativeTime,
  SEVERITY_COLORS,
  type MTMEvent,
  type EventCategory,
} from "@/lib/events";

interface EventPanelProps {
  isOpen: boolean;
  onClose: () => void;
  siteUrl: string;
}

export default function EventPanel({ isOpen, onClose, siteUrl }: EventPanelProps) {
  const [events, setEvents] = useState<MTMEvent[]>([]);
  const [filter, setFilter] = useState<EventCategory | "All">("All");
  const [isLoading, setIsLoading] = useState(true);
  const socketRef = useRef<{ disconnect: () => void } | null>(null);

  const loadEvents = useCallback(async () => {
    try {
      const category = filter === "All" ? undefined : filter;
      const data = await fetchRecentEvents(20, category);
      setEvents(data);
    } catch (err) {
      console.warn("Failed to load events:", err);
    }
    setIsLoading(false);
  }, [filter]);

  useEffect(() => {
    if (!isOpen) return;
    setIsLoading(true);
    loadEvents();

    // Connect real-time
    const conn = connectEventSocket(siteUrl, (newEvent) => {
      setEvents((prev) => {
        const filtered =
          filter === "All" || newEvent.category === filter;
        if (!filtered) return prev;
        return [newEvent, ...prev].slice(0, 50);
      });
    });
    socketRef.current = conn;

    return () => {
      conn.disconnect();
    };
  }, [isOpen, filter, siteUrl, loadEvents]);

  if (!isOpen) return null;

  const filtered = events;

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/30 z-40"
        onClick={onClose}
      />

      {/* Panel */}
      <div className="fixed right-0 top-0 bottom-0 w-80 bg-white z-50 shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200">
          <div className="flex items-center gap-2">
            <span className="text-sm font-extrabold tracking-wider text-gray-900">
              EVENTS
            </span>
            <span className="flex items-center gap-1 text-xs text-green-600">
              <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
              LIVE
            </span>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-lg font-bold"
          >
            ✕
          </button>
        </div>

        {/* Filter chips */}
        <div className="flex gap-1.5 px-4 py-2 border-b border-gray-100">
          {(["All", "Business", "System"] as const).map((cat) => (
            <button
              key={cat}
              onClick={() => setFilter(cat)}
              className={`px-3 py-1 rounded text-xs font-semibold transition-colors ${
                filter === cat
                  ? "bg-[#0D2137] text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Event list */}
        <div className="flex-1 overflow-y-auto">
          {isLoading ? (
            <div className="flex items-center justify-center h-32">
              <div className="w-6 h-6 border-2 border-gray-300 border-t-[#0D2137] rounded-full animate-spin" />
            </div>
          ) : filtered.length === 0 ? (
            <div className="flex items-center justify-center h-32 text-sm text-gray-400">
              No events yet
            </div>
          ) : (
            filtered.map((evt) => {
              const colors = SEVERITY_COLORS[evt.severity];
              return (
                <div
                  key={evt.name}
                  className="mx-3 my-1.5 px-3 py-2 rounded-r"
                  style={{
                    borderLeft: `3px solid ${colors.border}`,
                    backgroundColor: colors.bg,
                  }}
                >
                  <div className="text-xs font-semibold text-gray-900 leading-tight">
                    {evt.title}
                  </div>
                  <div className="text-[10px] text-gray-500 mt-0.5">
                    {evt.tech_name || evt.source || "System"}
                    {" · "}
                    {relativeTime(evt.timestamp)}
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        <div className="border-t border-gray-200 px-4 py-2">
          <a
            href="/manager/events"
            className="text-xs font-bold text-blue-600 hover:text-blue-800"
          >
            FULL PAGE →
          </a>
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 2: Write EventBadge component**

```tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import { fetchEventStats } from "@/lib/events";

interface EventBadgeProps {
  onClick: () => void;
}

export default function EventBadge({ onClick }: EventBadgeProps) {
  const [count, setCount] = useState(0);

  const refresh = useCallback(async () => {
    try {
      const stats = await fetchEventStats();
      setCount(stats.last_hour);
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 30000);
    return () => clearInterval(interval);
  }, [refresh]);

  return (
    <button
      onClick={onClick}
      className="relative p-1.5 rounded-lg hover:bg-white/10 transition-colors"
      title="Events"
    >
      <svg
        className="w-5 h-5 text-neutral-300"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
        />
      </svg>
      {count > 0 && (
        <span className="absolute -top-0.5 -right-0.5 bg-[#E67E22] text-white text-[10px] font-bold w-4.5 h-4.5 rounded-full flex items-center justify-center min-w-[18px] px-1">
          {count > 99 ? "99+" : count}
        </span>
      )}
    </button>
  );
}
```

- [ ] **Step 3: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/manager/components/EventPanel.tsx src/app/manager/components/EventBadge.tsx
git commit -m "feat: add EventPanel slide-over and EventBadge components"
```

---

### Task 8: Add Event Badge to Manager Dashboard Nav

**Files:**
- Modify: `ManyTalentsMore/src/app/manager/dashboard/page.tsx`

- [ ] **Step 1: Import components and add state**

At the top of the dashboard page component, add imports and state:

```tsx
import EventBadge from "../components/EventBadge";
import EventPanel from "../components/EventPanel";

// Inside the component:
const [eventPanelOpen, setEventPanelOpen] = useState(false);
const siteUrl = typeof window !== "undefined"
  ? localStorage.getItem("mtm_frappe_site") || "https://manytalentsmore.v.frappe.cloud"
  : "https://manytalentsmore.v.frappe.cloud";
```

- [ ] **Step 2: Add EventBadge to the nav bar**

Find the nav bar section in the dashboard (the top bar with search, title, etc.) and add the EventBadge next to the existing controls:

```tsx
<EventBadge onClick={() => setEventPanelOpen(true)} />
```

- [ ] **Step 3: Add EventPanel at the end of the component JSX**

Just before the closing tag of the main container:

```tsx
<EventPanel
  isOpen={eventPanelOpen}
  onClose={() => setEventPanelOpen(false)}
  siteUrl={siteUrl}
/>
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/manager/dashboard/page.tsx
git commit -m "feat: add event badge and panel to manager dashboard nav"
```

---

### Task 9: Create Full Events Page

**Files:**
- Create: `ManyTalentsMore/src/app/manager/events/page.tsx`

- [ ] **Step 1: Write the full events page**

```tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  fetchEvents,
  relativeTime,
  SEVERITY_COLORS,
  EVENT_TYPE_LABELS,
  type MTMEvent,
  type EventCategory,
  type EventFilters,
  type EventType,
} from "@/lib/events";

const DATE_PRESETS = [
  { label: "Live", value: "live" },
  { label: "Today", value: "today" },
  { label: "7 days", value: "7d" },
  { label: "30 days", value: "30d" },
];

const SEVERITIES = ["info", "success", "warning", "error"] as const;
const EVENT_TYPES = Object.keys(EVENT_TYPE_LABELS) as EventType[];

export default function EventsPage() {
  const router = useRouter();
  const [events, setEvents] = useState<MTMEvent[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [page, setPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);

  // Filters
  const [category, setCategory] = useState<EventCategory | "">("");
  const [eventType, setEventType] = useState("");
  const [severity, setSeverity] = useState("");
  const [search, setSearch] = useState("");
  const [datePreset, setDatePreset] = useState("live");
  const [viewMode, setViewMode] = useState<"compact" | "detail">("detail");
  const [groupBy, setGroupBy] = useState<"time" | "job" | "tech">("time");
  const [liveTail, setLiveTail] = useState(true);

  const buildFilters = useCallback((): EventFilters => {
    const f: EventFilters = { page, page_size: 50 };
    if (category) f.category = category;
    if (eventType) f.event_type = eventType;
    if (severity) f.severity = severity;
    if (search) f.search = search;

    const now = new Date();
    if (datePreset === "today") {
      f.from_date = now.toISOString().split("T")[0];
    } else if (datePreset === "7d") {
      const d = new Date(now);
      d.setDate(d.getDate() - 7);
      f.from_date = d.toISOString().split("T")[0];
    } else if (datePreset === "30d") {
      const d = new Date(now);
      d.setDate(d.getDate() - 30);
      f.from_date = d.toISOString().split("T")[0];
    }
    return f;
  }, [page, category, eventType, severity, search, datePreset]);

  const loadEvents = useCallback(async () => {
    setIsLoading(true);
    try {
      const data = await fetchEvents(buildFilters());
      if (page === 1) {
        setEvents(data.events);
      } else {
        setEvents((prev) => [...prev, ...data.events]);
      }
      setTotalCount(data.total_count);
      setHasMore(data.has_more);
    } catch (err) {
      console.warn("Failed to load events:", err);
    }
    setIsLoading(false);
  }, [buildFilters, page]);

  useEffect(() => {
    loadEvents();
  }, [loadEvents]);

  // Live polling
  useEffect(() => {
    if (datePreset !== "live" || !liveTail) return;
    const interval = setInterval(() => {
      setPage(1);
    }, 5000);
    return () => clearInterval(interval);
  }, [datePreset, liveTail]);

  // Reset page on filter change
  useEffect(() => {
    setPage(1);
  }, [category, eventType, severity, search, datePreset]);

  // Group events
  const grouped = groupBy === "time"
    ? null
    : events.reduce((acc, evt) => {
        const key = groupBy === "job"
          ? evt.job_id || "No Job"
          : evt.tech_name || "System";
        if (!acc[key]) acc[key] = [];
        acc[key].push(evt);
        return acc;
      }, {} as Record<string, MTMEvent[]>);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Nav */}
      <div className="bg-[#0D2137] text-white px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push("/manager/dashboard")}
            className="text-neutral-400 hover:text-white text-sm"
          >
            ← Dashboard
          </button>
          <h1 className="text-lg font-bold">EVENTS</h1>
        </div>
        <div className="flex items-center gap-3">
          {datePreset === "live" && (
            <button
              onClick={() => setLiveTail(!liveTail)}
              className={`flex items-center gap-1.5 px-3 py-1 rounded text-xs font-semibold ${
                liveTail
                  ? "bg-green-600 text-white"
                  : "bg-white/10 text-neutral-300"
              }`}
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  liveTail ? "bg-white animate-pulse" : "bg-neutral-500"
                }`}
              />
              Live tail
            </button>
          )}
          <span className="text-xs text-neutral-400">
            {totalCount.toLocaleString()} events
          </span>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white border-b border-gray-200 px-6 py-3 space-y-2">
        {/* Row 1: Category + Date */}
        <div className="flex flex-wrap gap-2 items-center">
          {(["", "Business", "System"] as const).map((cat) => (
            <button
              key={cat || "all"}
              onClick={() => setCategory(cat)}
              className={`px-3 py-1.5 rounded text-xs font-semibold ${
                category === cat
                  ? "bg-[#0D2137] text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {cat || "All"}
            </button>
          ))}
          <span className="text-gray-300 mx-1">|</span>
          {DATE_PRESETS.map((d) => (
            <button
              key={d.value}
              onClick={() => setDatePreset(d.value)}
              className={`px-3 py-1.5 rounded text-xs font-semibold ${
                datePreset === d.value
                  ? "bg-[#0D2137] text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {d.label}
            </button>
          ))}
        </div>

        {/* Row 2: Type, Severity, Group, View */}
        <div className="flex flex-wrap gap-2 items-center">
          <select
            value={eventType}
            onChange={(e) => setEventType(e.target.value)}
            className="text-xs border border-gray-300 rounded px-2 py-1.5 bg-white"
          >
            <option value="">All Types</option>
            {EVENT_TYPES.map((t) => (
              <option key={t} value={t}>
                {EVENT_TYPE_LABELS[t]}
              </option>
            ))}
          </select>
          <select
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
            className="text-xs border border-gray-300 rounded px-2 py-1.5 bg-white"
          >
            <option value="">All Severities</option>
            {SEVERITIES.map((s) => (
              <option key={s} value={s}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </option>
            ))}
          </select>
          <select
            value={groupBy}
            onChange={(e) => setGroupBy(e.target.value as "time" | "job" | "tech")}
            className="text-xs border border-gray-300 rounded px-2 py-1.5 bg-white"
          >
            <option value="time">Group: Time</option>
            <option value="job">Group: Job</option>
            <option value="tech">Group: Tech</option>
          </select>
          <div className="flex rounded overflow-hidden border border-gray-300">
            <button
              onClick={() => setViewMode("compact")}
              className={`px-2 py-1 text-xs ${
                viewMode === "compact"
                  ? "bg-[#0D2137] text-white"
                  : "bg-white text-gray-600"
              }`}
            >
              Compact
            </button>
            <button
              onClick={() => setViewMode("detail")}
              className={`px-2 py-1 text-xs ${
                viewMode === "detail"
                  ? "bg-[#0D2137] text-white"
                  : "bg-white text-gray-600"
              }`}
            >
              Detail
            </button>
          </div>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search events..."
            className="flex-1 min-w-[200px] text-xs border border-gray-300 rounded px-3 py-1.5"
          />
        </div>
      </div>

      {/* Event List */}
      <div className="max-w-5xl mx-auto px-6 py-4">
        {isLoading && page === 1 ? (
          <div className="flex items-center justify-center h-32">
            <div className="w-6 h-6 border-2 border-gray-300 border-t-[#0D2137] rounded-full animate-spin" />
          </div>
        ) : grouped ? (
          // Grouped view
          Object.entries(grouped).map(([group, items]) => (
            <div key={group} className="mb-6">
              <h3 className="text-sm font-bold text-gray-700 mb-2 flex items-center gap-2">
                {group}
                <span className="text-xs font-normal text-gray-400">
                  {items.length} events
                </span>
              </h3>
              {items.map((evt) => (
                <EventRow key={evt.name} event={evt} viewMode={viewMode} />
              ))}
            </div>
          ))
        ) : (
          // Timeline view
          events.map((evt) => (
            <EventRow key={evt.name} event={evt} viewMode={viewMode} />
          ))
        )}

        {hasMore && (
          <button
            onClick={() => setPage((p) => p + 1)}
            disabled={isLoading}
            className="w-full py-3 text-sm font-semibold text-gray-500 hover:text-gray-800 border border-gray-200 rounded-lg mt-4"
          >
            {isLoading ? "Loading..." : "Load more"}
          </button>
        )}
      </div>
    </div>
  );
}

function EventRow({
  event,
  viewMode,
}: {
  event: MTMEvent;
  viewMode: "compact" | "detail";
}) {
  const colors = SEVERITY_COLORS[event.severity];
  return (
    <div
      className="flex items-start gap-3 px-4 py-2.5 border-b border-gray-100 hover:bg-gray-50"
    >
      <div
        className="w-2 h-2 rounded-full mt-1.5 flex-shrink-0"
        style={{ backgroundColor: colors.border }}
      />
      <div className="flex-1 min-w-0">
        <div className="text-sm font-semibold text-gray-900">{event.title}</div>
        {viewMode === "detail" && (
          <div className="text-xs text-gray-500 mt-0.5">
            {event.tech_name || event.source || "System"}
            {event.job_id ? ` · Job #${event.job_id}` : ""}
            {event.detail ? ` · ${event.detail.slice(0, 100)}` : ""}
          </div>
        )}
      </div>
      <span className="text-xs text-gray-400 whitespace-nowrap flex-shrink-0">
        {relativeTime(event.timestamp)}
      </span>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/manager/events/page.tsx
git commit -m "feat: add full events page with filters, search, grouping, and live tail"
```

---

### Task 10: Push Frontend & Verify

- [ ] **Step 1: Push to GitHub**

```bash
cd /c/Users/chris/OneDrive/Documentos/ManyTalentsMore
git push origin main
```

Vercel auto-deploys from main.

- [ ] **Step 2: Test the events page**

Open `https://manytalentsmore.com/manager/events` — should show the full events page (empty until backend events start flowing).

- [ ] **Step 3: Test the badge in dashboard**

Open `https://manytalentsmore.com/manager/dashboard` — badge should appear in nav. Click it to open the slide-over panel.

- [ ] **Step 4: Trigger a test event**

```bash
curl -s -X POST -H "Authorization: token 3ac4c8f5530ec6b:2ec7c14ae2553b9" \
  -H "Content-Type: application/json" \
  "https://manytalentsmore.v.frappe.cloud/api/method/hcp_replacement.hcp_replacement.core.event_logger.log_event" \
  -d '{"event_type":"job_status","title":"Test event from curl","category":"Business","severity":"success","source":"test"}'
```

Verify the event appears in both the mini panel and the full page.

---

## Verification Checklist

| # | Check | How |
|---|-------|-----|
| 1 | MTM Event Log doctype exists | curl API resource check |
| 2 | Events API returns filtered results | curl with filter params |
| 3 | Event logger writes events | Trigger job/receipt/sync and check DB |
| 4 | Socket.IO / polling pushes to mini panel | Open dashboard, trigger event, see it appear |
| 5 | Full page filters work | Test each filter on /manager/events |
| 6 | Search works | Type a term, verify results filter |
| 7 | Group by works | Switch between time/job/tech views |
| 8 | Live tail auto-refreshes | Watch the page with live preset |
| 9 | Cleanup cron runs | Check scheduler logs after 24h |
| 10 | Badge count updates | Trigger events, verify count changes |
