/* =====================================================================
   DataLens — public runtime configuration
   ---------------------------------------------------------------------
   This file IS committed and served by GitHub Pages, because the two
   values below must reach the browser for the app to connect. One push
   activates the live site and the APK together.

   WHY THIS IS SAFE TO COMMIT
     SUPABASE_URL      A project URL is not a secret.
     SUPABASE_ANON_KEY Public by design. Supabase's own dashboard labels
                       it "anon public". It is protected by Row Level
                       Security in supabase/migrations/0001_init.sql,
                       NOT by secrecy. Anyone holding it still cannot
                       read another user's thesis, cannot write to the
                       extractions table, and cannot record a review
                       decision.

   WHAT MUST NEVER APPEAR IN THIS FILE
     GROQ_API_KEY       Server-side only.
     SLACK_WEBHOOK_URL  Server-side only.

   A Groq key or Slack webhook placed here would be readable by anyone
   who views page source and would be published to GitHub Pages. Both
   belong in Supabase Edge secrets and are reached only through the
   triage edge function. .gitignore denies filenames matching GROQ,
   gsk_, SLACK, slack and .webhook, so a stray paste fails to commit.

   TO ACTIVATE
     1. Replace the two placeholders below with the values from
        Supabase -> Project Settings -> Data API.
     2. Commit and push. The live build connects on the next deploy.

   Until then the app detects the placeholders and stays on its bundled
   sample data rather than attempting a doomed connection.
   ===================================================================== */

window.DATALENS_CONFIG = {

  /* --- Supabase: Project Settings -> Data API --- */
  SUPABASE_URL: "PASTE_YOUR_SUPABASE_PROJECT_URL_HERE",
  SUPABASE_ANON_KEY: "PASTE_YOUR_SUPABASE_ANON_PUBLIC_KEY_HERE",

  /* --- Edge function name (no URL path) --- */
  TRIAGE_FUNCTION: "triage"

};