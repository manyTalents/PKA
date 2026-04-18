# MTM Event Tracker — Design Spec

## Goal

A real-time event tracking system that captures every business and system event across MTM, displayed in the web dashboard as a mini slide-over panel (live feed) and a full events page (with rich filters and search).

## Architecture

```
Frappe Backend (source of truth)
  └── MTM Event Log doctype
        ├── Written by hooks on job/receipt/clock/sync/dispatch/cron/error/login events
        ├── Emits Socket.IO event on each insert
        └── REST API for filtered queries (full page)

MTM Web Dashboard (Next.js)
  ├── Mini Slide-Over Panel
  │     ├── Socket.IO connection to Frappe Cloud
  │     ├── Live feed of latest 20 events
  │     └── Business / System / All toggle
  └── Full Events Page (/manager/events)
        ├── REST API polling with filters
        ├── All filter controls
        ├── Group by, search, view modes
        └── Infinite scroll
```

## Backend — MTM Event Log Doctype

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `event_type` | Select | `job_status`, `clock`, `receipt`, `ocr`, `dispatch`, `hcp_sync`, `material`, `cron`, `api_error`, `login` |
| `category` | Select | `Business`, `System` |
| `severity` | Select | `info`, `success`, `warning`, `error` |
| `title` | Data | Short human-readable summary (e.g., "Job #40561 completed") |
| `detail` | Small Text | Optional longer description (e.g., error traceback, sync stats) |
| `tech` | Link (Employee) | Which tech triggered it (null for system events) |
| `tech_name` | Data | Denormalized tech name for fast display |
| `job` | Link (HCP Job) | Related job (null if not job-specific) |
| `job_id` | Data | Denormalized HCP job ID for display |
| `source` | Data | Module that generated the event (e.g., `hcp_sync`, `ocr_engine`, `limbo_processor`) |
| `timestamp` | Datetime | When the event occurred (auto-set to now) |

### Indexes

- `timestamp` (descending) — primary sort
- `category` — business vs system filter
- `event_type` — type filter
- `tech` — tech filter
- `job` — job filter
- `severity` — severity filter

### Event Sources & Hook Points

| Event Type | Category | Severity | Hook Location | Trigger |
|-----------|----------|----------|---------------|---------|
| `job_status` | Business | success/info | `hcp_sync.py` — `on_job_update` | Job status field changes |
| `clock` | Business | info | `tech_utils.py` — `toggle_clock` | Clock in or clock out |
| `receipt` | Business | info | `hcp_receipt.py` — `after_insert` | Receipt uploaded |
| `ocr` | Business/System | success/error | `ocr_engine.py` — `process_receipt` | OCR completes or fails |
| `dispatch` | Business | success | `limbo_processor.py` — `dispatch_limbo_items` | Items dispatched to destinations |
| `hcp_sync` | System | info/warning | `hcp_sync.py` — `pull_recent_hcp_jobs` | Sync cycle completes |
| `material` | Business | info | `stock_processor.py` — `on_job_submit` | Materials consumed on job submit |
| `cron` | System | info/error | `hooks.py` — scheduled tasks | Any scheduled task runs |
| `api_error` | System | error | Global error handler or per-endpoint catch | API call fails with 500 |
| `login` | System | info | `auth` hooks or session creation | User logs in |

### Socket.IO Integration

On every `MTM Event Log` insert, emit a Socket.IO event:

```python
# In MTM Event Log after_insert
frappe.publish_realtime(
    event="mtm_event",
    message={
        "name": self.name,
        "event_type": self.event_type,
        "category": self.category,
        "severity": self.severity,
        "title": self.title,
        "detail": self.detail,
        "tech_name": self.tech_name,
        "job_id": self.job_id,
        "source": self.source,
        "timestamp": str(self.timestamp),
    },
    after_commit=True,
)
```

### Auto-Cleanup

Scheduled task (daily): delete events older than 90 days.

```python
# hooks.py — add to scheduler_events
"daily": [
    "hcp_replacement.hcp_replacement.core.event_logger.cleanup_old_events"
]
```

### Event Logger Utility

A central `event_logger.py` module that all hook points call:

```python
def log_event(event_type, title, category="Business", severity="info",
              detail="", tech=None, job=None, source=""):
    doc = frappe.new_doc("MTM Event Log")
    doc.event_type = event_type
    doc.category = category
    doc.severity = severity
    doc.title = title
    doc.detail = detail
    doc.source = source
    doc.timestamp = frappe.utils.now_datetime()
    if tech:
        doc.tech = tech
        emp = frappe.get_cached_value("Employee", tech, "employee_name")
        doc.tech_name = emp or ""
    if job:
        doc.job = job
        doc.job_id = frappe.get_cached_value("HCP Job", job, "hcp_job_id") or job
    doc.insert(ignore_permissions=True)
    return doc.name
```

### REST API Endpoint

```python
@frappe.whitelist()
def get_events(category=None, event_type=None, severity=None,
               tech=None, job=None, search=None,
               from_date=None, to_date=None,
               group_by=None, page=1, page_size=50):
    """Filtered, paginated event list for the full events page."""
```

Returns `{ events: [...], total_count, has_more }`.

## Frontend — Mini Slide-Over Panel

### Location

MTM web dashboard nav bar. Notification badge (amber circle with unread count) in the top-right area, next to user menu.

### Behavior

1. **Badge** — shows count of events in the last hour (or since last viewed). Updates via Socket.IO.
2. **Click badge** — slide-over panel opens from the right edge, 320px wide, full height below nav.
3. **Panel contents:**
   - Header: "EVENTS" + "LIVE" indicator (pulsing dot) + close button
   - Quick filter: ALL | Business | System (3 toggle chips)
   - Event list: latest 20 events, newest at top
   - Each event: color-coded left border + title + tech/source + relative time
   - "FULL PAGE →" link at bottom → navigates to `/manager/events`
4. **Real-time** — new events push in via Socket.IO, animate into the top of the list
5. **Click an event** — if it has a job, navigate to job detail. If it's a receipt, navigate to receipt detail. System events just expand to show detail text.
6. **Close** — click outside, click X, or press Escape

### Color Coding

| Severity | Left Border | Background |
|----------|------------|------------|
| success | `#28a745` (green) | `#f8fff8` |
| info | `#2196F3` (blue) | `#f5f9ff` |
| warning | `#E67E22` (amber) | `#fffbf5` |
| error | `#dc3545` (red) | `#fff5f5` |

## Frontend — Full Events Page

### Route

`/manager/events` — new page in the MTM web dashboard.

### Layout

```
┌─────────────────────────────────────────────────┐
│ NAV BAR                                [Events●]│
├─────────────────────────────────────────────────┤
│ EVENTS                              [Live tail] │
│                                                 │
│ ┌─ Filters ──────────────────────────────────┐  │
│ │ [All] [Business] [System]                  │  │
│ │ Type: [All ▾]  Tech: [All ▾]  Job: [🔍]   │  │
│ │ Severity: [All ▾]  Date: [Today ▾]        │  │
│ │ Group by: [Time ▾]  View: [Compact|Detail] │  │
│ │ Search: [________________________🔍]       │  │
│ └────────────────────────────────────────────┘  │
│                                                 │
│ ● Job #40561 completed                    2m ago│
│   Chris · 201 N Farmerville St                  │
│                                                 │
│ ● Receipt scanned — Coburn's $145.14      5m ago│
│   Warren · Job #40589                           │
│                                                 │
│ ● HCP Sync — 3 new jobs, 12 updated       8m ago│
│   System · Automated                            │
│                                                 │
│ ● Adam clocked in                        12m ago│
│   Adam · GPS: AllTec Office                     │
│                                                 │
│           [Load more...]                        │
└─────────────────────────────────────────────────┘
```

### Filter Controls

| Filter | Type | Options |
|--------|------|---------|
| Category | Toggle chips | All, Business, System |
| Event Type | Multi-select dropdown | job_status, clock, receipt, ocr, dispatch, hcp_sync, material, cron, api_error, login |
| Tech | Dropdown | All Techs + list of active employees |
| Job | Search input | Type job number to filter |
| Severity | Multi-select dropdown | info, success, warning, error |
| Date Range | Preset dropdown + custom | Live, Today, Last 7 days, Last 30 days, Custom |
| Group By | Dropdown | Time (default), Job, Tech |
| View | Toggle | Compact (one-line per event), Detail (two-line with extra info) |
| Search | Text input | Full-text search across title and detail fields |

### Display Modes

**Compact view:** Single line per event — severity dot + title + tech + relative time.

**Detail view:** Two lines — title on first, detail/context on second. Shows job address, error details, sync stats, etc.

**Live tail mode:** Auto-scrolls to top as new events arrive. Toggle on/off. When off, new events show a "3 new events" banner at top that scrolls up when clicked.

**Group by Job:** Events grouped under job headers. Each group shows job number + address + event count.

**Group by Tech:** Events grouped under tech name headers. Shows tech name + event count.

### Pagination

Infinite scroll. Load 50 events per page. "Load more" button as fallback.

## Socket.IO Connection (Web Dashboard)

```javascript
// Connect to Frappe's Socket.IO
const socket = io(FRAPPE_SITE_URL, {
  extraHeaders: {
    Authorization: `token ${apiKey}:${apiSecret}`,
  },
});

// Subscribe to MTM events
socket.on("mtm_event", (data) => {
  // Add to mini panel feed
  // Update badge count
  // If full page is open, prepend to list (unless paused)
});
```

Note: Frappe Cloud's Socket.IO may require cookie-based auth instead of token headers. The implementation should test both approaches and use whichever works on the deployed Frappe Cloud instance.

## Event Volume Estimate

At AllTec's current scale (7 techs, ~20 jobs/day):
- Job status changes: ~60/day (created, assigned, in progress, completed)
- Clock in/out: ~14/day
- Receipt scans + OCR: ~10/day
- HCP sync: ~96/day (every 15 min)
- Dispatches: ~10/day
- Materials: ~20/day
- Cron tasks: ~26/day (hourly + daily)
- Logins: ~10/day

**Total: ~250 events/day, ~7,500/month.** At 90-day retention: ~22,500 rows max. Trivial for MariaDB.

## What's NOT In This Spec

- GPS location tracking / map view (separate feature, later)
- Mobile app event viewer (web only for now)
- Event-triggered notifications (email/SMS alerts on specific events)
- Custom event rules (if X happens, do Y)
- Event export (CSV/PDF)

These are all valid future features but out of scope for v1.
