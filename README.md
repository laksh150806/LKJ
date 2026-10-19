# L K Jewellers — private design preview

Buildless static storefront: serve `dist/` with a static HTTP server.

Includes customer/admin demo views, gold/silver catalogue, search/filter/sort, jewellery photo gallery with swipe and zoom, local admin CRUD, multi-photo upload/reordering/main image selection, per-piece fixed/per-gram/percentage shop charges, sample metal-rate settings, bag and demo checkout with GST/delivery/pickup and local orders.

**Not production commerce.** Demo role switching is not authentication. All state is local to each browser. No real personal/payment details should be entered. Real authentication, a server-side single-admin-email allowlist, database and image storage, a verified purity-specific rate API with freshness checks and IST timestamps, server-side price quotes, payment gateway with signed webhooks, shipping integrations, and confirmed policies are required before accepting real sales. Never promote these client-side controls to real authorization or accept totals from the browser.

Demo rates are invented and clearly labelled. Illustrative photos are from Unsplash; they are not shop inventory. Sample GST and delivery are configurable demonstrations, not confirmed business or tax settings. The Maps link is a search for the user-supplied shop name/location, not a verified place record.

Photo sources:
- https://unsplash.com/photos/1617038260897-41a1f14a8ca0 (image CDN ID)
- https://images.unsplash.com/photo-1605100804763-247f67b3557e
- https://images.unsplash.com/photo-1599643477877-530eb83abc8e
- https://images.unsplash.com/photo-1611591437281-460bfbe1220a
