# Render deployment

Public catalogue: https://lk-jewellers.onrender.com
Dashboard: https://dashboard.render.com/static/srv-dbfbu8q9lscs739horcg
Workspace: Laksh's workspace (`tea-daao6grtqb8s73ftloe0`).

Static site `srv-dbfbu8q9lscs739horcg` serves `dist` from GitHub
`laksh150806/LKJ`, branch `main`. Automatic deploys on commit are enabled.
Build: `npm ci && npm test && npm run build:auth && node scripts/copy-photo-runtime.mjs`.
Build environment: `SKIP_INSTALL_DEPS=true`, `NODE_VERSION=22`.
No private credentials are required in Render; Supabase remains the backend.
Hash-based catalogue routes require no SPA path rewrite.

First deployment `dep-dbfbu929lscs739hose0` became live on 2026-10-26,
from commit `bc16bf120858ab9d4ec715e773d70bcaccba526a`.
Existing owner-private Sites preview remains separate and unchanged.
Static hosting uses Render's free offering within workspace bandwidth/build allowances.

Live checks: HTTPS, mobile and desktop guest navigation, Gold/Silver categories,
empty catalogue state, hash route reload/back navigation, hidden admin controls,
Supabase catalogue/settings reads, rates dialog, sign-in form, shop address and policy.
No real OTP email, authenticated admin write, customer order or payment was generated
by these checks. Payments are not connected. The owner must verify email OTP login
and admin access from the new origin; sessions from the old site do not transfer.
Email authentication uses entered OTP codes, not redirect-based login.

The metal-rate scheduler was current at deployment. The upstream 18K quote was older
than 36 hours, so freshness warnings were correctly visible. Order submission remains
subject to the server's rate freshness checks; do not bypass them to launch.
