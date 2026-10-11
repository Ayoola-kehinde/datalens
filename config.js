/* =====================================================================
   DataLens — public runtime configuration
   ---------------------------------------------------------------------
   This file IS committed and served by GitHub Pages, and is bundled
   into the Android APK by Capacitor. Both values below must reach the
   browser for the app to connect.

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
   who views page source or unpacks the APK, and would be published to
   GitHub Pages. Both belong in Supabase Edge secrets and are reached
   only through the triage edge function. .gitignore denies filenames
   matching GROQ, gsk_, SLACK, slack and .webhook, so a stray paste
   fails to commit.

   TO ACTIVATE
     1. Paste the anon key below from Supabase -> Project Settings ->
        Data API -> Project API keys -> "anon public".
     2. Commit and push. The live build and the next APK both pick it up.

   Until the anon key is filled in, the app detects the placeholder and
   stays on its bundled sample data rather than failing on a 401.
   ===================================================================== */

window.DATALENS_CONFIG = {

  /* --- Supabase project --- */
  SUPABASE_URL: "https://mlnpssfposgmwsnjpmmm.supabase.co",
  SUPABASE_ANON_KEY: "PASTE_YOUR_SUPABASE_ANON_PUBLIC_KEY_HERE",

  /* --- Deployed Edge Function (Groq reviewer + Slack alerting) --- */
  TRIAGE_URL: "https://mlnpssfposgmwsnjpmmm.supabase.co/functions/v1/triage",

  /* --- Used only if TRIAGE_URL is omitted --- */
  TRIAGE_FUNCTION: "triage"

};