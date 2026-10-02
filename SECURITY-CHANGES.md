# Completed security fixes

Owner setup/recovery requires a configured OWNER_SETUP_TOKEN; missing configuration disables these actions. Existing password login remains available. Public contact inquiries retain a bounded phone field. Ownership and role inputs remain controlled by the server. Outreach uses new server-only atomic SQL functions, frozen retry requests, per-attempt leases and a conservative 23-hour retry window. Concurrent suppression survives both failures and successful delivery bookkeeping.

Apply migrations 0001 through 0005, in order. Environment templates are included with empty credentials. No generated secrets are shipped.

Validation: TypeScript, production build, database/RLS checks, existing route tests and new regression tests passed using the submitted npm dependency lockfile. Production dependency audit reported zero; full dependency audit includes development-tooling advisories.

## Dependency lockfile

The pnpm lockfile matches Next.js 16.3.8 and the frozen lockfile check passes. Release-age exclusions apply only to the exact 16.3.8 Next.js package family. All other versions keep the existing age check. Secret keys and owner setup tokens are configured in the hosting environment, never included in this archive.

Stripe replaces the former hosted gateway. Signed raw-body webhooks with a five-minute timestamp window retrieve canonical Checkout sessions and check invoice/payment metadata, test/live mode, amount and currency. Server-only SQL reservations serialize attempts and settlement is idempotent. Manual transfers require an administrator to confirm received funds. Active payment snapshots lock invoice billing details. Archived client access is blocked in application guards and private-record/file RLS. Client recovery uses Supabase verification and one-time server proofs; generic forgot-password responses avoid account enumeration.

Migration 0006 adds parent-project ownership checks, consistent shared-proposal visibility, all-admin notifications with independent read state, and client notification/file RLS. The browser receives only a verified client email scope; no layout or CSS redesign is included.
