-- =====================================================================
-- DataLens — schema, Row Level Security, and seed data
-- =====================================================================
-- Run once in the Supabase SQL editor, or:  supabase db push
--
-- SECURITY MODEL
--   The Supabase anon key is PUBLIC. It ships in index.html and anyone
--   can read it. These policies — not the key — are what protect data.
--   Everything below follows from that.
--
--   Public market data   companies, extractions  → readable by anyone
--   Personal research    theses, thesis_versions → owner only, strictly
--   Privileged actions   status/decision columns → reviewers only
--   Telemetry            events                  → own rows only
--
--   Server-side writes (extraction ingest, Groq verdict) use the
--   service_role key inside Edge Functions and bypass RLS by design.
--   The browser holds the anon key only, and can never reach those paths.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Extensions
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- =====================================================================
-- 2. Reference data — PUBLIC. Filed annual reports are already public.
-- =====================================================================
create table if not exists public.companies (
  id          uuid primary key default gen_random_uuid(),
  ticker      text unique not null,
  name        text not null,
  short_name  text,
  sector      text,
  industry    text,
  kind        text,                       -- 'bank' | 'telco' | ...
  exchange    text not null default 'NGX',
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- 3. Extractions — one row per company per fiscal year
-- =====================================================================
create table if not exists public.extractions (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references public.companies(id) on delete cascade,
  fiscal_year       int  not null,

  status            text not null default 'submitted'
                      check (status in ('submitted','processing','needs_review',
                                        'approved','rejected')),

  payload           jsonb not null default '{}'::jsonb,
  confidence        numeric(5,2),

  -- automated reviewer output. Server-written only.
  groq_verdict      text check (groq_verdict in ('approved','needs_review','reject')),
  groq_rationale    text,
  groq_concerns     jsonb not null default '[]'::jsonb,
  groq_model        text,
  reviewed_at       timestamptz,

  -- human reviewer decision
  decided_at        timestamptz,
  decided_by        uuid references auth.users(id) on delete set null,
  decision_note     text,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique (company_id, fiscal_year)
);

create index if not exists extractions_status_idx  on public.extractions (status, created_at desc);
create index if not exists extractions_company_idx on public.extractions (company_id);

-- =====================================================================
-- 4. Personal research — PRIVATE. Locked to auth.uid() = user_id.
-- =====================================================================
create table if not exists public.theses (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  growth        text not null default '',
  profitability text not null default '',
  strength      text not null default '',
  watchlist     jsonb not null default '[]'::jsonb,
  version       int  not null default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, company_id)
);

-- Append-only history so users can see how their thinking changed.
-- Deliberately has no UPDATE or DELETE policy: once written, a version
-- is immutable even to its own author.
create table if not exists public.thesis_versions (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  version       int  not null,
  snapshot      jsonb not null,
  created_at    timestamptz not null default now()
);

create index if not exists thesis_versions_user_idx
  on public.thesis_versions (user_id, company_id, created_at desc);

-- =====================================================================
-- 5. Reviewers — privileged accounts allowed to record decisions
-- =====================================================================
create table if not exists public.reviewers (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  added_at  timestamptz not null default now()
);

comment on table public.reviewers is
  'Allow-list for review decisions. Populate manually: insert into reviewers (user_id) values (''<uuid>'');';

-- =====================================================================
-- 6. Telemetry
-- =====================================================================
create table if not exists public.events (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users(id) on delete set null,
  session_id  uuid,
  name        text not null,
  properties  jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists events_name_idx  on public.events (name, created_at desc);
create index if not exists events_user_idx on public.events (user_id, created_at desc);

-- =====================================================================
-- 7. Enable RLS everywhere. A table with RLS off is fully exposed.
-- =====================================================================
alter table public.companies        enable row level security;
alter table public.extractions      enable row level security;
alter table public.theses           enable row level security;
alter table public.thesis_versions  enable row level security;
alter table public.reviewers        enable row level security;
alter table public.events           enable row level security;

-- Drop every policy so this script is safely re-runnable.
drop policy if exists companies_read        on public.companies;
drop policy if exists extractions_read      on public.extractions;
drop policy if exists extractions_insert    on public.extractions;
drop policy if exists extractions_review    on public.extractions;
drop policy if exists theses_owner_all      on public.theses;
drop policy if exists thesis_versions_owner_read   on public.thesis_versions;
drop policy if exists thesis_versions_owner_insert on public.thesis_versions;
drop policy if exists reviewers_self_read   on public.reviewers;
drop policy if exists events_insert         on public.events;
drop policy if exists events_read_own       on public.events;

-- ---------------------------------------------------------------------
-- 7a. companies — public reference data, read-only for everyone.
--     No INSERT/UPDATE/DELETE policy exists, so all writes are denied.
-- ---------------------------------------------------------------------
create policy companies_read on public.companies
  for select using (true);

-- ---------------------------------------------------------------------
-- 7b. extractions — read publicly.
--
--     INSERT is deliberately NOT granted. An unauthenticated write here
--     would let anyone inject fabricated financial figures into a table
--     every visitor can read. Extraction ingest belongs in an Edge
--     Function using the service_role key, not in the browser.
--
--     UPDATE is limited to reviewers AND to the four decision columns
--     (enforced by the column grants in section 8, not by RLS). RLS is
--     row-level only; without the grant a reviewer could tamper with
--     `payload` or `groq_verdict`, which must stay server-written.
-- ---------------------------------------------------------------------
create policy extractions_read on public.extractions
  for select using (true);

create policy extractions_review on public.extractions
  for update to authenticated
  using (exists (select 1 from public.reviewers r where r.user_id = auth.uid()))
  with check (exists (select 1 from public.reviewers r where r.user_id = auth.uid()));

-- ---------------------------------------------------------------------
-- 7c. theses — the privacy-critical table. Owner only, all operations.
-- ---------------------------------------------------------------------
create policy theses_owner_all on public.theses
  for all to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 7d. thesis_versions — owner read, owner insert, NO update or delete.
--     Append-only by construction.
-- ---------------------------------------------------------------------
create policy thesis_versions_owner_read on public.thesis_versions
  for select to authenticated using (auth.uid() = user_id);

create policy thesis_versions_owner_insert on public.thesis_versions
  for insert to authenticated with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 7e. reviewers — a user may check whether they are one, nothing else.
--     The allow-list itself can only be written server-side.
-- ---------------------------------------------------------------------
create policy reviewers_self_read on public.reviewers
  for select to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 7f. events — authenticated insert, own-rows read.
--     Anonymous insert is refused: on a free tier an unbounded append
--     endpoint is a storage-exhaustion vector.
-- ---------------------------------------------------------------------
create policy events_insert on public.events
  for insert to authenticated with check (user_id = auth.uid());

create policy events_read_own on public.events
  for select to authenticated using (user_id = auth.uid());

-- =====================================================================
-- 8. Column-level grants
-- ---------------------------------------------------------------------
-- RLS governs ROWS. Grants govern COLUMNS. Together they let a reviewer
-- record a decision without being able to alter the underlying data or
-- the automated reviewer's verdict.
--
-- Steps:
--   1. Revoke the broad UPDATE right from anon and authenticated.
--   2. Re-grant UPDATE on only the four decision columns to authenticated.
--   3. Re-grant full INSERT on theses so the upsert path still works.
-- =====================================================================

revoke update on public.extractions from anon, authenticated;
grant  update (status, decided_at, decided_by, decision_note)
  on public.extractions to authenticated;

-- Ensure anon holds no write rights anywhere. Belt and braces.
revoke insert, update, delete on public.extractions from anon;
revoke insert, update, delete on public.companies  from anon, authenticated;
revoke insert, update, delete on public.reviewers  from anon, authenticated;
revoke select               on public.reviewers  from anon;

-- =====================================================================
-- 9. updated_at maintenance
-- =====================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists theses_touch on public.theses;
create trigger theses_touch before update on public.theses
  for each row execute function public.touch_updated_at();

drop trigger if exists extractions_touch on public.extractions;
create trigger extractions_touch before update on public.extractions
  for each row execute function public.touch_updated_at();

-- =====================================================================
-- 10. Audit view — how many requests are sitting in each state
-- =====================================================================
create or replace view public.review_queue as
  select e.id, c.ticker, c.name, e.fiscal_year, e.status,
         e.confidence, e.groq_verdict, e.decided_at
  from public.extractions e
  join public.companies c on c.id = e.company_id
  where e.status = 'needs_review'
  order by e.created_at;

-- =====================================================================
-- 11. Seed — four demo companies, FY2025
-- =====================================================================
-- ILLUSTRATIVE SAMPLE DATA for a Nigerian market context.
-- Not real reported results for the named companies.
-- =====================================================================

insert into public.companies (ticker, name, short_name, sector, industry, kind) values
  ('GTCO',   'Guaranty Trust Holding Plc',     'Guaranty Trust',  'Financials',        'Banking',                 'bank'),
  ('ZNB',    'Zenith Bank Plc',                'Zenith Bank',     'Financials',        'Banking',                 'bank'),
  ('ACCESS', 'Access Holdings Plc',            'Access Holdings', 'Financials',        'Banking',                 'bank'),
  ('MTNN',   'MTN Nigeria Communications Plc', 'MTN Nigeria',     'Telecommunications','Mobile Network Operator', 'telco')
on conflict (ticker) do update
  set name = excluded.name, short_name = excluded.short_name,
      sector = excluded.sector, industry = excluded.industry, kind = excluded.kind;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 92.0, $$
{"price":105.00,"priceAsOf":"2026-09-19",
 "thesis":{"growth":"Revenue growth remains strong and consistent.",
           "profitability":"Margins held above 24% through FY2025.",
           "strength":"Debt remains manageable, though the new USD bond needs watching.",
           "watch":["Operating cash flow","Finance costs","Dividend growth","Cost-to-income"]},
 "m":{"revenue":[890,1000,1200,1470,1740],"netProfit":[250,280,340,420,425],
      "eps":[9.80,10.90,13.20,16.20,16.40],"equity":[1500,1700,1900,2000,1840],
      "totalAssets":[3500,4200,4900,5600,6300],"ocf":[480,560,640,700,574],
      "capex":[120,140,165,185,210],"debt":[380,410,450,520,690],
      "dps":[4.50,5.00,6.00,8.00,8.50],
      "costToIncome":[45.2,46.1,47.0,47.6,48.2],"npl":[3.2,3.4,3.6,3.7,3.8],
      "car":[25.1,25.4,25.0,24.9,24.8]}}
$$::jsonb from public.companies c where c.ticker='GTCO'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 97.0, $$
{"price":42.50,"priceAsOf":"2026-09-19",
 "thesis":{"growth":"Revenue compounding above 20% for four years.",
           "profitability":"Cost discipline improving - cost-to-income falling every year.",
           "strength":"Capital adequacy rising, NPL ratio declining.",
           "watch":["Cost-to-income","NPL ratio","Dividend growth"]},
 "m":{"revenue":[780,950,1240,1500,1880],"netProfit":[245,292,347,441,520],
      "eps":[3.20,3.80,4.50,5.70,6.70],"equity":[1200,1380,1600,1850,2200],
      "totalAssets":[3200,4000,5000,6100,7200],"ocf":[380,470,560,640,810],
      "capex":[90,105,125,150,180],"debt":[320,360,400,460,520],
      "dps":[2.50,2.80,3.20,3.50,3.85],
      "costToIncome":[52.1,51.0,50.2,49.4,48.8],"npl":[3.9,3.8,3.6,3.5,3.4],
      "car":[22.5,22.8,23.1,23.4,23.6]}}
$$::jsonb from public.companies c where c.ticker='ZNB'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'needs_review', 71.0, $$
{"price":9.85,"priceAsOf":"2026-09-19",
 "thesis":{"growth":"Topline growth has flattened since FY2023.",
           "profitability":"Margins under pressure - provisioning is rising.",
           "strength":"Capital adequacy has fallen below the 20% comfort line.",
           "watch":["NPL ratio","Capital adequacy","Cost-to-income","Profit margin"]},
 "m":{"revenue":[1000,1300,1450,1600,1720],"netProfit":[130,190,250,260,215],
      "eps":[0.28,0.40,0.52,0.54,0.44],"equity":[700,820,980,1180,1300],
      "totalAssets":[5000,6200,7400,8600,9500],"ocf":[260,380,420,400,310],
      "capex":[150,190,220,250,280],"debt":[620,700,800,950,1150],
      "dps":[0.08,0.14,0.20,0.18,0.10],
      "costToIncome":[61.2,58.0,55.5,58.4,63.1],"npl":[4.5,4.8,5.2,6.5,7.8],
      "car":[19.5,19.1,18.8,18.2,17.4]}}
$$::jsonb from public.companies c where c.ticker='ACCESS'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 89.0, $$
{"price":285.40,"priceAsOf":"2026-09-19",
 "thesis":{"growth":"Subscriber growth continues but revenue growth is slowing.",
           "profitability":"Opex rising faster than revenue - margin squeeze.",
           "strength":"Leverage has increased steadily alongside expansion capex.",
           "watch":["Receivables","Operating expenses","Free cash flow","Debt"]},
 "m":{"revenue":[1050,1180,1330,1490,1620],"netProfit":[95,125,155,178,140],
      "eps":[3.30,4.35,5.40,6.20,4.88],"equity":[700,800,900,1020,1080],
      "totalAssets":[1800,2100,2400,2700,2950],"ocf":[280,340,400,430,400],
      "capex":[200,240,280,320,350],"debt":[400,450,500,600,720],
      "dps":[0,0,0,2.00,2.00],
      "directCost":[480,540,610,670,700],"receivables":[120,145,180,220,303],
      "opex":[620,700,790,890,1010]}}
$$::jsonb from public.companies c where c.ticker='MTNN'
on conflict (company_id, fiscal_year) do nothing;