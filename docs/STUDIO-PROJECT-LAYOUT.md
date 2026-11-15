Build 1.0.9 adds domain/approval_qr.lua to the shipping allowlist: **eighteen** executable Lua files. The QR is generated public-URL drawing data, with no credentials and no runtime QR library. scripts/build_approval_qr.py is a non-executable development reference.

Build 1.0.8 adds domain/sync_credentials.lua to the shipping allowlist: **seventeen** executable Lua files. Credential data lives in app-private runtime storage and is never a source file, Studio backup input, fixture, log or repository artifact. The standalone sign-in diagnostic builder includes this required module but never enables persistence.

# Studio project layout — Phase 3

The development cloud project keeps its historical name **inkWrite GitHub Sync Phase 0** and ID e6d7a10b-8bdc-4f4c-bf77-1f5dfa1e5395. Phase 3 activates sixteen explicitly allowlisted Lua files: the original seven editor files plus sync core, metadata, auth, public config, HTTPS transport, primitives, GitHub payload validation, manual session controller and sync UI. The manifest now declares only `net` permission. Test/probe/diagnostic/tool code remains non-executable text under docs/development/, with DEVELOPMENT-SOURCE-MAP.json for restoring original paths.

scripts/build_studio_snapshot.py checks the executable allowlist, static module closure and network ownership. It refuses existing stage directories. Do not import the complete repository as one Studio app: desktop tests and standalone diagnostics have separate roots. The released original cloud project remains separate. Historical details follow.

# Studio project layout repair — 2026-11-12

The first cloud snapshot incorrectly combined three source roots: the inkWrite
editor, desktop controller tests and the standalone HTTPS probe. Studio analyzes
every Lua file under one root manifest. Consequently the probe's root-relative
`require("probe")` / `require("config")` could not resolve, its net requests were
checked against the editor's deliberately network-free manifest, and test-double
properties were mistaken for real host API calls. This was an export error.

The corrected **inkWrite GitHub Sync Phase 0** project contains only seven
executable Lua files: index.lua, keyboard.lua and the five domain modules. The
editor manifest retains no network permission. The audit and ADR stay readable
under docs/. Desktop tests, the probe and development tooling are preserved
byte-for-byte under `docs/development/`, with `.txt` added to each source name.
They remain references, not editor modules. `DEVELOPMENT-SOURCE-MAP.json` maps
these names back to their repository paths. To run the desktop suite, use the
local repository, or restore these files to their mapped paths and remove the
extra `.txt` suffix. The separate **inkWrite HTTPS probe** cloud project is the
executable probe, with its own root modules and net permission.

`scripts/build_studio_snapshot.py` makes this separation reproducible and checks
the exact executable allowlist, static require closure and network-free editor
boundary. It refuses an existing preview staging directory to prevent stale
executable files from surviving an export. Do not export all tracked Lua files
as one app again. The full source ZIP/repository keeps original test/probe paths.

Also removed the old `ctx.fonts.small` emergency fallback. Normal font selection
still uses `ctx.fonts:size(px)` and retains the returned system fallback when
appropriate. If that call is absent/fails, use medium/large built-in presets;
this avoids the small-font CJK promotion warning. No sync/UI/save integration,
network access or credential handling is added to inkWrite.

The four previously recorded cloud-baseline desktop mock failures are separate
from these Studio diagnostics. Packaging them as references does not assert
they pass. Native preview and final cloud-save evidence are recorded in the
delivery verification artifact after performing those checks.

Phase 1 adds inactive pure sync modules and tests. These also map to development
text references; the seven-file editor runtime remains unchanged. The four old
statistics mocks and the stale 30-second autosave test were repaired separately
in phase 1; see GITHUB-SYNC-PHASE1.md for the scope and final verification.
