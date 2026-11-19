# Split screen: implementation and acceptance plan

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
  New workspaces use Auto: follow screen: portrait top/bottom, landscape
  left/right. Choosing a fixed direction overrides Auto through later rotations
  and reopenings. The Auto menu row restores following the screen. Existing
  saved directions from earlier builds remain fixed choices.
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
  Ctrl+Shift+S cycles single → 1:1 → 2:1 → 1:2 → single, keeping the selected
  direction, active pane and both documents in normal/focus mode. Ctrl+Shift+R
  rotates the screen; Ctrl+R still performs a full refresh.
  Ctrl+Shift+P and Settings > Split screen open layout controls. Focus needs a
  reachable compact actions route on Classic without a touch dependency.
- Touch gestures belong to their starting pane. Active markers use shapes and
  black/white contrast. Headers retain a 44 px touch target when space permits.
  Narrow panes use capped inner margins without silently shrinking the font.
  A keyboard-obscured pane with no full row retains its identity and offers Hide
  keyboard; it must not draw an invented row outside its rectangle.

## Ownership and persistence

`A.editor` references the active session inside `A.workspace.sessions` (at most
two). `domain/editor_session.lua` owns construction, change tracking, selection,
save, checkpoint and saved snapshots. Both sessions retain their own undo/view
state; global keyboard, clipboard, typography and statistics remain shared.

`domain/workspace.lua` supplies a bounded two-slot model, duplicate detection,
reserved filenames, guarded activation, validated workspace persistence and
two-session startup/recovery. `domain/pane_geometry.lua` supplies rectangle
division, text capacity and hit testing shared by the renderer and input routes.

Before the first split, the writer continues to use `recovery.txt` unchanged.
Documents accepts explicit slots 1/2 (`recovery-a.txt`, `recovery-b.txt`) and two
reserved filenames. Invalid recovery slot values fail before IO. Save removes
only the selected recovery slot; conflict-copy allocation also reserves loaded
unsaved names. Session checkpoint caching includes filename as well as document
identity and buffer revision, so rename does not retain an obsolete filename.

Legacy migration is implemented as an explicit, tested copy/read-verify/remove
operation. It preserves conflicting/corrupt records and keeps the old record on
write, verification or cleanup failure. The first split enables slot storage;
startup discovers either slot even if the workspace preference write failed.
Matching clean outgoing recovery is removed before a pane loads a different
file. Unrelated or differing recovery blocks replacement and remains intact.

On pane switch, checkpoint outgoing dirty text before activation. A failed write
keeps the current pane active. This keeps at most one edited session newer than
its recovery checkpoint and avoids requiring two large writes at exit. Timers
capture their originating session and ignore late callbacks after replacement.
Text/undo/caches never enter ctx.state. Persist only a versioned, validated small
workspace manifest containing layout, active pane and per-pane cursor/path.
Recovery records remain discoverable even if workspace metadata was not saved.

## Integrated sync safeguards

1. Automatic uploads conservatively wait while either loaded session is dirty
   or has a save failure, including hidden sessions. Existing profile ownership,
   retries, cancellation and saved-disk fingerprint checks remain in use.
2. Named conflict review resolves to its loaded session before taking the
   non-active-disk path. A confirmed update can replace clean inactive B while
   leaving dirty active A, A's identity and A's recovery unchanged. A new edit
   or replacement session invalidates the captured review.
3. Snapshot/apply hooks capture pane/session/document identity, revision, exact
   bytes and filename. Delayed callbacks cannot retarget after activation or
   document replacement. Retain modal ownership during manual sync/setup.
4. Imports, historical restores, backups, conflict copies and New reserve both
   loaded names. Rename/delete inspect both loaded sessions and recovery slots.
   Queue/name changes follow existing explicit retry/reconciliation rules.
5. The GitHub badge and shared word count identify the active document; held
   uploads elsewhere remain discoverable without mislabelling the active pane.

## Usage

Open Settings > More > Split screen, or press Ctrl+Shift+P. Choose Horizontal
(top/bottom), Vertical (left/right), or a ratio. A stays first; selecting B does
not reverse 2:1 or 1:2. Direction/ratio selection returns to writing. Current
choices show an asterisk in the settings page.

Ctrl+Tab switches panes. Classic Left/Right select A/B when no toolbar or other
overlay owns input. In focus, Classic OK opens the Split page, whose last row
toggles focus. Pro can tap a header to activate without moving its caret, tap
text to activate/place the caret, or hold a header to open Split settings.
Cross-divider swipes do not retarget selection/navigation. Existing outer-edge
gestures retain priority.

The filled header and > marker identify the active pane. Prefix * means unsaved;
! means Save failed. New/Open/Save and journal shortcuts target the active pane;
the Save label and file browser identify A/B. Opening an already loaded file
selects its owning pane. Rename/delete of another open pane's file is refused;
activate that pane first. Save all / Discard all in the exit card affect both
dirty documents, even when one is hidden by Single pane.

Single pane expands the active session and retains the other in memory. Idle
autosave visits both sessions fairly, one write per tick; failure stops retrying
that session until another edit or an explicit Save. A failed Save prevents
New/Open replacement and prevents Save all from quitting. Shared notices draw
below the whole split, not over the other pane's filename strip.

## Milestones and gates

1. **Implemented here:** explicit editor-session extraction in the real writer;
   independent recovery APIs and opt-in verified migration; bounded workspace
   activation; ratio/text/hit geometry; controller and failure regression tests.
   Existing controller tests retain their behavioral assertions, with private
   state paths updated to A.editor. Runtime allowlist includes the new modules.
2. **Implemented:** two-session startup/recovery, workspace persistence, active
   file operations, both-session autosave and Save all / Discard all exit.
3. **Implemented:** auto/manual sync ownership, named review and library guards.
   Actual App/Auth/Session integration tests cover inactive B and stale reviews.
4. **Implemented:** both prepared views, presets, headers, keyboard/Classic/Pro
   input routes and focus access. Typing reuses the inactive prepared frame.
5. **Device acceptance pending:** verify 48 base combinations (two models x two rotations x two directions x
   three ratios x normal/focus), plus keyboard-visible, large/fallback fonts,
   SD failures, stale callbacks, missing files, legacy recovery, maximum text,
   suspend and restart. Geometry tests cover 96 combinations including keyboard
   visibility; they do not constitute native-rendering or physical acceptance.

Decisive end-to-end gate: edit A, switch, edit B, save/sync B, interrupt and reopen.
A's original/public content and newest recoverable edits must remain intact.
Benchmark maximum documents and leave-time recovery on both physical devices;
the runtime cannot extend on_leave's callback budget.

## Delivery scope

This is a functional split-screen test branch, not a Store release. The first
deliberate split enables the new storage layout. No main merge, original-cloud
overwrite or Store publication is included. Before physical acceptance, use
copies of documents: older single-pane builds do not load the new recovery
slots. Native preview and hardware evidence are separate from desktop tests.

Validation: 35/35 desktop suites pass, 19,755 assertions. Session foundation:
59 checks; geometry: 3,084 checks across 96 configurations; real writer split
integration: 194 checks; shortcut cycle: 99 checks; rotation/Auto: 124 checks;
App/GitHub workflow: 62 checks
including inactive-pane
identity/revision guards, protected A recovery and blocked automatic uploads.
Static packaging verifies all 25 runtime Lua modules, their require closure,
network ownership and both existing XIC assets. A separate preview app identity
was staged as `inkwrite.split-screen-preview`. After the owner connected the
official preview, native Pro touch verified separate Alpha/Bravo documents,
horizontal 1:1, vertical 2:1 and 1:2, portrait/landscape, normal/focus, header
activation/settings, the virtual keyboard and Save B. Independent app-file
reads confirmed Alpha stayed exactly 148 bytes while Bravo became 155 bytes
after appending q. Native Classic restart, Left/Right pane activation, OK focus
settings and Back all reported supported/handled with null faults. Final Pro
restart preserved focus, ratio, orientation, both files and active pane. Final
Pro and Classic diagnostics were empty. Screenshots are delivery artifacts.

Preview project: `f1ec8532-6e59-448c-aa1c-751b802089d1`; foundation runtime-source
revision: `b7dca52c987916f7b50fa9762b880617a3e5fbdfc47f4d7f4c596d5e5e46e29f`.
This is an isolated plugin preview, not a save of the original cloud project.
Real GitHub transfers, real Bluetooth keyboards, physical panel latency/memory
and SD interruption/power-loss acceptance remain pending. Manifest stays 1.0.22 /
API 2.26 and the pre-existing menu version stays 1.0.20; release numbering was
not advanced.

Shortcut follow-up: Ctrl+Shift+S cycles the existing guarded presets; rotation
is Ctrl+Shift+R. Native restart smoke checks passed on Classic and Pro for source
revision `e55e40805752b370200513dcbcfe78d1d72debeeb3fdfe0be39c2524e9db21f7`,
with empty diagnostics. Classic device controls were handled without faults.
Raw Bluetooth shortcut delivery remains a physical-device check; simulator
input tools do not expose those chords.

Automatic direction follow-up: `direction_auto` is a validated optional boolean
in workspace schema 1. New workspaces default to true; older saved workspaces
without it retain their fixed direction. Geometry derives the effective
orientation from the current screen dimensions without changing document state
or doing layout during drawing. Ratio changes do not turn Auto off. Rotation
schedules frame preparation outside drawing after the host publishes its size.
35 suites pass with 124 new rotation/Auto assertions, including asynchronous
rotation, both launch shapes/modes, fixed overrides, restore, invalid settings,
recovery failures and both sessions' text/selection/undo. The shared test host
now correctly avoids swapping dimensions for an already-applied orientation.

Native source revision `1e04fff913a8b5a934d42722151a70a19fda994efeced185ca489b0183d3ad58`
showed Auto top/bottom in portrait and left/right in landscape, and a fixed
top/bottom choice after a rotation round trip. Auto was restored before Classic
and Pro restart checks; Classic Left/Right were handled without faults. The
native preview required another input to finish the rotated prepared frame;
idle timer delivery/immediate redraw after rotation remains a hardware check.
There were no runtime errors. Studio raised a refresh-full-input warning after
four screen rotations; the contract schedules full refresh for orientation
changes. No new explicit full-refresh request is added here.
