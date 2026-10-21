# L K Jewellers — private design preview

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

## Automatic category pictures

Category covers are independent of product images. Names for pendants/lockets/chains/necklaces/chokers, earrings/hoops/studs/jhumkas, rings/bands, and bangles/bracelets select from the bundled illustrative photo library, including common singular/plural forms and some Tamil names. Existing empty categories receive a cover without any data reset. Unknown names use a photo from that category when available, otherwise a general jewellery cover; the admin preview explains when there is no name match. This is curated local matching, not an AI generator or a live image search.

Admins can preview automatic covers while naming a category, choose another library image, upload a custom cover, or restore automatic selection. Custom covers persist separately by metal/category, survive renaming, and are removed with their category. Individual product photos are unchanged. As elsewhere in this preview, uploads and category changes are browser-local.
