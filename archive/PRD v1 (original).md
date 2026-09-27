Absolutely. Based on all the decisions we've made, here's a **build-ready PRD** for DataLens. I've kept it product-focused rather than prescribing a particular programming stack, so you can give it to OpenCode and let the coding process determine the implementation.

# **DataLens — Product Requirements Document**

**Product:** DataLens  
 **Product type:** AI-powered investment research and financial-report analysis platform  
 **Primary market:** Self-directed retail investors  
 **Initial context:** Nigerian listed companies / NGX, with potential to expand internationally  
 **Document status:** MVP/Product Definition

---

## **1\. Product Vision**

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

### **Product promise**

**Turn complex company reports into clear, evidence-backed investment research.**

DataLens should **inform the investor, not make the investment decision for them.**

---

# **2\. Problem Statement**

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

# **3\. Target User**

### **Primary user**

A **self-directed retail investor** who:

* Understands basic investment concepts  
* Wants to research individual companies  
* Finds annual reports cumbersome  
* Wants evidence rather than generic investment opinions  
* May not have advanced financial-analysis skills  
* Wants to retain control over their investment decisions

### **User example**

An investor interested in Nigerian listed companies downloads several annual reports but doesn't want to manually extract dozens of figures into spreadsheets before understanding what is happening.

DataLens should reduce that analytical burden.

---

# **4\. Product Goals**

### **Primary goals**

1. Make financial reports easier to understand.  
2. Reduce the time required to perform company research.  
3. Surface meaningful financial trends and anomalies.  
4. Allow investors to investigate findings conversationally.  
5. Make every important insight traceable to evidence.  
6. Enable meaningful historical and peer comparisons.  
7. Help investors build and monitor their own investment theses.  
8. Keep the investor in control of the final investment decision.

### **Non-goals**

DataLens should **not**:

* Tell users what stocks to buy or sell.  
* Automatically make investment decisions.  
* Present speculative conclusions as facts.  
* Hide uncertainty or missing information.  
* Treat estimates as company-reported figures.  
* Give an arbitrary overall "investment score" in the initial product.

---

# **5\. Core User Journey**

The primary journey is:

**Upload report → Analyse → Financial Health Snapshot → Investigate → Compare → Detect changes/risks → Form thesis → Monitor**

A returning user can instead start from:

**My Companies → Select company → Updated analysis → What changed? → Investigate → Update thesis**

---

# **6\. Core Feature: Financial Health Snapshot**

Immediately after analysis, DataLens should present a high-level overview of the company's financial health.

The snapshot contains six core pillars.

### **6.1 Growth**

Analyse:

* Revenue  
* Revenue growth  
* Profit growth  
* EPS  
* EPS growth

DataLens should explain trends rather than merely display numbers.

Example:

🟢 **Growth — Strong & Improving**  
 Revenue increased consistently over the last five years, while EPS growth accelerated during the latest two reporting periods.

---

### **6.2 Profitability**

Analyse relevant metrics such as:

* Gross margin  
* Operating margin  
* Net margin  
* ROE  
* ROA

Example:

🟢 **Profitability — Improving**  
 Net margin increased from 21% to 24% over three years.

---

### **6.3 Cash Flow**

Analyse:

* Operating cash flow  
* Free cash flow  
* Cash conversion  
* Relevant working-capital movements

Example:

⚠️ **Cash Flow — Requires Investigation**  
 Net profit increased while operating cash flow declined.

---

### **6.4 Financial Strength**

Analyse:

* Debt  
* Liquidity  
* Capital position  
* Relevant solvency metrics

Industry-specific metrics should be added where appropriate.

---

### **6.5 Shareholder Returns**

Analyse:

* Dividend per share  
* Dividend growth  
* Payout ratio  
* Relevant shareholder-return metrics

---

### **6.6 Valuation**

Where reliable market data is available, analyse relevant measures such as:

* P/E  
* P/B  
* Dividend yield  
* Other appropriate valuation metrics

Market data must be clearly distinguished from company-reported information.

---

# **7\. Insight Format**

DataLens should communicate findings using:

**Status \+ Evidence \+ Explanation**

Example:

🟢 **Profitability — Strong & Improving**

ROE increased from 18% to 23% over three years, while net margin increased from 21% to 24%.

**Why it matters:** The company is generating more profit relative to shareholders' equity.

Avoid arbitrary numerical health scores in the initial product.

---

# **8\. Evidence & Traceability**

Every significant analytical insight should allow the user to verify it.

For each insight, DataLens should provide:

1. Underlying figures  
2. Source location  
3. Calculation where applicable  
4. Interpretation  
5. Relevant report/date

Example:

**ROE: 23%**

Net profit: ₦Xbn  
 Average shareholders' equity: ₦Ybn

**Calculation:** Net profit ÷ average shareholders' equity

**Source:** 2025 Annual Report, relevant page

The principle is:

**Insight → Evidence → Calculation → Interpretation → Source**

---

# **9\. Data Provenance**

DataLens must clearly distinguish three types of information.

### **Company-reported**

Information directly obtained from the company's report.

### **Market data**

Information obtained from an external market-data source.

Example:

Share price: ₦105  
 As of: 19 September 2026

### **Calculated**

Values derived by DataLens.

Example:

P/E \= Share price ÷ EPS  
 ₦105 ÷ ₦12.50 \= 8.4×

Users should never mistake calculated or estimated values for company-reported figures.

---

# **10\. Historical Analysis**

DataLens should use **all relevant historical information available**.

However, the default presentation should emphasize recent history, with approximately five years as the primary analytical window where sufficient data exists.

If seven years of data are available, DataLens should not arbitrarily discard the additional history.

Users should be able to ask:

"Show me the five-year trend."

or:

"Compare 2021–2023 with 2024–2025."

---

# **11\. Multiple Reports**

Users should be able to upload multiple reports from the same company.

DataLens should construct a connected company history.

Example:

* 2021 Annual Report  
* 2022 Annual Report  
* 2023 Annual Report  
* 2024 Annual Report  
* 2025 Annual Report

The system should identify relevant:

* Restatements  
* Changes in reporting  
* Missing periods  
* Changes in metric definitions

Users should also be able to control which periods are included in an analysis.

---

# **12\. Conversational Analysis**

Users should be able to ask natural-language questions.

The system must support **multi-step analytical questions**.

Example:

"Revenue grew strongly over the last five years, but has profitability actually improved?"

DataLens should determine which metrics are relevant, analyse them together, and explain the answer.

Other examples:

"Why did profitability decline?"

"What caused operating expenses to increase?"

"How has cash generation changed?"

"Is the company's debt increasing faster than its earnings?"

"What did management say about expansion?"

"What are the major risks mentioned in the report?"

The investor should not need to know which financial ratio is required before asking the question.

---

# **13\. Guided Investigation**

DataLens should proactively surface interesting findings.

Example:

⚠️ **Operating expenses increased faster than revenue.**

**Explore**

• Why did expenses increase?  
 • Which expense categories contributed most?  
 • How does this compare with previous years?  
 • Ask your own question →

This creates a guided \+ open-ended experience.

---

# **14\. Risk & Anomaly Detection**

DataLens should identify **potential financial signals that deserve investigation**.

Examples:

⚠️ Receivables increased 38% while revenue increased 12%.

⚠️ Operating cash flow declined while reported profit increased.

⚠️ Debt increased significantly over the reporting period.

The system should:

1. Identify the signal.  
2. Show the evidence.  
3. Explain why it may deserve attention.  
4. Suggest possible investigative questions.  
5. Allow conversational investigation.

DataLens should **not** simply label a company "risky."

---

# **15\. Industry-Specific Analysis**

The six core pillars should apply to all companies.

DataLens should additionally identify relevant industry-specific metrics.

### **Example: Banks**

Potential metrics:

* NPL ratio  
* Cost-to-income ratio  
* Capital adequacy  
* Loan growth  
* Net interest margin

### **Example: Manufacturing**

Potential metrics:

* Inventory turnover  
* Receivables days  
* Payables days  
* Asset utilisation  
* Operating margin

The specific metrics should depend on the company's industry and available information.

---

# **16\. Peer Comparison**

DataLens should support both:

### **Automatic peer suggestions**

DataLens identifies potentially comparable companies based on:

* Industry  
* Business model  
* Relevant characteristics

### **User-controlled comparison**

Users can:

* Accept suggested peers  
* Remove peers  
* Add companies manually

Example:

**Suggested peers**

Zenith Bank  
 GTCO  
 Access Holdings

The investor remains in control of the comparison set.

---

# **17\. Adaptive Data Presentation**

DataLens should not force every answer into the same format.

The presentation should depend on the question.

### **Trends**

Use charts.

### **Company comparisons**

Use tables or comparative visualizations.

### **Financial explanations**

Use narrative.

### **Complex changes**

Use a combination of:

* Visuals  
* Numbers  
* Narrative  
* Evidence

Principle:

**The question determines the format.**

---

# **18\. Financial Concept Explanations**

DataLens should explain financial terminology when needed.

Users should be able to choose explanation depth:

### **Quick**

One-sentence explanation.

### **Standard**

Simple explanation \+ example.

### **Deep**

Detailed explanation \+ calculation \+ relevance to the company.

Example:

**Free Cash Flow declined 18%.**

**Quick:**  
 Cash remaining after the company spends money on capital investments.

**Standard:**  
 Free cash flow shows how much cash the business generates after spending on things such as property and equipment.

**Deep:**  
 Explain the calculation, underlying figures, historical trend and relevance to the company.

---

# **19\. Company Workspace**

Users should be able to save companies they've researched.

Example:

### **My Companies**

**GTCO**  
 Last analysed: FY2025

**Zenith Bank**  
 Last analysed: FY2025

**Access Holdings**  
 Last analysed: FY2025

The workspace should preserve:

* Previous analyses  
* Uploaded reports  
* Peer comparisons  
* Research notes  
* Investment thesis  
* Metrics being monitored

---

# **20\. What Changed?**

When a new report becomes available, DataLens should compare it with previous information.

Example:

🔄 **What changed since your previous analysis?**

**Profitability**

Net margin: 24% → 19%

ROE: 23% → 18%

**Potential drivers identified in the report:**

• Higher operating expenses  
 • Increased finance costs  
 • Slower revenue growth

**Investigate**

"Why did finance costs increase?"

DataLens should explain documented drivers while distinguishing them from its own analytical interpretation.

---

# **21\. Investment Research Thesis**

Users should be able to create a structured personal thesis.

Example:

### **My Thesis**

**Growth**

* Revenue growth remains strong.

**Profitability**

* Margins continue improving.

**Financial strength**

* Debt remains manageable.

### **Things I'm watching**

* Operating cash flow  
* Finance costs  
* Dividend growth  
* Margins

DataLens should help organize the research without deciding whether the thesis is "correct."

---

# **22\. Thesis Monitoring**

When new company data becomes available, DataLens should compare it against the user's thesis.

Example:

**Your thesis has changed in one area**

Operating cash flow has declined for two consecutive years.

**Relevant to your thesis:** Yes

**Evidence:** \[supporting figures\]

**Investigate:** "What caused the decline?"

The system should highlight relevant changes without telling the investor to buy, hold or sell.

---

# **23\. Final Research Output**

DataLens should ultimately provide three interconnected outputs.

### **1\. Company Research Report**

A structured summary of:

* Financial health  
* Historical performance  
* Valuation  
* Peer comparison  
* Risks/signals  
* Management commentary  
* Key findings

### **2\. Investment Research Dashboard**

A persistent workspace containing:

* Metrics  
* Trends  
* Comparisons  
* Risks  
* Notes  
* Historical analyses

### **3\. Personal Investment Thesis**

A structured record of:

* Investor's thesis  
* Supporting evidence  
* Assumptions  
* Things being monitored  
* Changes over time

Together:

**Research → Understand → Form thesis → Monitor → Reassess**

---

# **24\. MVP Definition**

For the **first build**, I recommend resisting the temptation to build every future feature immediately.

### **MVP should include**

**Core input**

* Upload financial report  
* Support multiple reports

**Core analysis**

* Financial Health Snapshot  
* Six core pillars  
* Historical analysis  
* Basic industry-specific metrics  
* Evidence-backed insights  
* Calculated metrics

**AI interaction**

* Conversational questions  
* Multi-step analytical questions  
* Guided investigation  
* Financial concept explanations

**Trust**

* Source references  
* Data provenance  
* Clear distinction between reported/calculated/market data  
* Missing-data handling

**Comparison**

* Basic peer comparison  
* User-selected peers  
* Suggested peers

**Research**

* Save company  
* Research notes  
* Basic investment thesis

### **Post-MVP**

Consider adding:

* Automated new-report detection  
* Advanced thesis monitoring  
* More sophisticated market-data integration  
* Expanded sector-specific analysis  
* Notifications  
* Advanced portfolio features  
* Additional research workflows

---

# **25\. Key UX Principle**

The product should feel like:

**"An intelligent research analyst sitting beside me."**

Not:

**"A complicated financial dashboard I have to learn."**

The user should be able to start with a simple question and progressively go deeper.

For example:

**“How is GTCO doing?”**

↓

**Financial Health Snapshot**

↓

**“Why is cash flow weaker?”**

↓

**Evidence \+ analysis**

↓

**“How does this compare with Zenith?”**

↓

**Peer comparison**

↓

**“Does this affect my thesis?”**

↓

**Thesis monitoring**

That is the core DataLens experience.

---

# **26\. Success Metrics**

The initial product should measure whether it actually reduces research friction.

### **Activation**

* Percentage of users who successfully upload a report  
* Percentage who complete their first analysis

### **Engagement**

* Questions asked per analysis  
* Percentage of users who investigate surfaced insights  
* Number of companies analysed per user

### **Research depth**

* Reports analysed per company  
* Peer comparisons performed  
* Follow-up questions per insight  
* Investment theses created

### **Retention**

* Users returning to previously analysed companies  
* Users returning after new reports  
* Frequency of company monitoring

### **Trust**

Potential qualitative/quantitative measures:

* Users accessing source evidence  
* Users rating explanations as useful  
* User-reported confidence in understanding the report

---

# **27\. Product Success Definition**

DataLens succeeds when an investor can take a complex annual report and move from:

**“I have this report, but I don't know where to start.”**

to:

**“I understand what happened, why it happened, how the company compares with its peers, what deserves further investigation, and which parts of my own thesis the evidence supports or challenges.”**

without DataLens making the investment decision for them.

---

## **One-sentence product definition**

**DataLens is an AI-powered investment research platform that transforms complex company reports and market data into clear, evidence-backed analysis, conversational investigation, peer comparison and ongoing thesis monitoring for self-directed investors.**

This is the PRD I would give **OpenCode as the product specification**. The next practical step is to turn this into an **MVP build sequence**—i.e., the exact order in which OpenCode should build DataLens feature by feature, starting with the smallest usable version rather than attempting the whole PRD at once.

