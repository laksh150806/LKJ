# Shared catalogue (23 October 2026)

Categories, product records and indicative shop settings now live in Supabase project `pjwhuowljtglrtjxmuzj`. Uploaded category/product images live in the public `jewellery-images` Storage bucket. These images are public catalogue content; never upload customer identity or payment documents to this bucket.

## Access and schema

`inventory-schema.sql` records the deployed `shared_inventory_and_photos` migration. Guests and customers may read catalogue data. Only the verified sole-admin identity selected by `shop_private.is_admin()` may insert/update/delete categories or jewellery, change shop settings, or upload/remove images. No client secret/service key is used. Settings cannot be deleted through the customer API. Views use `security_invoker=true`; their underlying tables enforce RLS.

A category containing products cannot be deleted. Renaming a category cascades to its pieces. Database-managed version numbers reject stale edits from another tab/device. Product lists use database filtering, price sorting, stable ordering and 12-row pages. Only visible pieces, an opened detail and bag pieces are retained in browser memory. Category counts are database-derived. Fresh page loads/focus and catalogue writes refresh shared metadata; product navigation fetches current rows. This is not a WebSocket live-update subscription.

## Photos

Up to eight JPEG/PNG/WebP images per product. Images are compressed to at most 900px on the long side before upload. Storage caps each uploaded object at 5 MiB. Paths use generated UUIDs, and URLs are immutable. The first entry is the main image; changing its position persists the photo order online.

A failed upload batch removes its newly uploaded, unreferenced files where possible. After a definitive rejected database write, newly uploaded photos are cleaned up. A lost database response may follow a committed write, so images are retained when the outcome is uncertain. Previously saved images removed from a product are retained in Storage to avoid breaking reused references; storage cleanup is a separate maintenance task.

Keyword category searches run only for the admin after creating a category or explicitly searching. The selected image URL and licence attribution are persisted in the category record. Visitors do not run searches or write covers. Uploaded covers use Storage. A failed/no-match search never substitutes a generic picture.

## Earlier browser data

The previous `lk-preview-v1` data is kept unchanged. In Manage shop, **Import old browser catalogue** shows the saved items for review. Earlier built-in samples are unselected by default and retain an illustrative marker if deliberately imported. Custom pieces are selected by default. Import preserves existing shared products/covers, uploads selected images, and uses unique legacy IDs to skip already imported pieces on retry. Accounts, local demo orders and rates are never imported. If an import stops, completed records remain and retry resumes by skipping them. The shared catalogue was not seeded with the six sample products.

The shopping bag remains local to the device under `lk-bag-v2`; it stores only product IDs and quantities. On opening it, current product data is fetched and deleted pieces are removed.

## Validation and remaining boundaries

- `verify-inventory.sql` ran against the real database inside a rolled-back transaction: admin CRUD, category rename/restrict-delete, optimistic concurrency, guest reads, and denied customer/guest writes.
- Unit tests cover bounded pagination, escaped search terms, version conflicts, error mapping, and photo cleanup on failed/uncertain writes.
- Live anonymous browser checks exercised the real Supabase category/product endpoints and mobile/deep-link navigation.
- Browser checks with intercepted Auth/Storage/API responses exercised two isolated admin/guest contexts, category cover upload, multi-photo ordering, product create/edit/delete, stale writes and retryable import. No real admin session was available in the execution environment, so an authenticated production photo upload still needs the owner's first use.
- Security advisor found no catalogue/RLS warnings. It reported the existing [leaked-password protection setting](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); this application uses email OTP rather than passwords.

Live Chennai rates now refresh automatically every five minutes; see LIVE-RATES.md. Server-validated checkout quotes, payment webhooks and delivery remain unconnected. Orders stay closed. Admin can edit GST/delivery while automatic metal rates are maintained by the private scheduler. The website's existing owner-private Sites sharing is unchanged.
