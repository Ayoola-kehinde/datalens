// =====================================================================
// DataLens — automated triage function (Supabase Edge Function)
//
// This is the ONLY place GROQ_API_KEY and SLACK_WEBHOOK_URL exist.
// They are read from Edge secrets and never returned to the client.
//
// Why an Edge Function instead of calling Groq from the browser:
//   A Groq API key shipped in client-side HTML is readable by anyone who
//   views source or opens DevTools, and this repository is public. The
//   same applies to a Slack incoming-webhook URL. Both must stay server
//   side. Supabase Edge Functions run on Deno close to the database, on
//   the free tier, with no server for us to operate.
//
// Behaviour contract
//   * Approves only when extraction confidence and completeness are clean.
//   * ANY failure — no key, rate limit, timeout, bad JSON — resolves to
//     "needs_review". The automated reviewer is an optimisation, never a
//     dependency. It must never be able to block the workflow.
//   * Slack is fire-and-forget. A Slack outage cannot fail the triage.
//
// Deploy:
//   supabase functions deploy triage --no-verify-jwt
//
// Set secrets (never commit these):
//   supabase secrets set GROQ_API_KEY=gsk_...   SLACK_WEBHOOK_URL=https://hooks.slack.com/...
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const GROQ_MODEL = "llama-3.1-70b-versatile";
const TIMEOUT_MS = 20_000;

/* Approval gate. Anything at or above these passes automatic approval. */
const APPROVE_MIN_CONFIDENCE = 90;
const APPROVE_MIN_STATEMENT = 92;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/* ---------- deterministic quality gates (run before any LLM call) ---------- */
function assess(payload: any) {
  const confidence = Number(payload.confidence ?? 0);
  const statements: Record<string, number> = payload.statements ?? {};
  const values = Object.values(statements).map(Number);
  const weakest = values.length ? Math.min(...values) : 0;
  const flagged: string[] = payload.flagged ?? [];
  const unresolved: string[] = payload.unresolved ?? [];
  const restated: string[] = payload.restatements ?? [];

  const reasons: string[] = [];
  if (confidence < APPROVE_MIN_CONFIDENCE)
    reasons.push(`Overall extraction confidence ${confidence}% is below the ${APPROVE_MIN_CONFIDENCE}% gate`);
  if (values.length && weakest < APPROVE_MIN_STATEMENT)
    reasons.push(`Weakest statement parsed at ${weakest}% (gate ${APPROVE_MIN_STATEMENT}%)`);
  if (unresolved.length)
    reasons.push(`${unresolved.length} figure(s) unresolved, so dependent metrics cannot be computed`);
  if (flagged.length)
    reasons.push(`${flagged.length} section(s) had unrecognised table structure`);
  if (restated.length)
    reasons.push(`Prior-period restatement changes the comparison baseline`);

  return { confidence, weakest, flagged, unresolved, restated, reasons, passes: reasons.length === 0 };
}

/* ---------- Groq ---------- */
async function callGroq(groqKey: string, input: any, gate: ReturnType<typeof assess>): Promise<any> {
  const summary = {
    company: input.company,
    fiscal_year: input.fiscalYear,
    pages: input.pages,
    confidence: gate.confidence,
    statements: input.statements,
    flagged: gate.flagged,
    unresolved: gate.unresolved,
    restatements: gate.restated
  };

  const system = [
    "You are an extraction-quality reviewer for a financial document pipeline.",
    "You judge whether extracted data is trustworthy enough to publish automatically.",
    "You do NOT evaluate the company, its performance, or whether anyone should invest.",
    "You do NOT recalculate financial ratios - deterministic code already did that.",
    "You do NOT invent figures that were not given to you.",
    "Reply with ONLY a JSON object, no prose and no markdown fence:"
  ].join(" ");

  const user = [
    "Extraction summary:",
    JSON.stringify(summary, null, 2),
    "",
    "Deterministic gate result:",
    gate.passes
      ? "All quality gates passed."
      : "The following gates FAILED:\n- " + gate.reasons.join("\n- "),
    "",
    'Respond in exactly this shape: {"verdict":"approved|needs_review|reject","concerns":["..."],"rationale":"one or two sentences"}',
    'Use "approved" only if the gate passed and nothing you can see undermines it.',
    'Use "reject" only if the document is unusable (wrong company, corrupt, no text layer).',
    'Otherwise use "needs_review".'
  ].join("\n");

  const res = await fetch(GROQ_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${groqKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      temperature: 0,
      max_tokens: 400,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS)
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Groq ${res.status}: ${body.slice(0, 200)}`);
  }

  const json = await res.json();
  const content = json?.choices?.[0]?.message?.content ?? "";
  const parsed = JSON.parse(content);

  if (!["approved", "needs_review", "reject"].includes(parsed.verdict))
    throw new Error(`Unexpected verdict: ${parsed.verdict}`);

  return {
    verdict: parsed.verdict,
    concerns: Array.isArray(parsed.concerns) ? parsed.concerns.slice(0, 6) : [],
    rationale: String(parsed.rationale || "").slice(0, 800),
    model: json?.model ?? GROQ_MODEL,
    usage: json?.usage ?? null
  };
}

/* ---------- Slack (fire-and-forget) ---------- */
async function notifySlack(webhook: string, d: any): Promise<boolean> {
  const colour =
    d.verdict === "reject" ? "#ef5350" : "#ff9800";

  const payload = {
    text: `${d.verdict === "reject" ? "❌" : "⚠️"} DataLens review needed — ${d.company}`,
    blocks: [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: `${d.verdict === "reject" ? "❌ Extraction rejected" : "⚠️ Needs review"} — ${d.company}`
        }
      },
      {
        type: "section",
        fields: [
          { type: "mrkdwn", text: `*Company*\n${d.company}` },
          { type: "mrkdwn", text: `*Extraction ID*\n\`${d.extractionId}\`` },
          { type: "mrkdwn", text: `*Fiscal year*\n${d.fiscalYear}` },
          { type: "mrkdwn", text: `*Confidence*\n${d.confidence}%` },
          { type: "mrkdwn", text: `*Verdict*\n${d.verdict}` },
          { type: "mrkdwn", text: `*Source*\n${d.source}` }
        ]
      },
      {
        type: "section",
        text: { type: "mrkdwn", text: `*Rationale*\n${d.rationale}` }
      },
      ...(d.concerns.length
        ? [{
            type: "section",
            text: {
              type: "mrkdwn",
              text: `*Concerns*\n${d.concerns.map((c: string) => `• ${c}`).join("\n")}`
            }
          }]
        : []),
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: `Automated triage by ${d.model}. No financial figures are included here — open the app for detail.`
          }
        ]
      }
    ]
  };

  try {
    const res = await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(8000)
    });
    return res.ok;
  } catch {
    // Swallowed on purpose: ops alerting must never fail triage.
    return false;
  }
}

/* ---------- entry point ---------- */
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS")
    return new Response("ok", { headers: CORS });

  try {
    const body = await req.json().catch(() => ({}));
    const input = body || {};

    const company = input.company ?? "unknown";
    const fiscalYear = input.fiscalYear ?? null;
    const extractionId = input.extractionId ?? null;
    const gate = assess(input);

    /* Fallback answer used whenever the model path cannot run. */
    const fallback = (why: string) => ({
      verdict: "needs_review",
      concerns: gate.reasons.length ? gate.reasons : ["Automated reviewer unavailable"],
      rationale: `Sent to manual review because ${why}. A person will check the flagged sections before anything is published.`,
      model: "deterministic-gate",
      degraded: true
    });

    const groqKey = Deno.env.get("GROQ_API_KEY");
    if (!groqKey) {
      const r = fallback("GROQ_API_KEY is not configured on the edge function");
      r.slackNotified = await maybeNotify(r, input, gate, company, fiscalYear, extractionId);
      return json(r);
    }

    let result: any;
    try {
      result = await callGroq(groqKey, input, gate);
    } catch (err) {
      console.error("triage: Groq call failed ->", (err as Error).message);
      result = fallback(`the automated reviewer was unavailable (${(err as Error).message.slice(0, 120)})`);
    }

    /* A model must not be able to override the deterministic gate.
       If any gate failed, the answer is needs_review regardless. */
    if (!gate.passes && result.verdict === "approved") {
      result.verdict = "needs_review";
      result.concerns = [...gate.reasons, ...(result.concerns ?? [])].slice(0, 6);
      result.rationale =
        `Downgraded from approved: ${gate.reasons[0]}. ` + (result.rationale || "");
      result.gateOverrode = true;
    }

    result.slackNotified = await maybeNotify(result, input, gate, company, fiscalYear, extractionId);

    return json({
      ...result,
      gate: {
        passed: gate.passes,
        confidence: gate.confidence,
        weakestStatement: gate.weakest,
        reasons: gate.reasons
      }
    });
  } catch (err) {
    console.error("triage: unhandled", err);
    // Never let triage 500 — that would look like an outage to the caller.
    return json({
      verdict: "needs_review",
      concerns: ["Triage function error"],
      rationale: "The triage function could not complete, so this went to manual review to be safe.",
      model: "error-path",
      degraded: true
    });
  }
});

async function maybeNotify(
  result: any, input: any, gate: any,
  company: string, fiscalYear: number | null, extractionId: string | null
): Promise<boolean> {
  // Approved extractions are the normal case — do not spam the channel.
  if (result.verdict === "approved") return false;

  const webhook = Deno.env.get("SLACK_WEBHOOK_URL");
  if (!webhook) return false;

  return await notifySlack(webhook, {
    company,
    fiscalYear: fiscalYear ?? "—",
    extractionId: extractionId ?? "pending",
    confidence: gate.confidence,
    verdict: result.verdict,
    rationale: result.rationale || "No rationale returned.",
    concerns: result.concerns ?? [],
    model: result.model,
    source: input.source ?? "DataLens triage"
  });
}

function json(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    headers: { ...CORS, "Content-Type": "application/json" },
    status: 200
  });
}