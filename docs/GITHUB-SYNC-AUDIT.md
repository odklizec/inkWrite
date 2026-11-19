# GitHub document sync: phase 0 audit

Audit date: 2026-11-12. Status: local proof of concept implemented; feasibility
gates remain open. No production synchronization, authentication, credential
storage, network permission or save hook was added to inkWrite.

## Source provenance and scope

The supplied implementation plan is a proposal, not evidence of an API or a
blanket authorization to publish, create credentials or deploy infrastructure.
This work implements its phase 0 audit and isolated synthetic probe only.

- GitHub: private `odklizec/inkWrite`, default branch `main`, observed head
  `5684402fded124006ee5a3de8e1b158e4a93d893`, manifest/runtime 0.1.47, API 2.18.
- Explicitly opened **My cloud workspace → inkWrite**, saved November 11 at
  22:06 as displayed by Studio. Original project ID from exported metadata:
  `bc6ebcee-26df-4d19-b814-b9e488605d51`; app ID `inkwrite`.
- Preserved the pre-open local source archive, then accepted Replace local with
  cloud. Exported the loaded workspace at `2026-11-12T19:18:20.620Z`.
- Cloud archive: manifest **1.0.1**, runtime `M.VERSION` **1.0.2**, README
  **0.1.51**. These inconsistent identifiers are preserved, not silently repaired.
  Studio showed an uncommitted-changes row after cloud open; this audit does not
  certify the export as a clean release or claim a new cloud save.
- After converting export CRCRLF/CRLF source line endings to LF, content differs
  from GitHub only in manifest, README, HANDOVER, `domain/app.lua` and
  `domain/stats.lua`. The other five text sources match. Both shipping XIC assets
  match exactly. Repository-only tests, docs and original artwork are retained.
- The source import is a separate baseline commit on
  `phase0/github-sync-audit`; phase 0 itself does not edit runtime source.
  `docs/GITHUB_SYNC.json` remains historical 0.1.47 release metadata, not proof
  that the current cloud baseline is synchronized or a document-sync database.

The cloud baseline has Markdown marker shortcuts, keyboard help/toolbar routes,
last/average/worst timing, deferred statistics checkpoints and a 120-second
forced autosave. The plan's 30-second dirty interval is outdated for this source.

## Architecture and local persistence trace

| Boundary | Actual owner and behavior | Future extension point |
| --- | --- | --- |
| Lifecycle | `index.lua` delegates to `domain/app.lua` | Controller owns any transient sync operation |
| Editor | Local `A` owns document identity, buffer, caret, selection, layout and timers | Never retain a second editor buffer or sync in draw |
| Text | `domain/buffer.lua`: bounded UTF-8 source buffer, 32 KiB; bounded undo | Read saved bytes through Documents, not undo/recovery |
| Public files | `domain/documents.lua`, `ctx.files`, `/AppFiles/inkwrite/` | `Docs.read` validates names, size and UTF-8/NUL policy |
| Recovery | `Docs.recovery/load_recovery`, private `recovery.txt` | Recovery is not an upload source |
| Statistics | `domain/stats.lua`, private bounded history | Separate from sync bookkeeping |
| Preferences | `ctx.state`: last filename/cursor, layout and UI preferences | No document bodies, credentials or growing history |
| UI | App owns settings/menu/help pages and button/touch focus | Later opt-in sync page; preserve editor context |

`new_document` chooses a fresh dated/untitled `.md` or `.txt` name (up to 512
attempts); `open_file` first saves dirty content, then validates through
`Docs.read`. `set_document` cancels navigation/redraw and resets document-bound
transient state. Startup reads recovery first. Matching recovery/public bytes can
be cleared; differing text gets a recovered identity. Unknown/corrupt recovery
blocks mutation. A stale missing last-file preference creates a fresh document.

The controller's local `save(ctx)` extends the callback budget and snapshots
`A.buffer:text()` inside a protected call to `Docs.save`. Documents writes private
recovery **first**, reads the current public file and compares exact bytes with
`doc.base`. An external change switches to a fresh conflict filename and writes
recovery for that identity. The public write must succeed before `doc.base` is
updated; matching stale recovery removal is best effort. A failed save keeps the
editor dirty and reports failure.

The public comparison and replacement are separate calls, not a filesystem
compare-and-swap. Atomic writes protect against partial replacement, not an
external writer racing between the check and write. Rename likewise has no
transaction spanning its source verification/removal. Existing safeguards are
preserved, but concurrent SD mutation still needs explicit device/failure tests.

The future success notification belongs immediately after the successful
`Docs.save` return in controller `save`, where dirty/failure flags are cleared.
Capture the **resulting** `A.doc.name` (which may be a conflict copy) and buffer
revision, then release the save snapshot. The clean/no-write early return is
not a new save. A future explicit upload must re-read/validate the public file
and compare current identity/revision; it must never upload the current unsaved
buffer merely because a previous save succeeded. No notification is installed.

Autosave runs in `M.tick`: approximately five seconds since edit plus keyboard
quiet (700 ms), or 120 dirty seconds forced. Failure pauses retries until edit or
explicit Save. Statistics writes are gated separately, forced after 180 seconds.
`pause/leave` cancel navigation/redraw and checkpoint dirty recovery; they do not
equate that checkpoint with a successful public save. Resume resets transient
keyboard state/listening and layout. Future network work must cancel/ignore late
responses on pause, leave and document switches.

Rename uses 1 KiB timer slices: create a free destination, copy, compare, then
remove source. Failures preserve source, possibly with an incomplete copy. Delete
requires the existing confirmation and recovery checks. Neither operation should
propagate a destructive remote action in MVP. There is no safe remote import
entry point yet: phase 3 must implement verified download-as-new-copy using a
fresh name, with explicit read-back before recording synced metadata. Network
`save.to=files` must never target the active document directly.

## Current public XTApp contract evidence

Read through `search_xtapp_knowledge` on the audit date. Results identified
`version: 2.x`, `source: public-contract`, not a particular tested firmware build.
These are contract facts, **not hardware observations**. Relevant sections of
[official docs](https://xtapp-ai.xteink.cc/docs?doc=v2-spec-00):

| Topic / source path under `contract/v2/spec-en/` | Contract facts |
| --- | --- |
| `00-总则.md`, Manifest, line 58 | API minor must be supported by host; net requires `permissions: ["net"]`; latest indexed features are 2.18 |
| `14-联网.md`, line 1 | `ctx.net:request(opts, function(ctx,res))`; asynchronous; GET/POST plus PUT/PATCH/DELETE/HEAD/OPTIONS and DAV methods since 2.18; uppercase only |
| same | String headers supported, including custom names; at most 16, names ≤64 B, values ≤1024 B. GET/HEAD cannot set body. Request body ≤65536 B, URL ≤1024 B |
| same | HTTPS validates built-in root certificates; invalid clock can produce `io_error`. HTTP is also accepted by host; sync must enforce HTTPS |
| same | No redirects followed. Deadline 1000–60000 ms, default 30000; Wi-Fi connection time counts; 2.17 ignores custom timeout |
| same | One unfinished request; `busy` during cancellation until slot released. `job:cancel()` suppresses completion; session end cancels unfinished jobs |
| same | Response retains ≤131072 B, total body size in `bytes`; overflow gives `limit_exceeded` even with `ok=true`. OOM gives `ok=false`, body nil |
| same | Response headers lowercased, ≤32 entries /4096 B. `ok` indicates transport completion, not a successful HTTP status |
| `14-联网.md`, Saving to a file, line 60 | 2.18 optional `save={to="storage" or "files",name=...}`; 2xx complete responses replace atomically before callback. Private limit 262144 B, public 8 MiB; errors can still return body in memory |
| `09-私有文件.md`, line 1 | App-private directory inaccessible to other apps, removed on uninstall; atomic old-or-new writes. File ≤262144 B, ≤512 files, total ≤128 MiB; quota is not free-space guarantee |
| `29-应用文件.md`, line 1 | Public folder survives upgrade/uninstall; flat case-insensitive UTF-8 names, no Unicode normalization, ≤512 files. Reads ≤65536 B per call; write ≤262144 B atomic old-or-new, append may be partial |
| `26-编码哈希与随机.md`, line 1 | `ctx.base64:encode/decode`, `ctx.hash:sha256`, `ctx.hex:encode`, hardware random bytes/UUID; input ≤1 MiB. Digests are raw bytes. No encryption/decryption provided |
| `10-JSON.md`, line 1 | `ctx.json:encode/decode`, encode ≤262144 B, depth ≤32; calls count against callback time; never parse in draw |
| `02-生命周期.md`, line 1 | Network completions/timers normally have 1000 ms budget; pause queues them until after resume and its first redraw |
| `12-时钟日志与内存.md`, line 1 | `clock:millis()` wraps at 2^31; use masked subtraction. `clock:now().valid` must be checked before dates; clock is not conflict authority |

No encrypted credential vault, device keystore or browser-launch API was found
in the reviewed authoritative sections. Absence from these results does not
prove firmware impossibility: vendor confirmation remains open. App-private
storage is **not verified encrypted storage**; SD extraction/uninstall/backups
must be considered. Showing an authorization URL/code needs no embedded browser.
GitHub device authorization can use the documented POST/header/JSON primitives,
subject to real-device validation and application registration.

32 KiB → 43692 B padded base64, plus JSON/path/message/SHA: below the 65536 B
request ceiling if all metadata is bounded. This arithmetic does not demonstrate
heap headroom: source buffer, save base, encoded text, JSON, response and parser
can overlap. Fingerprints can use `hex(sha256(exact_saved_bytes))`; keep GitHub
Contents **blob SHA** separate from commit SHA. Directory/history responses need
their own caps/paging, not the per-file size assumption.

Supplemental evidence for saved state: the connector's `idle-games.en.md`,
"Keep progress in ctx.state", line 5 (source `xtapp-studio`, **guide**, not the
contract) describes host save after on_leave, no latest-state save on crash or
power loss, and a 16384 B JSON state cap. A direct indexed section 28 match was
not returned. Verify the current section before implementing metadata migration;
use explicitly written, bounded private metadata rather than relying on exit.

## Probe implementation and evidence

`tools/github-sync-probe/` is a separate app ID with net permission. inkWrite's
manifest remains network-free. Config defaults to disabled; nothing runs on
load or draw. An explicit OK/tap advances one of seven synthetic cases: GET,
POST, PUT, DELETE, 49152 B response, 131073 B overflow and HTTP 401. Headers use
only a visibly fake bearer string and fixed content type; UTF-8/CRLF payload is
synthetic. Echo checks compare method, header and exact body. The large bodies
are never JSON-decoded. Only bounded result summaries survive a callback.

Transport is injectable through a mock `ctx.net`. It enforces one operation,
10-second deadline, HTTPS-only origin, no retries, cancellation/generation guard,
tiny echo JSON limit and error allowlist. It cannot prevent the host allocating
up to 128 KiB before callback; the overflow case belongs only in this isolated
diagnostic. Pause cancels; reopen to repeat a cancelled/failed case. See probe
README for endpoint contract and execution instructions.

| Layer | Result on this task |
| --- | --- |
| GitHub 0.1.47 unchanged regression files | 7/7 PASS; 13532 returned assertions (includes overlapping suites) |
| Loaded cloud baseline, before phase 0 | 3/7 PASS: layout 44, startup 24, timing 104; four failures |
| Same existing files after phase 0 | Identical 3/7 outcome, same failure location; files unchanged |
| Synthetic transport unit suite | 93 assertions PASS in Fengari 0.1.5 / Node 24.21.0 |
| Native preview Classic / Pro | NOT TESTED: preview source-upload action rejected by automatic approval review |
| Physical Classic / Pro, TLS/headers/methods/limits | NOT TESTED; no firmware versions inspected |
| Real GitHub document upload / authentication | NOT TESTED; no production credentials requested/stored |
| Device heap/input latency/SD power loss | NOT TESTED; no performance claim |

Four cloud-baseline failures are `keyboard_orientation`,
`keyboard_shortcut_popup`, `preferred_font`, `typing_snapshot`. Their existing
`domain.stats` doubles return a function for missing properties, while the newer
controller reads `A.stats.saved` and subtracts it as a timestamp in `M.tick`.
Thus `age` throws arithmetic-on-function. This demonstrates outdated test-double
compatibility, not a verified device failure. Later autosave assertions also
encode the older 30-second behavior; fixing only the doubles is insufficient to
certify this cloud release. Phase 0 does not change the tests or hide these
failures. Full regression acceptance is **not green** for the latest cloud app.

Reproduction: `npm install --ignore-scripts`, `npm run test:probe`, `npm test`.
An existing Fengari 0.1.5 installation was reused via `INKWRITE_FENGARI` for this
task. `tests/run.cjs` preloads actual Lua source into a fresh VM per suite and
returns a nonzero exit code on any failure. Mock assertions are not independent
hardware scenarios. Source and asset hashes are in `GITHUB-SYNC-BASELINE.json`.

## Gates and next steps

**Gate A: incomplete.** Methods/headers/limits are documented and mocks pass;
native and physical behavior is explicitly unverified. Run the isolated probe
on both variants, record firmware/API, HTTP status/echo flags/bytes, validate TLS
with a deliberately invalid certificate/clock without bypassing validation, and
measure memory for 32 KiB data. No production token handling until reviewed.

**Gate B: recommendation only.** See ADR 0001. Direct GitHub App device flow with
memory-only expiring authorization is feasible on paper; a Worker is not required
just to translate PUT. Persisted sessions, remote revocation and server-enforced
path restrictions have separate tradeoffs. No Worker, GitHub App registration or
hosting/security commitment was selected or deployed.

Before phase 1: review this audit and source-version drift, bring the cloud
baseline's tests into agreement with its intended behavior in a separate change,
and approve the architecture. Phase 1 can then add a pure comparison/state core
with mocked transport without enabling network or changing autosave.
