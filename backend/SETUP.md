## Admin assignment — 22 October 2026

Verified `lkjewellers1234@gmail.com` has been assigned as the sole admin in `shop_private.admin_account`. The frontend now uses the server-controlled access result and shows Manage shop. Catalogue management is still browser-local and is labelled accordingly; profile data and admin authorization use Supabase. Earlier unassigned/locked notes below describe setup history.

## Activation update — 22 October 2026

Owner confirmed Brevo sender verification, saved custom SMTP, and saved the OTP template. Email-code sign-in is enabled on the private site for the owner to test live delivery. Delivery and end-to-end sign-in are not yet confirmed. The designated sole admin email is `lkjewellers1234@gmail.com`; assign its verified Auth user ID only after successful sign-in. No admin assignment has been made yet.

# L K Jewellers authentication deployment

Project: `pjwhuowljtglrtjxmuzj` (Mumbai), organisation `Laksh Projects`.

Implemented: Supabase verified-email sessions, database-backed preferred names, row-level security, singleton admin account reservation, session restoration/sign-out, and bundled/pinned SDK. No admin is assigned. Previous browser-local roles are ignored. Catalogue administration remains disabled until production catalogue persistence is implemented. The earlier local orders are never shown as customer orders.

## Email delivery: required owner setup

The available Supabase connector can create projects and database schemas, but has no tool for configuring Auth SMTP or Google OAuth. No SMTP or Google credentials were supplied. Default SMTP is for authorised team addresses only; it cannot support general customer sign-in. The runtime flag `emailOtpEnabled` is intentionally false until delivery is verified.

1. Configure a transactional sender in [Supabase SMTP settings](https://supabase.com/dashboard/project/pjwhuowljtglrtjxmuzj/auth/smtp), using the provider's host, port, username, password and verified sender. Enter secrets directly in that dashboard, never in chat or frontend code. No email service has been purchased.
2. In [Email templates](https://supabase.com/dashboard/project/pjwhuowljtglrtjxmuzj/auth/templates), replace the Magic Link body with `otp-email.html`. It uses `{{ .Token }}` to deliver an entered code. Custom SMTP is required before template customisation on new Free projects.
3. Keep email confirmation enabled and set an appropriate short OTP expiry in the email provider settings. Configure production rate limits and CAPTCHA before opening unrestricted public registrations.
4. Test a code with an owner-designated address, verify the saved profile, sign out and sign in again. Invalid/expired codes must not establish a session. No live emails were sent during implementation.
5. Set `dist/auth-config.js` `emailOtpEnabled: true` only after delivery works, then publish the changed artifact.

Google login is optional and not configured. It would need the shop's Google OAuth client and secret entered directly into Supabase.

## Sole admin

Wait for the user's explicit admin email. After that account verifies its email, verify `auth.users.id` and insert that UUID into `shop_private.admin_account` through the trusted database connection. Do not copy frontend metadata into this table. The singleton constraint prevents two admins; customers have no write privileges. Never use the first signup or the project's owner email as an implicit admin.

## Hosting and commerce boundaries

The existing `chatgpt.site` is still owner-private; its outer ChatGPT access gate has not changed. Supabase account code does not replace or bypass that platform gate. Use an external public static host for the production shop with conventional customer authentication. The files in `dist/` are portable; configure the final site URL in Supabase before launch. No new public hosting or domain was created.

This is authentication preparation, not a sales launch. Products/photos/rates are still labelled illustrative and remain browser-local. No order creation or payment collection is available. Remaining production work includes database catalogue and image storage, verified rates/server-side quotes, payments/webhooks, delivery and policies. Do not remove illustrative price notices until real inventory and rates replace them.

## Verification

`npm ci && npm run build:auth && npm test` rebuilds the pinned browser bundle and checks validation/error handling.

`verify-access.sql` was executed against the project in a transaction that rolls back its temporary test accounts. It checks self-only profile writes, denial of cross-user reads/inserts/ownership transfer, and denial of admin elevation via user metadata. The Supabase security advisor returned no findings after the explicit private-table deny policy.

Browser QA uses intercepted Auth responses to exercise form errors, verified-session handling, saved preferred names, checkout continuation, reload and sign-out. This is not evidence that production email delivery works.
