# Swift — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Lessons

### 2026-05-17: OneDrive EPERM blocks EAS builds
- **Category:** mobile
- **Lesson:** EAS (Expo Application Services) builds must run from a non-OneDrive directory — OneDrive file locking causes EPERM errors that fail the build.
- **Context:** Running `eas build` from a project directory inside OneDrive (`C:\Users\chris\OneDrive\...`) triggered EPERM (permission denied) errors because OneDrive's sync agent locks files during read/write. Fix: copy or clone the project to a local temp directory outside OneDrive (e.g., `C:\temp\project`) before running EAS builds.
- **Keywords:** EAS, Expo, OneDrive, EPERM, build, permission, temp directory, file lock

### 2026-05-18: TTS reads Unicode arrows aloud
- **Category:** mobile
- **Lesson:** Sanitize Unicode characters (arrows, symbols, special chars) from text before passing to `Speech.speak()` — TTS engines will read them as literal character names.
- **Context:** Flashcard content included Unicode arrows (e.g., right arrow, up arrow) for visual formatting. When TTS read the card aloud, it pronounced each arrow as "rightwards arrow" or similar, breaking the audio experience. Fix: strip or replace Unicode symbols with plain-text equivalents before calling `Speech.speak()`.
- **Keywords:** TTS, Speech.speak, Unicode, arrows, sanitize, Expo Speech, accessibility

### 2026-05-18: Flashcard content overflow with fixed-height Views
- **Category:** mobile
- **Lesson:** For variable-length content (flashcards, notes), use `ScrollView` with `maxHeight` instead of a fixed-height `View` with `overflow: 'hidden'` — hidden overflow silently truncates content.
- **Context:** Flashcard answers with long text were cut off because the container used a fixed-height `View` with `overflow: 'hidden'`. Users could not see the full answer. Fix: replace with `ScrollView` and `maxHeight` so content remains scrollable when it exceeds the visible area.
- **Keywords:** ScrollView, overflow, maxHeight, flashcard, View, content truncation, layout

### 2026-04-04: npm install wipes patched ngrok binary
- **Category:** mobile
- **Lesson:** After running `npm install` on the mobile app, re-apply the ngrok v3 binary patch — `@expo/ngrok` reinstalls the deprecated v2 binary on every install.
- **Context:** SOLUTIONS_LOG #6. `@expo/ngrok` bundles ngrok v2, whose servers are deprecated. The fix (replace binary + patch client.js/utils.js) gets overwritten by every `npm install`. Must re-copy ngrok v3 binary to `node_modules/@expo/ngrok-bin-win32-x64/ngrok.exe` and re-patch after each install. Standard #12 created from this.
- **Keywords:** npm install, ngrok, Expo, tunnel, binary patch, v2, v3, node_modules

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

