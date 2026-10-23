# Automatic Live Chennai rates

Enabled on 23 October 2026. The private Supabase Cron job `lk-livechennai-rates` calls `sync-metal-rates` every five minutes, including when the website is closed. It fetches the source HTML afresh each time, validates labelled rate tables, dates, timestamps and per-gram/multiple-gram totals, then atomically updates shared settings. No current price is hardcoded in the application.

Sources:
- https://www.livechennai.com/gold_silverrate.asp : 22K gold and silver per gram.
- https://www.livechennai.com/18k_goldrate_chennai.asp : 18K gold per gram.

The owner explicitly chose the listed silver rate directly, also for 925 jewellery. No 0.925 multiplier is applied. Product price remains weight × applicable rate + configured shop charge. GST and delivery remain separate estimates; orders and payments are closed.

## Freshness and failure behavior

The browser re-reads shared metadata every minute while visible and when returning to the tab. Current catalogue, rate dialog, product detail and bag prices refresh. Source publication timestamps and successful fetch time are distinct and shown in IST. Typical update latency is up to five minutes plus the browser's one-minute refresh, not instantaneous market streaming.

A failed request, malformed page, changed columns, bad totals, future timestamp, timestamp regression or source data older than 72 hours does not replace last verified prices. The worker records a failure indicator. A successful fetch more than 15 minutes old displays CHECK DELAYED; a source publication older than 36 hours displays OLDER SOURCE RATES. These remain indicative prices. A future order implementation must validate current server-side rates and lock a quote before taking payment; never accept browser totals.

This integration parses public HTML, not a contracted API or webhook. Source layout/access changes require maintenance; stale warnings remain until successful recovery. The job retries automatically on the next scheduled run.

## Security and operations

`backend/live-rates-schema.sql` is the applied migration, after inventory-schema.sql. The cron token is generated inside Postgres and stored in Vault (`lk_rate_job_token`), never in the repository/client. JWT gateway verification is disabled only because the function performs its own private job-token authentication via the service-role-only `authorize_rate_job` RPC. The service-role key comes from Supabase's server environment. Invalid/missing tokens receive 401. Browser roles cannot execute that RPC or change source values/timestamps. Admin RLS still controls GST/delivery edits. No user inputs can choose the fetched URL or prices.

Inspect `cron.job`, `cron.job_run_details`, `net._http_response`, and `shop_settings.rate_checked_at/rate_sync_error` for health. Avoid selecting Vault secret values into logs. Schedule: `*/5 * * * *` (UTC; every five minutes equally in IST). Deploy the two files in backend/functions/sync-metal-rates with index.ts as entrypoint.

Tests: `npm test` covers source parsing, unit checks, freshness failures and changes in prices. `backend/verify-inventory.sql` checks RLS with rollback. Browser QA exercised real anonymous reads, IST display and automatic open-dialog price updates with a simulated changed response. Live worker fetch and scheduled run were verified separately.
