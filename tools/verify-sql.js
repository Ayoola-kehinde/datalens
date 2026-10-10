const fs = require("fs");

const sql = fs.readFileSync("supabase/migrations/0001_init.sql", "utf8");

// Extract every $$ ... $$::jsonb literal.
// The content must start with '{' so the PL/pgSQL function body
// (which also uses dollar-quoting) is not swallowed by the match.
const re = /\$\$\s*(\{[\s\S]*?\})\s*\$\$::jsonb/g;
const blocks = [];
let m;
while ((m = re.exec(sql)) !== null) blocks.push(m[1]);

console.log("jsonb seed payloads found:", blocks.length);
if (blocks.length === 0) {
  console.log("  !! none matched — check the dollar-quote pattern in the SQL");
  process.exit(1);
}

let bad = 0;
blocks.forEach((b, i) => {
  try {
    const o = JSON.parse(b);
    const years = o.m && Object.keys(o.m).length;
    console.log(
      `  block ${i + 1}: valid JSON  ticker-payload keys=[${Object.keys(o).join(",")}]` +
      `  metric-series=${years}`
    );
    // sanity: every array series should be length 5 (FY2021-FY2025)
    let lenMismatch = 0;
    for (const [k, v] of Object.entries(o.m || {})) {
      if (Array.isArray(v) && v.length !== 5) {
        console.log(`    !! ${k} has ${v.length} points, expected 5`);
        lenMismatch++;
      }
    }
    if (lenMismatch) bad++;
  } catch (e) {
    console.log(`  block ${i + 1}: INVALID JSON -> ${e.message}`);
    bad++;
  }
});

// Policy / grant sanity
const tables = [...sql.matchAll(/create table if not exists public\.(\w+)/g)].map(x => x[1]);
const rls    = [...sql.matchAll(/alter table public\.(\w+)\s+enable row level security/g)].map(x => x[1]);
console.log("\ntables created :", tables.length, tables.join(", "));
console.log("rls enabled    :", rls.length, rls.join(", "));
const missing = tables.filter(t => !rls.includes(t));
console.log(missing.length ? "  !! RLS MISSING ON: " + missing.join(", ") : "  RLS enabled on every table");

const policies = [...sql.matchAll(/create policy (\w+)/g)].map(x => x[1]);
console.log("policies       :", policies.length, policies.join(", "));

const grants = [...sql.matchAll(/grant\s+(update|insert|select)[^;]*?on public\.(\w+)/gis)].map(x => `${x[2]}:${x[1]}`);
console.log("column grants  :", grants.join("  "));

process.exit(bad || missing.length ? 1 : 0);