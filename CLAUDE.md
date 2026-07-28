# Kujira Macro

Market-intelligence dashboard, mock data for now, no live feed. Not yet hosted, local-only build.

## Naming

This app is "Kujira Macro", referred to as "Macro" throughout.

## Milestones

- M0 Scaffold, done. Config, schema, git init
- M1 Mock market-data engine, done. Seeded deterministic generator
- M2 Dashboard shell plus overview grid, done. Dark/light, sparklines, responsive
- M3 Watchlist CRUD, not built
- M4 Instrument detail drawer, not built
- M5 Polish pass, not built

## Architecture

Single-file SPA. All CSS, JS, and HTML live in `index.html`. Shared colour, type, shape and motion tokens live in `tokens.css`. No framework, no bundler, no build step. Open the file and it runs.

### Data layer

Scaffolded from the Kujira web-app starter, sync layer inert (no Supabase project exists yet).

- `DB.watchlist`, empty today, wired through `TABLES` so the starter's dirty-tracking, save, load and merge machinery already treats it as a real table
- `saveData()` writes to localStorage first, cloud flush is a no-op while `SB_DIRECT_URL` is empty
- The dashboard itself (the mock instruments shown on screen) is NOT part of `DB`, it is generated fresh on every boot by the mock engine below, nothing about it persists or syncs

### Mock market-data engine (M1)

`MARKET_SEED` (fixed) feeds `mulberry32`, a small deterministic PRNG. `INSTRUMENTS` lists 9 indices, 9 FX pairs and 7 commodities (real-world tickers, no crypto), each with a plausible base price and a volatility factor. `generateMarketData()` walks each instrument through `SERIES_POINTS` (78) intraday ticks in one seeded pass, so last price, day high, day low and the sparkline series can never disagree with each other, and the exact same numbers come back on every reload.

Never swap in `Math.random()` here, it breaks reload determinism (the M2 acceptance test compares a printed value across two reloads).

### Derived values, single source of truth

`changeAbs`, `changePct`, `direction`, `dayRangePos` and `priceDecimals`/`formatPrice` are each computed in one function, called fresh at render time. No view stores its own copy of a change percentage or direction, so nothing can go stale.

### Adding a table

1. Add the name to `TABLES`
2. Add a matching table to `schema.sql`, run it once a Supabase project exists
3. Build its view, `markDirty(table, id)` on every create or edit, then `saveData()`

## Design system

`tokens.css` only, both themes. Never a hardcoded colour in page CSS. Dark is default, `html.light` overrides colour tokens.

Movement direction is never colour alone: every up/down/flat state pairs an arrow glyph, an explicit `+`/`-` text sign, and a colour class (`.instr-change.up/.down/.flat`).

## Known follow-ups (for whoever builds M3+)

- `schema.sql`'s `watchlist` table uses named typed columns (symbol, label, asset_class, sort_order) per the packet's data contract, not the starter's generic `{id, data jsonb, updated_at}` row shape. The client's `sbBatchUpsert`/`sbFetchAll` in `index.html` still assume the generic shape for every table in `TABLES`. Reconcile one way or the other before wiring real sync
- No Supabase project exists yet, `SB_DIRECT_URL` stays empty until one is created
- `kjr-calendar.js` and `kjr-sortable.js` are vendored in `lib/` (matching the starter's standard set) but not `<script src>`-loaded, nothing in M0-M2 needs them yet

## Files

- `index.html`, the whole app
- `tokens.css`, the design system
- `sw.js`, offline shell cache, bump `CACHE` on every ship
- `manifest.webmanifest`, whale icons, PWA install
- `schema.sql`, the `watchlist` table and RLS options, not yet applied anywhere (no project)
- `lib/kjr-format.js`, vendored, loaded (uid/esc helpers). `lib/kjr-calendar.js`, `lib/kjr-sortable.js`, vendored but unused so far. `lib/lexend.woff2`, the self-hosted font
- `qc.sh`, static QC (syntax, style discipline, version consistency, duplicate ids), adapted from the starter's copy: no `workbench.html` in this project, so every check runs against `index.html` only

## Version badge

`APP.version` drives the topbar pill. Bump it in the same edit as any change, match it to the commit message.

## Preview

No project-local `.claude/launch.json`, that file is gitignored per-project and this app has nothing else to configure. A `macro` entry lives in the shared root `Claude Projects/.claude/launch.json` (`python3 -m http.server 8792 --directory Kujira/Macro`) for local preview via the Browser pane tooling.

## Hosting

Not deployed. No Supabase project, no remote, no push yet, all local.
