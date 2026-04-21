# Options Platform Monetization — Design Spec

**Date:** 2026-04-20
**Author:** 10T (brainstorm with Owner)
**Status:** Approved
**Owner:** Chris
**Depends on:** [Options Trading Platform Design (2026-04-18)](2026-04-18-options-trading-platform-design.md)

---

## What Does Done Look Like?

The existing options dashboard at `manytalentsmore.com/money/options` becomes a revenue-generating product:

1. Public visitors see a "loaded teaser" — real tickers, confidence scores, and expected returns for top 3 — but actionable trade details are gated behind payment.
2. One-time purchases ($4.99 base) unlock trade details for the current analysis run.
3. Monthly subscribers ($9.99/mo) get full access with up to 5 runs per day.
4. Each recommendation has a shareable rationale page that acts as free marketing.
5. Chris has full admin bypass (no charges, no limits).
6. A legal disclaimer is acknowledged before first use and visible on every subsequent run.

---

## Pricing & Access Model

| Plan | Price | Access | Limit |
|------|-------|--------|-------|
| One-time (base) | $4.99 | Top 3 recommendations | 1 run, locked until next hour window |
| One-time +5 | +$0.99 | Top 5 recommendations | Same run |
| One-time +10 | +$0.99 | All 10 recommendations | Same run |
| Monthly subscription | $9.99/mo | All 10 recommendations | 5 runs per day |
| Admin | Free | Everything | Unlimited, instant, no hour window |

### Caching & Cost Control

- Real Claude API analysis runs **max once per hour**.
- Maximum API cost: 24 runs/day (24X per-run Claude cost).
- When a user pays and hits "Run":
  - **No cached run < 1hr old:** Real Claude API call fires (2-5 min, real progress).
  - **Cached run exists, user hasn't seen it:** Simulated "thinking" delay (30-45 seconds with staged progress messages), then reveals cached results.
  - **Cached run exists, user already saw it:** Locked out. Shows "Next analysis available in X minutes."
- Users are only charged if they will receive results that are new to them.
- The countdown/timestamp ("Last analysis: 2:15 PM | Next update in: 13m") is only shown AFTER a user has paid and run — not on the public teaser.

---

## Public Teaser Page

### Headline

> **"The Edge Is in the Data"**
> Four specialized AI agents research, rank, and surface the highest-conviction options plays daily.

### Zone A — Header (Above the Fold)

- Headline + subheadline (above)
- **Market Pulse** (live from cached analysis): VIX level, Fed rate, market regime, 2-3 key risks
- "10 Recommendations Ready" badge
- No countdown/timestamp until after payment + run

### Zone B — Proof Table

All 10 rows visible with strategic blurring:

| Row | Ticker | Confidence | Direction | Exp. Return | Structure/Strikes/Expiry/Cost |
|-----|--------|-----------|-----------|-------------|-------------------------------|
| 1-3 | Visible | Visible | Visible | Visible | Blurred (CSS blur) |
| 4-10 | Blurred | Blurred | Blurred | Blurred | Blurred |

Clicking any locked row or the "Unlock" button opens the payment modal.

### Zone C — Trust Layer (Below Table)

1. **"How It Works"** — 3-step visual:
   - AI squad analyzes macro, flow, fundamentals & risk
   - Recommendations ranked by confidence with defined-risk structures
   - You get specific strikes, expiry, cost, and exit plan — ready to execute

2. **Methodology transparency:**
   - "Four specialized research agents: Macro (Fed/VIX/rates), Flow (unusual options activity, IV rank), Fundamentals (earnings, insider buying), Risk (confidence scoring, max loss calculation)"

3. **Performance tracker** (added after 2-4 weeks of live data):
   - "Last 30 days: X recommendations | Y% avg confidence | Z% hit rate"
   - Paper trading results labeled honestly

4. **Risk disclaimer:**
   - "All strategies use defined risk. Max loss always known before entry."
   - "One-time purchase. No subscription." (prominently displayed)

---

## Payment Modal

Triggered by clicking any locked content or the "Unlock Recommendations" button.

```
+--------------------------------------------------+
|  Unlock Today's AI Options Recommendations        |
|                                                    |
|  [x] Top 3 Picks ................ $4.99            |
|  [ ] Top 5 Picks ................ $5.98  (+$0.99)  |
|  [ ] All 10 Picks ............... $6.97  (+$0.99)  |
|                                                    |
|  ─── OR ───                                        |
|                                                    |
|  [ ] Subscribe: $9.99/mo — 5 runs/day, all 10     |
|                                                    |
|  Includes: Full trade structure, strikes, expiry,  |
|  cost, 10 reasons, kill conditions, exit plan      |
|                                                    |
|  [Apple Pay] [Google Pay] [Card]                   |
|                                                    |
|  One-time purchase. No subscription required.      |
|  New recommendations available hourly.             |
+--------------------------------------------------+
```

- Pre-selected: Top 3 at $4.99
- No account creation for one-time purchases
- Email captured automatically for subscribers (via Stripe)
- Stripe Checkout (hosted, trusted UI)

---

## Payment Flow & Server-Side Gating

### Architecture: Server-side gating (Approach 1)

The API returns different data based on payment verification. Content cannot be accessed via DevTools.

### One-Time Purchase Flow

1. Visitor clicks "Unlock" → payment modal opens
2. Selects tier (top 3 / 5 / 10)
3. Stripe Checkout session created
4. On success: Stripe webhook or redirect confirms payment
5. API verifies Stripe session → returns full recommendation data for purchased tier
6. Sets cookie: `mtm_purchase_{run_id}` tied to that specific analysis run
7. User sees results. Locked out until next hour window.

### Subscriber Flow

1. Visitor selects "Subscribe" in modal
2. Stripe Checkout creates customer (captures email)
3. On success: API verifies active subscription via Stripe
4. Sets cookie: `mtm_sub` (long-lived, linked to Stripe customer email)
5. Full access to all 10 recommendations, up to 5 runs/day
6. Daily run counter resets at midnight ET

### Run Button Behavior After Payment

| User Type | Cached Run (new to them) | Cached Run (already seen) | No Cached Run |
|-----------|--------------------------|---------------------------|---------------|
| One-time buyer | Simulated delay (30-45s) → reveal tier | Locked, countdown shown | Real API call (2-5 min) → reveal tier |
| Subscriber | Simulated delay (30-45s) → reveal all 10 | Locked, countdown shown | Real API call (2-5 min) → reveal all 10 |
| Admin | Instant reveal | Can trigger new run anytime | Real API call, no wait UX |

### Database Additions

```sql
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_session_id TEXT NOT NULL,
    email TEXT,
    run_id UUID REFERENCES analysis_runs(id),
    tier INT NOT NULL CHECK (tier IN (3, 5, 10)),
    type TEXT NOT NULL CHECK (type IN ('one_time', 'subscription')),
    amount_cents INT NOT NULL,
    acknowledged_disclaimer BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE subscribers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    stripe_customer_id TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'past_due')),
    runs_today INT NOT NULL DEFAULT 0,
    last_run_date DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Disclaimer UX

### First Run — Acknowledgment Popup (Shown Once)

When user clicks "Run" for the first time, BEFORE the payment modal:

> **Disclaimer**
>
> The information provided is not investment advice and should not be relied upon for making financial decisions. It may aid your own research.
>
> **[I Acknowledge]**

- Acknowledgment stored in cookie + recorded in `purchases.acknowledged_disclaimer`
- Never shown again for that user (cookie persists)
- Writ (Legal) will finalize exact language

### Subsequent Runs — Loading Screen Line

Every run after acknowledgment, the disclaimer appears as a static (non-blocking) line on the loading/progress screen:

> *"Not investment advice. May aid research only."*

Shown alongside progress messages ("Analyzing macro conditions...", "Scoring confidence...", etc.)

### Rationale Pages — Footer

Every shareable rationale page includes the disclaimer in the page footer. Always visible.

---

## Rationale Pages (Shareable)

Each recommendation gets a unique public URL: `/money/options/rec/{id}`

### What's PUBLIC (shareable, drives traffic):

- Ticker + direction (bull/bear/neutral)
- Confidence score + expected return %
- The 10 reasons (thesis, catalysts, data points)
- Kill conditions (what invalidates the thesis)
- Verification links (Yahoo Finance, news articles, SEC filings)
- Market Pulse snapshot from that analysis run
- Disclaimer footer

### What's GATED (requires payment):

- Strike prices, expiry date, cost per contract
- Trade structure (the specific spread/option to buy)
- Exit plan details (trailing stop %, profit target, time stop)

### Marketing Purpose:

Someone shares "look at this AI's NVDA thesis" on social media → visitor sees compelling analysis but can't trade it → clicks "Unlock the trade" → payment modal → conversion.

---

## Admin Bypass

- Small "Admin" link in page footer (subtle, not prominent)
- Clicking opens a simple password input field
- Correct password sets a persistent cookie (`mtm_admin`)
- Password stored in Bitwarden: "MTM / Options Dashboard / Admin Password"
- Once authenticated:
  - All tiers unlocked permanently
  - No payment required
  - No run limits, no hour window restriction
  - No simulated delay — instant results
  - Can trigger real runs anytime
  - Sees admin-only data: actual API cost of last run, cache status, subscriber count, purchase history

---

## Payment Integration: Stripe

- **Account:** ManyTalents More (sole proprietorship, DBA)
- **Keys:** Stored in Bitwarden ("Stripe / ManyTalents More / API Keys")
- **Integration:** Stripe Checkout (server-side session creation)
  - One-time: `mode: 'payment'`
  - Subscription: `mode: 'subscription'` with monthly price
- **Webhook:** Listens for `checkout.session.completed` and `customer.subscription.updated/deleted`
- **Apple Pay / Google Pay:** Enabled via Stripe Checkout (automatic when configured)
- **Future:** Stripe via ERPNext Frappe Payments app (when multi-business billing consolidates)

---

## Legal (Pending — Writ's First Assignments)

1. Finalize disclaimer language (popup, loading screen, rationale footer)
2. Terms of Service for the platform
3. Privacy Policy (email collection via Stripe, cookies)
4. Regulatory position memo (Publisher's Exclusion analysis)
5. Conflict-of-interest disclosure (Chris may trade the same recommendations)

---

## File Structure (New/Modified)

### MTM Web (ManyTalentsMore repo) — New Files

```
src/
  app/money/options/
    components/
      TeaserTable.tsx           # Blurred proof table (public view)
      PaymentModal.tsx          # Tier selection + Stripe checkout trigger
      DisclaimerModal.tsx       # First-run acknowledgment popup
      AdminLogin.tsx            # Footer admin password input
      RunProgress.tsx           # Loading animation + disclaimer line
      MarketPulse.tsx           # Free VIX/macro summary section
      RationalePage.tsx         # Shareable rec detail page
    rec/[id]/
      page.tsx                  # Dynamic rationale page route
  app/api/options/
    checkout/route.ts           # POST — create Stripe checkout session
    webhook/route.ts            # POST — Stripe webhook handler
    verify/route.ts             # GET — check payment/subscription status
  lib/options/
    stripe.ts                   # Stripe client + session helpers
    gating.ts                   # Logic: what data to return based on auth state
```

### Droplet — Modifications

```
options-service/
  routes/
    recommendations.py          # Modified: returns filtered fields based on auth
  config.py                     # Add: Stripe secret key for webhook verification
```

### Supabase — New Migration

```
supabase/
  migrations/
    002_monetization.sql        # purchases + subscribers tables, indexes
```

---

## Success Criteria

1. Visitor lands on `/money/options` and sees the loaded teaser (tickers, confidence, returns for top 3) without paying.
2. Visitor clicks "Unlock" → Stripe Checkout → pays $4.99 → sees full trade details for top 3 within 45 seconds.
3. Subscriber pays $9.99/mo → gets all 10 recommendations, up to 5 runs/day.
4. Sharing a rationale page URL shows the thesis publicly but gates the trade details.
5. Chris enters admin password once → never pays, no limits, instant access.
6. Real Claude API costs are capped at max 24 runs/day regardless of traffic.
7. Disclaimer is acknowledged once (recorded) and visible on every subsequent interaction.
8. Stripe payments process successfully with Apple Pay / Google Pay / Card.
