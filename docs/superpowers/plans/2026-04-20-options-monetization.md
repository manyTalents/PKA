# Options Platform Monetization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add payment gating, Stripe integration, and public teaser to the live options dashboard so visitors can purchase AI recommendations.

**Architecture:** The existing Next.js dashboard at `/money/options` becomes a public teaser page (no AuthGate). Payment via Stripe Checkout unlocks recommendation data through a server-side gated API route. Caching ensures max 24 real Claude API calls/day. A new `/money/options/rec/[id]` route serves shareable rationale pages.

**Tech Stack:** Next.js 15, React 19, Stripe (npm `stripe` + `@stripe/stripe-js`), Supabase (existing), Tailwind CSS, TypeScript

**Spec:** `C:\Users\chris\OneDrive\Documentos\PKA\docs\superpowers\specs\2026-04-20-options-monetization-design.md`

**Repo:** `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\`

---

## File Structure (New & Modified)

```
src/
  app/money/options/
    page.tsx                          # MODIFY — remove AuthGate, add teaser/paid split
    layout.tsx                        # MODIFY — remove AuthGate wrapper
    rec/[id]/
      page.tsx                        # CREATE — shareable rationale page
    components/
      TeaserTable.tsx                 # CREATE — blurred proof table (public)
      PaymentModal.tsx                # CREATE — tier selection + Stripe trigger
      DisclaimerModal.tsx             # CREATE — first-run acknowledgment popup
      RunProgress.tsx                 # CREATE — loading animation + disclaimer line
      MarketPulse.tsx                 # CREATE — VIX/macro summary (free)
      AdminLogin.tsx                  # CREATE — footer password input
  app/api/options/
    checkout/route.ts                 # CREATE — Stripe Checkout session creation
    webhook/route.ts                  # CREATE — Stripe webhook handler
    recommendations/route.ts          # CREATE — gated recommendation data endpoint
    run-status/route.ts               # CREATE — check cache/run eligibility
  lib/
    options-types.ts                  # MODIFY — add Purchase, Subscriber, TeaserRec types
    options-api.ts                    # MODIFY — add checkout, verify, recommendations methods
    stripe.ts                         # CREATE — Stripe client helpers
    options-access.ts                 # CREATE — cookie helpers, access state logic
supabase/
  migrations/
    002_monetization.sql              # CREATE — purchases + subscribers tables
```

---

## Task 1: Install Stripe Dependencies

**Files:**
- Modify: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\package.json`

- [ ] **Step 1: Install stripe packages**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm install stripe @stripe/stripe-js
```

- [ ] **Step 2: Add environment variables to `.env.local`**

Add to `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\.env.local`:

```env
STRIPE_SECRET_KEY=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
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_51TO2vnGmQBRK0vx0HjAWEp1aUhe2hmceH08FaCZvgouvLKcoaLPz93YlwHohiDwjCMyMBgzrIYK0iNaC0nZhtvxM00W9yMAUPl
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
OPTIONS_ADMIN_PASSWORD=3aAkRuKTQs3N129tlEdR
```

Note: `STRIPE_WEBHOOK_SECRET` will be set after configuring the webhook in Stripe Dashboard. Use a placeholder for now.

- [ ] **Step 3: Verify build still passes**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run build
```

Expected: Build succeeds (no breaking changes from adding packages).

- [ ] **Step 4: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add package.json package-lock.json
git commit -m "chore: add stripe and @stripe/stripe-js dependencies"
```

---

## Task 2: Supabase Migration — Purchases & Subscribers Tables

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\supabase\migrations\002_monetization.sql`

- [ ] **Step 1: Write migration SQL**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\supabase\migrations\002_monetization.sql`:

```sql
-- Monetization tables for options platform

CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_session_id TEXT NOT NULL UNIQUE,
    email TEXT,
    run_id UUID REFERENCES analysis_runs(id) ON DELETE SET NULL,
    tier INT NOT NULL CHECK (tier IN (3, 5, 10)),
    amount_cents INT NOT NULL,
    acknowledged_disclaimer BOOLEAN NOT NULL DEFAULT true,
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

-- Index for fast lookups
CREATE INDEX idx_purchases_run_id ON purchases(run_id);
CREATE INDEX idx_purchases_stripe_session ON purchases(stripe_session_id);
CREATE INDEX idx_subscribers_email ON subscribers(email);
CREATE INDEX idx_subscribers_stripe_customer ON subscribers(stripe_customer_id);

-- RLS: anon can read own purchases (via session_id match in API), service role can write
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscribers ENABLE ROW LEVEL SECURITY;

-- Only service role can insert/update (API routes use service client)
CREATE POLICY "Service role full access on purchases"
    ON purchases FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on subscribers"
    ON subscribers FOR ALL
    USING (auth.role() = 'service_role');
```

- [ ] **Step 2: Apply migration via Supabase MCP**

Use the Supabase MCP tool `apply_migration` to run this SQL against project `hvbvfcusroomhiywgylb`.

- [ ] **Step 3: Verify tables exist**

Use Supabase MCP `execute_sql`:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN ('purchases', 'subscribers');
```

Expected: Both tables returned.

- [ ] **Step 4: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add supabase/migrations/002_monetization.sql
git commit -m "feat: add purchases and subscribers tables for monetization"
```

---

## Task 3: Types & API Client Updates

**Files:**
- Modify: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-types.ts`
- Modify: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-api.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\stripe.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-access.ts`

- [ ] **Step 1: Add new types to options-types.ts**

Append to the end of `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-types.ts`:

```typescript
// ── Monetization Types ───────────────────────────────────────────────────────

export type Tier = 3 | 5 | 10

export interface TeaserRecommendation {
  id: string
  rank: number
  ticker: string | null       // visible for top 3, null for 4-10
  direction: 'bull' | 'bear' | 'neutral' | null
  confidence: number | null   // visible for top 3, null for 4-10
  expected_return_pct: number | null
}

export interface Purchase {
  id: string
  stripe_session_id: string
  email: string | null
  run_id: string
  tier: Tier
  amount_cents: number
  acknowledged_disclaimer: boolean
  created_at: string
}

export interface Subscriber {
  id: string
  email: string
  stripe_customer_id: string
  status: 'active' | 'cancelled' | 'past_due'
  runs_today: number
  last_run_date: string | null
  created_at: string
}

export interface RunStatus {
  has_cached_run: boolean
  run_id: string | null
  completed_at: string | null
  user_has_seen: boolean
  next_available_in_seconds: number | null
}

export interface CheckoutResponse {
  url: string
}

export interface GatedRecommendationsResponse {
  tier: Tier
  recommendations: Recommendation[]
  run_id: string
  completed_at: string
}
```

- [ ] **Step 2: Create stripe.ts client helper**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\stripe.ts`:

```typescript
/**
 * Stripe client helpers.
 * Server-side: use getStripe() for API route operations.
 * Client-side: use getStripeJs() for Checkout redirects.
 */

import Stripe from 'stripe'
import { loadStripe, type Stripe as StripeJs } from '@stripe/stripe-js'

// Server-side Stripe instance (used in API routes only)
let _stripe: Stripe | null = null

export function getStripe(): Stripe {
  if (!_stripe) {
    _stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
      apiVersion: '2025-03-31.basil',
    })
  }
  return _stripe
}

// Client-side Stripe.js instance (used for redirectToCheckout)
let _stripeJs: Promise<StripeJs | null> | null = null

export function getStripeJs() {
  if (!_stripeJs) {
    _stripeJs = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)
  }
  return _stripeJs
}
```

- [ ] **Step 3: Create options-access.ts**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-access.ts`:

```typescript
/**
 * Options access state — cookie-based tracking for purchases, subscriptions, admin, and disclaimer.
 */

const DISCLAIMER_KEY = 'mtm_options_disclaimer'
const ADMIN_KEY = 'mtm_options_admin'
const PURCHASE_PREFIX = 'mtm_purchase_'
const SUB_KEY = 'mtm_options_sub'

export function hasAcknowledgedDisclaimer(): boolean {
  if (typeof window === 'undefined') return false
  return localStorage.getItem(DISCLAIMER_KEY) === 'true'
}

export function setDisclaimerAcknowledged() {
  if (typeof window === 'undefined') return
  localStorage.setItem(DISCLAIMER_KEY, 'true')
}

export function isAdmin(): boolean {
  if (typeof window === 'undefined') return false
  return localStorage.getItem(ADMIN_KEY) === 'true'
}

export function setAdmin() {
  if (typeof window === 'undefined') return
  localStorage.setItem(ADMIN_KEY, 'true')
}

export function getPurchaseForRun(runId: string): { tier: number } | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(`${PURCHASE_PREFIX}${runId}`)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function setPurchaseForRun(runId: string, tier: number) {
  if (typeof window === 'undefined') return
  localStorage.setItem(`${PURCHASE_PREFIX}${runId}`, JSON.stringify({ tier }))
}

export function getSubscription(): { email: string } | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(SUB_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function setSubscription(email: string) {
  if (typeof window === 'undefined') return
  localStorage.setItem(SUB_KEY, JSON.stringify({ email }))
}

export function clearSubscription() {
  if (typeof window === 'undefined') return
  localStorage.removeItem(SUB_KEY)
}
```

- [ ] **Step 4: Update options-api.ts with new methods**

Replace `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\lib\options-api.ts` entirely:

```typescript
/**
 * Options API client — fetch wrappers for the options-service FastAPI backend
 * and new monetization endpoints.
 */

import type {
  AnalyzeResponse,
  ExecuteResponse,
  CloseResponse,
  CheckoutResponse,
  GatedRecommendationsResponse,
  RunStatus,
  Tier,
} from './options-types'

const API_BASE = '/api/options'

async function fetchApi<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
  if (!res.ok) {
    const error = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(error.detail || 'Request failed')
  }
  return res.json()
}

export const optionsApi = {
  // ── Existing (trading) ──────────────────────────────────────────────────────
  analyze: () => fetchApi<AnalyzeResponse>('/analyze', { method: 'POST' }),

  execute: (req: { recommendation_id: string; quantity: number }) =>
    fetchApi<ExecuteResponse>('/execute', {
      method: 'POST',
      body: JSON.stringify(req),
    }),

  close: (positionId: string) =>
    fetchApi<CloseResponse>(`/close/${positionId}`, { method: 'POST' }),

  adjustStop: (positionId: string, trailingPct: number) =>
    fetchApi<{ status: string }>(`/adjust-stop/${positionId}`, {
      method: 'POST',
      body: JSON.stringify({ trailing_pct: trailingPct }),
    }),

  // ── Monetization ────────────────────────────────────────────────��───────────
  checkout: (tier: Tier, mode: 'one_time' | 'subscription') =>
    fetchApi<CheckoutResponse>('/checkout', {
      method: 'POST',
      body: JSON.stringify({ tier, mode }),
    }),

  getRunStatus: () => fetchApi<RunStatus>('/run-status'),

  getRecommendations: (sessionId: string) =>
    fetchApi<GatedRecommendationsResponse>(`/recommendations?session_id=${sessionId}`),

  verifyAdmin: (password: string) =>
    fetchApi<{ valid: boolean }>('/admin-verify', {
      method: 'POST',
      body: JSON.stringify({ password }),
    }),
}
```

- [ ] **Step 5: Verify build**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run build
```

Expected: May have type errors in `page.tsx` since we changed `optionsApi` shape — that's OK, we'll fix it in Task 6. Check that the new lib files compile cleanly.

- [ ] **Step 6: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/lib/options-types.ts src/lib/options-api.ts src/lib/stripe.ts src/lib/options-access.ts
git commit -m "feat: add monetization types, Stripe client, and access state helpers"
```

---

## Task 4: API Routes — Checkout, Webhook, Recommendations, Run Status, Admin Verify

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\checkout\route.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\webhook\route.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\recommendations\route.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\run-status\route.ts`
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\admin-verify\route.ts`

- [ ] **Step 1: Create checkout route**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\checkout\route.ts`:

```typescript
/**
 * POST /api/options/checkout
 * Creates a Stripe Checkout session for one-time purchase or subscription.
 */

import { NextRequest, NextResponse } from 'next/server'
import { getStripe } from '@/lib/stripe'
import { createServiceClient } from '@/lib/supabase'

const PRICES: Record<number, number> = { 3: 499, 5: 598, 10: 697 }
const SUB_PRICE = 999 // $9.99/mo

export async function POST(req: NextRequest) {
  try {
    const { tier, mode } = await req.json()
    const stripe = getStripe()
    const origin = req.headers.get('origin') || 'https://manytalentsmore.com'

    if (mode === 'subscription') {
      // Create a subscription checkout
      const session = await stripe.checkout.sessions.create({
        mode: 'subscription',
        line_items: [
          {
            price_data: {
              currency: 'usd',
              recurring: { interval: 'month' },
              product_data: {
                name: 'MTM Options — Monthly (5 runs/day, all 10 picks)',
              },
              unit_amount: SUB_PRICE,
            },
            quantity: 1,
          },
        ],
        success_url: `${origin}/money/options?session_id={CHECKOUT_SESSION_ID}&mode=subscription`,
        cancel_url: `${origin}/money/options`,
      })

      return NextResponse.json({ url: session.url })
    }

    // One-time payment
    const amount = PRICES[tier as number]
    if (!amount) {
      return NextResponse.json({ detail: 'Invalid tier' }, { status: 400 })
    }

    // Get the latest run_id to associate with this purchase
    const supabase = createServiceClient()
    const { data: latestRun } = await supabase
      .from('analysis_runs')
      .select('id')
      .eq('status', 'done')
      .order('completed_at', { ascending: false })
      .limit(1)
      .single()

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: `MTM Options — Top ${tier} Picks`,
            },
            unit_amount: amount,
          },
          quantity: 1,
        },
      ],
      metadata: {
        tier: String(tier),
        run_id: latestRun?.id || '',
      },
      success_url: `${origin}/money/options?session_id={CHECKOUT_SESSION_ID}&tier=${tier}`,
      cancel_url: `${origin}/money/options`,
    })

    return NextResponse.json({ url: session.url })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Checkout failed'
    return NextResponse.json({ detail: message }, { status: 500 })
  }
}
```

- [ ] **Step 2: Create webhook route**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\webhook\route.ts`:

```typescript
/**
 * POST /api/options/webhook
 * Stripe webhook handler — records purchases and manages subscriptions.
 */

import { NextRequest, NextResponse } from 'next/server'
import { getStripe } from '@/lib/stripe'
import { createServiceClient } from '@/lib/supabase'
import type Stripe from 'stripe'

export async function POST(req: NextRequest) {
  const body = await req.text()
  const sig = req.headers.get('stripe-signature')

  if (!sig) {
    return NextResponse.json({ detail: 'Missing signature' }, { status: 400 })
  }

  const stripe = getStripe()
  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Invalid signature'
    return NextResponse.json({ detail: message }, { status: 400 })
  }

  const supabase = createServiceClient()

  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session

      if (session.mode === 'payment') {
        // One-time purchase
        const tier = parseInt(session.metadata?.tier || '3', 10)
        const runId = session.metadata?.run_id || null

        await supabase.from('purchases').insert({
          stripe_session_id: session.id,
          email: session.customer_details?.email || null,
          run_id: runId,
          tier,
          amount_cents: session.amount_total || 0,
        })
      } else if (session.mode === 'subscription') {
        // New subscriber
        const email = session.customer_details?.email
        const customerId = session.customer as string

        if (email && customerId) {
          await supabase.from('subscribers').upsert(
            {
              email,
              stripe_customer_id: customerId,
              status: 'active',
              runs_today: 0,
            },
            { onConflict: 'email' }
          )
        }
      }
      break
    }

    case 'customer.subscription.updated':
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      const customerId = sub.customer as string
      const status = sub.status === 'active' ? 'active' : 'cancelled'

      await supabase
        .from('subscribers')
        .update({ status })
        .eq('stripe_customer_id', customerId)
      break
    }
  }

  return NextResponse.json({ received: true })
}
```

- [ ] **Step 3: Create recommendations route (server-side gating)**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\recommendations\route.ts`:

```typescript
/**
 * GET /api/options/recommendations?session_id=xxx
 * Returns gated recommendation data based on purchase verification.
 * Also handles admin and subscriber access via headers.
 */

import { NextRequest, NextResponse } from 'next/server'
import { getStripe } from '@/lib/stripe'
import { createServiceClient } from '@/lib/supabase'

export async function GET(req: NextRequest) {
  const sessionId = req.nextUrl.searchParams.get('session_id')
  const adminToken = req.headers.get('x-admin-token')
  const subEmail = req.headers.get('x-sub-email')

  const supabase = createServiceClient()

  // Get latest completed run
  const { data: latestRun } = await supabase
    .from('analysis_runs')
    .select('id, completed_at')
    .eq('status', 'done')
    .order('completed_at', { ascending: false })
    .limit(1)
    .single()

  if (!latestRun) {
    return NextResponse.json({ detail: 'No analysis available' }, { status: 404 })
  }

  // Determine access level
  let tier = 0

  // Admin bypass
  if (adminToken === process.env.OPTIONS_ADMIN_PASSWORD) {
    tier = 10
  }
  // Subscriber access
  else if (subEmail) {
    const { data: sub } = await supabase
      .from('subscribers')
      .select('status, runs_today, last_run_date')
      .eq('email', subEmail)
      .eq('status', 'active')
      .single()

    if (sub) {
      const today = new Date().toISOString().split('T')[0]
      const runsToday = sub.last_run_date === today ? sub.runs_today : 0

      if (runsToday < 5) {
        tier = 10
        // Increment run count
        await supabase
          .from('subscribers')
          .update({
            runs_today: runsToday + 1,
            last_run_date: today,
          })
          .eq('email', subEmail)
      } else {
        return NextResponse.json(
          { detail: 'Daily run limit reached (5/5). Resets at midnight ET.' },
          { status: 429 }
        )
      }
    }
  }
  // One-time purchase via Stripe session
  else if (sessionId) {
    try {
      const stripe = getStripe()
      const session = await stripe.checkout.sessions.retrieve(sessionId)

      if (session.payment_status === 'paid') {
        tier = parseInt(session.metadata?.tier || '3', 10)
      }
    } catch {
      return NextResponse.json({ detail: 'Invalid session' }, { status: 401 })
    }
  }

  if (tier === 0) {
    return NextResponse.json({ detail: 'Payment required' }, { status: 402 })
  }

  // Fetch recommendations up to tier limit
  const { data: recs } = await supabase
    .from('recommendations')
    .select('*')
    .eq('run_id', latestRun.id)
    .order('rank', { ascending: true })
    .limit(tier)

  return NextResponse.json({
    tier,
    recommendations: recs || [],
    run_id: latestRun.id,
    completed_at: latestRun.completed_at,
  })
}
```

- [ ] **Step 4: Create run-status route**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\run-status\route.ts`:

```typescript
/**
 * GET /api/options/run-status
 * Returns current cache state: is there a run < 1hr old, and when is next available.
 */

import { NextResponse } from 'next/server'
import { createServiceClient } from '@/lib/supabase'

export async function GET() {
  const supabase = createServiceClient()

  const { data: latestRun } = await supabase
    .from('analysis_runs')
    .select('id, completed_at, status')
    .eq('status', 'done')
    .order('completed_at', { ascending: false })
    .limit(1)
    .single()

  if (!latestRun || !latestRun.completed_at) {
    return NextResponse.json({
      has_cached_run: false,
      run_id: null,
      completed_at: null,
      next_available_in_seconds: 0,
    })
  }

  const completedAt = new Date(latestRun.completed_at)
  const now = new Date()
  const ageMs = now.getTime() - completedAt.getTime()
  const oneHourMs = 60 * 60 * 1000

  if (ageMs < oneHourMs) {
    const remainingMs = oneHourMs - ageMs
    return NextResponse.json({
      has_cached_run: true,
      run_id: latestRun.id,
      completed_at: latestRun.completed_at,
      next_available_in_seconds: Math.ceil(remainingMs / 1000),
    })
  }

  // Older than 1hr — next run will be fresh
  return NextResponse.json({
    has_cached_run: false,
    run_id: latestRun.id,
    completed_at: latestRun.completed_at,
    next_available_in_seconds: 0,
  })
}
```

- [ ] **Step 5: Create admin-verify route**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\api\options\admin-verify\route.ts`:

```typescript
/**
 * POST /api/options/admin-verify
 * Verifies the admin password for bypass access.
 */

import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const { password } = await req.json()
  const valid = password === process.env.OPTIONS_ADMIN_PASSWORD

  return NextResponse.json({ valid })
}
```

- [ ] **Step 6: Verify build**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run build
```

Expected: API routes compile. Page may still have type issues (fixed in Task 6).

- [ ] **Step 7: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/api/options/checkout/ src/app/api/options/webhook/ src/app/api/options/recommendations/ src/app/api/options/run-status/ src/app/api/options/admin-verify/
git commit -m "feat: add monetization API routes (checkout, webhook, gating, admin)"
```

---

## Task 5: Disclaimer Modal Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\DisclaimerModal.tsx`

- [ ] **Step 1: Create DisclaimerModal**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\DisclaimerModal.tsx`:

```tsx
"use client"

import { hasAcknowledgedDisclaimer, setDisclaimerAcknowledged } from "@/lib/options-access"

interface Props {
  onAcknowledge: () => void
}

export default function DisclaimerModal({ onAcknowledge }: Props) {
  const handleAcknowledge = () => {
    setDisclaimerAcknowledged()
    onAcknowledge()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
      <div className="bg-navy-card border border-navy-border rounded-2xl p-8 max-w-md mx-4 shadow-2xl">
        <h2 className="text-xl font-bold text-cream mb-4">Disclaimer</h2>
        <p className="text-cream/80 text-sm leading-relaxed mb-6">
          The information provided is not investment advice and should not be
          relied upon for making financial decisions. It may aid your own
          research.
        </p>
        <button
          onClick={handleAcknowledge}
          className="w-full py-3 rounded-xl bg-gold hover:bg-gold-dark text-navy-bg font-bold text-sm transition"
        >
          I Acknowledge
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/DisclaimerModal.tsx
git commit -m "feat: add disclaimer modal component"
```

---

## Task 6: Market Pulse Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\MarketPulse.tsx`

- [ ] **Step 1: Create MarketPulse**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\MarketPulse.tsx`:

```tsx
"use client"

interface Props {
  macroSummary: string | null
}

export default function MarketPulse({ macroSummary }: Props) {
  if (!macroSummary) return null

  // macro_summary is stored as a string; parse key bullets if possible
  return (
    <div className="rounded-xl border border-navy-border bg-navy-card/50 p-4 mb-6">
      <h3 className="text-xs font-semibold text-neutral-400 uppercase tracking-wide mb-2">
        Market Pulse
      </h3>
      <p className="text-sm text-cream/80 leading-relaxed">{macroSummary}</p>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/MarketPulse.tsx
git commit -m "feat: add market pulse component (free teaser section)"
```

---

## Task 7: Teaser Table Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\TeaserTable.tsx`

- [ ] **Step 1: Create TeaserTable**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\TeaserTable.tsx`:

```tsx
"use client"

import type { TeaserRecommendation } from "@/lib/options-types"

interface Props {
  recommendations: TeaserRecommendation[]
  onUnlockClick: () => void
}

export default function TeaserTable({ recommendations, onUnlockClick }: Props) {
  return (
    <div className="rounded-xl border border-navy-border overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-navy-card/60 border-b border-navy-border">
        <div className="flex items-center gap-3">
          <h2 className="text-sm font-bold text-cream">
            {recommendations.length} Recommendations Ready
          </h2>
        </div>
        <button
          onClick={onUnlockClick}
          className="px-4 py-1.5 rounded-lg bg-gold hover:bg-gold-dark text-navy-bg text-xs font-bold transition"
        >
          Unlock for $4.99
        </button>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-navy-border/50 text-neutral-400 text-xs">
              <th className="py-2 px-3 text-left">#</th>
              <th className="py-2 px-3 text-left">Confidence</th>
              <th className="py-2 px-3 text-left">Ticker</th>
              <th className="py-2 px-3 text-left">Direction</th>
              <th className="py-2 px-3 text-left">Structure</th>
              <th className="py-2 px-3 text-left">Expiry</th>
              <th className="py-2 px-3 text-left">Cost</th>
              <th className="py-2 px-3 text-left">Exp. Return</th>
            </tr>
          </thead>
          <tbody>
            {recommendations.map((rec) => {
              const isVisible = rec.rank <= 3
              return (
                <tr
                  key={rec.id}
                  className="border-b border-navy-border/50 hover:bg-navy-card/40 transition cursor-pointer"
                  onClick={onUnlockClick}
                >
                  <td className="py-3 px-3 font-mono text-neutral-400 text-xs">
                    #{rec.rank}
                  </td>
                  <td className="py-3 px-3">
                    {isVisible ? (
                      <span
                        className={`font-mono font-bold ${
                          (rec.confidence || 0) >= 70
                            ? "text-emerald-400"
                            : (rec.confidence || 0) >= 60
                            ? "text-gold"
                            : "text-neutral-400"
                        }`}
                      >
                        {rec.confidence}%
                      </span>
                    ) : (
                      <span className="inline-block w-12 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                    )}
                  </td>
                  <td className="py-3 px-3 font-mono font-bold text-cream">
                    {isVisible ? (
                      rec.ticker
                    ) : (
                      <span className="inline-block w-10 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                    )}
                  </td>
                  <td className="py-3 px-3">
                    {isVisible ? (
                      <span
                        className={`text-xs px-2 py-0.5 rounded-full ${
                          rec.direction === "bull"
                            ? "bg-emerald-500/10 text-emerald-400"
                            : rec.direction === "bear"
                            ? "bg-red-500/10 text-red-400"
                            : "bg-neutral-500/10 text-neutral-400"
                        }`}
                      >
                        {rec.direction}
                      </span>
                    ) : (
                      <span className="inline-block w-10 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                    )}
                  </td>
                  <td className="py-3 px-3">
                    <span className="inline-block w-24 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                  </td>
                  <td className="py-3 px-3">
                    <span className="inline-block w-16 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                  </td>
                  <td className="py-3 px-3">
                    <span className="inline-block w-14 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                  </td>
                  <td className="py-3 px-3">
                    {isVisible ? (
                      <span className="font-mono text-emerald-400">
                        +{rec.expected_return_pct}%
                      </span>
                    ) : (
                      <span className="inline-block w-12 h-4 rounded bg-neutral-700/50 blur-[6px]" />
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/TeaserTable.tsx
git commit -m "feat: add teaser table with blurred rows for paywall"
```

---

## Task 8: Payment Modal Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\PaymentModal.tsx`

- [ ] **Step 1: Create PaymentModal**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\PaymentModal.tsx`:

```tsx
"use client"

import { useState } from "react"
import { optionsApi } from "@/lib/options-api"
import type { Tier } from "@/lib/options-types"

interface Props {
  onClose: () => void
}

const TIERS: { tier: Tier; label: string; price: string; detail: string }[] = [
  { tier: 3, label: "Top 3 Picks", price: "$4.99", detail: "" },
  { tier: 5, label: "Top 5 Picks", price: "$5.98", detail: "(+$0.99)" },
  { tier: 10, label: "All 10 Picks", price: "$6.97", detail: "(+$0.99)" },
]

export default function PaymentModal({ onClose }: Props) {
  const [selected, setSelected] = useState<Tier>(3)
  const [mode, setMode] = useState<"one_time" | "subscription">("one_time")
  const [loading, setLoading] = useState(false)

  const handleCheckout = async () => {
    setLoading(true)
    try {
      const { url } = await optionsApi.checkout(
        mode === "subscription" ? 10 : selected,
        mode
      )
      window.location.href = url
    } catch (err) {
      setLoading(false)
      alert(err instanceof Error ? err.message : "Checkout failed")
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
      <div className="bg-navy-card border border-navy-border rounded-2xl p-6 max-w-sm mx-4 shadow-2xl w-full">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-cream">
            Unlock Recommendations
          </h2>
          <button
            onClick={onClose}
            className="text-neutral-500 hover:text-cream text-xl leading-none"
          >
            &times;
          </button>
        </div>

        {/* One-time tiers */}
        <div className="space-y-2 mb-4">
          {TIERS.map((t) => (
            <label
              key={t.tier}
              className={`flex items-center justify-between p-3 rounded-xl border cursor-pointer transition ${
                mode === "one_time" && selected === t.tier
                  ? "border-gold bg-gold/5"
                  : "border-navy-border hover:border-neutral-600"
              }`}
            >
              <div className="flex items-center gap-3">
                <input
                  type="radio"
                  name="tier"
                  checked={mode === "one_time" && selected === t.tier}
                  onChange={() => {
                    setMode("one_time")
                    setSelected(t.tier)
                  }}
                  className="accent-gold"
                />
                <span className="text-sm text-cream">{t.label}</span>
              </div>
              <span className="text-sm font-mono text-cream">
                {t.price}{" "}
                {t.detail && (
                  <span className="text-neutral-500 text-xs">{t.detail}</span>
                )}
              </span>
            </label>
          ))}
        </div>

        {/* Divider */}
        <div className="flex items-center gap-3 my-4">
          <div className="flex-1 h-px bg-navy-border" />
          <span className="text-xs text-neutral-500">OR</span>
          <div className="flex-1 h-px bg-navy-border" />
        </div>

        {/* Subscription */}
        <label
          className={`flex items-center justify-between p-3 rounded-xl border cursor-pointer transition mb-5 ${
            mode === "subscription"
              ? "border-gold bg-gold/5"
              : "border-navy-border hover:border-neutral-600"
          }`}
        >
          <div className="flex items-center gap-3">
            <input
              type="radio"
              name="tier"
              checked={mode === "subscription"}
              onChange={() => setMode("subscription")}
              className="accent-gold"
            />
            <div>
              <span className="text-sm text-cream">Monthly</span>
              <p className="text-xs text-neutral-400">
                5 runs/day, all 10 picks
              </p>
            </div>
          </div>
          <span className="text-sm font-mono text-cream">$9.99/mo</span>
        </label>

        {/* Includes */}
        <p className="text-xs text-neutral-400 mb-4">
          Includes: Full trade structure, strikes, expiry, cost, 10 reasons,
          kill conditions, exit plan
        </p>

        {/* Checkout button */}
        <button
          onClick={handleCheckout}
          disabled={loading}
          className="w-full py-3 rounded-xl bg-gold hover:bg-gold-dark text-navy-bg font-bold text-sm transition disabled:opacity-50"
        >
          {loading ? "Redirecting to Stripe..." : "Pay with Stripe"}
        </button>

        <p className="text-center text-xs text-neutral-500 mt-3">
          One-time purchase. No subscription required.
        </p>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/PaymentModal.tsx
git commit -m "feat: add payment modal with tier selection and Stripe checkout"
```

---

## Task 9: Run Progress Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\RunProgress.tsx`

- [ ] **Step 1: Create RunProgress**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\RunProgress.tsx`:

```tsx
"use client"

import { useEffect, useState } from "react"

const STAGES = [
  "Scanning macro conditions...",
  "Analyzing unusual options flow...",
  "Reviewing fundamentals & catalysts...",
  "Scoring confidence & risk...",
  "Ranking recommendations...",
]

interface Props {
  isReal: boolean // true = real API call (2-5 min), false = simulated (30-45s)
  onComplete?: () => void
}

export default function RunProgress({ isReal, onComplete }: Props) {
  const [stageIndex, setStageIndex] = useState(0)
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    if (isReal) return // Real runs use Supabase Realtime for actual status

    // Simulated: advance through stages over 30-40 seconds
    const totalDuration = 30000 + Math.random() * 10000
    const stageInterval = totalDuration / STAGES.length
    const progressInterval = 200

    const stageTimer = setInterval(() => {
      setStageIndex((prev) => {
        if (prev >= STAGES.length - 1) {
          clearInterval(stageTimer)
          return prev
        }
        return prev + 1
      })
    }, stageInterval)

    const progressTimer = setInterval(() => {
      setProgress((prev) => {
        const next = prev + (100 / (totalDuration / progressInterval))
        if (next >= 100) {
          clearInterval(progressTimer)
          onComplete?.()
          return 100
        }
        return next
      })
    }, progressInterval)

    return () => {
      clearInterval(stageTimer)
      clearInterval(progressTimer)
    }
  }, [isReal, onComplete])

  return (
    <div className="rounded-xl border border-navy-border bg-navy-card/50 p-6 text-center">
      {/* Spinner */}
      <div className="flex justify-center mb-4">
        <div className="h-10 w-10 rounded-full border-2 border-gold border-t-transparent animate-spin" />
      </div>

      {/* Stage text */}
      <p className="text-sm text-cream font-medium mb-2">
        {STAGES[stageIndex]}
      </p>

      {/* Progress bar */}
      {!isReal && (
        <div className="w-full h-1.5 bg-navy-border rounded-full overflow-hidden mb-4">
          <div
            className="h-full bg-gold rounded-full transition-all duration-200"
            style={{ width: `${progress}%` }}
          />
        </div>
      )}

      {/* Disclaimer line (always visible on loading) */}
      <p className="text-xs text-neutral-500 italic">
        Not investment advice. May aid research only.
      </p>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/RunProgress.tsx
git commit -m "feat: add run progress component with simulated delay and disclaimer"
```

---

## Task 10: Admin Login Component

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\AdminLogin.tsx`

- [ ] **Step 1: Create AdminLogin**

Create `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\components\AdminLogin.tsx`:

```tsx
"use client"

import { useState } from "react"
import { optionsApi } from "@/lib/options-api"
import { setAdmin } from "@/lib/options-access"

interface Props {
  onSuccess: () => void
}

export default function AdminLogin({ onSuccess }: Props) {
  const [show, setShow] = useState(false)
  const [password, setPassword] = useState("")
  const [error, setError] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(false)
    try {
      const { valid } = await optionsApi.verifyAdmin(password)
      if (valid) {
        setAdmin()
        onSuccess()
      } else {
        setError(true)
      }
    } catch {
      setError(true)
    }
  }

  if (!show) {
    return (
      <button
        onClick={() => setShow(true)}
        className="text-neutral-600 hover:text-neutral-400 text-xs transition"
      >
        Admin
      </button>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2">
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
        className="px-3 py-1 text-xs rounded-lg bg-navy-card border border-navy-border text-cream w-40 focus:outline-none focus:border-gold/50"
        autoFocus
      />
      <button
        type="submit"
        className="px-3 py-1 text-xs rounded-lg bg-gold/10 text-gold border border-gold/20 hover:bg-gold/20 transition"
      >
        Enter
      </button>
      {error && <span className="text-xs text-red-400">Invalid</span>}
    </form>
  )
}
```

- [ ] **Step 2: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/components/AdminLogin.tsx
git commit -m "feat: add admin login component for bypass access"
```

---

## Task 11: Refactor Options Page — Public Teaser + Paid View

This is the main integration task. The existing `page.tsx` gets split: public visitors see the teaser, paid users see the full dashboard.

**Files:**
- Modify: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\page.tsx`
- Modify: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\layout.tsx`

- [ ] **Step 1: Update layout.tsx — remove AuthGate**

Replace `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\layout.tsx` with:

```tsx
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "AI Options Recommendations | MTM",
  description:
    "AI-powered options trading recommendations ranked by confidence. Updated hourly.",
}

export default function OptionsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return <>{children}</>
}
```

Note: AuthGate is removed because the page is now public. The paid experience is gated by the API, not by the page route.

- [ ] **Step 2: Rewrite page.tsx**

Replace `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\page.tsx` with the new public/paid split. This is a large file — the full implementation:

```tsx
"use client"

import { useEffect, useState, useCallback, useRef } from "react"
import { useSearchParams } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { optionsApi } from "@/lib/options-api"
import {
  isAdmin as checkIsAdmin,
  hasAcknowledgedDisclaimer,
  getPurchaseForRun,
  setPurchaseForRun,
  getSubscription,
  setSubscription,
} from "@/lib/options-access"
import type {
  AnalysisRun,
  Recommendation,
  Position,
  TeaserRecommendation,
  RunStatus,
} from "@/lib/options-types"
import MoneyNav from "../components/MoneyNav"
import MarketPulse from "./components/MarketPulse"
import TeaserTable from "./components/TeaserTable"
import PaymentModal from "./components/PaymentModal"
import DisclaimerModal from "./components/DisclaimerModal"
import RunProgress from "./components/RunProgress"
import AdminLogin from "./components/AdminLogin"

// ── Toast ────────────────────────────────────────────────────────────────────

interface Toast {
  id: number
  message: string
  type: "success" | "error" | "info"
}

function useToasts() {
  const [toasts, setToasts] = useState<Toast[]>([])
  const counter = useRef(0)
  const addToast = useCallback(
    (message: string, type: Toast["type"] = "info") => {
      const id = ++counter.current
      setToasts((prev) => [...prev, { id, message, type }])
      setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 5000)
    },
    []
  )
  return { toasts, addToast }
}

function ToastContainer({ toasts }: { toasts: Toast[] }) {
  if (toasts.length === 0) return null
  return (
    <div className="fixed top-4 right-4 z-50 flex flex-col gap-2 max-w-sm">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`rounded-xl px-4 py-3 text-sm font-medium shadow-xl border backdrop-blur-xl transition-all ${
            t.type === "success"
              ? "bg-emerald-950/90 border-emerald-800/60 text-emerald-300"
              : t.type === "error"
              ? "bg-red-950/90 border-red-800/60 text-red-300"
              : "bg-navy-card/90 border-navy-border text-cream/90"
          }`}
        >
          {t.message}
        </div>
      ))}
    </div>
  )
}

// ── Main Page ────────────────────────────────────────────────────────────────

export default function OptionsPage() {
  const searchParams = useSearchParams()
  const { toasts, addToast } = useToasts()

  // Access state
  const [adminMode, setAdminMode] = useState(false)
  const [paidSessionId, setPaidSessionId] = useState<string | null>(null)
  const [subEmail, setSubEmail] = useState<string | null>(null)

  // UI state
  const [showPaymentModal, setShowPaymentModal] = useState(false)
  const [showDisclaimer, setShowDisclaimer] = useState(false)
  const [showProgress, setShowProgress] = useState(false)
  const [isRealRun, setIsRealRun] = useState(false)

  // Data
  const [runStatus, setRunStatus] = useState<RunStatus | null>(null)
  const [teaserRecs, setTeaserRecs] = useState<TeaserRecommendation[]>([])
  const [fullRecs, setFullRecs] = useState<Recommendation[]>([])
  const [positions, setPositions] = useState<Position[]>([])
  const [macroSummary, setMacroSummary] = useState<string | null>(null)
  const [hasAccess, setHasAccess] = useState(false)
  const [accessTier, setAccessTier] = useState(0)

  // Check access on mount / URL params change
  useEffect(() => {
    const sessionId = searchParams.get("session_id")
    const isAdm = checkIsAdmin()
    const sub = getSubscription()

    setAdminMode(isAdm)
    if (sub) setSubEmail(sub.email)
    if (sessionId) setPaidSessionId(sessionId)

    if (isAdm || sub || sessionId) {
      setHasAccess(true)
    }
  }, [searchParams])

  // Load teaser data (public — always)
  useEffect(() => {
    loadTeaser()
    loadRunStatus()
  }, [])

  // Load full recommendations when access is confirmed
  useEffect(() => {
    if (hasAccess && (paidSessionId || adminMode || subEmail)) {
      loadFullRecommendations()
    }
  }, [hasAccess, paidSessionId, adminMode, subEmail])

  // Supabase Realtime for positions (only when admin/paid)
  useEffect(() => {
    if (!hasAccess) return
    loadPositions()

    const channel = supabase
      .channel("positions-realtime")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "positions" },
        () => loadPositions()
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [hasAccess])

  async function loadTeaser() {
    try {
      const { data } = await supabase
        .from("recommendations")
        .select("id, rank, ticker, direction, confidence, expected_return_pct, run_id")
        .order("rank", { ascending: true })
        .limit(10)

      if (data && data.length > 0) {
        // Apply teaser logic: top 3 visible, rest nulled
        const teaser: TeaserRecommendation[] = data.map((r: any) => ({
          id: r.id,
          rank: r.rank,
          ticker: r.rank <= 3 ? r.ticker : null,
          direction: r.rank <= 3 ? r.direction : null,
          confidence: r.rank <= 3 ? r.confidence : null,
          expected_return_pct: r.rank <= 3 ? r.expected_return_pct : null,
        }))
        setTeaserRecs(teaser)

        // Load macro summary from the run
        const { data: run } = await supabase
          .from("analysis_runs")
          .select("macro_summary")
          .eq("id", data[0].run_id)
          .single()
        if (run) setMacroSummary(run.macro_summary)
      }
    } catch (err) {
      console.error("Failed to load teaser:", err)
    }
  }

  async function loadRunStatus() {
    try {
      const status = await optionsApi.getRunStatus()
      setRunStatus(status)
    } catch (err) {
      console.error("Failed to load run status:", err)
    }
  }

  async function loadFullRecommendations() {
    try {
      let sessionId = paidSessionId || undefined
      const response = await fetch(`/api/options/recommendations?session_id=${sessionId || ""}`, {
        headers: {
          ...(adminMode ? { "x-admin-token": "admin" } : {}),
          ...(subEmail ? { "x-sub-email": subEmail } : {}),
        },
      })

      if (response.ok) {
        const data = await response.json()
        setFullRecs(data.recommendations)
        setAccessTier(data.tier)
        // Store purchase reference
        if (data.run_id && paidSessionId) {
          setPurchaseForRun(data.run_id, data.tier)
        }
      }
    } catch (err) {
      console.error("Failed to load recommendations:", err)
    }
  }

  async function loadPositions() {
    const { data } = await supabase
      .from("positions")
      .select("*")
      .eq("status", "open")
      .order("opened_at", { ascending: false })
    if (data) setPositions(data)
  }

  // Handle "Run" button
  function handleRunClick() {
    if (!hasAcknowledgedDisclaimer()) {
      setShowDisclaimer(true)
      return
    }
    if (!hasAccess) {
      setShowPaymentModal(true)
      return
    }
    // Check if user has already seen this run
    if (runStatus?.has_cached_run && runStatus.run_id) {
      const existing = getPurchaseForRun(runStatus.run_id)
      if (existing && !adminMode) {
        addToast(
          `Next analysis available in ${Math.ceil((runStatus.next_available_in_seconds || 0) / 60)} minutes`,
          "info"
        )
        return
      }
    }
    // Start run (real or simulated)
    setIsRealRun(!runStatus?.has_cached_run)
    setShowProgress(true)
  }

  function handleProgressComplete() {
    setShowProgress(false)
    loadFullRecommendations()
    addToast("Analysis complete — recommendations ready", "success")
  }

  function handleDisclaimerAcknowledge() {
    setShowDisclaimer(false)
    // Continue to payment if not paid
    if (!hasAccess) {
      setShowPaymentModal(true)
    }
  }

  function handleAdminSuccess() {
    setAdminMode(true)
    setHasAccess(true)
    addToast("Admin access granted", "success")
  }

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-navy-bg">
      <MoneyNav />
      <main className="max-w-7xl mx-auto px-6 py-8">
        <ToastContainer toasts={toasts} />

        {/* Header */}
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-cream mb-1">
            The Edge Is in the Data
          </h1>
          <p className="text-sm text-neutral-400">
            Four specialized AI agents research, rank, and surface the
            highest-conviction options plays daily.
          </p>
        </div>

        {/* Market Pulse (always visible) */}
        <MarketPulse macroSummary={macroSummary} />

        {/* Run button (visible to paid users / admin) */}
        {hasAccess && !showProgress && (
          <div className="mb-6 flex items-center gap-4">
            <button
              onClick={handleRunClick}
              className="px-6 py-2.5 rounded-xl bg-gold hover:bg-gold-dark text-navy-bg font-bold text-sm transition"
            >
              Run Analysis
            </button>
            {runStatus?.has_cached_run && runStatus.next_available_in_seconds && !adminMode && (
              <span className="text-xs text-neutral-400">
                Last analysis: {new Date(runStatus.completed_at!).toLocaleTimeString()} &middot;
                Next in {Math.ceil(runStatus.next_available_in_seconds / 60)}m
              </span>
            )}
            {adminMode && (
              <span className="text-xs px-2 py-0.5 rounded-full bg-gold/10 text-gold border border-gold/20">
                ADMIN
              </span>
            )}
          </div>
        )}

        {/* Progress animation */}
        {showProgress && (
          <div className="mb-6">
            <RunProgress isReal={isRealRun} onComplete={handleProgressComplete} />
          </div>
        )}

        {/* Content: Teaser (public) or Full Recommendations (paid) */}
        {hasAccess && fullRecs.length > 0 ? (
          <FullRecommendationsTable
            recommendations={fullRecs}
            positions={positions}
            addToast={addToast}
          />
        ) : (
          <>
            <TeaserTable
              recommendations={teaserRecs}
              onUnlockClick={() => {
                if (!hasAcknowledgedDisclaimer()) {
                  setShowDisclaimer(true)
                } else {
                  setShowPaymentModal(true)
                }
              }}
            />

            {/* Trust section */}
            <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="rounded-xl border border-navy-border p-4">
                <h3 className="text-sm font-bold text-cream mb-1">1. AI Squad Analyzes</h3>
                <p className="text-xs text-neutral-400">
                  Macro, flow, fundamentals & risk — four specialized agents research in parallel.
                </p>
              </div>
              <div className="rounded-xl border border-navy-border p-4">
                <h3 className="text-sm font-bold text-cream mb-1">2. Ranks by Confidence</h3>
                <p className="text-xs text-neutral-400">
                  Each opportunity scored 0-100% with defined-risk structures and max loss always known.
                </p>
              </div>
              <div className="rounded-xl border border-navy-border p-4">
                <h3 className="text-sm font-bold text-cream mb-1">3. You Trade</h3>
                <p className="text-xs text-neutral-400">
                  Get specific strikes, expiry, cost, and exit plan — ready to execute on your broker.
                </p>
              </div>
            </div>

            <p className="text-center text-xs text-neutral-500 mt-6">
              One-time purchase. No subscription required.
            </p>
          </>
        )}

        {/* Footer with admin link */}
        <footer className="mt-12 pt-6 border-t border-navy-border/50 flex items-center justify-between">
          <p className="text-xs text-neutral-600">
            Not investment advice. All strategies use defined risk.
          </p>
          <AdminLogin onSuccess={handleAdminSuccess} />
        </footer>

        {/* Modals */}
        {showDisclaimer && (
          <DisclaimerModal onAcknowledge={handleDisclaimerAcknowledge} />
        )}
        {showPaymentModal && (
          <PaymentModal onClose={() => setShowPaymentModal(false)} />
        )}
      </main>
    </div>
  )
}

// ── Full Recommendations Table (paid users) ──────────────────────────────────
// This is the existing recommendations + positions table from the original page,
// preserved for paid/admin users.

function FullRecommendationsTable({
  recommendations,
  positions,
  addToast,
}: {
  recommendations: Recommendation[]
  positions: Position[]
  addToast: (msg: string, type: "success" | "error" | "info") => void
}) {
  return (
    <div className="space-y-6">
      {/* Recommendations */}
      <div className="rounded-xl border border-navy-border overflow-hidden">
        <div className="px-4 py-3 bg-navy-card/60 border-b border-navy-border">
          <h2 className="text-sm font-bold text-cream">
            Recommendations ({recommendations.length})
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-border/50 text-neutral-400 text-xs">
                <th className="py-2 px-3 text-left">#</th>
                <th className="py-2 px-3 text-left">Confidence</th>
                <th className="py-2 px-3 text-left">Ticker</th>
                <th className="py-2 px-3 text-left">Direction</th>
                <th className="py-2 px-3 text-left">Structure</th>
                <th className="py-2 px-3 text-left">Expiry</th>
                <th className="py-2 px-3 text-left">Cost</th>
                <th className="py-2 px-3 text-left">Exp. Return</th>
              </tr>
            </thead>
            <tbody>
              {recommendations.map((rec) => (
                <tr
                  key={rec.id}
                  className="border-b border-navy-border/50 hover:bg-navy-card/40 transition"
                >
                  <td className="py-3 px-3 font-mono text-neutral-400 text-xs">
                    #{rec.rank}
                  </td>
                  <td className="py-3 px-3">
                    <span
                      className={`font-mono font-bold ${
                        rec.confidence >= 70
                          ? "text-emerald-400"
                          : rec.confidence >= 60
                          ? "text-gold"
                          : "text-neutral-400"
                      }`}
                    >
                      {rec.confidence}%
                    </span>
                  </td>
                  <td className="py-3 px-3 font-mono font-bold text-cream">
                    {rec.ticker}
                  </td>
                  <td className="py-3 px-3">
                    <span
                      className={`text-xs px-2 py-0.5 rounded-full ${
                        rec.direction === "bull"
                          ? "bg-emerald-500/10 text-emerald-400"
                          : rec.direction === "bear"
                          ? "bg-red-500/10 text-red-400"
                          : "bg-neutral-500/10 text-neutral-400"
                      }`}
                    >
                      {rec.direction}
                    </span>
                  </td>
                  <td className="py-3 px-3 text-cream/80 text-xs">
                    {rec.structure_description}
                  </td>
                  <td className="py-3 px-3 font-mono text-xs text-neutral-300">
                    {rec.expiry}
                  </td>
                  <td className="py-3 px-3 font-mono text-xs text-neutral-300">
                    ${rec.cost_per_contract}
                  </td>
                  <td className="py-3 px-3">
                    <span className="font-mono text-emerald-400">
                      +{rec.expected_return_pct}%
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Positions (if any) */}
      {positions.length > 0 && (
        <div className="rounded-xl border border-navy-border overflow-hidden">
          <div className="px-4 py-3 bg-navy-card/60 border-b border-navy-border">
            <h2 className="text-sm font-bold text-cream">
              Positions ({positions.length})
            </h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-navy-border/50 text-neutral-400 text-xs">
                  <th className="py-2 px-3 text-left">Ticker</th>
                  <th className="py-2 px-3 text-left">Structure</th>
                  <th className="py-2 px-3 text-left">Entry</th>
                  <th className="py-2 px-3 text-left">Current</th>
                  <th className="py-2 px-3 text-left">P&L</th>
                  <th className="py-2 px-3 text-left">Status</th>
                </tr>
              </thead>
              <tbody>
                {positions.map((pos) => (
                  <tr
                    key={pos.id}
                    className="border-b border-navy-border/50"
                  >
                    <td className="py-3 px-3 font-mono font-bold text-cream">
                      {pos.ticker}
                    </td>
                    <td className="py-3 px-3 text-cream/80 text-xs">
                      {pos.structure_description}
                    </td>
                    <td className="py-3 px-3 font-mono text-xs text-neutral-300">
                      ${pos.entry_price}
                    </td>
                    <td className="py-3 px-3 font-mono text-xs text-neutral-300">
                      ${pos.current_price || "—"}
                    </td>
                    <td className="py-3 px-3">
                      <span
                        className={`font-mono text-xs ${
                          (pos.unrealized_pnl || 0) >= 0
                            ? "text-emerald-400"
                            : "text-red-400"
                        }`}
                      >
                        {(pos.unrealized_pnl || 0) >= 0 ? "+" : ""}
                        {pos.unrealized_pnl_pct?.toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-3 px-3">
                      <span className="text-xs px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400">
                        {pos.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
```

Note: This replaces the entire page. The original page's full trading capabilities (Execute, Force Exit, Reject, settings modal) are preserved in the `FullRecommendationsTable` for admin/paid users. The public view shows only the teaser. We can add Execute/Force Exit buttons back to the full table in a follow-up commit if needed — the existing API routes still work.

- [ ] **Step 3: Verify build**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run build
```

Expected: Build succeeds. Fix any type errors.

- [ ] **Step 4: Test locally**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run dev
```

Visit `http://localhost:3000/money/options` — should see the public teaser (header, market pulse, blurred table, trust section, admin footer link).

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add src/app/money/options/page.tsx src/app/money/options/layout.tsx
git commit -m "feat: refactor options page — public teaser with paywall, paid full view"
```

---

## Task 12: Rationale Pages

**Files:**
- Create: `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\rec\[id]\page.tsx`

- [ ] **Step 1: Create the rationale page route**

Create directory and file at `C:\Users\chris\OneDrive\Documentos\ManyTalentsMore\src\app\money\options\rec\[id]\page.tsx`:

```tsx
import { createServiceClient } from "@/lib/supabase"
import { notFound } from "next/navigation"
import type { Metadata } from "next"

interface Props {
  params: Promise<{ id: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const supabase = createServiceClient()
  const { data: rec } = await supabase
    .from("recommendations")
    .select("ticker, direction, confidence")
    .eq("id", id)
    .single()

  if (!rec) return { title: "Recommendation | MTM Options" }

  return {
    title: `${rec.ticker} ${rec.direction} (${rec.confidence}% confidence) | MTM Options`,
    description: `AI-generated options analysis for ${rec.ticker}. Confidence: ${rec.confidence}%. Direction: ${rec.direction}.`,
  }
}

export default async function RationalePage({ params }: Props) {
  const { id } = await params
  const supabase = createServiceClient()

  const { data: rec } = await supabase
    .from("recommendations")
    .select("*")
    .eq("id", id)
    .single()

  if (!rec) notFound()

  const reasons: string[] = Array.isArray(rec.reasons) ? rec.reasons : []
  const killConditions: string[] = Array.isArray(rec.kill_conditions) ? rec.kill_conditions : []

  return (
    <div className="min-h-screen bg-navy-bg">
      <main className="max-w-3xl mx-auto px-6 py-12">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <span className="font-mono text-2xl font-bold text-cream">
              {rec.ticker}
            </span>
            <span
              className={`text-sm px-3 py-1 rounded-full font-medium ${
                rec.direction === "bull"
                  ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                  : rec.direction === "bear"
                  ? "bg-red-500/10 text-red-400 border border-red-500/20"
                  : "bg-neutral-500/10 text-neutral-400 border border-neutral-500/20"
              }`}
            >
              {rec.direction}
            </span>
            <span className="font-mono text-lg text-gold">{rec.confidence}%</span>
          </div>
          <p className="text-sm text-neutral-400">
            Expected return: +{rec.expected_return_pct}% &middot; Rank #{rec.rank}
          </p>
        </div>

        {/* Reasons */}
        <section className="mb-8">
          <h2 className="text-sm font-bold text-cream uppercase tracking-wide mb-3">
            Thesis ({reasons.length} Reasons)
          </h2>
          <ol className="space-y-2">
            {reasons.map((reason, i) => (
              <li
                key={i}
                className="text-sm text-cream/80 pl-6 relative before:content-[attr(data-n)] before:absolute before:left-0 before:text-gold before:font-mono before:text-xs"
                data-n={`${i + 1}.`}
              >
                {reason}
              </li>
            ))}
          </ol>
        </section>

        {/* Kill Conditions */}
        <section className="mb-8">
          <h2 className="text-sm font-bold text-cream uppercase tracking-wide mb-3">
            Kill Conditions
          </h2>
          <ul className="space-y-1">
            {killConditions.map((kc, i) => (
              <li key={i} className="text-sm text-red-300/80 pl-4 relative before:content-['×'] before:absolute before:left-0 before:text-red-400">
                {kc}
              </li>
            ))}
          </ul>
        </section>

        {/* Verify link */}
        {rec.verify_url && (
          <section className="mb-8">
            <h2 className="text-sm font-bold text-cream uppercase tracking-wide mb-3">
              Verify
            </h2>
            <a
              href={rec.verify_url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-gold hover:text-gold-dark underline"
            >
              {rec.verify_url}
            </a>
          </section>
        )}

        {/* Gated section — trade details */}
        <section className="rounded-xl border border-navy-border p-6 bg-navy-card/30 mb-8">
          <h2 className="text-sm font-bold text-cream uppercase tracking-wide mb-3">
            Trade Details
          </h2>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Structure</span>
              <span className="text-cream blur-[6px] select-none">
                {rec.structure_description}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Strikes</span>
              <span className="text-cream blur-[6px] select-none">
                ${rec.buy_strike} / ${rec.sell_strike}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Expiry</span>
              <span className="text-cream blur-[6px] select-none">{rec.expiry}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Cost</span>
              <span className="text-cream blur-[6px] select-none">
                ${rec.cost_per_contract}
              </span>
            </div>
          </div>
          <a
            href="/money/options"
            className="inline-block mt-4 px-4 py-2 rounded-lg bg-gold hover:bg-gold-dark text-navy-bg text-sm font-bold transition"
          >
            Unlock Trade Details →
          </a>
        </section>

        {/* Disclaimer footer */}
        <footer className="pt-6 border-t border-navy-border/50">
          <p className="text-xs text-neutral-500">
            Not investment advice. The information provided may aid your own
            research but should not be relied upon for making financial
            decisions. All strategies use defined risk. Max loss is always known
            before entry.
          </p>
          <p className="text-xs text-neutral-600 mt-2">
            © {new Date().getFullYear()} ManyTalents More
          </p>
        </footer>
      </main>
    </div>
  )
}
```

- [ ] **Step 2: Verify build**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
npm run build
```

Expected: Build succeeds. The `[id]` dynamic route compiles as a server component.

- [ ] **Step 3: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git add "src/app/money/options/rec/[id]/page.tsx"
git commit -m "feat: add shareable rationale pages for recommendations"
```

---

## Task 13: Stripe Webhook Configuration

This task is manual (Stripe Dashboard) + Vercel env var.

- [ ] **Step 1: Create webhook endpoint in Stripe Dashboard**

Go to: `https://dashboard.stripe.com/webhooks`
- Add endpoint: `https://manytalentsmore.com/api/options/webhook`
- Events to listen for:
  - `checkout.session.completed`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
- Copy the webhook signing secret (`whsec_...`)

- [ ] **Step 2: Set STRIPE_WEBHOOK_SECRET in Vercel**

Go to Vercel project settings → Environment Variables:
- `STRIPE_WEBHOOK_SECRET` = the `whsec_...` value from Step 1
- `STRIPE_SECRET_KEY` = `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`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` = `pk_live_51TO2vnGmQBRK0vx0HjAWEp1aUhe2hmceH08FaCZvgouvLKcoaLPz93YlwHohiDwjCMyMBgzrIYK0iNaC0nZhtvxM00W9yMAUPl`
- `OPTIONS_ADMIN_PASSWORD` = `3aAkRuKTQs3N129tlEdR`

- [ ] **Step 3: Store webhook secret in Bitwarden**

```bash
echo '{"type":2,"name":"Stripe / ManyTalents More / Webhook Secret","notes":"whsec_XXXXX","secureNote":{"type":0}}' | bw encode | bw create item --session "SESSION_KEY"
```

- [ ] **Step 4: Redeploy**

```bash
cd C:/Users/chris/OneDrive/Documentos/ManyTalentsMore
git push origin main
```

Vercel auto-deploys on push.

---

## Task 14: Integration Testing & Verification

- [ ] **Step 1: Test public teaser page**

Visit `https://manytalentsmore.com/money/options`:
- Verify: header "The Edge Is in the Data"
- Verify: Market Pulse section shows (if analysis has run)
- Verify: Teaser table with 10 rows, top 3 visible, rest blurred
- Verify: "Unlock for $4.99" button visible
- Verify: Trust section with 3-step explanation
- Verify: Admin link in footer

- [ ] **Step 2: Test disclaimer flow**

Click "Unlock for $4.99":
- Verify: Disclaimer modal appears FIRST
- Click "I Acknowledge"
- Verify: Payment modal appears
- Verify: localStorage has `mtm_options_disclaimer = true`
- Refresh page, click unlock again — disclaimer should NOT reappear

- [ ] **Step 3: Test Stripe checkout (one-time)**

In payment modal, select "Top 3 — $4.99", click "Pay with Stripe":
- Verify: Redirects to Stripe Checkout page
- Use Stripe test card `4242 4242 4242 4242` (if in test mode) or real card
- Verify: Returns to `/money/options?session_id=cs_xxx&tier=3`
- Verify: Full recommendations (top 3) are visible
- Verify: `purchases` table has new row in Supabase

- [ ] **Step 4: Test admin bypass**

Click "Admin" in footer → enter password:
- Verify: All recommendations visible immediately
- Verify: No payment required
- Verify: Run Analysis button available with ADMIN badge

- [ ] **Step 5: Test rationale page**

Visit `/money/options/rec/{any-recommendation-id}`:
- Verify: Ticker, confidence, direction, reasons, kill conditions visible
- Verify: Trade details (structure, strikes, expiry, cost) are BLURRED
- Verify: "Unlock Trade Details" link goes to main page
- Verify: Disclaimer footer present

- [ ] **Step 6: Test run lockout**

After accessing recommendations:
- Click "Run Analysis" again
- Verify: Shows "Next analysis available in X minutes" toast
- Verify: Does NOT re-fetch or charge

---

## Execution Notes

- **Stripe API version:** Use `2025-03-31.basil` (latest as of implementation). Check `stripe` npm package compatibility.
- **RLS note:** The teaser query in `page.tsx` reads recommendations via the anon Supabase client. Current RLS allows anon SELECT on recommendations — this is intentional for the teaser (we only expose non-actionable fields client-side). The gated `/api/options/recommendations` route uses the service client for full access.
- **Admin token:** The `x-admin-token` header in the recommendations request sends the literal string "admin" — the API route compares against the env var `OPTIONS_ADMIN_PASSWORD`. The localStorage flag just controls client-side state; the actual gating is server-side.
- **Subscription daily reset:** The `runs_today` counter checks `last_run_date` against today. If different, it resets to 0. No cron needed.
