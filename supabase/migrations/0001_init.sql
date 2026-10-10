-- =====================================================================
-- DataLens — schema, Row Level Security, and seed data
-- =====================================================================
-- Run this once in the Supabase SQL editor, or via:
--   supabase db push
--
-- Design notes
--   * companies + extractions hold PUBLIC market data (already filed
--     reports), so they are readable by anyone including anonymous
--     visitors. Nothing confidential lives in these tables.
--   * theses and thesis_versions hold PERSONAL research notes. These are
--     locked to their owner with RLS. This is the policy that actually
--     protects user data — the anon key is public by design.
--   * events is append-only funnel telemetry, written by the browser.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Extensions
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 2. Reference data
-- ---------------------------------------------------------------------
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

comment on table public.companies is 'NGX-listed company reference data. Public.';

-- ---------------------------------------------------------------------
-- 3. Extractions — one row per company per fiscal year
-- ---------------------------------------------------------------------
create table if not exists public.extractions (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references public.companies(id) on delete cascade,
  fiscal_year       int  not null,

  -- request lifecycle
  status            text not null default 'submitted'
                      check (status in ('submitted','processing','needs_review',
                                        'approved','rejected')),

  -- the normalised financial series + market data
  payload           jsonb not null default '{}'::jsonb,
  confidence        numeric(5,2),

  -- automated reviewer output (Groq), kept separate from the human decision
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

comment on column public.extractions.groq_verdict is
  'Automated triage recommendation. Distinct from decided_at/decided_by, which record the human decision.';

create index if not exists extractions_status_idx  on public.extractions (status, created_at desc);
create index if not exists extractions_company_idx on public.extractions (company_id);

-- ---------------------------------------------------------------------
-- 4. Theses — one per user per company
-- ---------------------------------------------------------------------
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

comment on table public.theses is 'Personal investment thesis. Row is visible only to its owner.';

-- append-only history so users can see how their thinking changed
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

-- ---------------------------------------------------------------------
-- 5. Events — funnel telemetry
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 6. Row Level Security
-- ---------------------------------------------------------------------
alter table public.companies        enable row level security;
alter table public.extractions      enable row level security;
alter table public.theses           enable row level security;
alter table public.thesis_versions  enable row level security;
alter table public.events           enable row level security;

-- companies: public reference data, readable by everyone
drop policy if exists companies_read on public.companies;
create policy companies_read on public.companies
  for select using (true);

-- extractions: public filings + their analysis, readable by everyone.
-- Anonymous visitors may also submit a request (status 'submitted').
drop policy if exists extractions_read on public.extractions;
create policy extractions_read on public.extractions
  for select using (true);

drop policy if exists extractions_insert on public.extractions;
create policy extractions_insert on public.extractions
  for insert to anon, authenticated with check (true);

drop policy if exists extractions_update on public.extractions;
create policy extractions_update on public.extractions
  for update to authenticated using (auth.uid() = decided_by)
                     with check (auth.uid() = decided_by);

-- theses: STRICTLY the owner. This is the policy that matters.
drop policy if exists theses_owner_all on public.theses;
create policy theses_owner_all on public.theses
  for all to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists thesis_versions_owner_all on public.thesis_versions;
create policy thesis_versions_owner_all on public.thesis_versions
  for all to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- events: anyone may log in; you can only read your own back.
drop policy if exists events_insert on public.events;
create policy events_insert on public.events
  for insert to anon, authenticated with check (true);

drop policy if exists events_read_own on public.events;
create policy events_read_own on public.events
  for select to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 7. updated_at maintenance
-- ---------------------------------------------------------------------
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
-- 8. Seed — the four demo companies and their five-year extractions
-- =====================================================================
-- NOTE: figures are ILLUSTRATIVE SAMPLE DATA for a Nigerian market
-- context. They are not real reported results for the named companies.
-- =====================================================================

insert into public.companies (ticker, name, short_name, sector, industry, kind) values
  ('GTCO',   'Guaranty Trust Holding Plc',     'Guaranty Trust',   'Financials',        'Banking',                    'bank'),
  ('ZNB',    'Zenith Bank Plc',                'Zenith Bank',      'Financials',        'Banking',                    'bank'),
  ('ACCESS', 'Access Holdings Plc',            'Access Holdings',  'Financials',        'Banking',                    'bank'),
  ('MTNN',   'MTN Nigeria Communications Plc', 'MTN Nigeria',      'Telecommunications','Mobile Network Operator',    'telco')
on conflict (ticker) do update
  set name = excluded.name,
      short_name = excluded.short_name,
      sector = excluded.sector,
      industry = excluded.industry,
      kind = excluded.kind;

-- FY2025 extraction per company. The payload column mirrors the shape the
-- front end expects, so a live fetch is a drop-in replacement for the
-- bundled sample object.
insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 92.0, $$
{
  "price": 105.00, "priceAsOf": "2026-09-19",
  "thesis": {
    "growth": "Revenue growth remains strong and consistent.",
    "profitability": "Margins held above 24% through FY2025.",
    "strength": "Debt remains manageable, though the new USD bond needs watching.",
    "watch": ["Operating cash flow","Finance costs","Dividend growth","Cost-to-income"]
  },
  "m": {
    "revenue":[890,1000,1200,1470,1740], "netProfit":[250,280,340,420,425],
    "eps":[9.80,10.90,13.20,16.20,16.40], "equity":[1500,1700,1900,2000,1840],
    "totalAssets":[3500,4200,4900,5600,6300], "ocf":[480,560,640,700,574],
    "capex":[120,140,165,185,210], "debt":[380,410,450,520,690],
    "dps":[4.50,5.00,6.00,8.00,8.50],
    "costToIncome":[45.2,46.1,47.0,47.6,48.2], "npl":[3.2,3.4,3.6,3.7,3.8],
    "car":[25.1,25.4,25.0,24.9,24.8]
  }
}
$$::jsonb
from public.companies c where c.ticker = 'GTCO'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 97.0, $$
{
  "price": 42.50, "priceAsOf": "2026-09-19",
  "thesis": {
    "growth": "Revenue compounding above 20% for four years.",
    "profitability": "Cost discipline improving - cost-to-income falling every year.",
    "strength": "Capital adequacy rising, NPL ratio declining.",
    "watch": ["Cost-to-income","NPL ratio","Dividend growth"]
  },
  "m": {
    "revenue":[780,950,1240,1500,1880], "netProfit":[245,292,347,441,520],
    "eps":[3.20,3.80,4.50,5.70,6.70], "equity":[1200,1380,1600,1850,2200],
    "totalAssets":[3200,4000,5000,6100,7200], "ocf":[380,470,560,640,810],
    "capex":[90,105,125,150,180], "debt":[320,360,400,460,520],
    "dps":[2.50,2.80,3.20,3.50,3.85],
    "costToIncome":[52.1,51.0,50.2,49.4,48.8], "npl":[3.9,3.8,3.6,3.5,3.4],
    "car":[22.5,22.8,23.1,23.4,23.6]
  }
}
$$::jsonb
from public.companies c where c.ticker = 'ZNB'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'needs_review', 71.0, $$
{
  "price": 9.85, "priceAsOf": "2026-09-19",
  "thesis": {
    "growth": "Topline growth has flattened since FY2023.",
    "profitability": "Margins under pressure - provisioning is rising.",
    "strength": "Capital adequacy has fallen below the 20% comfort line.",
    "watch": ["NPL ratio","Capital adequacy","Cost-to-income","Profit margin"]
  },
  "m": {
    "revenue":[1000,1300,1450,1600,1720], "netProfit":[130,190,250,260,215],
    "eps":[0.28,0.40,0.52,0.54,0.44], "equity":[700,820,980,1180,1300],
    "totalAssets":[5000,6200,7400,8600,9500], "ocf":[260,380,420,400,310],
    "capex":[150,190,220,250,280], "debt":[620,700,800,950,1150],
    "dps":[0.08,0.14,0.20,0.18,0.10],
    "costToIncome":[61.2,58.0,55.5,58.4,63.1], "npl":[4.5,4.8,5.2,6.5,7.8],
    "car":[19.5,19.1,18.8,18.2,17.4]
  }
}
$$::jsonb
from public.companies c where c.ticker = 'ACCESS'
on conflict (company_id, fiscal_year) do nothing;

insert into public.extractions (company_id, fiscal_year, status, confidence, payload)
select c.id, 2025, 'approved', 89.0, $$
{
  "price": 285.40, "priceAsOf": "2026-09-19",
  "thesis": {
    "growth": "Subscriber growth continues but revenue growth is slowing.",
    "profitability": "Opex rising faster than revenue - margin squeeze.",
    "strength": "Leverage has increased steadily alongside expansion capex.",
    "watch": ["Receivables","Operating expenses","Free cash flow","Debt"]
  },
  "m": {
    "revenue":[1050,1180,1330,1490,1620], "netProfit":[95,125,155,178,140],
    "eps":[3.30,4.35,5.40,6.20,4.88], "equity":[700,800,900,1020,1080],
    "totalAssets":[1800,2100,2400,2700,2950], "ocf":[280,340,400,430,400],
    "capex":[200,240,280,320,350], "debt":[400,450,500,600,720],
    "dps":[0,0,0,2.00,2.00],
    "directCost":[480,540,610,670,700], "receivables":[120,145,180,220,303],
    "opex":[620,700,790,890,1010]
  }
}
$$::jsonb
from public.companies c where c.ticker = 'MTNN'
on conflict (company_id, fiscal_year) do nothing;