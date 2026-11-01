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
