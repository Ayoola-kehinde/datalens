/* =====================================================================
   DataLens runtime configuration
   ---------------------------------------------------------------------
   Copy this file to `config.js` and fill in your values.

       Copy-Item config.example.js config.js

   `config.js` is gitignored. NEVER commit it and never paste real
   values into this template — this file is public.

   WHAT IS SAFE TO PUT HERE
     SUPABASE_URL         Public project URL. Fine in client code.
     SUPABASE_ANON_KEY    Public by design. Protected by Row Level
                          Security, NOT by secrecy. If you can find it,
                          you still cannot read another user's thesis.
     TRIAGE_FUNCTION      Name of the Supabase Edge Function to call.

   WHAT MUST NEVER GO HERE
     GROQ_API_KEY         Server-side only. Put it in Edge secrets.
     SLACK_WEBHOOK_URL    Server-side only. Put it in Edge secrets.

   A Groq key or Slack webhook placed in this file would be readable by
   anyone who views the page source, and would be published to GitHub
   Pages. Both would leak immediately.
   ===================================================================== */

window.DATALENS_CONFIG = {

  /* --- Supabase: Project Settings → Data API --- */
  SUPABASE_URL: "https://YOUR-PROJECT-REF.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_SUPABASE_ANON_PUBLIC_KEY",

  /* --- Edge function name (do not include the URL path) --- */
  TRIAGE_FUNCTION: "triage"

};