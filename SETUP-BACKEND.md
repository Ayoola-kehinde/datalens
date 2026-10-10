# Connecting DataLens to Supabase, Groq and Slack

The integration code is written and committed. It is **inert until you supply four
credentials**, because none of them exist yet and two of them must never live in the browser.

Estimated setup: **20 minutes.**

---

## Where the two live keys now

`config.js` is **committed to the repository** and served by GitHub Pages, so the deployed
build and the APK both pick it up with no extra step.

That is safe because only these two values are in it:

| Value | In `config.js`? | Why it's acceptable |
|---|---|---|
| `SUPABASE_URL` | ✅ yes | A project URL is not a secret |
| `SUPABASE_ANON_KEY` | ✅ yes | **Public by design.** Supabase's dashboard labels it *anon public*. Data is protected by Row Level Security, not by keeping the key secret |
| `GROQ_API_KEY` | ❌ never | Would be readable by anyone viewing page source |
| `SLACK_WEBHOOK_URL` | ❌ never | Anyone holding it can post to your channel |

The anon key is shipped in the HTML precisely because Supabase expects it there. What stops
one investor reading another's thesis is the policy
`auth.uid() = user_id` in `supabase/migrations/0001_init.sql` — not the secrecy of the key.

`.gitignore` denies `*GROQ*`, `*gsk_*`, `*SLACK*`, `hooks.slack.com` and `*.webhook`, so a
stray paste into any committed file fails to commit rather than leaking to a public repo.

---

## Step 0 — Fill in the two public values

`config.js` currently holds placeholders. The app detects them and stays on sample data
(this is deliberate — it fails visibly rather than silently). Open it and paste:

```js
SUPABASE_URL: "https://YOUR-PROJECT-REF.supabase.co",
SUPABASE_ANON_KEY: "eyJhbGciOi..."
```

From **Project Settings → Data API**. Then commit and push. That single push activates the
live build and the APK together.

---

## Step 1 — Create the Supabase project

1. <https://supabase.com/dashboard> → **New project**
2. Pick a name (`datalens`) and a region near your users — **Frankfurt or Singapore** for Nigeria
3. Save the database password somewhere safe. You need it once, for the CLI
4. Wait ~2 minutes for provisioning

## Step 2 — Load the schema

**Easiest — SQL editor.** Open **SQL Editor → New query**, paste the whole of
`supabase/migrations/0001_init.sql`, and click **Run**.

That creates six tables, enables RLS with column-level grants, and seeds the four demo
companies with their five-year extractions.

**Or with the CLI:**

```powershell
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### Verify the security posture

RLS is the only thing protecting personal data, so check it rather than assume it.

```sql
-- 1. Every table must report enabled = true
select relname, relrowsecurity from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
order by relname;

-- 2. Public tables: read only, no write policies for anon
select tablename, policyname, cmd, roles::text from pg_policies
where schemaname = 'public' order by tablename, cmd;

-- 3. Confirm anon has no write rights on extractions
select has_table_privilege('anon','public.extractions','INSERT') as anon_can_insert,
       has_table_privilege('anon','public.extractions','UPDATE') as anon_can_update,
       has_table_privilege('anon','public.theses','SELECT')     as anon_can_read_theses;
-- expect all three = false

-- 4. Confirm column-level UPDATE is narrowed to the decision columns
select column_name, is_updatable from information_schema.columns
where table_name = 'extractions' and table_schema = 'public'
order by ordinal_position;
-- is_updatable should be YES for status/decided_at/decided_by/decision_note
-- and NO for payload/confidence/groq_*

-- 5. Public data visible
select ticker from companies order by ticker;

-- 6. Private data must return nothing when not signed in
select count(*) from theses;   -- expect 0
```

If `theses` returns rows to an anonymous session, **stop** — that is a privacy breach.

## Step 3 — Deploy the triage Edge Function

```powershell
supabase functions deploy triage --no-verify-jwt
```

## Step 4 — Set the server-side secrets

```powershell
supabase secrets set GROQ_API_KEY=gsk_...   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

Both land in Supabase's encrypted secret store. Confirm:

```powershell
supabase secrets list
```

You should see both names listed with a masked value. **Never paste these into `config.js`,
a `.env` file, or any commit.**

## Step 5 — Confirm config.js is committed

`config.js` is deliberately tracked, unlike a normal `.env`:

```powershell
git ls-files config.js
# should print: config.js
```

If it prints nothing, a stray deny rule is matching it:

```powershell
git check-ignore -v config.js
```

You want that to report *no matching pattern*.

## Step 6 — Enable email sign-in

**Authentication → Providers → Email.** For local testing, turn **"Confirm email"** off so you
can sign in without an inbox. Turn it back on before real users arrive.

---

## Step 7 — Wire up Slack

1. In Slack: <https://api.slack.com/messaging/webhooks> → **Add New Webhook to Workspace**
2. Pick a channel (e.g. `#analysis-review`)
3. Copy the `https://hooks.slack.com/services/...` URL
4. `supabase secrets set SLACK_WEBHOOK_URL=<that url>`
5. Redeploy so the function picks up the new secret:

```powershell
supabase functions deploy triage --no-verify-jwt
```

Confirm with a test webhook — you should see a message in the channel:

```powershell
curl -X POST -H "Content-Type: application/json" `
  -d '{"text":"DataLens triage test — ignore"}' `
  "YOUR_WEBHOOK_URL"
```

---

## Step 8 — Test the triage endpoint

```powershell
curl -X POST `
  "https://YOUR-PROJECT-REF.supabase.co/functions/v1/triage" `
  -H "Content-Type: application/json" `
  -H "apikey: YOUR_ANON_KEY" `
  -d '{
    "company":"GTCO","fiscalYear":2025,"pages":236,"confidence":92,
    "statements":{"income_statement":98,"balance_sheet":95,"cash_flow":71},
    "flagged":[{"page":44,"section":"operating expenses"}],
    "unresolved":["operating expenses FY2025"],
    "restatements":["FY2024 revenue restated 1.47T -> 1.44T"]
  }'
```

Expect:

```json
{
  "verdict": "needs_review",
  "concerns": ["Overall extraction confidence 92% is below the 90% gate", "..."],
  "rationale": "Sent to manual review because ...",
  "model": "llama-3.1-70b-versatile",
  "slackNotified": true
}
```

If `model` reads `deterministic-gate` or `error-path`, the Groq key did not load — check
`supabase secrets list`.

---

## What happens at runtime

### Data

On boot the app calls `DataStore.hydrate()`, which selects `companies` joined to the newest
`extractions` per company. On success `COMPANIES` is swapped from the bundled sample to live
rows, the sidebar badge flips to **Supabase live**, and every view re-renders. On any failure
the app stays on sample data and the badge keeps saying **Sample data**. It never half-loads.

### Thesis writes

Save is local-first: `localStorage` always writes, so nothing is lost offline. Then, when
signed in, it upserts into `theses` and appends a row to `thesis_versions`. The badge on the
button changes from *"saved in this browser"* to *"synced to your Supabase account"*.

A user who is not signed in keeps the local copy and is told so plainly.

### Triage

The Reports view's **Automated review** panel posts an extraction summary to the edge function.
The function runs deterministic quality gates first, then calls Groq. On `needs_review` or
`reject` it posts to Slack. The UI shows the verdict, the rationale, the concerns, the model
name, and whether Slack was notified.

---

## Design guarantees worth knowing

These are deliberate and tested by reading the code:

1. **The model cannot override the gate.** If any deterministic check failed, an `approved`
   verdict from Groq is downgraded to `needs_review` and flagged `gateOverrode`.

2. **Every failure mode resolves to `needs_review`** — no key, rate limit, timeout, malformed
   JSON, or an unhandled exception. The reviewer is an optimisation, never a dependency. It
   cannot block the workflow.

3. **The function never returns 5xx.** A triage error is a `200` with
   `"degraded": true`, so callers can't mistake it for an outage.

4. **Slack is fire-and-forget** with an 8-second timeout. A Slack outage cannot fail triage.

5. **No financial figures go to Slack** — only company, extraction ID, confidence, verdict
   and reasons. Slack persists indefinitely and is readable by everyone in the workspace.

6. **Telemetry is append-only and never throws.** A failed analytics write cannot break a
   user action.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Sidebar says "Sample data" after setup | `config.js` absent or failed to parse | Check the file exists, is valid JS, and `git status` shows it ignored |
| `config.js` shows in `git status` | Gitignore rule not applied | `git check-ignore -v config.js` |
| Triage button disabled | `DataStore.isLive()` is false | Supabase URL/key wrong, or the CDN script was blocked |
| Triage returns `error-path` | Edge function crashed | `supabase functions logs triage` |
| Triage returns `deterministic-gate` | `GROQ_API_KEY` not set | `supabase secrets list`, then redeploy |
| `slackNotified: false` on needs_review | Webhook not set or rejected it | Re-set the secret, redeploy, curl-test the webhook |
| Slack shows a fetch/CORS error | Browser is calling Slack directly | It isn't — that means an older cached `index.html`. Bump `CACHE_VERSION` in `sw.js` |
| Thesis saves but doesn't sync | Not signed in | The button reports why; check the Account badge in the sidebar |
| `insert` denied by RLS | Anonymous insert on a restricted table | Check `pg_policies` against `supabase/migrations/0001_init.sql` |

### Clearing a stale service worker

After several edits, old cached code can persist. Bump `CACHE_VERSION` in `sw.js`:

```js
const CACHE_VERSION = 'datalens-v2';   // was v1
```

Or in Chrome: the ⤓ button in the header → unregister → reload.

---

## Cost

| Service | Free tier | Our usage at 3 testers |
|---|---|---|
| Supabase (DB + Auth + Storage) | 500 MB, 50k MAU | negligible |
| Edge Functions | 500k invocations/mo | ~1 per review |
| Groq | 14k requests/day | ~1 per review |
| Slack incoming webhooks | unlimited | ~1 per flagged review |
| GitHub Pages | unlimited | static |

**Expected spend: $0.**

---

*See `PRD.md` for product scope and `APK-BUILD.md` for distribution.*