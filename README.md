# Empire Flippers → Postgres → HubSpot (Rails)

**End-to-end flow**

1. **Empire Flippers API** — “For Sale” listings (paginated, ~1 req/sec).
2. **PostgreSQL** — upserted into `listings` (`SyncListingsService`).
3. **HubSpot** — each For Sale row without `hubspot_deal_id` becomes a Deal (`SyncHubspotDealsService`). Duplicates avoided by stored id + matching deal name before create.
4. **Automation** — `DailySyncJob` runs steps 2–3. **sidekiq-scheduler** triggers it on a **cron** in [`config/sidekiq.yml`](config/sidekiq.yml) (default **09:00 UTC**). **Sidekiq** needs Redis.

---

## Run with Docker (everything)

```bash
cp .env.example .env          # add HUBSPOT_API_KEY
docker compose build
docker compose up
```

- **App:** http://localhost:3000  
- **Postgres / Redis:** localhost `5432` / `6379`  
- **Logs:** `docker compose logs -f web sidekiq`  

Useful:

```bash
docker compose run --rm web bin/rails empire_flippers:daily_sync_async   # queue job
docker compose run --rm web bin/rails empire_flippers:fetch_listings      # EF → DB only
```

After **Gemfile** changes: `docker compose build` again. Dev image: [`docker/development/Dockerfile`](docker/development/Dockerfile).

---

## Run locally (Ruby on host)

```bash
docker compose up -d postgres redis    # or install Postgres + Redis yourself
cp .env.example .env                   # HUBSPOT_API_KEY, POSTGRES_HOST=127.0.0.1, REDIS_URL
bundle install
bin/rails db:create db:migrate
```

**Sidekiq + scheduler**

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

**Rake tasks**

| Command | What it does |
|--------|----------------|
| `bin/rails empire_flippers:fetch_listings` | EF API → Postgres |
| `bin/rails empire_flippers:sync_hubspot` | Pending rows → HubSpot |
| `bin/rails empire_flippers:daily_sync` | Both steps, in this process |
| `bin/rails empire_flippers:daily_sync_async` | Enqueue `DailySyncJob` (needs Sidekiq) |

---

## Tests

Postgres must be running for the test database (e.g. `docker compose up -d postgres`).

```bash
export POSTGRES_HOST=127.0.0.1 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres
bin/rails db:test:prepare
bundle exec rspec
```

Same idea as [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (`DATABASE_URL` for CI).

---

## HubSpot

Create a [private app](https://developers.hubspot.com/) with **CRM deal read/create**, put the token in **`.env`** as `HUBSPOT_API_KEY`.

---

## Layout

| Path | Role |
|------|------|
| `app/utils/empire_flippers/listings_client.rb` | EF HTTP client |
| `app/utils/hub_spot/deals_client.rb` | HubSpot Deals API client |
| `app/services/empire_flippers/sync_listings_service.rb` | Upsert listings |
| `app/services/hub_spot/sync_hubspot_deals_service.rb` | Listings → deals |
| `app/workers/daily_sync_job.rb` | Sidekiq entrypoint |
| `config/sidekiq.yml` | Queues + cron |
