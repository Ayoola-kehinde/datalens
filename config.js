/* =====================================================================
   DataLens — public runtime configuration
   ---------------------------------------------------------------------
   Committed and served by GitHub Pages, and bundled into the Android
   APK. Both values below must reach the browser for the app to connect.

   WHY THIS IS SAFE TO COMMIT
     SUPABASE_URL      A project URL is not a secret.
     SUPABASE_ANON_KEY Public by design. Supabase's dashboard labels it
                       "anon public". Data is protected by Row Level
                       Security in supabase/migrations/0001_init.sql,
                       NOT by secrecy. Anyone holding this key still
                       cannot read another user's thesis, cannot write
                       to the extractions table, and cannot record a
                       review decision.

   WHAT MUST NEVER APPEAR IN THIS FILE
     service_role key  It bypasses RLS entirely. Full database access.
     GROQ_API_KEY      Server-side only.
     SLACK_WEBHOOK_URL Server-side only.

   A service_role key, a Groq key or a Slack webhook placed here would be
   readable by anyone viewing page source or unpacking the APK. The
   latter two belong in Supabase Edge secrets and are reached only via
   the triage edge function. .gitignore denies filenames matching
   GROQ, gsk_, SLACK, slack and .webhook.
   ===================================================================== */

window.DATALENS_CONFIG = {

  /* --- Supabase project ---
     anon key: role=anon, ref=mlnpssfposgmwsnjpmmm, expires 2036-10-10.
     Verified by decoding the JWT payload before use. */
  SUPABASE_URL: "https://mlnpssfposgmwsnjpmmm.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sbnBzc2Zwb3NnbXdzbmpwbW1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDI0NzMsImV4cCI6MjEwNzIxODQ3M30.7p3x9NPMSRZ4xTFr9dYcBe-kgqej8VYAgoMb6o7ym0g",

  /* --- Deployed Edge Function (Groq reviewer + Slack alerting) --- */
  TRIAGE_URL: "https://mlnpssfposgmwsnjpmmm.supabase.co/functions/v1/triage",

  /* --- Fallback used only if TRIAGE_URL is omitted --- */
  TRIAGE_FUNCTION: "triage"

};