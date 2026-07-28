-- ===========================================================================
-- Macro, Supabase schema
-- Run this in the Supabase SQL editor once a project exists (none does yet,
-- index.html ships with an empty Supabase URL, fully local). One block per
-- table, RLS is ON by default, pick ONE policy option.
--
-- Row shape: generic {id, user_id, data jsonb, updated_at}, matching the
-- starter's sbBatchUpsert/sbFetchAll in index.html unchanged. Every
-- per-instrument field (symbol, label, asset_class, sort_order) lives inside
-- the data jsonb column rather than as a named typed column. This keeps the
-- proven generic sync layer untouched, no per-table client code path. RLS
-- still needs user_id as a real column (a policy cannot filter cheaply on a
-- value buried in jsonb), so user_id stays outside data.
-- ===========================================================================

create table if not exists watchlist (
  id          text primary key,
  user_id     uuid        default auth.uid(),   -- single-user seam, nullable for now
  data        jsonb       not null,              -- symbol, label, asset_class, sort_order
  updated_at  timestamptz not null default now()
);

-- The client pages ascending on (updated_at, id) (sbFetchAll's keyset
-- pagination in index.html), so the compound index matches that exact key
-- order.
create index if not exists watchlist_updated_id_idx on watchlist (updated_at, id);

-- RLS is ON by default. Pick ONE policy block below. Never ship with RLS off.
alter table watchlist enable row level security;

-- ---------------------------------------------------------------------------
-- OPTION A: quick start (single-user personal app, direct anon path).
-- The browser holds the anon key and gets full access. Simple, but anyone with
-- the URL + anon key can read and write. Use only for low-sensitivity, personal
-- data. This matches USE_WORKER_DB = false in index.html.
-- ---------------------------------------------------------------------------
create policy "anon full access" on watchlist
  for all to anon
  using (true) with check (true);

-- ---------------------------------------------------------------------------
-- OPTION B: locked down via the Cloudflare Worker proxy (recommended for
-- single-user when the data matters). Leave RLS on with NO anon policy, so the
-- anon role is denied outright. The Worker injects the service-role key, which
-- bypasses RLS. Set USE_WORKER_DB = true in index.html and DROP option A:
--     drop policy if exists "anon full access" on watchlist;
-- (No policy needed here, denial is the default once RLS is on.)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- OPTION C: per-user accounts (multi-user). Requires Supabase Auth (email OTP,
-- SB_AUTH = 'email-otp' in index.html) sending the user's JWT instead of the
-- anon key. Each user sees only their own rows. Drop option A first, then:
-- (select auth.uid()) wraps the call so Postgres evaluates it ONCE per query
-- (an initPlan) rather than once per row, the recommended performance form
-- for RLS policies at any scale.
-- ---------------------------------------------------------------------------
-- create policy "own rows read"  on watchlist for select to authenticated
--   using ((select auth.uid()) = user_id);
-- create policy "own rows write" on watchlist for all to authenticated
--   using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
--
-- An RLS policy filters every query by user_id, so index it too:
-- create index if not exists watchlist_user_id_idx on watchlist (user_id);

-- ===========================================================================
-- To add another table, copy the block above and rename. Then add the table
-- name to TABLES in index.html. That is all the sync layer needs.
-- ===========================================================================
