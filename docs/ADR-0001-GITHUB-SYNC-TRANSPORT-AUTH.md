# ADR 0001: GitHub sync transport and per-user authorization

Date: 2026-11-12. Status: **Direct GitHub with memory-only sessions approved by
the owner; live feasibility acceptance pending**. The owner confirmed the choice
and that App setup is not yet done. No hosting or credentials were created.

Decision: implement GitHub App device flow with expiring RAM-only access tokens,
discard refresh tokens, reauthorize after session end and revoke through GitHub
settings. Require one selected installation/repository with Contents write and
Metadata read only, expected account and private repo/branch verification. The
token still has repository-level scope; the client restricts paths. No encrypted
storage or path-scoped server enforcement is claimed. See GITHUB-APP-SETUP.md.

## Context

XTApp API 2.18 documents HTTPS PUT, custom headers and bounded asynchronous
responses. GitHub Contents can therefore be used directly on paper. Neither
device variant has been tested here. No encrypted device credential vault is
verified. The editor must remain usable offline and independent of cloud work.

## Alternatives

| Topic | Direct GitHub App device flow | Optional Worker + GitHub App |
| --- | --- | --- |
| Device credentials | Expiring user token in RAM only; discard refresh token; authorize again next session | Short-lived, revocable device session; GitHub tokens stay server-side; device credential is still a secret |
| Setup | Register App, enable device flow, Contents read/write, user authorizes and installs only on selected repo | Register App plus HTTPS service, protected token/session store, pairing UI, webhook/revocation infrastructure |
| Pairing practicality | Display GitHub URL/code; POST device-code and token endpoints; no embedded browser or client secret needed for initial device flow | Short-lived single-use codes, rate limits, expiry, replay protection; browser completes GitHub installation/authorization |
| Repository scope | App installation and user intersection; verify selected repository; fail if inaccessible | Bind authenticated user/install/repository server-side; never trust client owner/repo/path |
| Document paths | App validates allowed basenames/prefix; repository token itself is not restricted to `documents/` | Server can enforce only `.md`/`.txt` beneath selected prefix, size and exact operation allowlist |
| Persistence | No token written to SD/state; reconnect after close/crash; RAM compromise remains possible | Remembered pairing still exposes its session credential to SD extraction unless secure storage is verified or persistence explicitly accepted |
| Revocation | User revokes App authorization through GitHub settings; app discards local token. Do not embed a client secret to invoke secret-authenticated management endpoints | Disconnect invalidates server session immediately; revoke/expire GitHub grants; process authorization-revocation webhook |
| Expiration | Honor token response expiry; no silent permanent credentials. Refresh may require confidential-client handling; out of scope for RAM-only prototype | Protect and rotate refresh tokens/installation authorization server-side; expire sessions and reject revoked grants |
| Abuse controls | GitHub limits plus one request/deadline and explicit user actions in device app | Also per-user/device/IP limits, pairing throttling, size caps, audit redaction, replay defense and operator monitoring |
| Operations | No new hosting bill/service; GitHub outage affects sync only | Hosting/account/cost/key rotation/service availability become owner responsibilities |
| Service outage | Local saves work; manual sync shows Offline/Error | Same local behavior, but Worker outage additionally prevents auth and sync; no automatic bypass to a broader credential |
| Trust | GitHub sees selected document bytes | Worker operator and GitHub see bytes in transit; do not persist documents or include them in logs |

Broad OAuth `repo` access and a shared developer token are unsuitable defaults.
Manual fine-grained PAT entry remains an explicitly labeled advanced experiment,
not a consumer flow; no PAT storage or entry screen is implemented.

## Recommendation and decision boundary

Start with **direct transport feasibility and memory-only GitHub App device
authorization** if the owner accepts reconnecting after session end, manual
GitHub-side revocation and repository-level token scope. This avoids a Worker
whose only purpose would be method translation. Do not call this production-ready.

Choose the Worker only if remembered sessions, server-enforced permitted paths
or immediate server-side session revocation are product requirements. That choice
requires explicit acceptance of operator trust, hosting/costs and device-session
storage risk. A Worker does not remove the need for device credentials. If secure
storage remains unavailable, prefer RAM-only sessions even with a Worker; any
persisted bearer credential needs narrowly scoped permissions, short lifetime,
revocation and explicit user consent.

Phase 0 left the choice open. Phase 1 repaired the stale test doubles and passed
all regressions. The owner's subsequent explicit choice resolves Gate B for this
RAM-only prototype; Gate A's real-device/network evidence remains incomplete.
The pure Phase 1 core remains independent of transport.

## Implementation notes for a later approved adapter

- Treat GitHub App authorization and repository installation as separate grants.
  Check both and selected repository privacy/access before writing.
- Respect device-flow `interval`, `slow_down`, expiry, cancellation and denied
  authorization; never poll in draw or with tight retries.
- Current GitHub docs list a `repository_id` narrowing parameter but say an
  inaccessible ID can be ignored. Verify the returned accessible repository set;
  do not treat a requested ID as proof of narrow authorization.
- Require HTTPS, explicit GitHub Accept/API-version headers and bounded JSON.
  Contents update uses current file blob SHA, never the commit SHA. After a lost
  response, re-fetch and compare exact bytes before retrying.
- Keep one operation with document identity/revision and operation-generation
  guards. Cancel on pause/leave; errors never alter local Saved state.
- Future Worker must reject arbitrary URL proxying, cross-account/repository
  substitution, traversal and unauthorized extensions; keep credentials protected
  at rest with keys separate from records, and redact diagnostics.

## Evidence

- [XTApp contract](https://xtapp-ai.xteink.cc/docs?doc=v2-spec-14), reviewed via
  official public-contract search on 2026-11-12; audit records exact paths/limits.
- [GitHub App user-token and device flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app), read 2026-11-12:
  initial device flow uses client ID and device code; expiring tokens and
  repository narrowing require deliberate lifecycle handling.
- [User/app access intersection](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user).
- [Contents REST API](https://docs.github.com/en/rest/repos/contents): supported
  fine-grained token types, Contents permission and optimistic SHA update.

No OAuth flow, Worker infrastructure, account permissions or real GitHub document
write was exercised. These references support design feasibility, not delivery.
