# Strategic Spec: MTM as Multi-Instance SaaS Platform

**Date:** 2026-05-31
**Authors:** Claude (10Tc) + Grok (10Tg) + Chris (Owner)
**Status:** Strategic direction — approved in principle, family-first execution
**Origin:** Colab v1 session, rounds 24-25

---

## The Vision

ManyTalents Manager becomes a managed ERPNext hosting platform with vertical-specific apps and AI services. One frontend (manytalentsmore.com), login is the gate, each client gets their own ERPNext instance on shared infrastructure.

## Architecture

```
homes.manytalentsmore.com (PM vertical)
services.manytalentsmore.com (service company vertical)
    → Login → JWT with backend routing
    → Client A → droplet-1 (ERPNext site A)
    → Client B → droplet-1 (ERPNext site B, same droplet)
    → Client C → droplet-2 (new droplet when capacity fills)
```

### Multi-Instance (NOT Multi-Tenant)
- Each client gets their own Frappe site + database
- 3-5 sites per $28/mo droplet
- Zero customization drift — clients customize freely without affecting others
- Zero data isolation risk — separate databases
- Same golden Docker image for all (mtm_property + mtm_service baked in)
- Horizontal scaling — add droplets as needed

### Modules
- **MTM Property** (mtm_property) — PM vertical: units, leases, tenants, owners, billing, maintenance, portals
- **MTM Service** (mtm_service) — service vertical: jobs, trucks, techs, invoicing, receipts
- **MTM Trade** — test prep (existing)
- **MTM Money** — trading dashboards (existing)

## Economics (Chris's Model)

Chris's insight: "If I can get this working for my family from my laptop, I can do it for $50 or less. If I take home $5 a client I'll make over my current check."

| Scale | Clients | Revenue/mo | Infra/mo | Take-home/mo |
|-------|---------|-----------|----------|-------------|
| Family | 2 (AllTec + Providence) | $0 | $28 | Proof of concept |
| Early | 50 | $2,500 | ~$400 | ~$2,100 |
| Growth | 1,000 | $50,000 | ~$8,000 | ~$42,000 |
| Scale | 10,000 | $500,000 | ~$70,000 | ~$430,000 |

Additional revenue: AI API costs passed through at 20% markup (estimates, intake, customer service).

Pricing is not fixed at $50 — could be lower to disrupt subscription model entirely. Even $5/year/client at massive scale changes the game.

## Support Model

- Contract out droplet groups to DevOps people (infrastructure)
- AI-first product support (self-serve, in-app guidance, automated onboarding)
- Human QC and relationship maintenance only
- Tiered: self-serve base, human support on premium

## Onboarding Flow

1. Client signs up at homes/services.manytalentsmore.com
2. AI intake: "Tell me about your business" → determines modules
3. Automated provisioning: DigitalOcean API → Docker → bench new-site → install apps
4. AI walks client through setup
5. Client live in < 1 hour

## Technical Requirements (Not Yet Built)

- [ ] Provisioning automation script (DO API → Docker → bench → apps → routing table)
- [ ] Frontend auth routing (JWT + backend URL lookup from central DB/Redis)
- [ ] Golden Docker image with mtm_property + mtm_service
- [ ] White-label theme system (company config → CSS variables)
- [ ] Rename providence_pm → mtm_property
- [ ] AI onboarding intake flow
- [ ] Droplet health monitoring + alerting
- [ ] Update pipeline (canary rollouts per client cohort)

## Key Risks (from Grok's Analysis)

1. **Infra cost creep** — storage, AI usage, photos grow over time. Budget 30-50% increase per client over 12 months.
2. **Onboarding reliability** — must work at 2am without human intervention.
3. **Support telephone game** — contracted DevOps + AI support can create confusion. Clear escalation paths needed.
4. **$50 pricing psychology** — must feel like a steal, not "cheapest option."
5. **Engineer competition** — AI will enable more people to build similar platforms. Speed to market + AI integration depth is the moat.

## Execution Order

1. **NOW:** Get family stuff working (AllTec + Providence on same infra, proven)
2. **NEXT:** Rename providence_pm → mtm_property, build golden Docker image
3. **THEN:** Provisioning automation + frontend routing
4. **THEN:** First external client (find one PM company willing to try for free/cheap)
5. **THEN:** AI onboarding + self-serve support
6. **THEN:** Scale

## Chris's Strategic Insight

"I expect rates to start dropping on things. What I am thinking is incorporating AI into the services and charging 20% on the API costs. We'll be making estimates and checking pricing and intaking customers and renters with AI — largely humans just QCing basically and maintaining relationships."

The moat isn't the code — it's the AI integration depth and the willingness to price below what traditional SaaS charges because the cost structure is fundamentally different (one person + AI vs engineering teams).
