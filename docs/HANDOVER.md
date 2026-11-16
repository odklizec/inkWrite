## 1.0.14 - Phase 4 document history and restore

Added per-document history from the current document and remote browser. Five commits per page, at most 20 pages / 100 versions. First page anchors to the branch SHA returned by the existing scope check; later pages keep that immutable anchor. Every history/read operation revalidates account/App/private repo/branch. Historical Contents reads use the selected full commit SHA, not a blob SHA or mutable branch. Restores allocate verified restore-### copies, preserve active document/recovery/current sync metadata, and never rewrite GitHub. Cancel selected initially. Failures retain prior history page, show fixed/redacted status and require manual retry. One page retained only, clear on close/disconnect. No auto-sync.

Desktop 24/24 suites, 15,793 assertions. New history suite has 48 checks, including paging stability/limits, malformed payloads, account mismatch, 32 KiB accented CRLF, exact-copy import, unchanged recovery/checkpoint, SD failures, stale callbacks, cancellation and actual UI/auth integration. Synthetic native Pro touch selected and restored a fixture; preview file API verified its exact 31 bytes. Direction input moves focus; simulator OK reports unsupported, so Classic OK acceptance remains desktop-only. Native history preview has zero Problems diagnostics and no runtime fault. Full writer startup and Settings touch also passed in a separate clean native preview identity. Physical hardware and real GitHub history matching remain NOT TESTED. Public network contract rechecked on 16 November 2026; API stays 2.26. Final delivery artifact records cloud identity/source/icon hashes and branch commit. See GITHUB-SYNC-PHASE4.md.

## 1.0.13 - Simpler direct GitHub document sync

Implemented the recommendations in the owner's chat "Compare Draftling and inkWrite": prominent Sync this document, Ctrl+G, cached file status, and confirmed remote-only update of the active document with a verified local backup. Owner chose direct device sign-in without hosting; first connection combines Remember/session-only choice with sign-in. Existing QR and single footer Back retained. No automatic transfer after sign-in or on startup. Desktop: 23/23 suites, 15,737 assertions in the final code checks. Synthetic native Pro main/connect/QR screens and Classic update confirmation were visually checked with zero runtime fault; Pro touch opens sign-in. Classic OK is unavailable in this simulator; desktop input tests cover Cancel selection and navigation. New integration cases exercise real App/Docs/auth/session/metadata modules with synthetic HTTP/SD, including dirty edits, remote revision drift, recovery conflicts, failed backup/recovery/public writes, checkpoint failure and cancellation. See GITHUB-SYNC-1.0.13.md. Delivery verification records final counts, cloud identity, source/assets and Git commit. Hardware acceptance remains pending.

## 1.0.10 — One Back control on GitHub sync main page

Owner confirmed QR works and requested removal of the duplicate top Back row. Main sync list now begins with GitHub sync: On/Off; bottom Back and physical/keyboard Back/Escape remain available. Nested Back/Cancel rows are preserved for remote browsing and confirmations. Existing input tests adjusted for shifted main-page rows; no sync/auth behavior change.

## 1.0.9 — Reconnect without discarding refresh, approval QR

Owner clarified the 1–2 day reapproval was in the sign-in diagnostic, not the writer; no writer failure is established. Found a concrete recovery weakness: a rejected saved access token discarded the refresh grant. Restore now tries exactly one device-flow refresh on API 401, without replaying a document write. Generic 401/403 and unknown refresh/configuration failures no longer delete saved credentials; explicit expired/bad refresh grants and identity/scope mismatches still fail closed. New synthetic fresh-VM tests cover 1, 2, 3 and 100 days. Added offline static QR under the approval message; it encodes only https://github.com/login/device, not secrets/codes or a third-party QR service. Cancel removes it. Static data is 37 modules including quiet zone, 214 merged black runs. Actual Lua QR draw commands independently decoded in four desktop geometry/font cases. 21/21 suites, 15,647 assertions. API updated to newest verified public contract 2.26. Studio sign-in restored. Synthetic native Pro QR screen has no runtime fault/Problems diagnostics; screenshot independently decoded to GitHub device approval URL; Cancel touch handled. Physical reentry remains NOT TESTED. Cloud-save verification is in the delivery artifact. Prepared from last verified 1.0.8 source. See GITHUB-CONNECTION-1.0.9.md.

## 1.0.8 — Remember connection and visible sign-in code

Owner rejected browser authorization after every app restart and reported missing code on return. Added explicit consented app-private credential persistence, lazy saved-session restoration when opening sync, automatic device-flow refresh without a client secret, verified Forget and clear persistence errors. System-cover pause now preserves sign-in code/RAM session; true exit clears RAM but retains an opted-in saved grant. Code has a dedicated visible line, with requesting/failure/expiry states. New credential module and standalone diagnostic builder dependency included. Desktop 19/19 suites, 14,755 assertions. No real credential was read or created in verification. See GITHUB-CONNECTION-1.0.8.md. The prior RAM-only ADR decision is superseded by this explicit opt-in; no relay, permanent token or GitHub security-setting change is needed.

## 1.0.7 — Phase 3 manual GitHub sync

Owner reported Phase 2 standalone device sign-in/private-repo authorization working. This is owner evidence, not upload/download/revocation/power-loss evidence. Phase 3 now imports the validated core, metadata, transport and RAM-only auth into the editor. Settings > More > GitHub sync provides explicit opt-in, connect/disconnect, manual upload, bounded remote listing and download-as-copy; touch and Classic/keyboard routes share geometry. No auto-sync. Existing document/buffer/selection/recovery remain separate. See GITHUB-SYNC-PHASE3.md for limits, verification and acceptance instructions. Desktop 18/18 suites pass (14,660 assertions); native synthetic Pro touch and Classic buttons reach the sync panel without runtime fault or Problems diagnostics. Transfers/hardware remain NOT TESTED. Latest website access failed; verified public contract is still 2.18 (see XTAPP-API-REVIEW-2026-11-13.md).

## Phase 2 public setup and separate sign-in diagnostic

Owner supplied public Client ID/App ID, login and docs repo/main. Configured
domain/sync_config.lua; connector verified private repo ID 1455886532 and main.
Added separate tools/github-auth-check app (inkwrite.githubauthcheck, saved v0.0.2),
explicit builder, button/touch/lifecycle tests. No document operation controls.
Auth public status now includes a bounded HTTP code for diagnosing failed HTTPS;
no response bodies/credentials are exposed. Writer runtime/version remain 1.0.6.
Pro native starts/draws/touch handles with fault null and zero Studio diagnostics.
GitHub device-code request: Studio 502 twice; independent desktop HTTPS 200 with
valid device-flow response. No codes persisted/printed, no token exchange.
See tools/github-auth-check/README.md for device instructions and exact limits.
Live device authorization and App scope/revocation acceptance still pending.
Classic native startup and Back exit pass with fault null. Desktop 16/16 suites,
14,448 assertions. Diagnostic cloud project 803d9404-1aa3-469a-8547-96e7425bf08d
saved successfully; exported ten Lua sources + manifest are verified separately.

## 1.0.6 — Phase 2 Direct GitHub, live acceptance pending

Owner chose Direct GitHub/RAM-only sessions; App not set up. Added sync_auth.lua
with device flow, bounded polling/expiry, scope checks, fixed API routes and
credential-free status; read/write adapters use Phase 1 payload validation. Every
operation rechecks account/App/private-repository/branch scope; revoked grants
clear session. Pause/disconnect cancels and discards access/refresh material.
No editor import, net permission, save hook, local import or actual credentials.
Added GitHub setup guide and accepted the ADR's architecture choice. JSON tests
now model host null with a sentinel. Tests/delivery counts are in the final
artifact. Real HTTPS/auth/hardware acceptance waits for the registered App.
Desktop: 15/15 suites pass, 14,423 assertions; auth suite 109, six sync/safety
suites 343. Development snapshot version 1.0.6 matches the next Studio save;
the only editor-runtime change is the version string. Sync code remains inactive
as development text references in Studio. The original released project is untouched.

## Phase 2 preparation — no runtime release

Added inactive bounded HTTPS and host hash/base64 adapters, with two mock suites.
All 14 suites pass, 14,314 assertions. Architecture choice and public GitHub App
setup questions are pending; no credentials/auth implementation/hosting chosen.
Phase 2 is incomplete. Cloud stays verified Phase 1 v1.0.5, runtime unchanged.
See GITHUB-SYNC-PHASE2.md. Real HTTPS/hardware acceptance remains NOT TESTED.

## 1.0.5 — GitHub sync phase 1 (inactive core, 2026-11-12)

Owner accepted filename fix and authorized the next phase. Added pure sync
state/decisions, scoped schema-1 metadata with checksum/revision/readback guards,
bounded Contents payload conversion, fake transport/fixtures and failure tests.
No editor hook, transport, credentials, public-document overwrite or auth decision.
All sync modules remain text references in the Studio export until integration.
Repository modules keep their original paths. See GITHUB-SYNC-PHASE1.md.

Repaired four statistics test doubles (`saved=0`) and updated the snapshot test
to the current cloud controller's 120-second forced save with a pre-boundary
assertion. Existing runtime save logic unchanged. All 12 suites pass, 14,256
assertions (176 sync/safety). Studio Save automatically advanced 1.0.3 to 1.0.4;
the follow-up 1.0.5 aligns manifest/runtime. Only runtime version string changes.
Cloud-save identity/version and GitHub commit are in the phase 1 delivery artifact.
Physical-device sync/network remains NOT TESTED. Phase 2 is the auth/transport gate.

## 1.0.3 — restore filenames in Open file

The Open file list placed filenames in a 24 px text box even when the preferred
20 px font returned a taller line height. The host could fit zero lines, leaving
size/action controls visible but no filename. Labels now get row height minus
8 px; library row height is at least the returned UI line height plus 8 px.
Shared geometry keeps pagination and touch rows aligned, with size/actions
centered in taller rows. No filename/document-byte transformation or extra font
opens. New controller regression: 464 assertions for 24/28/36/44 px line heights,
portrait/landscape, short/long/accented names, touch/keyboard opening and exact
UTF-8/CRLF preservation without public writes. The four older statistics-double
failures remain recorded; this fix does not claim they pass. Final native/cloud
and GitHub evidence is recorded in the delivery artifact after verification.

## 2026-11-12 — correct Studio snapshot source boundaries

The initial phase 0 cloud snapshot was saved with probe/test Lua as executable
editor modules, causing the reported missing-module, missing-net-permission and
test-double API diagnostics. Corrected exporter keeps only the seven editor Lua
files executable; supporting source is preserved under docs/development/ as text
with a restore map. The probe remains a separate app. No net permission is added
to inkWrite. Removed ctx.fonts.small emergency fallback in favor of medium/large;
preferred fonts still use fonts:size. See STUDIO-PROJECT-LAYOUT.md and the
post-repair delivery verification for actual Studio/cloud results. This does not
resolve or hide the separately recorded desktop regression failures.

## 2026-11-12 — GitHub sync phase 0 (no editor integration)

Explicitly opened the latest original cloud inkWrite (project
bc6ebcee-26df-4d19-b814-b9e488605d51), after exporting a local backup. Imported
the cloud source on phase0/github-sync-audit; manifest 1.0.1, runtime 1.0.2 and
README 0.1.51 conflict. Preserve and review that drift before release. Cloud
autosave is 5 s idle / 120 s forced, superseding the old 30 s notes below.

Added GITHUB-SYNC-AUDIT.md, ADR-0001-GITHUB-SYNC-TRANSPORT-AUTH.md,
GITHUB-SYNC-BASELINE.json, a reproducible Fengari runner and an isolated
tools/github-sync-probe app. No inkWrite Lua, identity, network permission,
storage schema, editor UI or save behavior changed after the baseline import.
No production credentials or Worker deployment. ADR is proposed, not approved.

GitHub 0.1.47 existing tests: 7/7 pass, 13532 returned assertions including
overlapping suites. Latest cloud: 3/7 pass, four existing mock-statistics
compatibility failures before and after phase 0. Existing tests unchanged;
regression acceptance is not green. Probe: 93 mock assertions pass. Native
preview upload was rejected by automatic approval review as an unapproved
external source upload. No workaround used; both preview/device variants are
NOT TESTED. Owner approval is required for the standalone probe upload before
native preview can proceed. Cloud retrieval does not prove a new cloud save.

See the audit for exact tests, API evidence, save hook and next gates. The old
docs/GITHUB_SYNC.json describes the 0.1.47 release, not this branch or document
sync. No phase 1 integration or production transport should be inferred.

## Maintenance 0.1.47 — follow the Ink App font preference

Confirmed the reported font bug in the controller: empty font_name selected ctx.fonts.medium/large directly, bypassing the user's font; its picker called the removed installed/open API. Migrated to ctx.fonts:size(px), without checking the retired ttf capability flag. Preload 20/24/30 px UI fonts during on_load and acquire the selected body size in lifecycle/input callbacks. Drawing reuses those objects; no font opens occur in on_draw. All writing, preview, chrome, lists, help and virtual-key labels use the preferred font. Six bounded sizes: 20/24/28/30/32/36. No extra reserve or framebuffer. The host owns cache/memory.

Typography displays the actual returned font.name for TTF or System fallback if font.px is nil. The old in-app picker now opens instructions for Ink App > Settings > Font; close and reopen inkWrite after changing that setting because the host keeps the chosen file for a session. Retire state.font_name while preserving valid size/spacing/margins and document/caret/selection. List/title text boxes accommodate TTF line height. English em-dash/ellipsis labels use -- and ... while insertion remains Unicode — and ….

Contract: current official public specification section 7, Contract api-2.18.2 / 7c82d5089d12, https://xtapp-ai.xteink.cc/docs?doc=v2-spec-07. From 2.17, fonts.size follows the Ink App selection, then reader font; small/medium/large are only built-in presets. installed/open are nil and capabilities.ttf is false; manifest ttf_reserve_kb is ignored on these hosts. The connector's older prose guides still describe the retired picker, so the current public contract takes precedence.

Verification: preferred-font controller checks 83; existing shortcut/popup 5032, layout 44, typing/snapshot/autosave 3569, startup 24, timing 105; 8857 total Fengari assertions. Checks cover a selected TTF despite ttf=false, actual font names, all six sizes, no font acquisition in draw, preference migration, TTF UI drawing, bounded unique sizes, new-session preference change, explicit fallback, and ASCII key labels inserting exact Unicode bytes. Native Pro preview showed Font: MiSans, working 24-to-36 size change and system-font guidance with fault null. Physical device font selection remains to be checked by the owner. Final cloud/GitHub hashes are recorded in the release verification artifact.

## Maintenance 0.1.46 — keyboard switching and popup settings

The owner reports that Left Alt+Shift does not switch layouts on their physical keyboard; other 0.1.45 behavior is accepted. Previous code required a separately observed AltLeft down when Alt was pressed first. Shift down now uses ev.mods.alt directly, while explicit AltRight state protects AltGr+Shift. Either Shift key and either modifier order work; held/repeated keys do not cycle repeatedly. Ctrl+Space is an additional fallback. At least two checked layouts are required for a visible switch. The physical keyboard's actual missing/event behavior has not been captured, so hardware resolution remains to be checked.

Added Add more... as the final language-popup row, opening the existing Keyboard settings page. Shared row counts include this action in drawing, touch, arrows, page navigation and Classic OK. It is reachable with one language and in landscape above the on-screen keyboard. Popup ownership now precedes Classic virtual-key navigation, so opening the popup over the virtual keyboard does not divert device keys to text. Document bytes, selection and virtual-keyboard visibility are preserved.

Input contract: public-contract 2.x, contract/v2/spec-en/04-输入.md, Listening, line 253: code follows W3C physical key positions; ev.mods contains currently held modifier booleans; modifier keys have down/up events. Updated only the application event handling; no firmware/BT behavior is claimed.

Verification: Fengari controller assertions: shortcut/popup plus national/orientation checks 5032, layout 44, typing/snapshot/autosave 3569, startup 24, timing 105 (8774 total). Cases include missing Alt down, both modifier orders/Shift sides, AltGr, repeated keys, Ctrl+Space, modal input ownership, text/selection retention and Add more by touch/keyboard/Classic in portrait/landscape with virtual keyboard shown/hidden. Native preview and final cloud/GitHub verification are recorded in the release artifact. No physical keyboard test was performed here.

## Keyboard settings and native rotation — 2026-11-02

Loaded the latest original cloud save: 0.1.42, project bc6ebcee-26df-4d19-b814-b9e488605d51. The requested 1.0.42 is identified as 0.1.42 by both manifest and handover. Final version: 0.1.45; Studio cloud Save automatically advanced intermediate manifests to 0.1.43/0.1.44. Both version fields were aligned before the final save.

Settings > Keyb. opens a paged Keyboard page. The first row toggles the on-screen keyboard; remaining rows are language checkboxes. Defaults to English US, validates saved IDs, requires at least one selected layout, and moves the active layout to an enabled choice if unchecked. The status popup shows only enabled layouts. Left Alt+Shift cycles them once per press in either modifier order, without consuming AltGr+Shift. Changes preserve document/caret/selection and reset transient keyboard state.

Added Romanian Standard, Russian, Ukrainian, Hungarian, Vietnamese, Polish Programmers, Turkish Q, Dutch, Swedish, Danish, Norwegian, Finnish and Greek: 24 profiles total, all left-to-right. Physical position mappings use Windows layout definitions, with six Shift/Caps/AltGr layers. Only the chosen mapping expands into a Lua table. Virtual national rows provide additional characters; Vietnamese supports post-vowel tone composition, not an IME/dictionary. Native font coverage and physical Bluetooth acceptance remain device checks.

API 2.18: Screen and Ctrl+Shift+S toggle portrait/landscape through ctx.screen:set_orientation(). Successful choices persist in ctx.state.screen_orientation and restore on load; failure keeps the saved choice. Cancel navigation/redraw and invalidate touch geometry before rotation. The API changes dimensions after the callback; existing frame preparation handles the next geometry. No extra offscreen buffer. Contract api-2.18.2, section 3: https://xtapp-ai.xteink.cc/docs?doc=v2-spec-03#in-app-orientation-change-2-18 (connector knowledge index was still 2.17; read current official page).

Verification: Fengari desktop controller regressions: layout 44, typing/snapshot/autosave 3569, startup 24, timing 105, keyboard/orientation 4673 assertions. Native Pro preview verified language checkboxes, filtered English/Romanian/Russian popup and Screen rotation from 480x800 to 800x480 with no runtime fault. Physical-device/BT testing remains unperformed. Personal GitHub destination odklizec/inkWrite main; final delivery metadata is in docs/GITHUB_SYNC.json on GitHub.

## Maintenance 0.1.42 — 2026-11-01

Typing/navigation after idle now prepares a coherent editor snapshot and requests a frame in the input callback, avoiding the initial timer wait. A 30 ms cooldown groups subsequent inputs on a fixed deadline. If a cooldown expires with no changes, it does not prepare or request another frame. A changed window prepares once and starts the next cooldown. Byte revision, caret, selection anchor, document, font, geometry and viewport changes are checked. Timer exhaustion falls back to immediate preparation. Pause/document-switch cancellation, stale-touch guards, missing-last-file startup handling and 5/30-second autosave remain intact.

Session diagnostics remain app-side only, excluding Bluetooth and physical panel refresh. The owner reported previous maxima of input 16 ms, layout 12 ms, draw 10 ms, queue 197 ms, save 203 ms and input-to-draw 269 ms. Those independent maxima do not prove which event caused the queue delay. This update removes the timer dependency for the first input after idle; it does not guarantee a particular key-to-visible-pixel latency.

Verification includes immediate first preparation, fixed batched deadline, no duplicate standalone refresh, selection-only updates, stale text touch rejection, save accounting and clock wrap, plus existing layout/recovery/startup tests. Exact assertion counts and final cloud/GitHub identity are recorded in the release verification artifact. Original cloud project bc6ebcee-26df-4d19-b814-b9e488605d51; GitHub odklizec/inkWrite main. Physical-device latency remains unmeasured.

## Maintenance 0.1.41 — 2026-11-01

Reduced the typing/navigation burst deadline from 80 ms to 30 ms. It remains a fixed first-input deadline, not a trailing debounce; later keys share the timer rather than postponing it. The coherent prepared editor snapshot, stale touch guard, 5/30-second autosave and missing-last-file startup fix remain intact.

Added bounded session-only timing counters for editor input callback, first queued input to preparation, editor layout/snapshot preparation, editor drawing, public save, and first queued input to frame composition. Counters use wrap-safe monotonic elapsed times and reset on load; pending measurements cancel on pause/document change. No file writes, event logs, text capture or extra refresh requests are introduced. More > Memory & timing displays maxima on demand. Input-to-draw stops after app drawing and excludes Bluetooth transport, firmware input queue before callback entry and physical panel refresh; it is not key-to-visible-pixel latency.

Lua 5.4 controller verification: layout 44, typing/snapshot/autosave 3,547, startup missing-file 24, controlled latency/timing 92 assertions (3,707 total). The controlled test checks exact 30 ms first-input deadline, no extension by later keys, draw/queue/layout/save timing, no extra writes, clock wrap and session reset. Synthetic elapsed times validate accounting only; real Bluetooth/e-ink performance remains unmeasured. Original cloud bc6ebcee-26df-4d19-b814-b9e488605d51; personal GitHub odklizec/inkWrite main.

## Maintenance 0.1.40 — 2026-11-01

Startup now treats Last file not opened: not_found as a stale last-file preference, clears its saved filename/cursor, and opens a fresh uniquely named page. It never recreates the stale filename, overwrites another document, or removes recovery data. Valid recovery still takes precedence. Unreadable, oversized or invalid UTF-8 public files, unreadable/malformed recovery and failure to allocate a fresh filename remain protected. The existing 5/30-second autosave and coherent typing snapshot fix remain unchanged.

Verified with Lua 5.4 controller mocks: startup missing-file suite 24 assertions, existing layout suite 44, typing/snapshot/autosave suite 3,231 (3,299 total). Physical-device startup acceptance remains unverified. Original Studio project bc6ebcee-26df-4d19-b814-b9e488605d51; personal GitHub odklizec/inkWrite main.

## Maintenance 0.1.39 — 2026-11-01

Fixed the recurring Preparing text... screen during typing. Prepared editor frames now retain a coherent bounded snapshot of visible rows, selected text and its measured rectangles, caret position and scroll-indicator inputs. Drawing can present that snapshot while a newer buffer revision waits for the existing 80 ms burst deadline. Drawing never slices the newer buffer using old row offsets. Text hit testing retains the actual displayed document/revision and rejects stale edits. Geometry/font/view/document changes prepare immediately in lifecycle/input callbacks even when a burst timer is pending; unexpected geometry changes during draw retain the existing one-shot recovery path. No whole-document copy, new font or framebuffer added.

Autosave now waits for five idle seconds or thirty continuously dirty seconds (previously two/ten). Explicit Save, save-before-switch, pause/leave recovery, conflict preservation and save-failure retry rules remain unchanged.

Verification: existing layout regression 44 assertions; new timing/snapshot/autosave regression 3,231 assertions, Lua 5.4 controller mocks. Cases include edits after preparation before draw, replacement of UTF-8 text with an active selection, 200 continuous edits, stale touch rejection, notice geometry, rotation, timer exhaustion, 5/30-second boundaries, failed autosave, immediate explicit save and exact pause recovery. These are desktop tests, not Bluetooth/e-ink hardware timing certification.

Original cloud project: bc6ebcee-26df-4d19-b814-b9e488605d51. GitHub destination: odklizec/inkWrite main. Delivery verification is recorded after source/cloud synchronization.

## Maintenance 0.1.38 — 2026-11-01

Editor, help and typography wrapping now runs before drawing in lifecycle,
input or timer callbacks. Continuous typing retains its 80 ms frame deadline.
Unexpected geometry changes queue one preparation and suspend stale text hit
testing until the prepared frame is presented. Loading, file operations,
custom font opens and layout explicitly extend the active callback budget.
Final lifecycle recovery remains bounded and does not attempt to extend on_leave.
Existing 32 KiB buffer, recovery-first saves, conflict copies, close choices,
eight font attempts and sliced navigation/rename remain in place.
Manifest and runtime version: 0.1.38; API 2.17. Physical-device timing remains
unverified; desktop regressions cannot establish e-ink latency.

# inkWrite handover

## Maintenance 0.1.51 — Markdown source shortcuts (no rendering)

Owner asked whether inkWrite really supports Markdown, and chose the cheap path
now with a preview toggle possibly later.

Answer recorded plainly: inkWrite writes and edits Markdown *source*. It does
not render it. Headings are not enlarged, `**bold**` is not bold, list and
quote markers stay visible, and there is no preview mode. The only formatting
help before this version was Ctrl+B / Ctrl+I, which wrap the selection in
`**` or `*` and refuse in .txt files.

Added this turn (marker insertion only; no layout or drawing change):

| Key | Effect |
| --- | --- |
| Ctrl+1..Ctrl+6 | Set that heading level on every selected line |
| Ctrl+0 | Remove the heading marker |
| Ctrl+L | Toggle `- ` bullet |
| Ctrl+Quote | Toggle `> ` quote |
| Ctrl+K | Link: wraps selection as `[text]()`, unwraps an existing link, or inserts `[]()` with the caret inside the brackets |

Behaviour:

- All of them are editor-only and .md-only; .txt gives the existing "Markdown
  formatting is available in .md files" message (now shared by
  markdown_doc/markdown_action).
- Heading and marker commands apply to every line the selection touches and
  replace the block in one buffer call, so byte offsets stay valid and undo
  records a single step.
- Set-heading replaces an existing level rather than stacking (`## ` -> `# `),
  toggles off when the level already matches, and leaves `#hashtag` alone
  because a heading needs a space after the hashes.
- Two scoping bugs were caught and fixed during the work: markdown_action was
  first declared before markdown_doc (nil capture at definition time), and the
  first caret heuristic used a tail offset; markers now records the caret's line
  and column, then re-applies it after the marker shift.

Verification: the 16-case transformation suite (heading add/toggle/replace,
hashtag non-heading, empty line, quote and bullet toggles, caret before/after
shift on line 1 and line 2 of a multi-line block) passed. Native preview booted
with an .md document and drew plain source. Ctrl combinations cannot be sent
through run_project, so the key path itself was checked by reading the code.

Still not supported on purpose: on-screen rendering, hidden markers, and
rendered preview. That is the later, expensive piece.

## Maintenance 0.1.50 — counters show last / average / worst

Owner corrected the 0.1.49 reading: draw was 76 ms, not 763. So nothing
regressed; input 13, layout 10, draw 76, key to prepare 30 are all at or better
than 0.1.47. Key to drawn (1100 ms) is dominated by the panel: a frame takes
about 650 ms and a request during a refresh merges into the next one, so honest
values are 650-1300 ms. The 28 ms reading in 0.1.47 was one lucky sample taken
as a draw finished, which is why a max-only counter misled twice.

Change: timing() now keeps last, count and sum as well as max, and the page
prints "last/avg/worst" per counter. Six metrics no longer fit the More menu's
box (about 126 px in landscape), so Memory & timing became its own view
("timing") with a full page; the menu item still opens it and Back/pager
returns. Text is capped at ten lines so the landscape page does not clip.

Save went 140 -> 183 ms: that is the SD card, not the app; the write is outside
the keystroke path either way.

## Maintenance 0.1.49 — the 250 ms window was a regression; revert it

Owner measured the 0.1.48 diagnostics on the device:

| Counter | 0.1.47 | 0.1.48 |
| --- | --- | --- |
| input | 15 | 9 |
| layout | 9 | 4 |
| draw | 77 | 68 |
| queue | 30 | 303 |
| save | 140 | 132 |
| input-to-draw | 28 | 1049 |

Conclusion: three of the four 0.1.48 changes helped; the fourth caused a clear
regression. `queue` is measured from the queued keystroke to preparation, so it
rising 30 → 303 ms is almost exactly the added 250 ms coalescing window, and
input-to-draw 28 → 1049 ms is that window plus the wait for a full refresh.

Cause: on this platform a frame requested while a refresh is in progress is
merged into the next frame anyway (contract section 5). A coalescing window
cannot therefore make anything appear sooner; it can only hold the newest text
back past the frame that was already coming. The 30 ms window is a work-saving
grouping for keys pressed within a few milliseconds, not a pace setter.

Fix: COALESCE_MS back to 30. Left alone: the SD-write gating (save fell 140 →
132 min and the gesture no longer sits in a keystroke), the single statistics
update per edit (input 15 → 9 ms), and the longer full-refresh deferral. That
last one is bounded by FULL_REFRESH_HOLD=25000 so a marathon session still gets
ghosting cleared.

Diagnostics wording: the labels now say "key to prepare" and "key to drawn",
and state that key to drawn includes the screen refresh. `queue` is the app-side
part that can be tuned; `key to drawn` is dominated by the panel.

Not verified: the device numbers above are the owner's; this turn's Studio
run was a boot/smoke check in both orientations, and no desktop harness run was
made here. Physical Bluetooth transport remains unmeasured by the app.

## Maintenance 0.1.48 — keep SD writes out of the typing path

Owner asked what else can make the device respond faster while typing on the
Bluetooth keyboard. The panel sets the floor: one presented frame is about
650 ms, and a frame requested during a refresh merges into the next one. The
app's own input, layout and draw callbacks were already small (owner-reported
maxima 16/12/10 ms); the reported outliers were queue 197 ms and save 203 ms,
both SD writes. Four app-side changes, none of which shortens the panel time:

1. The statistics checkpoint is no longer written from a key callback. An edit
   only marks the minute checkpoint as due; `on_tick` writes it once the keyboard
   has been quiet for 700 ms, or unconditionally when 180 s have passed since the
   last checkpoint. Pause/exit and opening Statistics still flush immediately.
2. Autosave no longer fires on "30 continuous dirty seconds". It fires after 5 s
   without a keypress, and forced after 120 dirty seconds so a marathon session
   is still saved. The idle tick is now the only place a public save starts.
3. One word/statistics update per edit instead of two (the word delta computed
   in `insert` is passed through `changed`).
4. The typing coalescing window grows from 30 ms to 250 ms, and the automatic
   full-refresh deferral from 1.5 s to 4 s per edit. A frame takes about 650 ms
   anyway, so the shorter window only re-ran layout for a frame that could not be
   shown sooner, and 1.5 s let a full refresh land inside slow typing.

Save guarantees are unchanged: recovery is still written before the public
file, external edits still produce a conflict copy, and a failed save stays
visible and blocks the next write until another edit or an explicit save.
Statistics after a sudden power loss can now lose up to about three minutes
instead of one during an unbroken session; pause and exit lose nothing.
HD/Bluetooth transport and the firmware input queue remain outside the app.

Verification: native preview only in this turn; the desktop harness in the parent
workspace was not re-run here, and the physical Bluetooth timing is unmeasured.

## Identity and scope

- App ID: `inkwrite` (new app; preserve this ID for upgrades).
- Version: `0.1.0`, development milestone A.
- Manifest API: `2.17`; Gancao firmware support required.
- No network permission. Wireless export is explicitly outside release one.
- inkStream is inspiration only; no inkStream app identity, saved files, artwork, or source has been overwritten.

The saved product plan is `outputs/writerdeck-plan.md` in the parent workspace. The project lives in `outputs/inkWrite/`.

## Architecture

`index.lua` delegates lifecycle to `domain/app.lua`. `buffer.lua` is a bounded UTF-8 two-stack block buffer, `layout.lua` lays out a bounded source window, and `documents.lua` owns public SD writes and private recovery. No document body is placed in `ctx.state`.

Public files: `/AppFiles/inkwrite/`. Private recovery: `recovery.txt`, with a version header, target filename, and unescaped text. Recovery is written atomically before public replacement. Failed reads protect data rather than silently create an empty replacement. Conflicts save separate files. Unknown/corrupt recovery is preserved and blocks mutation.

No unbounded retries, decompression, large directory cleanup, images, or native font proliferation. Save snapshots still require contiguous strings, with a 32 KiB document cap. Synchronous save timing is an explicit remaining hardware question, not solved by desktop tests.

## Local verification

Run from the parent workspace: `node work/test-inkwrite.js`. The harness lives under `work/` and uses the already-installed Fengari runtime. It compiles project Lua and performs randomized buffer/model comparisons plus storage/lifecycle/controller tests. The running assertion count includes per-measurement invariants and does not represent independent scenarios.

Final local run: 331,818 checks passed, including end-of-document caret regressions and the final footer geometry. Re-run after every meaningful source change. This is a count of assertions, including repeated invariants, not independent test scenarios.

## Preview and packaging

The official `run_xtapp_preview` connector rejected the native Windows project directory as non-absolute, for both slash spellings. Do not work around this by pointing it at inkStream or by changing source files in that project. Studio fallback uses a separate inkWrite project and a source backup import. Preview, cloud-save, and package results must each be recorded from observed completion; none follows merely from a successful local test.

The fallback created a separate local Studio draft named inkWrite (source project ID `0b2b1e60-15a4-436a-8bad-8914be0796e4`) using the built-in template. Its initial backup was inspected only to prepare the import format. The source upload was then rejected by automatic approval review because implementation/preview authorization was not treated as authorization to transmit non-public source to the external XTApp Studio service. Do not retry or bypass that rejection without explicit user approval. The draft still has the template source, not this implementation. No official inkWrite runtime preview, cloud save, or installer export is claimed.

`inkWrite-Studio-backup.zip` in the parent outputs directory contains the implementation ready for the approved import. `inkWrite-0.1.0-source.zip` contains the same app sources for local review. The PNG views were rendered from actual controller drawing commands using local mock font metrics; they are approximate local views, not Studio or device screenshots.

## Required device checks

1. Install through official Studio on compatible X4Pro and X4Classic firmware.
2. Type continuously, including held Backspace and arrows. Check no lost/duplicated keys during refresh and autosave.
3. Save and retrieve a Markdown file manually from the SD card; compare exact bytes in a computer editor.
4. Reopen, edit, save, sleep/forced-exit while dirty, and check recovery preserves the prior public file.
5. Test full/missing SD and external same-length edits; ensure failure is visible and originals survive.
6. Measure save callback wall time at 32 KiB. If the 1,000 ms budget is threatened, split stages safely without admitting new mutations into a stale save transaction.
7. Compare post-GC heap at a fixed document size/undo state through repeated cycles. Native font/Wi-Fi/device memory is not measured by Lua heap.
8. Verify menus, selection inversion, long-line wrapping, and exit access on both device profiles.

## Next implementation work

After the device baseline is sound: coalesced undo, stable word-aware layout/navigation, Unicode filename handling, recovery-resolution UI, non-destructive read-only oversized-file viewing, font picker with a session pair budget, spacing/margins, clipboard/formatting, Compose input, journal library refinements. Keep wireless export deferred.


## Current update: 0.1.1

The owner confirmed that 0.1.0 types from Bluetooth, saves/loads files, and changes text size, but typing feels slow. Preserve app_id `inkwrite` and upgrade in place. No storage schema change.

Reflow moved out of per-key callbacks. A single 80 ms burst timer schedules drawing; a held stream cannot indefinitely postpone painting. Unchanged layout prefixes and caret-only layouts are reused. Automatic full refresh is deferred 1,500 ms from each edit; Ctrl+R requests a manual full refresh if ghosting accumulates. Timers cancel on pause/leave/document switch, and allocation failure falls back to immediate invalidation.

Full local regression: 22,884 assertions passed. Additional batching/cache suite: 31,300 assertions passed. In the fixed 600-character/50 ms mocked input stream, 39,114 old measurement calls fell to 1,741, and 600 draw requests became 300. This does not quantify hardware speed. A 960-character queued burst made zero layout measurements in input callbacks and saved exact bytes. Incremental layouts matched clean recomputation after 180 varied edits.

The existing Studio cloud project is bc6ebcee-26df-4d19-b814-b9e488605d51. The user explicitly approved source upload in the prior turn; that authorization persists for this update. Do not create another project or change installation identity. Updated runtime files are domain/app.lua and domain/layout.lua, plus manifest version 0.1.1. Update README/handover alongside source.

Owner clarification: typing was on X4Pro; text eventually catches up correctly, rather than losing characters. Treat this as a display-lag report, not a confirmed Bluetooth event-loss defect.


## Current update: 0.1.2

Pro tap-to-caret now uses the exact drawn row geometry and actual font-prefix measurement. UTF-8 code-point boundaries are preserved; blank area below text maps to the last visible row end. Taps after queued edits are rejected until a new frame is drawn. This guards stale text revisions but is not a firmware present-completion signal. Touch dragging/selection handles remain deferred.

Added a bounded 8 KiB app-local clipboard (Ctrl+C/X/V) and source Markdown bold/emphasis toggles (Ctrl+B/I), including marker-pair insertion at an empty selection. A cut exceeding clipboard capacity leaves text unchanged; .txt formatting commands do not mutate content. Storage and app identity unchanged.

Owner hardware feedback: 0.1.1 may be a little better, but speed difference is hard to judge. Do not claim proven speedup. Full local suite including touch/clipboard/formatting checks: 23,385 assertions passed; performance suite remains 31,300. Official preview/export verification is recorded in the release verification output.


## Current update: 0.1.3 — orientation

Portrait and landscape are now first-release requirements. Manifest follows system orientation. The API 2.11 contract (section 3) says changes occur between callbacks and pointer coordinates are transformed by the host. No raw sensor, sensor capability flag, or native runtime setter is exposed. Do not claim known sensor behavior on either physical device.

Editor draw invalidates layout caches on width/line-count changes even when the document revision and caret are unchanged. Touch snapshots carry a geometry key to reject pre-rotation hit testing. Menus/library use touch pagers and keyboard page navigation; help pages reflow to available width/height. Orientation menu text explains the host boundary. No document schema/app identity change; upgrade in place.

Local tests: 24,184 full-suite assertions and 31,300 batching/cache assertions pass. Hardware auto-rotation/manual firmware controls remain to be checked. Current runtime code change is domain/app.lua plus manifest 0.1.3/system orientation.


## Current update: 0.1.5 - typography

Owner says X4Pro has no automatic rotation; defer rotation UI to UI finalization. Do not spend this phase on sensor detection. Classic behavior still needs physical checking.

Typography uses explicit SD installed/open APIs with capability checking, system fallback, validated primitive preferences and at most eight attempted native font/size pairs per load-to-leave session. Successes and failures are cached; there is no claimed native font eviction. No native font calls occur in drawing. The picker retains at most 64 installed names (the host returns a whole list first). Existing 1024 KiB reserve stays unchanged. Spacing/margins use shared editor geometry, including touch snapshot invalidation. The app retains document/caret/selection while settings are changed. Raw Markdown file bytes and storage formats are unchanged.

Local verification: 25,523 assertions in full suite, 31,300 in typing/cache suite. New cases cover successful and failed fonts, cached failures, eight-attempt cap, no draw allocations, preference restore/validation, selection/content retention, and portrait/landscape at largest typography settings. Native firmware memory and SD font behavior still need owner checks. Official preview and export results are recorded separately with the delivery artifacts.


## Current update: 0.1.6 - everyday editing

Owner accepts typography on hardware. Added continuous-typing undo grouping through an optional buffer group token. Only adjacent insertions with the same token merge, up to 256 bytes; redo branches never merge with old history. Word/one-second pause/navigation/commands/save/pause delimit groups. Selection replacement, paste, deletion and formatting are standalone. History retention caps unchanged.

Word wrapping prefers ASCII space/tab boundaries while preserving all bytes. Rendered rows retain a conservative lookahead dependency for incremental invalidation. Existing cache equality tests plus 350 varied word-wrap edits match clean recomputation. Unicode words without ASCII spaces use character-boundary fallback. No public API, storage schema, font reserve or app identity change.

Local full suite: 44,980 assertions. Typing/cache suite: 31,718 assertions; input callback measurements remain zero in the 960-character burst. The fixed 600-character stream is 2,154 measurements / 300 draws. This modest layout increase is expected for word wrapping and is not a hardware latency claim. Native preview/export verification is separate.


## Current update: 0.1.7 - library and menu version

Owner accepts 0.1.6 and requests visible version identification. Menu subtitle now shows Version 0.1.7; the desktop runner requires equality with manifest.version. Keep these synchronized for future releases.

Public filename validation now follows current contract section 29 rather than an ASCII whitelist. UTF-8 names are preserved exactly through opening, saving, private recovery and conflict/recovered copies. Font glyph coverage remains a separate concern. Library rows show bytes and a warning above 32 KiB; geometry.row is shared by drawing, paging and touch. No rename/delete introduced and oversized files remain rejected intact. New dated names and storage schema remain unchanged.

45,047 full-suite assertions and 31,718 typing/cache assertions pass. Added accepted/rejected filename cases, Unicode save/recovery/external-change checks, visible menu version, library byte/oversize rendering and landscape paging. Owner device acceptance and official preview/export are distinct verification layers.


## Current update: 0.1.8 - navigation

Owner accepts 0.1.7; international keyboard layouts were added to the product roadmap as important upcoming work, without fixing their sequence. This phase implements whitespace-delimited Ctrl/Meta word movement, viewport paging, Shift selection and retained vertical target X. Word scanning uses a local bounded window and long-run 1 KiB hops. Upward reconstruction uses eight-row timer slices and at most 64 row descriptors (no retained text/whole-document index). New commands/edits/pause/geometry/font/document changes cancel pending work. Timer allocation failure reports a message without moving the caret. Clean explicit saves now update cursor preferences.

Local full suite: 54,312 assertions. Typing/cache suite remains separately checked. New cases cover UTF-8 word movement/long-run bounds, modifier repeats, short-row target X, forward/backward pages, Shift paging, cancel-on-edit/pause and timer failure. Hardware navigation latency and long-document upward scanning need owner testing. No file schema or font-reserve change. Keep menu VERSION and manifest at 0.1.8.


## Current update: 0.1.9 - position indicator and browsing

Owner confirms 0.1.8 shortcuts, selection and plain Home/End. Added an orientation-aware passive byte-progress indicator and Pro discrete swipe browsing. A.browsing decouples viewport from caret containment; swipes retain selection/undo/bytes, while typing/edit/navigation restores caret-following. Explicit taps intentionally reposition the caret. Save and pause/resume retain browsing; document changes reset it. Draw/touch use shared geometry and revision/font/document guards. Bottom indicator reserves a 12 px strip. No idle animation/full-document line index; upward browsing reuses eight-row timer slices with at most 64 descriptors.

Local full suite: 62,084 assertions; typing/cache suite: 31,718. New checks cover indicator geometry/empty/short files, viewport-only movement, exact selection replacement after browsing, tap on viewed text, backward scan, header rejection, resume retention and landscape placement/keyboard return. Typing mock remains 2154 measurements / 300 draws and zero input measurements in queued burst. Physical swipe/refresh behavior remains owner acceptance.

Bluetooth investigation: CACOE keyboard, X4Pro firmware 26102401, idle loss needs manual reconnect. Owner will observe whether it also occurs outside inkWrite. No documented timeout/keep-alive control in reviewed API; do not add a pretend setting. No app-level idle disconnect timer is present.


## Current update: 0.1.10 - word count and focus mode

Owner accepts 0.1.9 swipe browsing/progress on X4Pro. Added incremental buffer.words using whitespace transition contributions for old/new replacement ranges with adjacent-byte context. No new document string copies or full-document draw scans; initialization counts once, and undo/redo runs through the same replace path. This is whitespace-delimited source-token counting, not Markdown-aware or language-specific segmentation.

Menu action 11 toggles persisted focus_mode; existing command indices stay unchanged. Editor geometry moves body upward 48 px while keeping Menu, footer/save errors and progress indicator. Standard geometry returns in other views. Selection/caret/undo/browsing retained. No storage schema, native allocation, Bluetooth behavior or app identity change; VERSION/manifest 0.1.10.

64,863 local full-suite assertions and 31,718 typing/cache assertions pass. New randomized count checks compare 1,200 replacements and periodic undo/redo against a fresh reference. Focus tests cover visibility, selection retention, save errors and both orientation dimensions. Native preview and device acceptance remain separate layers.


## Current update: 0.1.11 - focus shortcut

Ctrl/Meta+Shift+F invokes existing command 11 from editor or other views, once on key-down. Repeat/up consumed without retoggling. Menu/help advertise Ctrl+Shift+F. No new preference/storage behavior. Local full and typing/cache suites rerun; official export verification recorded separately.


## Current update: 0.1.12 - quieter footer

Owner accepts 0.1.11 and requests hiding the focus footer and removing routine Saved: filename messages. Geometry now reserves no routine footer in focused editor, 40 px for normal one-line status, or the prior 94 px for important messages/errors. Save success clears the routine message; blank-page startup hint removed (empty-page guidance remains). Menu/other views keep their prior geometry and page hit targets. Position indicator follows the new text area; focus errors remain visible. No storage, input-shortcut or font allocation changes.

65,853 full-suite assertions and 31,499 typing/cache assertions pass after adapting page-size expectations to the expanded viewport. Fixed typing mock: 1926 measurements / 300 draws; queued burst still zero input measurements. Desktop counts are not physical latency measurements. Focus tests assert hidden routine footer and visible save failure. VERSION/manifest 0.1.12.


## Current update: 0.1.13 - journal and .txt creation

Added menu commands 12/13 for Today's journal and New plain text page; prior indices unchanged. Ctrl+J from editor opens the daily journal. Uses device date snapshot and deterministic `YYYY-MM-DD-journal.md`; only not_found allows a new buffer. Existing journal errors never become empty overwrites. Save-before-switch remains mandatory; selecting the same journal retains undo/caret/selection. No automatic midnight switch. Docs.fresh_name accepts only .md/.txt extensions with the existing bounded collision loop. Recovery format and app identity unchanged. VERSION/manifest 0.1.13.

65,870 full-suite assertions; 31,499 typing/cache assertions pass. Tests cover reopening, undo retention, date changes, invalid date, oversized journal preservation, save failure blocking transition, .txt collision suffixes and Markdown-command exclusion. Native preview/export results separate; owner hardware acceptance needed.


## Current update: 0.1.14 - national layouts, first batch

Added keyboard.lua with compact Windows-derived physical-key mappings for Czech/Slovak QWERTZ/QWERTY, plus existing English US. Only active map expands into tables. ASCII-space source word count unchanged. NFC Latin accent pairs are precomputed; unsupported combinations emit literal accent plus character. Right Alt events distinguish AltGr; Ctrl+Alt without Right Alt deliberately not inferred. Alt-modified combinations cannot fire Ctrl/Meta shortcuts. Pending accent state cancels on navigation/commands/menu/pause and is never saved into a document. Caps/Shift layers follow reference tables; US behavior remains compatible.

Menu action 14 opens a keyboard/touch layout picker; choice persists, document/selection/undo retained. App.listen lifecycle unchanged. Runtime root module must be included in Studio and package. VERSION/manifest 0.1.14, app identity/font reserve/storage schema unchanged. This does not complete all common-language layouts: broader rollout remains in the plan.

66,763 full-suite assertions including 866 non-dead layer outputs compared with an independently extracted Windows reference. Controller tests verify exact saved Czech accented text, acute/caron, dead repeat/cancel, Caps, AltGr euro, shortcut exclusion, pause cancellation and selection retention across layout changes. Typing/cache suite remains separately checked. Physical HID mapping, ISO keys, AltGr and reconnect need owner tests; local mapping evidence is not hardware certification.

## Current update: 0.1.17 - compact Tool shelf UI

Selected design implemented with direct vector drawing: compact document title and aligned keyboard/save/count row, four-action bottom dock, secondary Focus/Orientation/Typography/Keyboard shelf, and More route to version/help/exit. New chooser retains daily/Markdown/plain-text commands. No new assets, native font pairs, screen buffers or permissions. Focus retains keyboard icon and language code, word icon/count and overflow-only position bar; long hold on writing restores controls. Classic OK enters action navigation; arrows select, OK activates, Back cancels or exits focus. Panels own input and suspend typing/swipes; selection and document bytes survive tools. Orientation tool explains system controls because no runtime rotation API is verified.

Local full suite 69,006 assertions; typing/cache suite 31,816. 960-character burst still zero input measurement calls; 600-character stream 2,226 measurements / 300 draws (one small count-width measure per draw added). Geometry, overlay input ownership, Classic routes, aligned status, focus recovery, New .txt and SD retention checked through real controller. Official preview and package evidence recorded separately. Hardware e-ink feel and native heap acceptance remain unverified; owner BT hardware currently unavailable.


Official portrait previews: Pro opened an SD fixture and keyboard picker, selected CZ, entered focus with 640-word document and visible progress, and long hold restored controls (all handled/drew, fault null). Classic OK/right reached the shelf and focused Focus, OK entered focus, Back returned (fault null). Short shelf captions Screen and Type avoid crowding at native small-font metrics; their tools are Orientation guidance and Typography. Native landscape is not claimed; both orientation geometries are controller-tested. No physical device or BT test this phase.


## Current update: 0.1.19 - compact settings and file management

All views now share the editor header/dock positions, with 44 px settings/library rows and a bottom Back/Prev/page/Next bar. Header status groups remain aligned; word icon is ab with a whole-word bracket. Shelf is five equal buttons Focus/Screen/Type/Keyb./More; no separate More heading. More retains only SD location, keyboard help, memory sampling and Save/Exit. Internal command indices unchanged but visible More rows map to 6/7/8/9.

Library rows draw filename, pencil/trash controls and right-aligned byte size on one line. Classic Left/Right selects Open/Rename/Delete for current row; Up/Down moves rows, PageUp/Down pages. Rename uses full-screen system text input (also accessible without BT), validates names and refuses collisions/case-only changes. The public API has no native rename: Docs.rename copies/appends and compares in bounded 1 KiB timer slices, verifies size then removes source; failures or pause/leave keep original and may leave a new partial copy. No automatic resume after power loss; duplicate/copy preservation takes priority. SD concurrent modifications are not atomic/locked by public API; detectable content/size changes abort. Avoid externally editing files during rename.

Delete opens a custom warning page with Cancel selected by default. Explicit Delete required. Matching recovery must match saved SD data and be removed successfully before mutation. Deleting current file detaches to a fresh untitled draft, clears last-file preference and avoids autosave resurrection. Renaming current file updates doc/state association. Neither action invokes opening/reading the full file from draw. Source copy lifetime bounded to chunks; no extra fonts/native buffers.

Local suite: 69,224 assertions. Failure cases include append/read comparison/removal/scheduling, cancellation and source changes, collisions, recovery mismatch, current-file association and no resurrection. A 72 KiB UTF-8 file is renamed with max 1 KiB reads. Typing/cache: 31,816 assertions, same 2,226 measures / 300 draws and zero input measurements in 960-character burst. Native preview/export evidence recorded separately.


Native Pro portrait preview verified compact single-line library, size alignment, 44 px row/action targets, Delete warning with Cancel selected and cancellation without mutation, Typography shared geometry, More four nonduplicated actions/version, and system rename screen with on-screen keyboard plus cancellation. Connector reported an outdated-plugin warning; session/project ID was verified before simulator input and all source updates used the exact original project through Studio UI. No real SD deletion/rename was performed through preview; destructive success paths are controller-mock tested. Native Classic and landscape checks are recorded separately if performed.


Official Classic portrait: OK/Right opened library, Right/Right selected trash, OK opened the warning with Cancel visibly selected, and OK cancelled without mutation. Final selection-following-rename and help-label corrections passed the local suite; native destructive-success paths remain intentionally unperformed.


## Current update: 0.1.20 - refined controls and close flow

Library is filename / compact size / pencil+trash; sizes below 1000 use B, larger use decimal whole kB (16473 => 16kB). Size values right-align to the central column's common edge. More title and version are separate, version at top-right. Heap sample lives in A.memory_sample and draws only in More, never the shared footer. More no longer contains a quit row.

Typography follows inkStream's size gauge (A-/value points/A+), font picker and S/M/L spacing/margin segments. Shared geometry drives keys/taps, settings apply immediately and retain eight-pair native-font budget. Word icon letters now use single-pixel vector strokes, matching keyboard icon weight with no font/buffer addition.

Editor Back or header X opens a Fifteen-inspired opaque close modal; Cancel selected. Clean close confirms; dirty close offers Cancel/Save/Discard. Autosave pauses while modal is open, input cannot reach document, save errors keep app open, and explicit discard removes matching private recovery and skips on_leave recovery creation. Protected files remain untouched. Selection survives cancellation.

Owner explicitly chose firmware-controlled rotation over an offscreen-buffer prototype. No new buffer/API invented. Screen page removes sensor text and shows Portrait/Horizontal device illustrations (home button on Pro, four bottom keys on Classic), with firmware rotation note. Illustrations are not fake rotation switches; manual/mirrored app rotation deferred.

Local full suite 70,224 assertions; typing/cache 31,816, unchanged 2,226 measures/300 draws and zero input measurements in queued 960-character burst. Tests cover compact size column geometry, diagnostic visibility, custom-close cancellation/save/discard/failure/recovery in both orientations, gauge controls and native-font allocation boundaries. Official preview/export evidence separate.


Official Pro portrait preview: thin word icon and header X, typography font/size gauge/SML controls, close modal with Cancel selected and cancellation, More version right-aligned with heap sample, and subsequent library showing central B/kB values and rightmost actions with no diagnostic leakage. Classic Back then OK handled/drew with quitRequested false, confirming cancel route. All observed final outcomes fault null; native dirty Save/Discard not performed, covered locally. Source identity/session verified despite recurring old-plugin warning. No new buffers/assets/font pairs.


## Current update: 0.1.21 - live typography sample

Typography begins with a bounded three-line Lorem Ipsum preview rendered using the actual selected body font, size, line spacing and margins. The sample is a separate short buffer, never document/recovery/state content. At most three wrapped rows are cached by font/width/count; spacing affects placement. No font opens or offscreen layers are introduced by preview drawing.

Portrait controls shift below the sample. Landscape places font and size side-by-side, then spacing/margins beneath; About SD fonts becomes a header ? target. Shared geometry serves draw/keyboard/touch. Important notices may reduce preview line count if room is constrained. Existing document, selection and font pair budget retained.

Full local suite 71,784 assertions; typing/cache 31,816. Preview tests verify three rows, real metrics/margins, no overlap, controls above dock, no extra native opens and unchanged document bytes in both orientations at normal/largest settings. Typing mock unchanged at 2,226 measures/300 draws and zero input measurements in queued 960-character burst. Native preview/export evidence recorded separately.


Official Pro portrait preview verified three Lorem Ipsum rows above the moved controls. Selected system size 30, L line spacing and L margins through touch; preview grew/reflowed/inset immediately and controls remained below it. All final touch outcomes supported/handled/drew with fault null. Exact session and original project ID checked; initial startup still reported Classic before profile settled, and that early frame is not claimed as Pro evidence. Native landscape not claimed; responsive two-column layout checked through controller tests.


## 0.1.22 fixed typography controls

Typography controls are anchored above the bottom bar and stay in place when font, size, line spacing or margins change. The preview now fills up to five lines, using fewer only when the available height is constrained, such as large text in landscape.
Bounded preview cache remains separate from document; no extra fonts or screen buffers. Local suite: 72,262 assertions; performance suite 31,816, unchanged 2,226 measures/300 draws. Tests check fixed font-control coordinates after size, spacing and margin changes in both orientations.

## 0.1.24 touch keyboard and post-letter accents

Accent keys now apply to the character immediately before the caret: c then caron becomes č. No accent-order preference. Unsupported combinations insert the literal accent; holding an accent key does not repeat it. Each accent replacement has its own undo step.
Tap the keyboard icon or US/CZ/SK status abbreviation for a quick language popup, including focus mode. Selection survives switching. Settings > Keyb. now toggles the built-in on-screen keyboard; swipe up starting within the bottom 32 pixels also opens it. Hide or Back closes it. It uses the document buffer directly, keeps the caret above five 50-pixel key rows, and offers Shift, symbols, language popup, spaces, newline and backspace. Czech/Slovak QWERTZ swaps Y/Z; accents are post-letter. Classic buttons navigate virtual keys. This is a lightweight app keyboard, not a native IME/dictionary. No native font pairs or screen buffers added.
Local suite 72,337 assertions; performance 31,816, unchanged 2,226 measures/300 draws. Real BT/device acceptance remains required. Portrait and landscape mock checks cover popup ownership, selection preservation, accent undo, edge activation, virtual accent insertion and Back dismissal.

## 0.1.25 virtual keyboard layout and focus gesture

Removed Lang key (language remains in the status popup). Hide and Delete now occupy the upper left/right corners. Space uses 55% of the bottom-row area; a tall Enter key spans the final two rows. Swipe down starting on the virtual keyboard dismisses it without editing. Two nearby taps within 450 ms in the visible text area enter focus mode; document/revision changes and non-text gestures clear the sequence. Single-tap caret placement and existing focus exit routes remain.

## 0.1.26 text-area multi-tap gestures

Double-tap a word to select it; a third nearby tap selects its sentence. Double-tap empty text-area space toggles focus both on and off. Tap chains expire after 450 ms between taps, require the same drawn geometry/font/document revision, and reset on keyboard input or non-text gestures. Selection scans the bounded document in 1 KiB chunks. Sentence boundaries are period, question/exclamation marks, CJK equivalents, ellipsis and newline; this is punctuation-based, not linguistic abbreviation parsing.

## 0.1.27 stable multi-tap targeting

Raised inter-tap tolerance from 450 to 1200 ms for e-ink refresh latency. Later nearby taps reuse the original byte target and text/blank classification instead of re-hit-testing a changed caret view. A sequence is anchored within 28 pixels of the first tap and invalidates on viewport/font/geometry/document/revision changes. The line-spacing gap belongs to its text row, preventing false blank-space focus toggles. Caret-follow scrolling is suppressed during the tap chain. Added 800/900 ms gap and vertical-drift regressions; physical touch acceptance still required.

## 0.1.28 native fast double taps

Corrected missing support for firmware gesture double_tap. Fast sequences arrive as tap/double_tap/tap; previously only tap was counted, explaining slow-only operation. Use pointer time_ms rather than callback clock for multi-tap spacing so redraw/queue delays do not expire a real rapid sequence. Native double_tap counts as a double even if the preceding tap was unavailable; existing 1200 ms slow fallback retained. The public API does not expose device tap-delay settings; Home-area tap delay is separate from pointer recognition (documented native double-tap threshold: downs within 300 ms and under 20 px). Regression tests simulate native classification and multi-second callback delays with 150 ms captured tap spacing.


## Documentation refresh — 27 October 2026

Owner confirms 0.1.28 fast multi-tap behavior works. Replaced cumulative/outdated README with current user guide; preserved original in DEVELOPMENT-HISTORY.md. Added STATUS.md, RELEASE-CHECKLIST.md and draft STORE-LISTING.md. No executable, manifest or release-version changes. Bluetooth currently works on Pro; full idle/reconnect and long-run hardware certification remain outstanding.


## 0.1.29 common national keyboard profiles

Added German QWERTZ (00000407), French AZERTY (0000040C), Spanish Spain (0000040A), Italian (00000410), Portuguese Portugal (00000816) and Portuguese Brazil ABNT2 (00000416). Physical-position tables extracted with Windows MapVirtualKeyEx/ToUnicodeEx without activating the layout; six layers include Shift/Caps/AltGr. Existing post-letter composition and only-active-profile table expansion retained. No IME dictionaries or native fonts added; packed constants do increase Lua module memory. German/French Ctrl/Meta letter shortcuts follow layout letters. BR distinguishes Brazil from PT in status.

Language popup is paged using shared draw/hit geometry, with Prev/Next, arrows and PageUp/Down; all rows stay above the virtual keyboard and within landscape screen. Virtual alphabet follows German QWERTZ/French AZERTY; the basic virtual symbols page is unchanged and is not a complete national physical-key replica. Extra ABNT/ISO positions depend on firmware; Brazilian AltGr+Q provides slash. No Swiss, Canadian, Latin-American Spanish or alternate French layout variants claimed.

Local suite 74,042 assertions; performance 31,816 unchanged. New mapping layers compared with Windows reference, saved national characters checked byte-for-byte, AZERTY Ctrl+A tested and last popup page reached in portrait/landscape. Physical BT acceptance, native heap and new-profile reconnect tests pending.


## 0.1.31 statistics and alphabetical layouts

Reconciled prior cloud manifest 0.1.30/controller label 0.1.29 by making this feature build explicitly 0.1.31 in both. Preserve uploaded app_icon_s/app_icon_l and preload declarations. Layout IDs remain stable; names sorted alphabetically at module load, explicit US fallback retained.

Added domain/stats.lua and More → Statistics. Current calendar week Monday–Sunday, calendar month and year switch in one view. Bars show daily/monthly typing seconds; totals show inserted word increases, typing and foreground app duration, average over elapsed days including zero days. 30-second editing grace, no offline credit. Existing documents not backfilled. Integer Gregorian dates, 400-day bounded packed history, checkpoints every 60 seconds and pause/exit. Private writing-stats-v1.txt contains only counters; corrupt/unreadable data protected, recording/save errors isolated from document saves. No native fonts/buffers added. Native heap/device acceptance pending.

## 0.1.33 national virtual character row

Added language-specific direct characters below numbers, uppercase via Shift, and a More key for rows longer than nine characters. Czech/Slovak include their common accented letters; German ä/ö/ü/ß, French accented vowels/ç/œ/æ, Spanish accents/ñ/¿/¡, Italian accented vowels, and both Portuguese variants their accented vowels/ç. English US shows useful punctuation instead of Czech marks. Main accent controls now follow the selected layout: Czech/Slovak acute/caron, German diaeresis/circumflex, French grave/circumflex, Spanish acute/diaeresis, Italian grave/acute, Portuguese tilde/acute. Post-letter accent semantics retained. Six compact 44px rows occupy 264px; text and popup geometry share that height. No native fonts/buffers added.

Native Pro system font lacks capital sharp-S (ẞ); the German shifted virtual key uses conventional SS instead, avoiding an empty glyph and inserting the two letters.


## 0.1.34 Statistics shortcuts

Tap the word-count icon/number in the editor status area to open Statistics, including focus mode. Swipe left starting within 32 pixels of the right edge for the same page. Existing More route and Back return remain available; opening statistics preserves document, caret, selection and focus state and dismisses the virtual keyboard. No extra toolbar slot, fonts or buffers.


## 0.1.36 memory and allocation work

Reviewed the owner-supplied InkStream_memory.md and inkStream 1.0.54–1.0.57 implementation. The firmware allocator fix described in that correspondence is not assumed to be installed. inkWrite has no feed parser, networking or decompression, so those changes do not apply. Routine forced collections were already absent; only the explicit More memory diagnostic collects. Typing redraws and minute-level statistics checkpoints were already batched.

Buffer block construction now walks the original input rather than copying its shrinking tail. Single-block slices return directly without temporary closures/join tables, stop at the requested range, and byte/boundary/caret queries avoid string slices. UTF-8 boundaries, 32 KiB document limit, undo grouping/limits and exact source bytes are retained. No whole-document cache or extra native font/framebuffer allocations.

Pause/exit recovery records only the successfully saved document identity/revision, avoiding a second identical snapshot on immediate exit. New edits, a different document and any public-save attempt invalidate that reuse; failures are retried. Recovery-first public saves and external-edit/conflict checks remain intact. Read-back in these safety paths and rename verification is intentional, unlike inkStream's immutable body writes.

A deterministic 30,400-byte open/navigation/edit scenario reduced substring payload bytes from 533,721 to 92,804 (82.6%), substring calls from 2,427 to 295, joins from 1,902 to 1. Opening alone went from 466,716 substring bytes to 30,400. These are instrumented allocation-work counts, not native allocator, peak heap or physical typing-latency measurements. Full controller/UTF-8/save regressions: 74,741 assertions. Typing cache/batching: 31,816 assertions, unchanged stream measurements and frame count. Physical-device acceptance remains required.


## 0.1.37 Shortcuts and transient notices

Swipe right starting within 32 pixels of the left screen edge to open the paged Shortcuts reference, including focus mode. Back restores the editor and its focus state; More > Keyboard help remains available. Text, caret and selection are preserved. This uses the existing page renderer without slide animation or additional buffers. Font-picker notices and other transient messages dismiss on the next deliberate touch/key action; file-job guards, protected state and save-failure indicators remain. Pointer movement and trailing keyboard releases do not dismiss a newly created notice.




