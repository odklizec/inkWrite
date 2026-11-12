# Phase 2 — transport preparation (not complete)

The owner requested the next step after Phase 1. The architecture and public App
setup questions are pending; no Direct GitHub or Worker choice is inferred from
the supplied plan. Phase 2 acceptance has **not** been met.

Implemented independently of that decision:

- `domain/sync_transport.lua`: one asynchronous request at a time, bound to one
  explicit HTTPS origin; 15-second deadline; 64 KiB request / 48 KiB application
  response ceiling; strict method/header/input checks; cancellation/generation
  guards. No redirects, automatic retries, file targets or logs. Incomplete,
  truncated, oversized and malformed responses fail closed. Error bodies and
  raw exceptions are removed; only fixed errors/status and bounded Retry-After
  information escape. JSON parsing extends the callback budget and occurs in the
  completion callback, never draw. A cancellation can leave the host busy while
  it aborts; the adapter returns that result rather than retrying tightly.
- `domain/sync_primitives.lua`: inject the actual host SHA-256/raw-digest-to-hex
  and base64 methods into Phase 1. Bound inputs/outputs, validate the 32-byte raw
  digest and lowercase hex, contain host exceptions, and refuse weak fallbacks.
- Two mock suites cover transport/encoding limits, byte preservation, stale and
  duplicate callbacks, cancellation, TLS/network-style failures, rate limiting,
  redirects, exceptions, malformed data and missing primitives.

These modules are not imported by the editor. They do not grant network access,
store credentials, create a GitHub App or issue real document requests. The
transport is a low-level adapter: the future auth/API layer must provide its
fixed route allowlist, repository/account authorization checks and fixed headers.
An origin binding alone is not repository authorization.

## Evidence

Desktop: **14/14 suites, 14,314 assertions, zero failures**, Fengari 0.1.5.
New suites contribute 58 assertions; all five sync/safety suites total 234.
`npm test` runs all suites; `npm run test:sync` selects sync/safety suites.
`git diff --check` passed. Synthetic mocks do not establish real firmware HTTPS,
memory headroom or device timing. The host can retain up to 128 KiB before the
48 KiB application check; no lower host allocation limit is promised.

Contract reviewed 2026-11-12 via public-contract search: XTApp 2.x sections
14 (networking), 10 (JSON), 26 (encoding/hashes). JSON null is the host's explicit
`ctx.json.null`, not Lua nil; future auth response validation must account for it.

## Pending decisions and setup

Recommended route remains Direct GitHub App device flow, expiring RAM-only token,
no refresh-token persistence, reauthorize after session end, GitHub-side revocation.
The alternative Worker adds hosting, operator trust and session infrastructure.
See ADR-0001-GITHUB-SYNC-TRANSPORT-AUTH.md; no service has been deployed.

For Direct GitHub, implementation needs the public client ID, numeric App ID,
expected GitHub login and a separate private documents repository/branch. No
client secret or access token should be supplied in chat/source. Registration,
installation and granting access are distinct from implementing this adapter.
Those security-sensitive setup actions have not been performed.

Current official GitHub documentation was rechecked:

- [GitHub App device flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app):
  public client ID, device polling/slow-down/expiry; optional repository narrowing
  can be ignored for an inaccessible ID. Initial response is not proof of scope.
- [Installation access endpoints](https://docs.github.com/en/rest/apps/installations):
  verify the token's accessible installation and repository set. Do not infer
  authorization from a requested repo or account name.

Still required: approved auth flow, disconnect/revoke guidance, account/repository
checks, expiry handling, real HTTPS compatibility and invalid/revoked credential
tests. There is no Phase 2 completion or new device installation claim.

## Delivery state

Development source is on the existing feature branch. Cloud remains the verified
**1.0.5 Phase 1** snapshot until authentication decisions/setup allow Phase 2 to
be completed. Runtime/manifest version and editor behavior are unchanged. Studio
exports continue mapping these inactive modules/tests to development references.
