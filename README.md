# L K Jewellers

## Current status

Real Supabase email-code sign-in, preferred-name profiles, sole-admin authorization, shared categories/jewellery/settings and photo storage are connected. The verified shop email is the only admin. Product lists load 12 records per page; editing uses database version checks. Previous browser catalogue data can be reviewed and imported from Manage shop without deleting its backup.

See [shared inventory](backend/INVENTORY.md) for database changes, import behaviour and verification, and [authentication setup](backend/SETUP.md) for the earlier setup history. Online orders, payments, live metal rates and delivery are not yet connected. The existing Sites website is still owner-private. Initial prices are sample estimates; manually edited rates are labelled as shop-entered.

Build/check with `npm ci`, `npm run build:auth`, and `npm test`. Serve `dist/` as a static site. Supabase client settings use a public publishable key; no backend secrets belong in the repository.

## Original catalogue preview

Buildless static storefront: serve `dist/` with a static HTTP server.

Includes customer/admin demo views, gold/silver catalogue, search/filter/sort, jewellery photo gallery with swipe and zoom, local admin CRUD, multi-photo upload/reordering/main image selection, per-piece fixed/per-gram/percentage shop charges, sample metal-rate settings, bag and demo checkout with GST/delivery/pickup and local orders.

**Not production commerce.** Demo role switching is not authentication. All state is local to each browser. No real personal/payment details should be entered. Real authentication, a server-side single-admin-email allowlist, database and image storage, a verified purity-specific rate API with freshness checks and IST timestamps, server-side price quotes, payment gateway with signed webhooks, shipping integrations, and confirmed policies are required before accepting real sales. Never promote these client-side controls to real authorization or accept totals from the browser.

Demo rates are invented and clearly labelled. Illustrative photos are from Unsplash; they are not shop inventory. Sample GST and delivery are configurable demonstrations, not confirmed business or tax settings. The full shop address matches the Google Maps screenshot supplied by the user. The Maps link searches the shop name plus that full address; no exact Place ID has been verified. The displayed contact number +91 98407 63243 is supplied directly by the user and replaces the landline visible in their screenshot.

Photo sources:
- https://unsplash.com/photos/1617038260897-41a1f14a8ca0 (image CDN ID)
- https://images.unsplash.com/photo-1605100804763-247f67b3557e
- https://images.unsplash.com/photo-1599643477877-530eb83abc8e
- https://images.unsplash.com/photo-1611591437281-460bfbe1220a

## Navigation update

The home screen now contains Gold and Silver selection cards and shop/policy details. Each metal opens a dedicated category screen; each category opens its own product catalogue with 12 items per page and lazy image loading. Breadcrumbs, Back and Home controls, and browser history support navigation. Search, sort, page and scroll are retained in memory when returning to a screen during the current visit. Product details retain photo galleries and ordering controls. Admin category controls live on category screens; jewellery creation defaults to the current category.

Pagination currently limits rendered products in this browser-local demo. A production database should also paginate data and image retrieval on the server; local demo storage is not a scalable inventory backend.

## Keyword category-image search

The previous fixed photo-library matching and generic necklace fallback have been removed. New empty categories now perform actual browser-side Wikimedia Commons API searches using the category name and selected metal. Existing product photos and deliberately uploaded category covers are preserved. Existing empty categories such as Pendant and Dollars are searched when their category screen opens.

The search requests bitmap photos with image metadata, filters unrelated currency/medal imagery, requires category terms and an eligible open license, and ranks candidates. The first candidate is selected automatically. Admins can inspect the source/attribution, choose another returned image, refine the search words, or upload their own cover. Source, creator and license credits are displayed for searched covers. Results are cached in browser-local storage. No image-search secret is required for this provider.

Dollar/Dollars is interpreted as jewellery by adding pendant/Indian jewellery context. **The exact Dollar search returned no suitable image in live testing. It now displays no match; it does not substitute thali or a generic necklace.** Free Commons results can be historical and coverage of specific Indian jewellery is limited. A broader licensed image-search API is still needed for reliable coverage of those designs; no such credentials are configured. This is actual keyword retrieval, not an AI generator or an unrestricted Google Images integration.

Live browser checks verified API requests and a loaded Pendant result, no unrelated Dollar fallback, selecting another result, cache persistence, custom query search, custom upload, and mobile layout. Existing demo storage/security/payment limitations still apply.

## Repository and ongoing sync

The project is synced to [laksh150806/LKJ](https://github.com/laksh150806/LKJ). The owner requested prompt GitHub sync after each completed change; this standing instruction is recorded in [AGENTS.md](AGENTS.md). The Sites hosting remote stays separate from the `github` remote. Source control includes the implementation and setup scripts, not live Supabase customer records or SMTP credentials.

## Automatic metal rates (current)

Live Chennai 22K/18K gold and silver rates are now fetched server-side every five minutes; active pages refresh once a minute. No customer login is needed to see them. Rates show source timestamps in IST and warn on failed/stale updates. Silver uses the listed rate directly as requested. See [backend/LIVE-RATES.md](backend/LIVE-RATES.md) for source URLs, setup, security and failure behavior. This supersedes earlier preview notes about manual/sample metal rates. Payments, accepted orders and delivery integration remain outstanding.

## Request-first checkout (current)

Customers can request delivery or pickup after verified sign-in, with a mandatory address for either option. Admin checks stock and accepts with a final quote or rejects with a reason. Quotes include charges, expected date, editable validity and cancellation terms; customers can agree or cancel before payment. The split is 20% advance / 80% on delivery or pickup. **Payment collection is not enabled yet.** See [backend/ORDERS.md](backend/ORDERS.md) for the implemented workflow, schema, access controls and verification. This supersedes earlier notes that ordering is entirely closed.

The shop works with made-to-order designs: there are no stock or quantity controls and no inventory-based acceptance restrictions. Admin supplies the final quote and expected date, including making time. The receive-order choices are “Deliver to my address” and “Collect from shop”.
