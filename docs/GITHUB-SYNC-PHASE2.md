# Phase 2 — Direct GitHub implementation, live acceptance pending

The owner explicitly chose Direct GitHub with memory-only sessions and confirmed
the GitHub App is not set up. Auth/transport code and mock tests are implemented;
Phase 2 acceptance remains incomplete until registration and real HTTPS/auth tests.
No Worker, real token, client secret, private key or App registration was created.

## Code

- `domain/sync_transport.lua`: one request, bound HTTPS origin, 15-second deadline,
  64 KiB request / 48 KiB application response ceiling, strict inputs, cancellation
  and generation guards, redacted errors, no redirects/retries/file targets/logs.
- `domain/sync_primitives.lua`: real host SHA-256 → lowercase hex and base64 bridge,
  bounded inputs/results, raw 32-byte digest check and no weak fallbacks.
- `domain/sync_auth.lua`: device-code POST and interval-controlled polling, pending/
  slow-down/denied/expired handling, conservative expiring RAM-only token, public
  status without credentials, disconnect/pause cancellation and stale-callback
  guards. Exact GitHub origins/routes and fixed Accept/API-version/User-Agent
  headers; form bodies keep authorization material out of URLs. Refresh tokens
  are discarded. No secret getter, persistent state/storage or management secret.

Auth checks `/user`, `/user/installations`, the installation's accessible repo
set and the selected branch. It refuses wrong account/App/repository/branch,
suspended installs, all-repository access, extra installations/repos/permissions,
public/internal/archived/disabled repos and missing write access. It pins user and
repository numeric IDs during the session. Optional requested repository narrowing
is verified rather than trusted. Null suspension is the real `ctx.json.null`.
IDs must fit the host's signed 32-bit integer range; fail closed otherwise.

`read` and `write` only accept validated document basenames under `documents/`,
encode UTF-8 URL segments and branch, and revalidate scope before each operation.
Read returns bounded validated bytes; write returns only a validated blob-SHA/
fingerprint receipt. Caller must use Phase 1 decisions/revision guards before
acting or checkpointing. These methods do not themselves implement a sync UI,
safe local import, recovery write or metadata commit. Races return conflicts;
uncertain remote writes must be reconciled by re-fetch before retrying.

An operation's 401/403 authorization failure clears the session. 429/403 rate
limits do not get mistaken for revocation; there is no automatic retry. A failed
access recheck fails closed and clears the grant, including network failures;
reconnect explicitly. An uncertain document request can retain the unexpired
session but never returns a successful checkpoint. Local editor data is untouched.

All methods run outside draw. Future controller must call `poll` from a timer/tick
and `pause` on lifecycle suspension; no timer is installed implicitly. The editor
does not import these modules yet. No network permission or save hook was added.

## Verification and limits

Auth tests use real JSON/base64/SHA-256 through test-only Node bindings and fake
HTTPS. `ctx.json.null` now has a sentinel in the test binding, matching the host.
Tests cover success and exact byte requests, interval/slow-down/deadlines, wrap,
wrong/broad/revoked grants, changed privacy, malformed tokens, fixed destinations,
scope checks, late callbacks, cancellation and credential-free status/state.
Desktop result: **15/15 suites, 14,423 assertions, zero failures**; auth suite
109, six sync/safety suites 343. Run `npm test` or `npm run test:sync` with
Fengari 0.1.5. `git diff --check` passed. Development snapshot 1.0.6 aligns the
manifest/runtime with the next cloud save; only the editor version string changes.
The Studio exporter preserves all inactive modules/tests as text references with
a restore map; the repository/full-source archive keeps their original paths.

The host can allocate up to 128 KiB before the 48 KiB application check. Heap and
callback timing require real-device measurement. Private storage is not treated
as encrypted storage. RAM release is not guaranteed memory zeroization. Direct
tokens are repository-scoped; client path checks do not narrow a stolen token.
Scope/privacy changes racing after preflight remain a GitHub policy boundary.

Current contract evidence: public XTApp 2.x sections 14 (network), 10 (JSON),
26 (hash/encoding), 12 (monotonic wrap); API 2.18. GitHub REST version 2026-03-10.
Current official device-flow, registration and installation-access docs were read;
links and concrete public setup steps are in GITHUB-APP-SETUP.md.

## Next step

Follow [GitHub App setup](GITHUB-APP-SETUP.md). Send only public client ID, App ID,
expected login and the separate private docs repo/branch. Then configure and test
real HTTPS/authentication. Live revoked-token behavior, physical devices, network
compatibility, power loss and memory/timing remain **NOT TESTED**. No production
sync or Phase 2 completion is claimed; Phase 3 supplies the editor's manual UI.
