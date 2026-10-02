# gwppro — Supabase edition

The existing gwppro design and project workflows now use **Supabase PostgreSQL**, **Supabase Auth**, and a private **Supabase Storage** bucket. The app runs on Vinext/Cloudflare using Supabase's HTTPS APIs. There is no D1 or R2 runtime fallback in this edition.

## Connect the project

1. Create or select your Supabase project. Run `supabase/migrations/202610010001_gwppro.sql`, then `202610010002_analytics.sql` `202610010003_hardening.sql` and `202610010004_outreach_recovery.sql` and `202610020005_payments_and_client_access.sql` in its SQL Editor. It creates `gwppro_` tables, access policies, transaction functions and the private `gwppro-files` bucket. It does not insert sample projects or payments.
2. Fill `.env`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `ADMIN_EMAIL`, and `APP_URL`. Legacy `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are supported too. Keep the secret/service role key server-only. Production values must also be added to the hosting environment. For local Cloudflare runtime, copy server values to `.dev.vars`.
3. In Supabase Authentication settings, enable email/password login, disable public user signups, and set a minimum password length of 12. Enable email confirmations. Set Site URL to `APP_URL`, and allow `APP_URL/login` and `APP_URL/auth/callback` as redirects. Configure a working Supabase Auth SMTP sender for password reset emails. The default recovery email works through a PKCE callback when opened in the same browser that requested the reset. Alternatively set the recovery email link to `{{ .SiteURL }}/login#token_hash={{ .TokenHash }}&type=recovery` for cross-browser use; the app verifies this single-use token on password submission. Use your Supabase Auth expiry settings for invitation/recovery links.
4. Import existing data before switching the live app. A D1 export is included under `migration-data/d1-export.json` when supplied with this ZIP. Run `node --env-file=.env scripts/import-supabase.mjs migration-data/d1-export.json`. If there are file records, export the R2 object bytes and pass their directory as the second argument. The importer preserves IDs, timestamps, ownership, payment references, notification read status and object keys. It stops on conflicting existing records. It never copies old passwords or session/invitation tokens. Use an up-to-date final export if records changed after the snapshot.
5. Run `node --env-file=.env scripts/check-supabase.mjs`. Verify counts and account access, then publish with the Supabase environment configured. Keep the previous D1/R2 source until the migration is verified.
6. On the hosted private Site, open `/login` using the verified studio owner's platform identity and choose your studio password. An owner account is created in Supabase Auth; its role is stored in a protected profile. This setup/recovery route does not trust a browser-supplied email or role. If an existing Auth user already uses `ADMIN_EMAIL`, the verified owner can use **Recover studio access**.
For your own Cloudflare host without the Sites owner-verification headers, create and confirm the owner in Supabase Authentication → Users, and configure that exact email as `ADMIN_EMAIL`. A verified owner login receives the protected admin role automatically; `supabase/bootstrap-admin.sql` is also available for manual bootstrap. Sign in normally with that owner’s email/password.

7. Create or import clients, then use **Settings → Manage account → Invite a client**. Share the generated link yourself. Supabase verifies the one-time invite/recovery token and manages passwords and sessions. Existing D1 users must activate new Supabase accounts; previous D1 sessions and links do not carry over. Clients also need access to the private hosted Site. App invitations do not change Site sharing.

No production credentials are included in `.env`; provider fields are templates. The old hosted D1 version remains active until the Supabase project is configured, imported and verified.

## What stays available

- Portfolio and saved services; three-step project inquiries.
- Client directory, project progress, milestones, files and conversations.
- Draft/shared/accepted proposals; atomic proposal acceptance creates a project and deposit invoice. PostgreSQL functions lock the proposal and keep repeated requests idempotent.
- Final invoices calculate the remaining agreement balance, with mixed-currency checks and duplicate protection.
- Stripe hosted checkout requires `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` and `APP_URL`. Only signed webhooks or an authenticated server-side verification can mark Stripe invoices paid. Optional PayPal, bank, Binance and crypto transfer instructions enable manual payments with administrator confirmation.
- Brave discovery, PageSpeed evidence, optional OpenAI drafting, reviewed Resend outreach, suppression and daily sending limits. Configure `BRAVE_API_KEY`, `PAGESPEED_API_KEY`, `OPENAI_API_KEY`, `OPENAI_MODEL`, `RESEND_API_KEY`, and `EMAIL_FROM` for the relevant providers.
- Saved notification inbox and read state in PostgreSQL; encrypted Web Push with `VAPID_PUBLIC_KEY` and server-only `VAPID_PRIVATE_KEY`. Preserve the existing VAPID pair when migrating the same hosted Site and its subscriptions. A separate deployment should use its own matching key pair. Push messages contain only a generic update notice.
- Installable PWA, app badges where supported, and a generic offline screen. The service worker caches icons and the offline screen only; APIs, auth, private HTML and attachments are not cached. On iOS install to the Home Screen before enabling device notifications.

## Security and access

Authentication is managed by Supabase Auth through server-set HttpOnly cookies; middleware refreshes sessions. Authorization verifies the current Auth user and their database profile. Roles never come from user-editable metadata. PostgreSQL Row Level Security lets authenticated clients read only their assigned project records and hides draft proposals. Anonymous readers can see only portfolio/services. Client writes, payments, role changes and transaction functions go through the checked server API. Browser clients cannot directly modify profiles, projects or invoice status. The private file bucket has ownership-based read policies; authenticated file downloads also pass the server's project/email checks.

The server secret bypasses RLS and therefore is never sent to the browser. Never put it in a `NEXT_PUBLIC_` or `VITE_` variable. Old Drizzle/D1 files are retained only as migration history and are not used by the Supabase runtime.

## Routes and verification

`/contact` contact form · `/privacy` data controls · `/` portfolio · `/start-project` inquiry · `/login` Supabase login/setup/activation · `/holyghost` studio · `/portal` client workspace · `/account` password/invitations · `/workspace` role-based entry.

Install with the locked pnpm setup. `node node_modules/typescript/bin/tsc --noEmit` checks types. The Sites build helper produces the Cloudflare Worker. `node checks/supabase-database.mjs` runs the PostgreSQL schema and verifies access policies, role protection, proposal acceptance, final billing, private file access and rate-limit/claim functions against isolated PostgreSQL. `node checks/supabase-routes.mjs` checks server routes against simulated Supabase HTTP responses, not a live project. Target-project smoke checks require your actual Supabase configuration.

## Professional website and visitor analytics

The existing brand now includes light/dark/system theme support, sticky public and workspace headers, a mobile navigation menu, a full footer, contact and privacy pages, process steps and FAQs. Contact messages create real inquiries and notification records; they do not claim an automatic email was sent.

Configure **Settings → Studio profile → Edit business details** with your public email, location and international WhatsApp number. The floating contact button becomes a WhatsApp link when a valid number is configured. `CONTACT_EMAIL` and `WHATSAPP_NUMBER` are optional environment fallbacks. No sample phone number is shipped.

Studio **Analytics** records consenting visits, 30-second visible-page heartbeats, a 90-second live window, visitor/session/page-view totals, observed visit duration, daily trends, pages, devices, referrals, approximate network location and paginated history with CSV export. Choose a rolling 1/7/30/90-day period and Kampala or UTC display time. There are no invented visitors or historical backfills. Anonymous browser identifiers are random; stored identifiers are hashed. Referrals retain only the domain, page paths exclude query strings, and raw IPs are not stored in analytics. DNT/GPC are respected. Retention is 90 days with deletion during subsequent tracking. Report reads require admin access; analytics mutations run only through the server. Current report aggregation reads the selected retained period, so larger traffic deployments should move aggregation to database queries.

Run all six SQL migrations before starting this edition. Missing Supabase configuration shows an access setup screen at `/holyghost`; connect the database before authenticating or sending contact forms. The hosted D1 edition is separate and remains functional until Supabase credentials are supplied.


## Owner setup token (recommended for self-hosting)

Owner **setup/recover** actions require `OWNER_SETUP_TOKEN` in addition to the platform identity headers. If the token is missing, those actions are disabled on every host. Generate a long random token, store it as a server secret and enter it only in the owner setup/recovery form. Existing email/password login continues to work without this token. Never commit or include a real token in source archives. `ADMIN_EMAIL` is now required; there is no built-in fallback address.

## Corrected security release

Apply all six SQL migrations in order. Anonymous contact inquiries preserve the optional phone field (maximum 30 characters), while ownership and role fields remain server-controlled. Outreach uses atomic database merges that preserve concurrent suppression, a per-attempt lease, and a frozen provider payload. Failed calls can retry the same request within 23 hours. A crashed Sending attempt becomes retryable after 60 seconds. After 23 hours, automatic retry is blocked: inspect Resend delivery before deciding whether another email is needed. Accepted provider IDs are saved. Re-drafting is blocked once delivery has been attempted. Suppression cannot recall an email already accepted or in flight.

The pnpm lockfile now matches Next.js 16.3.8. The release-age exception is limited to the exact 16.3.8 Next.js package family; all other releases keep the existing age policy. Run TypeScript, build, database and route checks before deployment. Dependency audits must state whether development dependencies were included.


## Stripe and alternative payment setup

1. Apply migration `202610020005_payments_and_client_access.sql` after migrations 0001–0004. An upgrade SQL file is included as `STRIPE-UPGRADE.sql` (0003–0005, safe to rerun when 0001–0002 already exist). Back up the database before deployment.
2. Set `APP_URL` to your actual Cloudflare public HTTPS domain. In Stripe test mode, copy your `sk_test_...` secret to `STRIPE_SECRET_KEY`. Add it to Cloudflare as a Secret. This hosted Checkout integration does not need a publishable key.
3. Create a Stripe webhook endpoint at `https://YOUR-DOMAIN/api/stripe/webhook`. Subscribe to `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed` and `checkout.session.expired`. Copy that endpoint's `whsec_...` to `STRIPE_WEBHOOK_SECRET` as a Secret. Test and live webhook secrets are different. Keep test/live keys matched and finish pending attempts before changing mode.
4. Enable account-eligible methods in Stripe Dashboard → Payment methods. Checkout selects methods appropriate to the currency and account. PayPal processed by Stripe is limited to supported European/UK accounts. Stablecoin acceptance is available to supported businesses (currently US, with some additional regions in private preview). Binance Pay is not a built-in Stripe method in this integration. Live Stripe acceptance needs a business/account in a supported country; Uganda is not currently listed for direct Stripe merchant accounts. Do not select a fictitious country. See https://stripe.com/global and https://docs.stripe.com/payments/paypal and https://docs.stripe.com/payments/stablecoin-payments for current eligibility.
5. Optional manual alternatives are independent of Stripe. Set `PAYPAL_PAYMENT_INSTRUCTIONS` (recipient PayPal email/payment link and currency), `BANK_PAYMENT_INSTRUCTIONS` (account holder, bank, account/IBAN/SWIFT and currency), `BINANCE_PAYMENT_INSTRUCTIONS` (your Binance Pay ID or recipient and asset), or `CRYPTO_PAYMENT_INSTRUCTIONS` (asset, exact network and receiving address). Blank instructions hide that method. Use your own verified recipient details; no demo accounts or addresses are shipped. Store multiline values in Worker settings, or quote them with literal `\n` in dotenv files. These instructions appear only to signed-in workspace users.
6. Clients open their invoice, choose a method, pay externally and submit the transaction reference/hash. The invoice stays Pending while the payment is Awaiting review. In `/holyghost` → Invoices & Payments → open the invoice → Payment history → Review payment, verify the full received amount/currency in your provider/bank/wallet and confirm, or reject with a reason. No screenshot, client claim or redirect alone grants paid status. Wrong-network transfers and exchange-rate quotes must be handled with the studio before sending funds. Manual PayPal/Binance/crypto entries are not direct provider APIs and do not auto-reconcile.
7. Check Stripe with test card `4242 4242 4242 4242`, a future expiry and any three-digit CVC. Use test-mode recipient details for manual workflow checks; never send real funds just to test the UI. Then verify a signed webhook marks the invoice Paid exactly once and activates a project that was Awaiting Payment. Test delayed methods, failures and expiry in your actual Stripe account before live use.
8. Remove all former gateway variables from Worker settings. Previous payment rows are retained as `legacy`; reconcile any unresolved legacy attempts with the original provider before accepting another payment. The application no longer calls the previous gateway.

Checkout reservations lock billing details and reuse a stable provider idempotency key. A session lasts up to 24 hours. After expiration, Check payment releases it; start checkout again. If the first API call times out, retry the same checkout within 23 hours. After that window a never-confirmed reservation requires support/provider review; do not delete it to work around a potentially accepted payment. Full refunds, disputes and currency-conversion accounting are managed in Stripe and are not automatically reversed into project status by this edition.

## Client login review and fixes

- Client access is invitation-only. Save the client record first; an Archived client cannot be invited, sign in, read the workspace API, or access private records/files through Supabase RLS. An Auth profile by itself no longer grants workspace access. Reactivate all archived records for the email to restore access.
- First invitation / admin recovery links use a fragment token. The login page removes it from the address bar after reading it and verifies it only when the client submits matching passwords of 12–128 characters. Links are one-use and follow Supabase expiration settings.
- Forgot password responds generically for both known and unknown emails, avoiding account disclosure. Supabase sends recovery email only for an existing accessible account. For the default template, open the email in the same browser. `/auth/callback` exchanges the PKCE code for a verified session and creates a short-lived one-use reset proof. A normal signed-in session cannot call reset-password without that proof. Recovery links using the fragment template instead verify the OTP directly.
- Successful client login/activation/reset goes to `/portal`; admins go to `/holyghost`. Cookies are HttpOnly, Secure on HTTPS, and SameSite=Lax. Logout clears the local session. Client project, proposal, invoice and message ownership is verified on the server.
- Existing `/holyghost` owner setup/recovery still requires platform owner identity plus `OWNER_SETUP_TOKEN`. On an independent Cloudflare deployment create/confirm your owner user in Supabase and sign in normally; a token does not substitute for platform owner identity.

## Verification for this edition

`npm run build`, `npx tsc --noEmit`, `npm run check:supabase:db` and `npm run check:supabase:routes` cover compilation, migration reruns/RLS, payment reservations and locks, idempotent settlement, signatures and amount checks, manual-review authorization, archived clients, and single-use recovery. Route tests use simulated Stripe/Supabase HTTP; they do not prove live merchant credentials, real email delivery or actual financial transactions.


## Client isolation review (migration 0006)

Apply `supabase/migrations/202610020006_client_isolation.sql` after migrations 0001–0005 and deploy this source. `ACCESS-UPGRADE.sql` is a copy of this migration with one complete statement per line, suitable for SQL Editor. Run the whole file. If earlier upgrades are missing, apply 0003–0005 first.

Admins can read all workspace records, recent activity and notifications. Client identity is validated using Supabase Auth user ID and its protected profile, then record assignment uses the verified normalized email. The browser cannot choose a different email/role to broaden access. Clients receive only assigned projects/tasks/shared proposals/invoices/messages/files/inquiries. Linked records must also belong to a project assigned to that same client. Only Sent and Accepted proposals are shared. Orphaned or mismatched legacy child records are hidden from clients and remain available for admin review. New mismatched assignments are prevented in both the write API and a database trigger.

The same boundaries apply to payment history/checkout, proposal acceptance, private files and database RLS. Notification clients see only their own recipient entries linked to permitted records. Admins see all notifications, with `admin_read` separate from the client's `read` state. Dashboard statistics and recent activity use the already-scoped API dataset. Refresh removes detail records after access changes and clears workspace data when the session is rejected. The client Recent activity link opens Projects rather than admin-only Analytics. Visual styling and layouts are retained.

Verification covers two separate clients, all-admin visibility, direct-ID requests, wrong-parent legacy rows, private files, payment/proposal actions, notification isolation, separate read states and archived access. No live deployment or database change is performed by downloading this ZIP.
