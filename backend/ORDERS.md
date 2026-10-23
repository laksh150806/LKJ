# Made-to-order requests and quotes

The shop displays designs that can be supplied or made to order. There is **no stock management, quantity selector, reservation or inventory-based acceptance restriction**. The owner reviews each request and supplies the final price and expected date, including making time.

## Customer and admin flow

1. Guests browse designs and add each design once to their bag. Repeat adds do not increase a quantity. Existing browser bags are normalised to one entry per design.
2. Verified customers choose **Deliver to my address** or **Collect from shop**. Name, mobile number and full address are mandatory for either choice. These details are private to the customer and sole shop admin.
3. Submission snapshots each selected design and calculates an estimated jewellery subtotal from verified server-side rates, weight and shop charge. No GST/delivery total, payment or expected date is promised at this stage. Requests use one item per design; the compatibility quantity field in request snapshots is always one for new requests, regardless of client input. Sample designs and unavailable/stale rate estimates are rejected.
4. Admin accepts with jewellery amount, GST amount, delivery charge (zero for collection), expected date and cancellation/refund terms, or rejects with a reason. No stock count is checked. Quotes use saved request snapshots, so removal of a catalogue design does not prevent the shop from quoting to make it.
5. Quotes default to 24-hour validity, editable up to seven days, in IST. Server calculates 20% advance and 80% due upon delivery or collection. Each quote is immutable history; a revision resets customer agreement. Expiry applies to price/terms, not stock.
6. Customers review and agree to the quote, or cancel before payment without charge. An expired quote requires renewal. **Online payment remains disabled. Agreement never marks an order paid or confirmed.** Customers check My orders for updates; this release sends no email/WhatsApp notifications.

## Database and security

Apply `orders-schema.sql`, then `made-to-order-schema.sql`. The latter removes the reservation trigger/functions and replaces submit/quote RPCs. An unused legacy stock column remains solely for compatibility with already-open older clients; current application screens do not read or write it.

Orders/quotes are SELECT-only to authenticated clients with customer/admin RLS; anonymous reads and direct browser writes are forbidden. Three SECURITY DEFINER RPCs provide validated writes with empty search_path, explicit identity/ownership/admin checks and version checks. Admin remains the verified singleton account. Quotes, address snapshots and past amounts are preserved. Requests use per-customer UUID idempotency keys and a transaction lock, max20 requests/day and max50 distinct designs/request. Lists paginate by12.

The advisor flag for authenticated SECURITY DEFINER functions is intentional and reviewed: these are the access-controlled RPC write boundary. See https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable . The existing unused-password advisory remains: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

## Terms and payments

Request terms version request-v1 and quote agreement timestamps are recorded. Each quote preserves its cancellation/refund terms. Default terms allow free cancellation before paying, require explanation/agreement on later deductions before payment, full advance refund if the shop cannot fulfil, no bargaining/change-of-mind returns after fulfilment and suitable proof for wrong/defective items. Admin reviews these before issuing a quote.

Before collecting advances, integrate a real gateway with signed webhooks, server-created amounts bound to the exact unexpired quote, idempotent payment processing and refund handling. Test payment races against quote revision, cancellation and expiry. Add explicit paid fulfilment/refund states; never a client-side mark-paid control. Final refund process/timeframe must be shown before payment. No courier API is connected.

## Verification

`npm test` checks existing auth, catalogue and rates plus order pagination, IST expiry and safe errors. `verify-orders.sql` uses rollback-only synthetic users/designs to test private reads, idempotency, required address/terms, server estimates, quantity-input normalisation, zero-stock made-to-order quotes for multiple requests, re-quoting after catalogue removal, precise 20/80 amounts, expired/stale agreement and rejection/cancellation. Browser QA covers required address, renamed choices, absent stock/quantity controls, admin quotes and customer agreement/cancellation. Browser API responses are mocked; server rules are exercised separately with live SQL. No test emails or permanent test orders are created.
