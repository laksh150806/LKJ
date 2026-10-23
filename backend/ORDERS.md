# Order requests, quotes and stock

The owner chose home delivery or shop pickup, mandatory checkout address for both, no payment/ETA on initial request, admin accept/reject, a shop-issued final quote, 20% online advance and 80% due on delivery/pickup. This release implements requests, quotes, agreement and stock holds. **It does not collect payments or mark requests as paid/confirmed.**

## Flow

1. Guests browse; verified sign-in and preferred name are required at checkout. Customer supplies name, Indian mobile, street address, city, state, PIN for either fulfilment option. Address/contact are private to that customer and the sole admin. No personal address is stored in localStorage.
2. `submit_order_request` computes an estimated jewellery subtotal from server-side product weight, shop charge and current verified rates. It snapshots the product/name/weight/quantity/rate and contact address. GST, delivery, final total and ETA are only provided with the later quote. Sample products are rejected. Rate failures/staleness block new estimates; no client total is trusted. Requests do not hold stock.
3. Admin opens Manage shop → Order requests. Stock quantity is editable under Edit jewellery. Existing products start at zero (unknown stock is not assumed available). Admin checks physical availability, then accepts with jewellery amount, GST amount, delivery (zero for pickup), expected date, expiry and cancellation/refund terms. The default validity is 24 hours, editable up to seven days; dates/times are interpreted in IST.
4. Quote creates an immutable history row. Total, rounded 20% advance and remaining 80% are calculated server-side. Requested quantities are held until quote expiry while status is quoted/agreed. Stock row locks and reserved-quantity checks prevent accepting overlapping quotes beyond physical stock. Lowering/deleting reserved stock is blocked. Expired or cancelled/rejected quotes release holds by predicate, without waiting for a cleanup job.
5. Customer reviews the exact quote and terms, then agrees. Agreement is version-checked and expires server-side. A revised quote resets agreement. Unpaid requests may be cancelled without charge. Admin rejection requires a visible reason. Customers use My orders to refresh and view responses; no email/WhatsApp notifications are sent by this release.
6. Advance payment button stays disabled and clearly states it is not connected. There is no paid, dispatched or completed transition yet. A customer agreement never counts as payment. Expected fulfilment dates assume timely advance payment.

## Terms

Request terms version `request-v1` is stored with each request. Customer agreement timestamp and current quote ID are recorded; each quote preserves its terms. Default quote terms allow free cancellation before paying, require explanation/agreement on any later deductions before payment, promise full advance refund if the shop cannot fulfil, retain no bargaining/no change-of-mind return wording and permit appropriate proof for defects/wrong items. Admin must review/edit these terms before issuing a quote. A payment integration must present final terms before collecting money and define the refund process/timeframe.

## Access and limits

Apply orders-schema.sql after existing auth, inventory and live-rate migrations. It adds stock_quantity to jewellery and its public view; public users can read catalogue stock but only admin can change it. order_requests/order_quotes use RLS and grant authenticated SELECT only. Browser INSERT/UPDATE/DELETE are forbidden. The three SECURITY DEFINER RPCs use empty search_path and explicit verified-user/admin/ownership checks. Admin identity is still the server-controlled singleton. Anonymous RPC execution is revoked. Requests use per-customer UUID idempotency keys and a per-user transaction lock; 20 requests/day, max50 different pieces/request, quantity1–10 each. Lists are paginated by 12 with stable ordering.

Security advisor deliberately flags authenticated SECURITY DEFINER RPCs: these are the validated write boundary (direct table writes denied). Reviewed against https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable . The pre-existing unused-password warning remains: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

## Verification

`npm test` covers list pagination, IST expiry display, unpaid status and safe errors plus existing inventory/auth/rate tests. `backend/verify-orders.sql` uses rollback-only synthetic verified users and stock to exercise address/terms validation, server-side estimates, idempotency, customer isolation, admin quote totals, stock holds, stale/expired agreement, cancellation release, direct write denial and anonymous denial. No test emails, paid orders or user-owned products are created. Browser QA uses mocked auth/API for customer→admin→customer flow; actual server permissions and computations are tested by SQL separately.

## Before payment launch

Add a real gateway with signed webhook verification, server-created payment amounts bound to exact unexpired quote ID/version, idempotent webhook handling, payment-failure/refund processing and durable paid stock reservations. Online payment must lock the current request/stock against quote revision, expiry and cancellation. Replace the current unpaid-only response state machine with explicitly tested paid fulfilment/refund transitions. Never enable a client-side “mark paid” control. Verify delivery/pickup balance collection and actual stock adjustments. No courier API is connected.
