# Phase 1 — pure sync core

Implemented after the owner approved the next phase on 2026-11-12. This approval
covers the plan's pure core, fixtures and storage tests. The transport/auth ADR
remains proposed. There is no network adapter, credential, editor hook or sync UI.
Local editing, saving, recovery and the fixed Open file dialog remain authoritative.

## Modules and boundaries

- `domain/sync.lua`: deterministic upload/download decisions and one-operation
  state machine. Inputs are saved-file snapshots, remote bytes/blob SHA, optional
  checkpoint and an injected SHA-256 function. Operation IDs reject late/duplicate
  callbacks; finalization rechecks filename, revision, existence and exact bytes.
  Returned actions are intents, never filesystem or network operations.
- `domain/sync_metadata.lua`: explicit private `github-sync.json` adapter, schema
  1, repository/branch binding, strict field validation, at most 64 documents and
  64 KiB serialized data. SHA-256 checksum detects accidental corruption. Load
  does not write. Save requires the previously read revision (or explicit absence),
  validates the existing file, uses the host's atomic write and verifies readback.
  Checkpoints use copy-on-write. Unknown old/future schemas, changed scope, invalid
  records or corrupt data stop sync and remain untouched; no speculative migration.
- `domain/github_payload.lua`: bounded GitHub Contents representation validation,
  canonical base64, exact UTF-8/CRLF bytes, 32 KiB decoded limit and structured PUT
  request data. A response uses `content.sha`, never `commit.sha`. No HTTP calls,
  URLs, authorization headers, token parsing or retry loop.

The SHA-256 and base64 functions are injected explicitly. Desktop tests use Node's
standard crypto/JSON/base64 primitives through a test-only Fengari binding. The
future XTApp adapter must wire the verified host hash/hex/base64/JSON APIs; weak
hash fallbacks are refused. The metadata checksum is neither encryption nor
authentication. No credentials or document bodies belong in metadata.

The expected-revision check prevents accidental stale writes by a single owner;
it is not a filesystem compare-and-swap primitive. Future integration must retain
one writer and reload after an uncertain result. Hashing, JSON and storage work
must occur outside draw and with an appropriate callback budget. Physical-device
memory and timing for the eventual adapter are not established by these tests.

## Decisions

| Observation | Upload | Download |
| --- | --- | --- |
| Exact same bytes | Reconcile checkpoint, no PUT | Reconcile checkpoint |
| First local file; remote absent | Create without SHA | Remote missing |
| Local changed; remote blob unchanged | Update with blob SHA precondition | Conflict |
| Remote changed; local unchanged | Conflict | Import a new local copy |
| Both changed / untracked differing file | Conflict | Conflict |
| Tracked remote deleted | Conflict; no automatic recreation | Remote missing |
| Local absent | No upload | Verified new-file import intent |

Rename starts a new path; no remote deletion. No action replaces/deletes a local
file. A copy imported under another name does not mark its source as synced.
The future import adapter must allocate an unused name and verify the completed
write before supplying a success receipt. The core cannot itself prove external
side effects; adapters must enforce its preconditions before acting.

After a lost remote-write response or crash, re-fetch exact remote bytes. Equal
bytes reconcile metadata without another commit. A local edit during an operation
prevents its receipt from certifying the newer revision. Invalid/missing metadata
never authorizes overwriting a different file. HTTP errors become fixed labels;
response bodies, headers and raw exceptions are not shown in state reasons.

## Verification

`npm ci`, then `npm test` (Node.js; Fengari 0.1.5). `npm run test:sync` runs only
the three sync/safety suites; `npm run test:probe` runs the separate phase 0 probe.
The existing `INKWRITE_FENGARI` environment override can use an installed copy.
All tests use synthetic files and fake transport. No live GitHub document request.

New tests cover the decision matrix, stale/cancelled callbacks, concurrent edits,
lost remote success, copied imports, malformed Contents/base64/UTF-8/size/path,
blob-vs-commit SHA, read/write exceptions, lost metadata acknowledgement,
corrupt checksum, unsupported schema, changed scope, duplicate names, record/byte
limits, offline saves, recovery failure, failed SD write and external-file conflict.

Four older controller suites now give their statistics mock `saved=0`, matching
the numeric field read by the current cloud controller. The snapshot suite tests
the cloud baseline's existing 120-second forced-save policy (including the boundary
just before it), replacing obsolete 30-second expectations. Editor code is not
changed to accommodate tests. The final delivery records counts and cloud hashes.

Final desktop result: **12/12 suites, 14,256 assertions, zero failures**. The three
sync/safety suites contribute 176 assertions. Cloud Save advanced 1.0.3 to 1.0.4
without changing the runtime version. Final 1.0.5 aligns manifest/runtime on the
necessary follow-up save; the only editor-runtime change is that version string.

Phase 1 is desktop verified. Real HTTPS, authentication, physical-device network,
power-loss behavior and performance of a complete sync adapter are NOT TESTED.
No new on-device test is needed for this inactive core; normal writing remains
available. Phase 2 requires the transport/auth decision and compatibility evidence.

## Studio delivery

The existing development cloud project keeps its identity and historic name
**inkWrite GitHub Sync Phase 0**. The exporter preserves these new modules and
tests under `docs/development/` as text, with a restore map. They are deliberately
inactive in the editor until integration; only its original seven Lua files run.
The GitHub branch and full source archive retain executable module paths for
desktop development. See STUDIO-PROJECT-LAYOUT.md before importing source.
