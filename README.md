# Empire Flippers → Postgres → HubSpot / Google Sheets (Rails)

**End-to-end flow**

1. **Empire Flippers API** — “For Sale” listings (paginated, ~1 req/sec).
2. **PostgreSQL** — upserted into `listings` (`SyncListingsService`).
3. **Listing export** — `ListingExport::Orchestrator` runs **enabled connectors** (env-driven):
   - **HubSpot** — pending For Sale rows → deals (`SyncHubspotDealsService`).
   - **Google Sheets** — with `GOOGLE_SHEETS_SPREADSHEET_ID` set, **clears and rewrites** the same tab each sync (`GOOGLE_SHEETS_TAB_NAME` or `GOOGLE_SHEETS_SHEET_NAME_PREFIX`, default **Listings**). Without an ID, creates a **new** spreadsheet each run. Columns: **Listing #**, **Listing Price**, **Summary**.
4. **Automation** — `DailySyncJob`: step 2, then step 3. **sidekiq-scheduler** + [`config/sidekiq.yml`](config/sidekiq.yml) (default **09:00 UTC**). **Sidekiq** needs Redis.

---

## Run with Docker (everything)

```bash
cp .env.example .env          # HUBSPOT_API_KEY; optional Google vars
docker compose build
docker compose up
```

- **App:** http://localhost:3000  
- **Postgres / Redis:** localhost `5432` / `6379`  
- **Logs:** `docker compose logs -f web sidekiq`  

Useful:

```bash
docker compose run --rm web bin/rails empire_flippers:daily_sync_async
docker compose run --rm web bin/rails empire_flippers:fetch_listings
docker compose run --rm web bin/rails empire_flippers:sync_destinations   # connectors only
docker compose run --rm web bin/rails empire_flippers:sync_google_sheets   # Google Sheets only
```

After **Gemfile** changes: `docker compose build` again. Dev image: [`docker/development/Dockerfile`](docker/development/Dockerfile).

---

## Run locally (Ruby on host)

```bash
docker compose up -d postgres redis
cp .env.example .env
bundle install
bin/rails db:create db:migrate
```

**Sidekiq**

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

**Rake tasks**

| Command | What it does |
|--------|----------------|
| `bin/rails empire_flippers:fetch_listings` | EF API → Postgres |
| `bin/rails empire_flippers:sync_hubspot` | HubSpot only (same service the connector uses) |
| `bin/rails empire_flippers:sync_destinations` | Orchestrator (HubSpot + Google Sheets if enabled) |
| `bin/rails empire_flippers:sync_google_sheets` | Google Sheets only (DB → sheet; needs Google env) |
| `bin/rails empire_flippers:daily_sync` | EF → Postgres → orchestrator |
| `bin/rails empire_flippers:daily_sync_async` | Enqueue `DailySyncJob` |

---

## Check credentials (EF / HubSpot / Google)

Uses your **`.env`** (via dotenv-rails). Nothing secret is printed—only `ok` / `skip` / `error` and a short message.

```bash
bin/rails empire_flippers:check_credentials
```

**HTTP (development only):** with the app running,

```bash
curl -s http://localhost:3000/integration_check | jq
```

Production returns **404** for that path.

---

## Common developer tasks

### Run tests

1. Start Postgres (e.g. `docker compose up -d postgres`).
2. Point Rails at it (local example): `export POSTGRES_HOST=127.0.0.1 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres`
3. Prepare test DB once: `bin/rails db:test:prepare`
4. Run: `bundle exec rspec`

**Docker:** `docker compose run --rm web bin/rails db:test:prepare` then `docker compose run --rm web bundle exec rspec` (Compose already sets `POSTGRES_HOST` for `web`).

### Sync to HubSpot

1. Set **`HUBSPOT_API_KEY`** in `.env`.
2. Ensure **`listings`** rows exist (`bin/rails empire_flippers:fetch_listings` if you need fresh data).
3. Run: **`bin/rails empire_flippers:sync_hubspot`** (pushes pending For Sale listings to HubSpot as deals).

**Docker:** `docker compose run --rm web bin/rails empire_flippers:sync_hubspot`

### Sync to Google Sheets

1. Set **`GOOGLE_SHEETS_SYNC_ENABLED=true`** and **`GOOGLE_SERVICE_ACCOUNT_JSON`** or **`GOOGLE_SERVICE_ACCOUNT_JSON_BASE64`** in `.env`.
2. Set **`GOOGLE_SHEETS_SPREADSHEET_ID`** (ID or URL) and share that file with **`client_email`** as **Editor** (same sheet is overwritten each sync).
3. Optional: **`GOOGLE_SHEETS_TAB_NAME`** (tab to clear/write); if unset, **`GOOGLE_SHEETS_SHEET_NAME_PREFIX`** or **Listings** is used. The tab is created once if missing.
4. Ensure **`listings`** rows exist (`bin/rails empire_flippers:fetch_listings` if needed).
5. Run: **`bin/rails empire_flippers:sync_google_sheets`**

**Docker:** `docker compose run --rm web bin/rails empire_flippers:sync_google_sheets`

---

## Google Sheets (optional)

Service account JSON in **`.env`** (`GOOGLE_SERVICE_ACCOUNT_JSON_BASE64` or `GOOGLE_SERVICE_ACCOUNT_JSON`), `GOOGLE_SHEETS_SYNC_ENABLED=true`.

- **With** `GOOGLE_SHEETS_SPREADSHEET_ID` (ID or URL): each sync **clears** columns `A:ZZ` on the target tab and writes fresh rows from the DB (same spreadsheet every time). Target tab: `GOOGLE_SHEETS_TAB_NAME`, else `GOOGLE_SHEETS_SHEET_NAME_PREFIX`, else **Listings**. Share the file with **`client_email`** as **Editor**.
- **Without** `GOOGLE_SHEETS_SPREADSHEET_ID`: creates a **new** spreadsheet each run (often blocked by org policy; prefer a shared file + ID).

**403 PERMISSION_DENIED** on create: use a shared spreadsheet + `GOOGLE_SHEETS_SPREADSHEET_ID`. See [Sheets API concepts](https://developers.google.com/workspace/sheets/api/guides/concepts).

---

## HubSpot

Private app with **CRM deal read/create** → `HUBSPOT_API_KEY` in `.env`. See **Sync to HubSpot** above.

---

## Layout

| Path | Role |
|------|------|
| `app/utils/empire_flippers/listings_client.rb` | EF HTTP client |
| `app/utils/hub_spot/deals_client.rb` | HubSpot Deals API |
| `app/services/empire_flippers/sync_listings_service.rb` | Upsert listings |
| `app/services/hub_spot/sync_hubspot_deals_service.rb` | Listings → HubSpot deals |
| `app/services/listing_export/orchestrator.rb` | Runs enabled connectors |
| `app/services/listing_export/google_sheets_connector.rb` | Sheets API export |
| `app/services/listing_export/hubspot_deals_connector.rb` | HubSpot connector |
| `app/workers/daily_sync_job.rb` | Sidekiq entrypoint |
| `config/sidekiq.yml` | Queues + cron |
