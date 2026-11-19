# Split screen: reviewed plan and first implementation milestone

Reviewed 19 November 2026 against main `2dc835e10c381ef07bc0c998323949240bdc698c`.
Manifest 1.0.22 / API 2.26; runtime menu constant remains 1.0.20, matching the
existing source. No release version change is part of this test branch.

## Actual baseline and changes since the original plan

PR #1 is merged. `phase0/github-sync-audit` is historical; new development starts
from main. The canonical Studio project is the original inkWrite,
`bc6ebcee-26df-4d19-b814-b9e488605d51`. The old Phase 0 project is superseded.
The latest cloud consolidation and 1.0.22 manifest are recorded on main; this
task does not claim a new live cloud audit or overwrite that cloud project.

The writer now includes optional foreground automatic uploads, two-way conflict
review including named non-active SD files, a GitHub attention badge, immediate
touch caret/selection publication, and general connection setup with isolated
destination profiles. All must survive the split implementation. The original
plan's statements that automatic sync is absent and Phase 0 is still a draft are
superseded. Baseline: 30 suites / 16,177 assertions pass locally.

## Product behavior retained from the plan

- Horizontal means A above B; vertical means A left of B. Ratios 1:1, 2:1 and
  1:2 always describe A:B and never reverse when activation changes.
- Normal and focus modes show both documents at the selected ratio. Focus hides
  normal chrome, retaining compact filename/dirty/error indicators and an active
  badge. Screen rotation preserves session identities and positions.
- Each document owns text, saved base, undo/redo, caret/selection, scroll and
  prepared rows. Typography, clipboard, statistics, keyboard and GitHub
  connection remain shared. Statistics must count elapsed time only once.
- Save/New/Open/journal target a captured pane. A failed save blocks replacing
  that pane. Opening an already-loaded filename selects its existing pane;
  case aliases must not create two writers for one SD path.
- Disabling split retains the inactive session and its recovery/autosave. A
  workspace holds at most two sessions; no hidden third document is allocated.
- Pro: pane-header/text touch activation. Classic: Left/Right activation while
  editor input is owned, Up/Down document navigation. Ctrl+Tab switches panes;
  Ctrl+Shift+P and Settings > Split screen open layout controls. Focus needs a
  reachable compact actions route on Classic without a touch dependency.
- Touch gestures belong to their starting pane. Active markers use shapes and
  black/white contrast. Headers retain a 44 px touch target when space permits.
  Narrow panes use capped inner margins without silently shrinking the font.
  A keyboard-obscured pane with no full row retains its identity and offers Hide
  keyboard; it must not draw an invented row outside its rectangle.

## Ownership and persistence

`A.editor` now owns document/view state. `domain/editor_session.lua` owns session
construction, change tracking, selection, save, checkpoint and saved snapshots.
The controller still has exactly one active session in this milestone.

`domain/workspace.lua` supplies a bounded two-slot model, duplicate detection,
reserved filenames and activation guarded by outgoing recovery. It is not yet
connected to the writing-screen UI. `domain/pane_geometry.lua` supplies pure
rectangle division, text capacity and hit testing for the renderer to share.

The released single-pane writer continues to use `recovery.txt` unchanged.
Documents accepts explicit slots 1/2 (`recovery-a.txt`, `recovery-b.txt`) and two
reserved filenames. Invalid recovery slot values fail before IO. Save removes
only the selected recovery slot; conflict-copy allocation also reserves loaded
unsaved names. Session checkpoint caching includes filename as well as document
identity and buffer revision, so rename does not retain an obsolete filename.

Legacy migration is implemented as an explicit, tested copy/read-verify/remove
operation. It preserves conflicting/corrupt records and keeps the old record on
write, verification or cleanup failure. It is intentionally not called by the
single-pane startup: activation waits until startup can recover both slots.

On pane switch, checkpoint outgoing dirty text before activation. A failed write
keeps the current pane active. This keeps at most one edited session newer than
its recovery checkpoint and avoids requiring two large writes at exit. Timers
capture their originating session and ignore late callbacks after replacement.
Text/undo/caches never enter ctx.state. Persist only a versioned, validated small
workspace manifest containing layout, active pane and per-pane cursor/path.
Recovery records remain discoverable even if workspace metadata was not saved.

## Additional integration required by the new sync features

1. Automatic upload must check the loaded session matching the queued filename,
   including an inactive or hidden dirty session. Checking only the active
   session's dirty flag is insufficient. Preserve per-profile queue ownership,
   retries, cancellation and saved-disk fingerprint checks.
2. Conflict review of a named file must resolve to its loaded session before
   taking the existing non-active-disk path. It must never replace SD content
   while an inactive pane has a dirty buffer for that file.
3. Snapshot/apply hooks capture pane/session/document identity, revision, exact
   bytes and filename. Delayed callbacks cannot retarget after activation or
   document replacement. Retain modal ownership during manual sync/setup.
4. Imports, historical restores, backups, conflict copies and New reserve both
   loaded names. Rename/delete inspect both loaded sessions and recovery slots.
   Queue/name changes follow existing explicit retry/reconciliation rules.
5. The GitHub badge and shared word count identify the active document; held
   uploads elsewhere remain discoverable without mislabelling the active pane.

## Milestones and gates

1. **Implemented here:** explicit editor-session extraction in the real writer;
   independent recovery APIs and opt-in verified migration; bounded workspace
   activation; ratio/text/hit geometry; controller and failure regression tests.
   Existing controller tests retain their behavioral assertions, with private
   state paths updated to A.editor. Runtime allowlist includes the new modules.
2. Wire two-session startup/recovery, small workspace persistence, active-pane
   file operations, autosave of both sessions and save/discard/exit semantics.
   Audit every legacy recovery access before enabling slot migration. No split
   UI is exposed before this and the sync ownership work pass.
3. Bind auto/manual sync, named conflict review and library management to both
   sessions. Tests must prove dirty inactive text cannot be overwritten or sent.
4. Render both prepared views and expose split controls, headers, Classic/Pro
   activation and focus access. Cache the inactive pane; no wrapping in draw.
5. Verify 48 base combinations (two models x two rotations x two directions x
   three ratios x normal/focus), plus keyboard-visible, large/fallback fonts,
   SD failures, stale callbacks, missing files, legacy recovery, maximum text,
   suspend and restart. Geometry tests cover 96 combinations including keyboard
   visibility; they do not constitute native-rendering or physical acceptance.

Decisive end-to-end gate: edit A, switch, edit B, save/sync B, interrupt and reopen.
A's original/public content and newest recoverable edits must remain intact.
Benchmark maximum documents and leave-time recovery on both physical devices;
the runtime cannot extend on_leave's callback budget.

## Delivery scope

This is a foundation test branch, not a split-screen release. The writing screen
remains single-pane; no schema migration runs automatically, no main merge,
original-cloud overwrite or Store publication is included. Native preview and
hardware evidence must be reported separately from the desktop suite.

Validation: 32/32 desktop suites pass, 19,320 assertions. The new session suite
has 59 checks; the geometry suite has 3,084 checks across 96 configurations.
Static packaging verifies all 25 runtime Lua modules, their require closure,
network ownership and both existing XIC assets. A separate preview app identity
was staged, but the official preview URL redirected to the developer/sign-in
page; native rendering and physical-device acceptance were not performed.
