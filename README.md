# DataLens

**AI-powered investment research platform** that turns complex company financial reports into clear,
evidence-backed analysis for self-directed retail investors. Initial market: Nigerian listed companies (NGX).

> DataLens informs the investor — it does not make the investment decision.

**Status: installable PWA prototype.** Runs offline, installs on Android, and packages as an APK.
No backend yet — it operates on bundled sample data. See [Current Scope](#current-scope).

---

## Quick Start

```powershell
# 1. Serve the app locally (service workers need localhost or HTTPS)
powershell -ExecutionPolicy Bypass -File tools\serve.ps1

# 2. Open http://localhost:8080
```

To test on a real phone, deploy to GitHub Pages first — see **[APK-BUILD.md](APK-BUILD.md)**.

---

## Project Files

| File | What it is |
|------|------------|
| **`PRD.md`** | Product Requirements Document v2 — scope, MVP definition, architecture, phased plan |
| **`APK-BUILD.md`** | PWA + Android APK build guide, distribution options, troubleshooting |
| **`index.html`** | The app. Installable PWA with 7 views, offline support, sample data |
| **`design.html`** | Design system style guide — tokens, typography, states, components |
| `manifest.webmanifest` | PWA manifest — name, icons, display mode, app shortcuts |
| `sw.js` | Service worker — offline shell, update handling |
| `offline.html` | Fallback page shown when the network is unreachable |
| `icons/` | Generated app icons (192/384/512, maskable, apple-touch, favicon) |
| `.well-known/assetlinks.json` | Digital Asset Links — proves the APK owns this domain |
| `twa-manifest.json` | Bubblewrap/TWA config for the Android wrapper |
| `.nojekyll` | Stops GitHub Pages stripping `.well-known/` |
| `tools/serve.ps1` | Local static server with correct MIME types + traversal guard |
| `tools/generate-icons.ps1` | Draws the icon set from brand tokens — no design tool needed |
| `archive/PRD v1 (original).md` | Superseded first-pass PRD |

No build step, no bundler, no dependencies. Everything is static and works offline.

---

## Installing on Android

**As a PWA** (recommended — updates instantly, no permissions):

1. Deploy to GitHub Pages (2 clicks, see `APK-BUILD.md`)
2. Open the HTTPS URL in Chrome
3. Tap the ⤓ button in the header, or Chrome menu → **Install app**

**As an APK** (fallback): follow the PWA Builder route in `APK-BUILD.md`. Builds a signed APK in
your browser with no Android tooling required.

---

## The App — 7 views

| View | PRD ref | What it does |
|------|---------|--------------|
| **Snapshot** | §6 | Six-pillar financial health overview. Each pillar shows status + evidence + explanation with clickable page citations |
| **Ask** | §10 | Conversational analysis. Answers are computed from the underlying data; every figure carries a citation |
| **Signals** | §12 | Risk and anomaly detection with exact figures, severity and suggested follow-up questions |
| **Peers** | §14 | Peer comparison with percentile rankings and trend sparklines |
| **What Changed** | §18 | Year-over-year metric diff with driver attribution linked to report notes |
| **My Thesis** | §19 | Structured thesis editor, metric watchlist, version history. Persists to `localStorage` |
| **Reports** | §22 | Report list with extraction confidence and flagged sections |

**Four companies** with deliberately different financial profiles, so the analysis engine has to
actually discriminate rather than echo one template:

| | Profile | Signals |
|---|---|---|
| `GTCO` | Cash flow diverging from reported profit | 1 |
| `ZNB` | Strong on every pillar | 1 |
| `ACCESS` | Margin compression, NPL spike, capital adequacy below 20% | 3 |
| `MTNN` | Receivables +38% vs revenue +12%, opex outpacing revenue | 2 |

**Things to try**

- Click any citation badge (`p.38`, `mkt`) → full evidence chain with the actual arithmetic
- "Explain …" under a pillar → Quick / Standard / Deep, where Deep prints the real figures
- "Explore" on a signal → jumps to chat with the question pre-loaded
- Switch companies → different data, signals and peer sets
- Turn off your network → app still opens
- Long-press the installed app icon → Ask / Signals / Thesis shortcuts

**Design rules enforced in the UI**

- Provenance is never hidden — every figure is labelled `reported`, `calc` or `mkt`
- Colour never carries meaning alone — every status pairs it with a text label
- No arbitrary health score
- No buy/hold/sell language anywhere
- Missing data shows `—` and is excluded from averages, never imputed

---

## Current Scope

**Included:** the complete PWA experience — all 7 views, offline operation, installability,
APK packaging, responsive layout, light/dark themes.

**Not yet included:** accounts, database, and the Supabase / Groq / Slack integrations. There is no
backend in this build. The app runs entirely on bundled sample data for four companies; thesis
edits persist in device storage but do not sync between devices.

That is deliberate — this build proves the app installs, launches and works on real Android
hardware. The backend is the next milestone.

---

## Design System — `design.html`

**Signal Blue + Terminal Slate + Tape Gold**

- **Signal Blue** `#2962ff` — primary actions, focus, navigation
- **Tape Gold** `#e8a90d` — the signature. Evidence highlights, sparkline strokes, data accents.
  Always paired with near-black ink, because white on gold fails contrast
- **Terminal Slate** — blue-tinted charcoal surfaces with an inverted neutral ramp, so one token
  name resolves correctly in both themes
- **Market direction** — teal up, coral down, amber caution, cyan market data
- **Type** — Inter for UI, JetBrains Mono with `tabular-nums` for every figure

---

## Tech Stack (Free-First)

The shipped prototype has **zero dependencies**. The planned production stack is designed around free tiers.

| Layer | Choice | Cost |
|-------|--------|------|
| Frontend | Static PWA now; Vite + React when the backend lands | $0 |
| Database + vector + auth + storage | Supabase Free (PostgreSQL + pgvector + Auth + Storage) | $0 |
| Background jobs | BullMQ + Redis | $0 |
| LLM | Groq API Free Tier (Llama 3.1 70B) in production, Ollama locally | $0 |
| Embeddings | `nomic-embed-text` via Ollama → pgvector | $0 |
| Market data | Alpha Vantage Free, manual NGX price entry, Frankfurter FX | $0 |
| Document processing | `pdf-parse`, `unpdf`, `pdfjs-dist`, `tesseract.js` | $0 |
| Observability | PostHog Free + Sentry Free + custom cost tracking | $0 |
| Hosting | GitHub Pages Free (current) | $0 |
| CI/CD | GitHub Actions | $0 |

**Target MVP recurring cost: $0–$5/month.**

---

## Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| — | PRD, design system, prototype, PWA + APK packaging | ✅ Done |
| 0 | Backend scaffold, Supabase, auth, schema, RLS | ⬜ Next |
| 1 | PDF extraction pipeline | ⬜ |
| 2 | Core data model + pgvector | ⬜ |
| 3–5 | Snapshot, evidence, conversational RAG | ⬜ |
| 6–9 | Signals, peers, thesis, monitoring | ⬜ |
| 10 | React rebuild + adaptive presentation | ⬜ |
| 11 | Hardening, evaluation, external release | ⬜ |

Full detail in `PRD.md`.

---

## Disclaimer

DataLens provides research information, **not investment advice**. Analysis is based on
company-reported figures and may contain errors. Nothing here is a recommendation to buy, hold, or
sell any security.

All figures in `index.html` are **illustrative sample data** created for a Nigerian market context.
They are not real reported results for the companies named. Verify every figure against the source
report before making any investment decision.