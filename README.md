# DataLens

**AI-powered investment research platform** that turns complex company financial reports into clear,
evidence-backed analysis for self-directed retail investors. Initial market: Nigerian listed companies (NGX).

> DataLens informs the investor — it does not make the investment decision.

---

## Project Files

| File | What it is | Open with |
|------|------------|-----------|
| **`PRD.md`** | Product Requirements Document v2 — product scope, MVP definition, technical architecture, phased build plan, risks | Any Markdown viewer / GitHub |
| **`design.html`** | Design system style guide — colour tokens, typography, button states, form inputs, cards, and every DataLens product component | Double-click in a browser |
| **`index.html`** | Working front-end prototype — full app shell with snapshot, chat, signals, peers, diff, thesis and report views | Double-click in a browser |
| `archive/PRD v1 (original).md` | Superseded first-pass PRD, kept for reference | Any Markdown viewer |

No build step, no dependencies, no backend. Both HTML files are fully self-contained and work offline.

---

## Prototype — `index.html`

A working front-end application covering the core MVP flows from the PRD.

**Seven views**

| View | PRD ref | What it does |
|------|---------|--------------|
| **Snapshot** | §6 | Six-pillar financial health overview — Growth, Profitability, Cash Flow, Financial Strength, Shareholder Returns, Valuation. Each pillar shows status + evidence + explanation, with clickable page citations |
| **Ask** | §10 | Conversational analysis with multi-step questions. Answers are computed from the underlying data and every figure carries a citation |
| **Signals** | §12 | Risk and anomaly detection. Pure functions over the financial series produce signals with exact figures, severity and suggested follow-up questions |
| **Peers** | §14 | Peer comparison table with percentile rankings and inline trend sparklines |
| **What Changed** | §18 | FY2024 → FY2025 metric diff with driver attribution linked to report notes and pages |
| **My Thesis** | §19, §22 | Structured thesis editor, metric watchlist, FY2025 values against the watchlist, version history. Persists to `localStorage` |
| **Reports** | §22 | Report upload with simulated extraction pipeline showing real processing stages, extraction confidence and flagged notes |

**Interactive elements to test**

- **Company switcher** (top left) — 4 companies with genuinely different financial profiles: `GTCO`, `ZNB`, `ACCESS`, `MTNN`. Each has its own data, signals, peer set and chat history
- **Evidence drawer** — click any citation badge (`p.38`, `mkt`) to open the full traceability chain: Insight → Evidence → Calculation → Interpretation → Source
- **Concept explainer** — click "Explain …" under any pillar, then switch between Quick / Standard / Deep depth. Deep explanations use the actual company figures
- **"Explore" on any signal** — hands off to chat with the question pre-loaded
- **Thesis watchlist** — add metrics and see which ones moved in FY2025. Changes persist across reloads
- **Simulated upload** — click "Simulate upload & extraction" to watch the 8-stage pipeline run
- **Analysis period** — toggle 3-year / 5-year window in the sidebar
- **Theme toggle** (top right) — dark and light themes, persisted to `localStorage`

**Design principles enforced in the UI**

- **Provenance is never hidden** — every figure is labelled `reported`, `calc` or `mkt`
- **Colour never carries meaning alone** — every status pairs colour with a text label
- **No arbitrary health score** — statuses are `Strong & Improving` / `Improving` / `Stable` / `Requires Investigation` / `Deteriorating` / `Insufficient Data`
- **No buy/hold/sell language anywhere** — signals describe what moved and suggest what to investigate
- **Missing data is explicit** — unavailable figures show `—` and are excluded from averages, never imputed

---

## Design System — `design.html`

Style guide v2: **Signal Blue + Terminal Slate + Tape Gold**.

- **Signal Blue** `#2962ff` — primary actions, focus, navigation (TradingView lineage)
- **Tape Gold** `#e8a90d` — the DataLens signature. Evidence highlights, sparkline strokes, data accents. Always paired with near-black ink, because white text on gold fails contrast
- **Terminal Slate** — blue-tinted charcoal surfaces, inverted neutral ramp so one token name works in both themes
- **Market direction** — teal `#26a69a` up, coral `#ef5350` down, amber `#ff9800` caution, cyan `#00bcd4` market data
- **Type** — Inter for UI, JetBrains Mono with `tabular-nums` for every figure
- Dark theme default, light theme available, WCAG AA contrast reference table included

---

## Tech Stack (Free-First)

The prototype uses no paid or external dependencies. The planned production stack is designed around free tiers.

| Layer | Choice | Cost |
|-------|--------|------|
| Frontend + hosting | Next.js 14 + TypeScript + Tailwind on Vercel Free Tier | $0 |
| Database + vector + auth + storage | Supabase Free (PostgreSQL + pgvector + Auth + Storage) | $0 |
| Background jobs | BullMQ + Redis | $0 |
| LLM | Groq API Free Tier (Llama 3.1 70B) in production, Ollama locally | $0 |
| Embeddings | `nomic-embed-text` via Ollama, indexed into pgvector | $0 |
| Market data | Alpha Vantage Free, manual NGX price entry, Frankfurter FX | $0 |
| Document processing | `pdf-parse`, `unpdf`, `pdfjs-dist`, `tesseract.js` (WASM OCR) | $0 |
| Observability | PostHog Cloud Free + Sentry Free + custom cost tracking | $0 |
| CI/CD | GitHub Actions | $0 |

**Target MVP recurring cost: $0–$5/month.**

---

## Build Phases

| Phase | Focus | Duration |
|-------|-------|----------|
| 0 | Repo setup, Supabase, auth, upload, CI | 1 wk |
| 1 | Document processing pipeline | 2–3 wk |
| 2 | Core data model + pgvector | 1 wk |
| 3 | Financial Health Snapshot | 2 wk |
| 4 | Evidence and traceability | 1 wk |
| 5 | Conversational analysis (RAG) | 3 wk |
| 6 | Risk signals and guided investigation | 1.5 wk |
| 7 | Peer comparison and industry metrics | 2 wk |
| 8 | Workspace and thesis | 2 wk |
| 9 | What Changed and thesis monitoring | 1.5 wk |
| 10 | UI/UX polish and adaptive presentation | 2 wk |
| 11 | Testing, evaluation and hardening | 2 wk |

**Estimated 20–22 weeks to MVP.** Full detail in `PRD.md`.

---

## Disclaimer

DataLens provides research information, **not investment advice**. Analysis is based on company-reported
figures and may contain errors. Nothing here is a recommendation to buy, hold, or sell any security.

All figures in `index.html` are **illustrative sample data** created for a Nigerian market context. They are
not real reported results for the companies named. Verify every figure against the source report before
making any investment decision.
