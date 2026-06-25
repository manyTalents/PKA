# Pixel — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->


---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->


---

## Lessons

### General: Generic Part Names in Tech-Facing Views
- **Category:** UI/UX, naming
- **Lesson:** Tech-facing screens must use simple, recognizable part names (e.g., "3/4 AC line set"), never verbose manufacturer descriptions -- techs know what parts are, and long names clutter the UI.
- **Context:** Standard #4. Techs in the field need to scan parts quickly. Verbose names like "3/4 in. x 1/2 in. Copper Line Set 15ft Pre-Charged" slow them down and cause scrolling/truncation issues on mobile. Short names were adopted as the team-wide standard.
- **Keywords:** generic names, part names, tech-facing, verbose, mobile, UI clutter

### General: Shared Components -- No Duplicate Implementations
- **Category:** UI/UX, architecture
- **Lesson:** When search, matching, or display functionality appears on multiple screens, it must be ONE shared component imported everywhere -- never two separate implementations that will drift apart.
- **Context:** Standard #5. Two implementations of the same function will diverge as one gets updated and the other does not. Users see inconsistent behavior. The searchParts() function is defined once and imported by Limbo matching, "add part to job," and any future search screen.
- **Keywords:** shared component, duplicate, search, import, consistency, drift

### General: Three-Tier Confidence Color System
- **Category:** UI/UX, design pattern
- **Lesson:** Use the established three-tier confidence color system for match quality: white (low), sky blue (medium), dark cobalt (high) -- this pattern is now a recognized convention across the platform.
- **Context:** Matching interfaces (Limbo, part lookup) needed a visual way to communicate match confidence to users. The three-tier color system was established and must be reused consistently on any screen that shows match quality. Deviating from this palette confuses users who have learned the convention.
- **Keywords:** confidence tiers, color system, white, sky blue, cobalt, match quality, Limbo

