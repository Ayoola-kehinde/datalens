# **DataLens — Product Requirements Document (v2: MVP Implementation-Aligned)**

**Product:** DataLens  
**Product type:** AI-powered investment research and financial-report analysis platform  
**Primary market:** Self-directed retail investors  
**Initial context:** Nigerian listed companies / NGX, with potential to expand internationally  
**Document status:** MVP Definition — aligned with phased implementation plan (free-first stack)  
**Version:** 2.0 — reflects technical stack, phased build sequence, and cost constraints  

---

## **1. Product Vision**

DataLens helps self-directed investors understand companies without requiring advanced financial-data analysis skills.

Users upload company financial reports and DataLens transforms complex financial information into:

* Visual financial-health insights  
* Plain-language explanations  
* Historical trends  
* Peer comparisons  
* Risk signals  
* Conversational analysis  
* Evidence-backed research  
* Personal investment theses  
* Ongoing company monitoring  

### **Product Promise**

**Turn complex company reports into clear, evidence-backed investment research.**

DataLens should **inform the investor, not make the investment decision for them.**

---

## **2. Problem Statement** (unchanged)

Annual reports contain valuable information, but they are often:
* Long and difficult to navigate  
* Filled with financial terminology  
* Time-consuming to analyse  
* Difficult to compare across years  
* Difficult to compare across companies  
* Poorly suited to investors who want answers to specific questions  

A self-directed investor may understand basic investing concepts but still struggle to efficiently answer questions such as:
* Is the company's growth actually improving?  
* Is profitability improving alongside revenue?  
* Is the company generating enough cash?  
* Has its financial strength improved or deteriorated?  
* How does it compare with competitors?  
* What changed from last year?  
* What risks deserve further investigation?  
* Does the evidence still support my investment thesis?

DataLens addresses this gap.

---

## **3. Target User** (unchanged)

### **Primary User**
A **self-directed retail investor** who:
* Understands basic investment concepts  
* Wants to research individual companies  
* Finds annual reports cumbersome  
* Wants evidence rather than generic investment opinions  
* May not have advanced financial-analysis skills  
* Wants to retain control over their investment decisions  

### **User Example**
An investor interested in Nigerian listed companies downloads several annual reports but doesn't want to manually extract dozens of figures into spreadsheets before understanding what is happening.

DataLens should reduce that analytical burden.

---

## **4. Product Goals**

### **Primary Goals (MVP Scope)**
1. Make financial reports easier to understand.  
2. Reduce the time required to perform company research.  
3. Surface meaningful financial trends and anomalies.  
4. Allow investors to investigate findings conversationally.  
5. Make every important insight traceable to evidence.  
6. Enable meaningful historical and peer comparisons.  
7. Help investors build and monitor their own investment theses.  
8. Keep the investor in control of the final investment decision.  

### **Non-Goals (MVP)**
DataLens should **not**:
* Tell users what stocks to buy or sell.  
* Automatically make investment decisions.  
* Present speculative conclusions as facts.  
* Hide uncertainty or missing information.  
* Treat estimates as company-reported figures.  
* Give an arbitrary overall "investment score" in the initial product.  
* Provide real-time trading data or execution.  
* Support portfolio-level optimization (single-company focus).  

### **Post-MVP Goals**
* Automated new-report detection and ingestion  
* Advanced thesis monitoring with notifications  
* More sophisticated market-data integration (real-time, broader coverage)  
* Expanded sector-specific analysis templates  
* Collaborative workspaces / shared research  
* Mobile-native application  

---

## **5. Core User Journey** (unchanged)

**Upload report → Analyse → Financial Health Snapshot → Investigate → Compare → Detect changes/risks → Form thesis → Monitor**

A returning user can instead start from:
**My Companies → Select company → Updated analysis → What changed? → Investigate → Update thesis**

---

## **6. Core Feature: Financial Health Snapshot** (unchanged scope, implementation-defined)

Immediately after analysis, DataLens presents a high-level overview of the company's financial health across six core pillars:

### **6.1 Growth**
* Revenue, Revenue growth, Profit growth, EPS, EPS growth

### **6.2 Profitability**
* Gross margin, Operating margin, Net margin, ROE, ROA

### **6.3 Cash Flow**
* Operating cash flow, Free cash flow, Cash conversion, Working-capital movements

### **6.4 Financial Strength**
* Debt, Liquidity, Capital position, Solvency metrics (industry-specific where appropriate)

### **6.5 Shareholder Returns**
* Dividend per share, Dividend growth, Payout ratio

### **6.6 Valuation**
* P/E, P/B, Dividend yield (where reliable market data available — **market data clearly distinguished from company-reported**)

### **Insight Format (enforced)**
**Status + Evidence + Explanation**  
Example:  
🟢 **Profitability — Improving**  
Net margin increased from 21% to 24% over three years.  
**Why it matters:** The company is generating more profit per naira of revenue.

**Status classifications:** `STRONG_IMPROVING` | `STRONG_STABLE` | `IMPROVING` | `STABLE` | `DECLINING` | `WEAK` | `INSUFFICIENT_DATA`  
(Thresholds configurable per sector via JSON; Nigerian banking/manufacturing/consumer defaults provided.)

---

## **7. Evidence & Traceability** (strictly enforced)

Every significant analytical insight must allow the user to verify it.

For each insight, DataLens provides:
1. Underlying figures (exact values)  
2. Source location (report + page number)  
3. Calculation where applicable (formula + inputs)  
4. Interpretation (plain language)  
5. Relevant report/date  

**Provenance Chain:**  
`Insight → Evidence → Calculation → Interpretation → Source`

### **Data Provenance Labels (mandatory on every metric)**
| Label | Meaning |
|-------|---------|
| **Company-reported** | Directly from the company's filed report |
| **Market data** | External source (share price, index levels) — timestamped |
| **Calculated** | Derived by DataLens (formula shown) |

Users must never mistake calculated or estimated values for company-reported figures.

---

## **8. Historical Analysis**
* Default analytical window: **5 years** (where sufficient data exists)  
* All available history retained — not arbitrarily discarded  
* User can request custom periods: "Compare 2021–2023 vs 2024–2025"  
* Restatements detected and flagged automatically  

---

## **9. Multiple Reports per Company**
* Users upload multiple annual reports for the same company  
* DataLens constructs a connected company history  
* System identifies: restatements, reporting changes, missing periods, metric definition changes  
* User controls which periods are included in analysis  

---

## **10. Conversational Analysis (RAG-Powered)**

Users ask natural-language questions. The system supports **multi-step analytical questions**.

**Examples:**
* "Revenue grew strongly over the last five years, but has profitability actually improved?"  
* "Why did profitability decline?"  
* "What caused operating expenses to increase?"  
* "How has cash generation changed?"  
* "Is the company's debt increasing faster than its earnings?"  
* "What did management say about expansion?"  
* "What are the major risks mentioned in the report?"

**Implementation Constraints (MVP):**
* **LLM:** Groq API Free Tier (Llama 3.1 70B) for production; Ollama local for dev  
* **Embeddings:** `nomic-embed-text` via Ollama (local, free, unlimited) → pgvector  
* **Retrieval:** Hybrid — vector similarity + PostgreSQL `tsvector` full-text + metadata filters (company, year, statement type)  
* **Tools (function calling):** `getMetric`, `comparePeriods`, `searchReports`, `getPeerMetric`  
* **Citations mandatory:** Every claim in response must have inline citation linking to Evidence Drawer  
* **Hallucination guard:** "I don't have that data" instead of inventing figures  

**The investor should not need to know which financial ratio is required before asking the question.**

---

## **11. Guided Investigation**

DataLens proactively surfaces interesting findings with suggested follow-ups.

**Example:**
⚠️ **Operating expenses increased faster than revenue.**  
**Explore**  
• Why did expenses increase?  
• Which expense categories contributed most?  
• How does this compare with previous years?  
• Ask your own question →  

Clicking a suggestion opens chat with context pre-loaded.

---

## **12. Risk & Anomaly Detection**

DataLens identifies **potential financial signals that deserve investigation** — not binary "risky" labels.

**Built-in Signal Detectors (MVP):**
| Signal | Trigger |
|--------|---------|
| Receivables vs Revenue | AR growth > 1.5× revenue growth |
| Cash Flow vs Profit | OCF declining while net profit rising |
| Debt vs Earnings | Debt/EBITDA deteriorating > threshold |
| Margin Compression | Sustained margin decline > 2 years |
| Restatement Detected | Prior-year adjustments found |
| Missing Periods | Expected fiscal years not uploaded |
| Industry-Specific | Extensible registry (banks: NPL ratio spike; manufacturing: inventory buildup) |

**Each signal includes:**
1. The signal (with exact figures)  
2. Evidence (source page refs)  
3. Why it may deserve attention  
4. Suggested investigative questions  
5. One-click "Explore" → conversational analysis  

**Thresholds configurable per sector via JSON.**

---

## **13. Industry-Specific Analysis**

Six core pillars apply to all companies. Additionally, DataLens identifies relevant industry-specific metrics.

### **Banks (MVP Priority)**
* NPL ratio, Cost-to-income ratio, Capital adequacy (CAR), Loan growth, Net interest margin

### **Manufacturing / Consumer Goods**
* Inventory turnover, Receivables days, Payables days, Asset utilisation, Operating margin

### **Implementation**
* Sector detected from company metadata (seeded NGX taxonomy)  
* Metric registry: JSON-configurable, extensible  
* Only metrics with available data are shown  

---

## **14. Peer Comparison**

### **Automatic Peer Suggestions**
Based on: same sector/industry, similar market cap band, same exchange (NGX), liquidity filter.

### **User-Controlled Comparison**
* Accept/remove suggested peers  
* Add companies manually (by ticker)  

### **Comparison View**
* Metrics as rows, companies as columns  
* Sparklines for trends  
* Percentile rankings: "GTCO ROE: 23% → 75th percentile vs NGX Banks"  

### **Market Data Sources (MVP — Free Tier)**
* **Global fundamentals:** Alpha Vantage Free (25 req/day)  
* **Share prices:** Alpha Vantage + Yahoo Finance (unofficial, cached)  
* **NGX prices:** **Primary = user manual entry**; Secondary = lightweight cached scraper (respectful, rate-limited)  
* **FX rates:** Frankfurter API (free, no key)  

**Missing peer data handled gracefully:** "Data unavailable for Peer X — excluded from average."

---

## **15. Adaptive Data Presentation**

The presentation depends on the question — not forced into one format.

| Question Type | Presentation |
|---------------|--------------|
| Trends | Line/bar charts (Recharts) |
| Company comparisons | Tables with sparklines |
| Financial explanations | Narrative + inline citations |
| Complex changes | Combination: visuals + numbers + narrative + evidence |

**Intent classification:** Keyword-rule based (no LLM) for MVP; LLM fallback for ambiguous queries.

---

## **16. Financial Concept Explanations**

Three depths, user-selectable:

| Depth | Content |
|-------|---------|
| **Quick** | One-sentence definition |
| **Standard** | Simple explanation + generic example |
| **Deep** | Detailed explanation + calculation walkthrough + relevance to current company (uses actual figures) |

**MVP:** 50+ core concepts pre-authored in JSON; unknown terms → LLM-generated on demand (cached).

---

## **17. Company Workspace**

Users save companies they've researched.

### **My Companies View**
* Grid of saved companies: ticker, name, last analysed, thesis status  

### **Company Workspace Tabs**
1. **Snapshot** — Financial Health Snapshot  
2. **Chat** — Conversation history + new questions  
3. **Signals** — Risk/anomaly cards + investigation status  
4. **Peers** — Comparison table + percentile ranks  
5. **Thesis** — Structured thesis editor  
6. **Notes** — Research notes (attachable to report pages)  
7. **Reports** — Uploaded reports + processing status  

### **Persistence**
* Previous analyses  
* Uploaded reports  
* Peer sets  
* Research notes  
* Investment thesis (versioned)  
* Monitored metrics (watchlist)  

---

## **18. What Changed? (Report Diff)**

When a new report is uploaded for an existing company:

* **Metric diffs:** Side-by-side comparison (old vs new) with % change  
* **Driver attribution:** Text search in new report notes for changed line-item labels (e.g., "Finance costs ↑₦45B — new $50M USD bond, Note 18, p.67")  
* **Restatement highlighting:** Prior-year adjustments called out  
* **New/removed disclosures:** Section-level diff  

**UI:** Banner on company page → "What Changed?" diff view.

---

## **19. Investment Research Thesis**

Users create a structured personal thesis.

### **Thesis Structure**
```markdown
### My Thesis — [Company]

**Growth**
* Revenue growth remains strong.

**Profitability**
* Margins continue improving.

**Financial Strength**
* Debt remains manageable.

### Things I'm Watching
* Operating cash flow
* Finance costs
* Dividend growth
* Margins
```

### **Features**
* Guided sections (pillars) + free-form notes per pillar  
* Watchlist: metrics the user wants to monitor  
* **Version history:** Immutable append-only log of thesis changes  
* DataLens organizes — does not judge correctness  

---

## **20. Thesis Monitoring**

When a new report is processed for a company in the user's workspace:

* System checks each watchlist metric against new data  
* **Alert generated if:** metric crosses user-defined threshold OR changes directionally (e.g., "Operating cash flow declined 18% YoY — 2 consecutive years")  
* Alert links to: evidence, diff view, suggested "Investigate" question  
* **No buy/hold/sell recommendation** — only "your thesis item X has changed"  

**Implementation:** GitHub Actions scheduled cron (free) runs nightly on watched companies.

---

## **21. Final Research Outputs**

Three interconnected outputs:

### **1. Company Research Report**
Structured summary: Financial health, Historical performance, Valuation, Peer comparison, Risks/signals, Management commentary, Key findings.

### **2. Investment Research Dashboard**
Persistent workspace: Metrics, Trends, Comparisons, Risks, Notes, Historical analyses.

### **3. Personal Investment Thesis**
Structured record: Investor's thesis, Supporting evidence, Assumptions, Things being monitored, Changes over time.

**Together:** Research → Understand → Form thesis → Monitor → Reassess

### **Export**
* **Research Pack PDF:** Snapshot + Thesis + Top signals + Peer table + Citations  
* Generated via `@react-pdf/renderer` (client-side, no headless browser)

---

## **22. MVP Definition (Locked to Implementation Plan)**

### **MVP Includes**

#### **Core Input**
* Upload financial report (PDF, XBRL, Excel)  
* Support multiple reports per company  
* Manual share price entry for valuation  

#### **Core Analysis**
* Financial Health Snapshot (6 pillars)  
* Historical analysis (5-year default, all history retained)  
* Basic industry-specific metrics (banks + manufacturing/consumer)  
* Evidence-backed insights with full traceability  
* Calculated metrics with provenance labels  
* Restatement detection  

#### **AI Interaction**
* Conversational questions (RAG + tool use)  
* Multi-step analytical questions  
* Guided investigation from signals  
* Financial concept explanations (3 depths)  

#### **Trust & Transparency**
* Source references (page-level)  
* Data provenance (reported/calculated/market)  
* Clear missing-data handling  
* No hallucinated figures  

#### **Comparison**
* Basic peer comparison (user-controlled set)  
* Auto-suggested peers (sector + market cap)  
* Percentile rankings  

#### **Research Workspace**
* Save company  
* Research notes (page-attached)  
* Structured investment thesis (versioned)  
* Watchlist / monitored metrics  
* What Changed? diff view  
* Thesis monitoring alerts  
* PDF Research Pack export  

### **Post-MVP (Explicitly Deferred)**
* Automated new-report detection  
* Advanced thesis monitoring (notifications, email)  
* Real-time market data / broader coverage  
* Expanded sector templates (insurance, oil & gas, telco)  
* Collaborative/sharing features  
* Portfolio-level views  
* Mobile app  

---

## **23. Key UX Principle** (unchanged)

The product should feel like:
> **"An intelligent research analyst sitting beside me."**

Not:
> **"A complicated financial dashboard I have to learn."**

The user should be able to start with a simple question and progressively go deeper.

**Example Flow:**
> **“How is GTCO doing?”**  
> ↓  
> **Financial Health Snapshot**  
> ↓  
> **“Why is cash flow weaker?”**  
> ↓  
> **Evidence + analysis**  
> ↓  
> **“How does this compare with Zenith?”**  
> ↓  
> **Peer comparison**  
> ↓  
> **“Does this affect my thesis?”**  
> ↓  
> **Thesis monitoring**

That is the core DataLens experience.

---

## **24. Success Metrics** (unchanged)

### **Activation**
* % users who successfully upload a report  
* % who complete their first analysis  

### **Engagement**
* Questions asked per analysis  
* % users who investigate surfaced insights  
* Companies analysed per user  

### **Research Depth**
* Reports analysed per company  
* Peer comparisons performed  
* Follow-up questions per insight  
* Investment theses created  

### **Retention**
* Users returning to previously analysed companies  
* Users returning after new reports  
* Frequency of company monitoring  

### **Trust**
* Users accessing source evidence  
* Users rating explanations as useful  
* User-reported confidence in understanding the report  

---

## **25. Product Success Definition** (unchanged)

DataLens succeeds when an investor can take a complex annual report and move from:

> **“I have this report, but I don't know where to start.”**

to:

> **“I understand what happened, why it happened, how the company compares with its peers, what deserves further investigation, and which parts of my own thesis the evidence supports or challenges.”**

without DataLens making the investment decision for them.

---

## **26. One-Sentence Product Definition** (unchanged)

**DataLens is an AI-powered investment research platform that transforms complex company reports and market data into clear, evidence-backed analysis, conversational investigation, peer comparison and ongoing thesis monitoring for self-directed investors.**

---

## **27. Technical Architecture (Implementation-Aligned)**

### **Stack Summary (Free-First)**

| Layer | Technology | Cost |
|-------|------------|------|
| Frontend + Hosting | Next.js 14 (App Router) + React 18 + TypeScript + Tailwind on **Vercel Free Tier** | $0 |
| Database + Vector + Auth + Storage | **Supabase Free Tier** (PostgreSQL 500MB + pgvector + Auth + 1GB Storage + Realtime) | $0 |
| Background Jobs | **BullMQ + Redis** (Docker local; Railway/Render free tier for staging) | $0 |
| LLM (Chat/Reasoning) | **Groq API Free Tier** (Llama 3.1 70B) prod; **Ollama local** dev | $0 |
| Embeddings | **`nomic-embed-text` via Ollama** (local, free, unlimited) | $0 |
| Market Data (Global) | **Alpha Vantage Free** (25 req/day) + Yahoo Finance (cached) | $0 |
| Market Data (NGX) | **Manual CSV upload** (primary) + optional respectful scraper (secondary) | $0 |
| PDF Processing | `pdf-parse` + `unpdf` + `pdfjs-dist` + `tesseract.js` (WASM OCR) | $0 |
| Observability | **PostHog Cloud Free** (1M events) + **Sentry Free** (5k errors) + custom DB cost tracking | $0 |
| CI/CD | **GitHub Actions** (2,000 min/mo free private) | $0 |
| Charts | **Recharts** (open source) | $0 |
| PDF Export | **@react-pdf/renderer** (React-based) | $0 |

**Total MVP Recurring Cost: $0–$5/month**

### **Architecture Pattern**
Modular monolith — single Next.js app with clear internal module boundaries:
* `document-processing` — extraction, normalization, OCR
* `analysis-engine` — snapshot, signals, diff, peer comparison
* `chat` — RAG, agent, tool calling, streaming
* `workspace` — user companies, thesis, notes, alerts
* `market-data` — Alpha Vantage, Yahoo, NGX scraper, FX
* `evidence` — traceability, citations, calculation expansion

Each module owns its Prisma models and exposes typed procedures via **Next.js Server Actions** (or tRPC if preferred). Ready for future service extraction.

### **Data Flow Overview**
```
Upload (Supabase Storage)
    → BullMQ Job: processReport
        → Extract text/tables (pdf-parse, unpdf, pdfjs-dist)
        → OCR fallback (tesseract.js)
        → Normalize → canonical JSON
        → Upsert to Postgres (LineItem, FinancialStatement, CalculatedMetric)
        → Chunk tables/narrative → embed (nomic-embed-text via Ollama) → pgvector
    → User triggers: generateSnapshot(companyId, reportIds[])
        → Pure TS computes 6 pillars → status + evidence + explanation
    → User asks question → Chat Agent
        → Retrieve (hybrid: vector + tsvector + metadata)
        → Tool calls (getMetric, comparePeriods, searchReports, getPeerMetric)
        → Synthesize + cite → stream response
    → Signals engine runs on new report → surfaces anomalies
    → Peer comparison: Alpha Vantage + Yahoo + manual NGX prices
    → Workspace: thesis, notes, watchlist, version history
    → New report → Diff engine → driver attribution → thesis alerts
```

---

## **28. Free-Tier Limits & Mitigations (Operational Reality)**

| Service | Free Limit | MVP Impact | Mitigation |
|---------|------------|------------|------------|
| **Groq API** | 30k tokens/min, 14k req/day | ~500 chat sessions/day | Cache similar queries; fallback to local Ollama |
| **Alpha Vantage** | 25 req/day | 25 companies/day price refresh | User manual entry primary; cache 24h |
| **Supabase** | 500 MB DB, 1 GB storage, 2 GB bandwidth | ~100 companies × 5 years reports | Compress PDFs; archive old reports locally |
| **Vercel** | 100 GB bandwidth, 100 GB-hrs serverless | Sufficient for MVP | Optimize bundle; use Edge Runtime where possible |
| **GitHub Actions** | 2,000 min/mo (private) | CI + nightly cron | Self-hosted runner on local machine for heavy tests |

---

## **29. Phased Implementation Plan (Summary)**

| Phase | Duration | Focus | Key Deliverable |
|-------|----------|-------|-----------------|
| **0** | 1 wk | Setup & Infra | Repo, Supabase, Auth, Upload, CI |
| **1** | 2-3 wk | Document Processing | PDF→structured data pipeline (5 test reports) |
| **2** | 1 wk | Data Model | Prisma schema, pgvector, seed taxonomy |
| **3** | 2 wk | Financial Health Snapshot | 6 pillars + status + evidence refs |
| **4** | 1 wk | Evidence & Traceability | EvidenceDrawer, CitationBadge, CalculationExpander |
| **5** | 3 wk | Conversational Analysis | RAG + Groq/Ollama + tools + citations |
| **6** | 1.5 wk | Risk Signals | 7 detectors + guided investigation UI |
| **7** | 2 wk | Peer Comparison | Auto-suggest + comparison table + percentiles |
| **8** | 2 wk | Workspace & Thesis | My Companies, thesis editor, versioning, PDF export |
| **9** | 1.5 wk | What Changed? & Monitoring | Diff engine, driver attribution, thesis alerts |
| **10** | 2 wk | UI/UX Polish | Adaptive renderer, concept explainer, a11y, mobile |
| **11** | 2 wk | Testing & Hardening | Eval harness, load test, security, observability |

**Total: ~20-22 weeks to MVP**

---

## **30. Assumptions & Constraints**

1. **NGX Data Access:** No free programmatic API for NGX fundamentals. MVP relies on user-uploaded PDFs + manual share price entry.  
2. **LLM Reliability:** Groq free tier + local Ollama sufficient for MVP reasoning; GPT-4o-mini fallback only if quality gates fail.  
3. **OCR Quality:** `tesseract.js` works for clean scans; complex tables may need manual review — flagged in UI.  
4. **Single-User MVP:** No multi-tenancy complexity; auth is per-user isolation.  
5. **English Only:** UI and explanations in English; report text assumed English (NGX reports are).  
6. **No Regulatory Advice:** Explicit disclaimers; no "recommendation" language anywhere.  

---

## **31. Risks & Mitigations**

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| PDF extraction accuracy <90% on real NGX reports | Medium | High | Golden-set eval (10 reports); manual review queue; iterative prompt/chunking tuning |
| Groq rate limits / downtime | Low | Medium | Ollama local fallback; response caching; graceful degradation |
| Alpha Vantage 25/day insufficient | Medium | Low | Manual entry primary; user can upload CSV bulk prices |
| Supabase free tier exceeded | Low | Medium | Monitor usage; compress PDFs; archive old data; upgrade path clear ($25/mo Pro) |
| Hallucinated financial figures | Medium | High | Tool-use enforcement; citation mandatory; eval gate (hallucination rate <5%) |
| NGX scraper blocked / legal issues | Low | Medium | Manual entry primary; scraper optional, respectful, cached, user-opt-in |

---

## **32. Definition of Done (MVP Launch Gate)**

1. **Functional:** All MVP features (Section 22) working end-to-end on 3+ real NGX companies.  
2. **Accuracy:** Extraction F1 >0.92 on golden set; Chat citation precision >0.85; Signal precision >0.8.  
3. **Performance:** P95 snapshot <5s; Chat first token <2s; Peer table <2s.  
4. **Cost:** <$0.50 per full analysis session (Groq free tier covers typical usage).  
5. **Security:** 0 critical/high vulnerabilities (OWASP ZAP + `npm audit`).  
6. **Observability:** PostHog funnels + Sentry errors + custom cost dashboard operational.  
7. **Documentation:** README with local setup (Docker Compose: Postgres + Redis + Ollama), env vars, deploy steps.  
8. **Legal:** Disclaimer reviewed; data deletion flow tested; no financial advice language.  

---

## **33. Next Steps (Post-PRD Approval)**

1. **Approve this PRD v2** — confirms scope, stack, and phased plan.  
2. **Begin Phase 0** — scaffold repo with all configs, Supabase schema, auth, file upload, CI.  
3. **Gather test corpus** — 10 real NGX annual reports (PDF) for extraction tuning.  
4. **Set up Supabase project** — enable pgvector, create storage bucket, configure auth providers.  
5. **Configure local dev stack** — `docker-compose.yml` with Postgres, Redis, Ollama (models: `nomic-embed-text`, `llama3.1`, `nemotron3-ultra`).  

---

*This PRD v2 supersedes the previous version. It reflects the finalized free-first implementation plan and serves as the single source of truth for the MVP build.*