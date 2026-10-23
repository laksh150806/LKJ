# L K Jewellers working instructions

## Repository sync — explicit owner preference

- Canonical user repository: https://github.com/laksh150806/LKJ (branch `main`, local remote `github`).
- The owner explicitly requested that all subsequent work be synced to LKJ promptly. After each coherent, checked change, commit and push to `github/main` before completing the turn. This is standing authorization; no repeated confirmation is needed for ordinary changes within the requested scope.
- Fetch and inspect the current remote before pushing. Preserve other contributors' changes and never force-push or rewrite remote history. If protected-branch rules prevent a direct push, push a branch and prepare a PR; report the pending merge.
- Keep the existing Sites `origin` remote and `.openai/hosting.json` identity intact. GitHub sync and Sites publication are separate actions. Publish website changes with the Sites workflow, and also sync the same completed source to LKJ.
- Do not claim unattended synchronization outside an active work session. If pushing fails, report what remains local.
- Include source, built static assets, dependency lockfiles, database schema scripts, tests and setup documentation. Exclude credentials, private keys, SMTP keys, environment secrets, user records, logs, node_modules and temporary screenshots. The Supabase publishable client key is public by design.

## Current boundaries

- Sole admin email: lkjewellers1234@gmail.com. Authorization comes from the server-controlled singleton `shop_private.admin_account`, never editable user metadata or a client-side email check.
- Supabase project: pjwhuowljtglrtjxmuzj. Preserve row-level security and customer isolation.
- Real email sign-in, profiles, shared inventory and image storage are connected. Product reads are paginated and writes require the sole admin through database RLS. Old browser catalogue data is importable without deleting its backup. Production payments, live rate feeds and delivery are still outstanding; ordering remains closed. See backend/INVENTORY.md.
- Follow the user's preference for one step at a time when guiding them through external dashboard setup.
