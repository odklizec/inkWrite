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

The official `run_xtapp_preview` connector rejected th\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt'\tt?\tt'\tt?\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\td´\td¨\td´\td¨\tt{\tt\nSemicolon\ttñ\ttÑ\ttÑ\ttñ\tt\tt\nSlash\tt-\tt_\tt-\tt_\tt\tt\nSpace\tt \tt \tt \tt \tt\tt",
["it"]="Backquote\tt\\\tt|\tt\\\tt|\tt\tt\nBackslash\ttù\tt§\ttù\tt§\tt\tt\nBracketLeft\ttè\tté\ttè\tté\tt[\tt{\nBracketRight\tt+\tt*\tt+\tt*\tt]\tt}\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt\tt\nDigit3\tt3\tt£\tt3\tt£\tt\tt\nDigit4\tt4\tt$\tt4\tt$\tt\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt\tt\nDigit8\tt8\tt(\tt8\tt(\tt\tt\nDigit9\tt9\tt)\tt9\tt)\tt\tt\nEqual\ttì\tt^\ttì\tt^\tt\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt'\tt?\tt'\tt?\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttà\tt°\ttà\tt°\tt#\tt\nSemicolon\ttò\ttç\ttò\ttç\tt@\tt\nSlash\tt-\tt_\tt-\tt_\tt\tt\nSpace\tt \tt \tt \tt \tt\tt",
["pt"]="Backquote\tt\\\tt|\tt\\\tt|\tt\tt\nBackslash\td~\td^\td~\td^\tt\tt\nBracketLeft\tt+\tt*\tt+\tt*\td¨\tt\nBracketRight\td´\td`\td´\td`\tt]\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt@\tt\nDigit3\tt3\tt#\tt3\tt#\tt£\tt\nDigit4\tt4\tt$\tt4\tt$\tt§\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt«\tt»\tt«\tt»\tt\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt'\tt?\tt'\tt?\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttº\ttª\ttº\ttª\tt\tt\nSemicolon\ttç\ttÇ\ttÇ\ttç\tt\tt\nSlash\tt-\tt_\tt-\tt_\tt\tt\nSpace\tt \tt \tt \tt \tt\tt",
["pt_br"]="Backquote\tt'\tt\"\tt'\tt\"\tt\tt\nBackslash\tt]\tt}\tt]\tt}\ttº\tt\nBracketLeft\td´\td`\td´\td`\tt\tt\nBracketRight\tt[\tt{\tt[\tt{\ttª\tt\nComma\tt,\tt<\tt,\tt<\tt\tt\nDigit0\tt0\tt)\tt0\tt)\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt¹\tt\nDigit2\tt2\tt@\tt2\tt@\tt²\tt\nDigit3\tt3\tt#\tt3\tt#\tt³\tt\nDigit4\tt4\tt$\tt4\tt$\tt£\tt\nDigit5\tt5\tt%\tt5\tt%\tt¢\tt\nDigit6\tt6\td¨\tt6\td¨\tt¬\tt\nDigit7\tt7\tt&\tt7\tt&\tt\tt\nDigit8\tt8\tt*\tt8\tt*\tt\tt\nDigit9\tt9\tt(\tt9\tt(\tt\tt\nEqual\tt=\tt+\tt=\tt+\tt§\tt\nIntlBackslash\tt\\\tt|\tt\\\tt|\tt\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt₢\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt°\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt/\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt?\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt>\tt.\tt>\tt\tt\nQuote\td~\td^\td~\td^\tt\tt\nSemicolon\ttç\ttÇ\ttÇ\ttç\tt\tt\nSlash\tt;\tt:\tt;\tt:\tt\tt\nSpace\tt \tt \tt \tt \tt\tt",
}
DATA.sv="Backquote\ttö\ttÖ\ttÖ\ttö\tt\tt\nBackslash\tt§\tt½\tt§\tt½\tt\tt\nBracketLeft\td´\td`\td´\td`\tt\tt\nBracketRight\ttå\ttÅ\ttÅ\ttå\tt\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt@\tt\nDigit3\tt3\tt#\tt3\tt#\tt£\tt\nDigit4\tt4\tt¤\tt4\tt¤\tt$\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt+\tt?\tt+\tt?\tt\\\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt|\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\ttµ\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttä\ttÄ\ttÄ\ttä\tt\tt\nSemicolon\td¨\td^\td¨\td^\td~\tt\nSlash\tt'\tt*\tt'\tt*\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.tr="Backquote\tt\"\tté\tt\"\tté\tt<\tt\nBackslash\ttç\ttÇ\ttÇ\ttç\tt\tt\nBracketLeft\ttğ\ttĞ\ttĞ\ttğ\td¨\tt\nBracketRight\ttü\ttÜ\ttÜ\ttü\td~\tt\nComma\tt,\tt;\tt,\tt;\td`\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt>\tt\nDigit2\tt2\tt'\tt2\tt'\tt£\tt\nDigit3\tt3\td^\tt3\td^\tt#\tt\nDigit4\tt4\tt+\tt4\tt+\tt$\tt\nDigit5\tt5\tt%\tt5\tt%\tt½\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt\tt\tt\tt\tt\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt|\tt\nKeyA\tta\ttA\ttA\tta\ttæ\ttÆ\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\ttı\ttI\ttI\ttı\tti\ttİ\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt@\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\ttß\tt\nKeyT\ttt\ttT\ttT\ttt\tt₺\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt|\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\tti\ttİ\ttİ\tti\tt\tt\nSemicolon\ttş\ttŞ\ttŞ\ttş\td´\tt\nSlash\ttö\ttÖ\ttÖ\ttö\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.ru="Backquote\ttё\ttЁ\ttЁ\ttё\tt\tt\nBackslash\tt\\\tt/\tt\\\tt/\tt\tt\nBracketLeft\ttх\ttХ\ttХ\ttх\tt\tt\nBracketRight\ttъ\ttЪ\ttЪ\ttъ\tt\tt\nComma\ttб\ttБ\ttБ\ttб\tt\tt\nDigit0\tt0\tt)\tt0\tt)\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt\tt\nDigit3\tt3\tt№\tt3\tt№\tt\tt\nDigit4\tt4\tt;\tt4\tt;\tt\tt\nDigit5\tt5\tt%\tt5\tt%\tt\tt\nDigit6\tt6\tt:\tt6\tt:\tt\tt\nDigit7\tt7\tt?\tt7\tt?\tt\tt\nDigit8\tt8\tt*\tt8\tt*\tt₽\tt\nDigit9\tt9\tt(\tt9\tt(\tt\tt\nEqual\tt=\tt+\tt=\tt+\tt\tt\nIntlBackslash\tt\\\tt/\tt\\\tt/\tt\tt\nKeyA\ttф\ttФ\ttФ\ttф\tt\tt\nKeyB\ttи\ttИ\ttИ\ttи\tt\tt\nKeyC\ttс\ttС\ttС\ttс\tt\tt\nKeyD\ttв\ttВ\ttВ\ttв\tt\tt\nKeyE\ttу\ttУ\ttУ\ttу\tt\tt\nKeyF\ttа\ttА\ttА\ttа\tt\tt\nKeyG\ttп\ttП\ttП\ttп\tt\tt\nKeyH\ttр\ttР\ttР\ttр\tt\tt\nKeyI\ttш\ttШ\ttШ\ttш\tt\tt\nKeyJ\ttо\ttО\ttО\ttо\tt\tt\nKeyK\ttл\ttЛ\ttЛ\ttл\tt\tt\nKeyL\ttд\ttД\ttД\ttд\tt\tt\nKeyM\ttь\ttЬ\ttЬ\ttь\tt\tt\nKeyN\ttт\ttТ\ttТ\ttт\tt\tt\nKeyO\ttщ\ttЩ\ttЩ\ttщ\tt\tt\nKeyP\ttз\ttЗ\ttЗ\ttз\tt\tt\nKeyQ\ttй\ttЙ\ttЙ\ttй\tt\tt\nKeyR\ttк\ttК\ttК\ttк\tt\tt\nKeyS\ttы\ttЫ\ttЫ\ttы\tt\tt\nKeyT\ttе\ttЕ\ttЕ\ttе\tt\tt\nKeyU\ttг\ttГ\ttГ\ttг\tt\tt\nKeyV\ttм\ttМ\ttМ\ttм\tt\tt\nKeyW\ttц\ttЦ\ttЦ\ttц\tt\tt\nKeyX\ttч\ttЧ\ttЧ\ttч\tt\tt\nKeyY\ttн\ttН\ttН\ttн\tt\tt\nKeyZ\ttя\ttЯ\ttЯ\ttя\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\ttю\ttЮ\ttЮ\ttю\tt\tt\nQuote\ttэ\ttЭ\ttЭ\ttэ\tt\tt\nSemicolon\ttж\ttЖ\ttЖ\ttж\tt\tt\nSlash\tt.\tt,\tt.\tt,\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.nl="Backquote\td´\td`\td´\td`\tt\tt\nBackslash\tt<\tt>\tt<\tt>\tt\tt\nBracketLeft\tt/\tt?\tt/\tt?\tt\\\tt\nBracketRight\td¨\td^\td¨\td^\tt\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt'\tt0\tt'\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt¹\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt²\tt\nDigit3\tt3\tt#\tt3\tt#\tt³\tt\nDigit4\tt4\tt$\tt4\tt$\tt¼\tt\nDigit5\tt5\tt%\tt5\tt%\tt½\tt\nDigit6\tt6\tt&\tt6\tt&\tt¾\tt\nDigit7\tt7\tt_\tt7\tt_\tt£\tt\nDigit8\tt8\tt(\tt8\tt(\tt{\tt\nDigit9\tt9\tt)\tt9\tt)\tt}\tt\nEqual\tt+\tt±\tt+\tt±\tt\tt\nIntlBackslash\tt]\tt[\tt]\tt[\tt¦\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt¢\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\ttµ\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt¶\tt\nKeyS\tts\ttS\ttS\tts\ttß\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt»\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt«\tt\nMinus\tt-\tt=\tt-\tt=\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt·\tt\nQuote\tt@\tt§\tt@\tt§\tt¬\tt\nSemicolon\tt*\tt|\tt*\tt|\tt\tt\nSlash\tt°\td~\tt°\td~\td¸\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.vi="Backquote\tt`\tt~\tt`\tt~\tt`\tt~\nBackslash\tt\\\tt|\tt\\\tt|\tt\\\tt|\nBracketLeft\ttư\ttƯ\ttƯ\ttư\tt[\tt{\nBracketRight\ttơ\ttƠ\ttƠ\ttơ\tt]\tt}\nComma\tt,\tt<\tt,\tt<\tt,\tt<\nDigit0\ttđ\ttĐ\ttĐ\ttđ\tt0\tt)\nDigit1\ttă\ttĂ\ttĂ\ttă\tt1\tt!\nDigit2\ttâ\ttÂ\ttÂ\ttâ\tt2\tt@\nDigit3\ttê\ttÊ\ttÊ\ttê\tt3\tt#\nDigit4\ttô\ttÔ\ttÔ\ttô\tt4\tt$\nDigit5\tt̀\tt̀\tt̀\tt̀\tt5\tt%\nDigit6\tt̉\tt̉\tt̉\tt̉\tt6\tt^\nDigit7\tt̃\tt̃\tt̃\tt̃\tt7\tt&\nDigit8\tt́\tt́\tt́\tt́\tt8\tt*\nDigit9\tṭ\tṭ\tṭ\tṭ\tt9\tt(\nEqual\tt₫\tt+\tt₫\tt+\tt=\tt+\nIntlBackslash\tt\\\tt|\tt\\\tt|\tt\\\tt|\nKeyA\tta\ttA\ttA\tta\tta\ttA\nKeyB\ttb\ttB\ttB\ttb\ttb\ttB\nKeyC\ttc\ttC\ttC\ttc\ttc\ttC\nKeyD\ttd\ttD\ttD\ttd\ttd\ttD\nKeyE\tte\ttE\ttE\tte\tte\ttE\nKeyF\ttf\ttF\ttF\ttf\ttf\ttF\nKeyG\ttg\ttG\ttG\ttg\ttg\ttG\nKeyH\tth\ttH\ttH\tth\tth\ttH\nKeyI\tti\ttI\ttI\tti\tti\ttI\nKeyJ\ttj\ttJ\ttJ\ttj\ttj\ttJ\nKeyK\ttk\ttK\ttK\ttk\ttk\ttK\nKeyL\ttl\ttL\ttL\ttl\ttl\ttL\nKeyM\ttm\ttM\ttM\ttm\ttm\ttM\nKeyN\ttn\ttN\ttN\ttn\ttn\ttN\nKeyO\tto\ttO\ttO\tto\tto\ttO\nKeyP\ttp\ttP\ttP\ttp\ttp\ttP\nKeyQ\ttq\ttQ\ttQ\ttq\ttq\ttQ\nKeyR\ttr\ttR\ttR\ttr\ttr\ttR\nKeyS\tts\ttS\ttS\tts\tts\ttS\nKeyT\ttt\ttT\ttT\ttt\ttt\ttT\nKeyU\ttu\ttU\ttU\ttu\ttu\ttU\nKeyV\ttv\ttV\ttV\ttv\ttv\ttV\nKeyW\ttw\ttW\ttW\ttw\ttw\ttW\nKeyX\ttx\ttX\ttX\ttx\ttx\ttX\nKeyY\tty\ttY\ttY\tty\tty\ttY\nKeyZ\ttz\ttZ\ttZ\ttz\ttz\ttZ\nMinus\tt-\tt_\tt-\tt_\tt-\tt_\nPeriod\tt.\tt>\tt.\tt>\tt.\tt>\nQuote\tt'\tt\"\tt'\tt\"\tt'\tt\"\nSemicolon\tt;\tt:\tt;\tt:\tt;\tt:\nSlash\tt/\tt?\tt/\tt?\tt/\tt?\nSpace\tt \tt \tt \tt \tt\tt"
DATA.hu="Backquote\ttö\ttÖ\ttÖ\ttö\td˝\tt\nBackslash\ttű\ttŰ\ttŰ\ttű\tt¤\tt\nBracketLeft\ttő\ttŐ\ttŐ\ttő\tt÷\tt\nBracketRight\ttú\ttÚ\ttÚ\ttú\tt×\tt\nComma\tt,\tt?\tt,\tt?\tt;\tt\nDigit0\tt0\tt§\tt0\tt§\tt\tt\nDigit1\tt1\tt'\tt1\tt'\tt~\tt\nDigit2\tt2\tt\"\tt2\tt\"\tdˇ\tt\nDigit3\tt3\tt+\tt3\tt+\td^\tt\nDigit4\tt4\tt!\tt4\tt!\td˘\tt\nDigit5\tt5\tt%\tt5\tt%\td°\tt\nDigit6\tt6\tt/\tt6\tt/\td˛\tt\nDigit7\tt7\tt=\tt7\tt=\tt`\tt\nDigit8\tt8\tt(\tt8\tt(\td˙\tt\nDigit9\tt9\tt)\tt9\tt)\td´\tt\nEqual\ttó\ttÓ\ttÓ\ttó\td¸\tt\nIntlBackslash\ttí\ttÍ\ttÍ\ttí\tt<\tt\nKeyA\tta\ttA\ttA\tta\ttä\tt\nKeyB\ttb\ttB\ttB\ttb\tt{\tt\nKeyC\ttc\ttC\ttC\ttc\tt&\tt\nKeyD\ttd\ttD\ttD\ttd\ttĐ\tt\nKeyE\tte\ttE\ttE\tte\ttÄ\tt\nKeyF\ttf\ttF\ttF\ttf\tt[\tt\nKeyG\ttg\ttG\ttG\ttg\tt]\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\ttÍ\tt\nKeyJ\ttj\ttJ\ttJ\ttj\ttí\tt\nKeyK\ttk\ttK\ttK\ttk\ttł\tt\nKeyL\ttl\ttL\ttL\ttl\ttŁ\tt\nKeyM\ttm\ttM\ttM\ttm\tt<\tt\nKeyN\ttn\ttN\ttN\ttn\tt}\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\\\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\ttđ\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt€\tt\nKeyV\ttv\ttV\ttV\ttv\tt@\tt\nKeyW\ttw\ttW\ttW\ttw\tt|\tt\nKeyX\ttx\ttX\ttX\ttx\tt#\tt\nKeyY\tty\ttY\ttY\tty\tt>\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt*\tt\nPeriod\tt.\tt:\tt.\tt:\tt>\tt\nQuote\ttá\ttÁ\ttÁ\ttá\ttß\tt\nSemicolon\tté\ttÉ\ttÉ\tté\tt$\tt\nSlash\ttü\ttÜ\ttÜ\ttü\td¨\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.da="Backquote\ttæ\ttÆ\ttÆ\ttæ\tt\tt\nBackslash\tt½\tt§\tt½\tt§\tt\tt\nBracketLeft\td´\td`\td´\td`\tt|\tt\nBracketRight\ttå\ttÅ\ttÅ\ttå\tt\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt@\tt\nDigit3\tt3\tt#\tt3\tt#\tt£\tt\nDigit4\tt4\tt¤\tt4\tt¤\tt$\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt+\tt?\tt+\tt?\tt\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt\\\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\ttµ\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttø\ttØ\ttØ\ttø\tt\tt\nSemicolon\td¨\td^\td¨\td^\td~\tt\nSlash\tt'\tt*\tt'\tt*\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.no="Backquote\ttø\ttØ\ttØ\ttø\tt\tt\nBackslash\tt|\tt§\tt|\tt§\tt\tt\nBracketLeft\tt\\\td`\tt\\\td`\td´\tt\nBracketRight\ttå\ttÅ\ttÅ\ttå\tt\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt@\tt\nDigit3\tt3\tt#\tt3\tt#\tt£\tt\nDigit4\tt4\tt¤\tt4\tt¤\tt$\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt+\tt?\tt+\tt?\tt\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\ttµ\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttæ\ttÆ\ttÆ\ttæ\tt\tt\nSemicolon\td¨\td^\td¨\td^\td~\tt\nSlash\tt'\tt*\tt'\tt*\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.uk="Backquote\ttё\ttЁ\ttЁ\ttё\tt\tt\nBackslash\tt\\\tt/\tt\\\tt/\tt\tt\nBracketLeft\ttх\ttХ\ttХ\ttх\tt\tt\nBracketRight\ttї\ttЇ\ttЇ\ttї\tt\tt\nComma\ttб\ttБ\ttБ\ttб\tt\tt\nDigit0\tt0\tt)\tt0\tt)\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt\tt\nDigit3\tt3\tt№\tt3\tt№\tt\tt\nDigit4\tt4\tt;\tt4\tt;\tt\tt\nDigit5\tt5\tt%\tt5\tt%\tt\tt\nDigit6\tt6\tt:\tt6\tt:\tt\tt\nDigit7\tt7\tt?\tt7\tt?\tt\tt\nDigit8\tt8\tt*\tt8\tt*\tt\tt\nDigit9\tt9\tt(\tt9\tt(\tt\tt\nEqual\tt=\tt+\tt=\tt+\tt\tt\nIntlBackslash\ttґ\ttҐ\ttҐ\ttґ\tt\tt\nKeyA\ttф\ttФ\ttФ\ttф\tt\tt\nKeyB\ttи\ttИ\ttИ\ttи\tt\tt\nKeyC\ttс\ttС\ttС\ttс\tt\tt\nKeyD\ttв\ttВ\ttВ\ttв\tt\tt\nKeyE\ttу\ttУ\ttУ\ttу\tt\tt\nKeyF\ttа\ttА\ttА\ttа\tt\tt\nKeyG\ttп\ttП\ttП\ttп\tt\tt\nKeyH\ttр\ttР\ttР\ttр\tt\tt\nKeyI\ttш\ttШ\ttШ\ttш\tt\tt\nKeyJ\ttо\ttО\ttО\ttо\tt\tt\nKeyK\ttл\ttЛ\ttЛ\ttл\tt\tt\nKeyL\ttд\ttД\ttД\ttд\tt\tt\nKeyM\ttь\ttЬ\ttЬ\ttь\tt\tt\nKeyN\ttт\ttТ\ttТ\ttт\tt\tt\nKeyO\ttщ\ttЩ\ttЩ\ttщ\tt\tt\nKeyP\ttз\ttЗ\ttЗ\ttз\tt\tt\nKeyQ\ttй\ttЙ\ttЙ\ttй\tt\tt\nKeyR\ttк\ttК\ttК\ttк\tt\tt\nKeyS\ttі\ttІ\ttІ\ttі\tt\tt\nKeyT\ttе\ttЕ\ttЕ\ttе\tt\tt\nKeyU\ttг\ttГ\ttГ\ttг\ttґ\ttҐ\nKeyV\ttм\ttМ\ttМ\ttм\tt\tt\nKeyW\ttц\ttЦ\ttЦ\ttц\tt\tt\nKeyX\ttч\ttЧ\ttЧ\ttч\tt\tt\nKeyY\ttн\ttН\ttН\ttн\tt\tt\nKeyZ\ttя\ttЯ\ttЯ\ttя\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\ttю\ttЮ\ttЮ\ttю\tt\tt\nQuote\ttє\ttЄ\ttЄ\ttє\tt\tt\nSemicolon\ttж\ttЖ\ttЖ\ttж\tt\tt\nSlash\tt.\tt,\tt.\tt,\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.pl="Backquote\tt`\td~\tt`\td~\tt\tt\nBackslash\tt\\\tt|\tt\\\tt|\tt\tt\nBracketLeft\tt[\tt{\tt[\tt{\tt\tt\nBracketRight\tt]\tt}\tt]\tt}\tt\tt\nComma\tt,\tt<\tt,\tt<\tt\tt\nDigit0\tt0\tt)\tt0\tt)\tt\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt@\tt2\tt@\tt\tt\nDigit3\tt3\tt#\tt3\tt#\tt\tt\nDigit4\tt4\tt$\tt4\tt$\tt\tt\nDigit5\tt5\tt%\tt5\tt%\tt\tt\nDigit6\tt6\tt^\tt6\tt^\tt\tt\nDigit7\tt7\tt&\tt7\tt&\tt\tt\nDigit8\tt8\tt*\tt8\tt*\tt\tt\nDigit9\tt9\tt(\tt9\tt(\tt\tt\nEqual\tt=\tt+\tt=\tt+\tt\tt\nIntlBackslash\tt\\\tt|\tt\\\tt|\tt\tt\nKeyA\tta\ttA\ttA\tta\ttą\ttĄ\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\ttć\ttĆ\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\ttę\ttĘ\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\ttł\ttŁ\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\ttń\ttŃ\nKeyO\tto\ttO\ttO\tto\ttó\ttÓ\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\ttś\ttŚ\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt€\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\ttź\ttŹ\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\ttż\ttŻ\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt>\tt.\tt>\tt\tt\nQuote\tt'\tt\"\tt'\tt\"\tt\tt\nSemicolon\tt;\tt:\tt;\tt:\tt\tt\nSlash\tt/\tt?\tt/\tt?\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.el="Backquote\tt`\tt~\tt`\tt~\tt\tt\nBackslash\tt\\\tt|\tt\\\tt|\tt¬\tt\nBracketLeft\tt[\tt{\tt[\tt{\tt«\tt\nBracketRight\tt]\tt}\tt]\tt}\tt»\tt\nComma\tt,\tt<\tt,\tt<\tt\tt\nDigit0\tt0\tt)\tt0\tt)\tt°\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt@\tt2\tt@\tt²\tt\nDigit3\tt3\tt#\tt3\tt#\tt³\tt\nDigit4\tt4\tt$\tt4\tt$\tt£\tt\nDigit5\tt5\tt%\tt5\tt%\tt§\tt\nDigit6\tt6\tt^\tt6\tt^\tt¶\tt\nDigit7\tt7\tt&\tt7\tt&\tt\tt\nDigit8\tt8\tt*\tt8\tt*\tt¤\tt\nDigit9\tt9\tt(\tt9\tt(\tt¦\tt\nEqual\tt=\tt+\tt=\tt+\tt½\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt\tt\nKeyA\ttα\ttΑ\ttΑ\ttα\tt\tt\nKeyB\ttβ\ttΒ\ttΒ\ttβ\tt\tt\nKeyC\ttψ\ttΨ\ttΨ\ttψ\tt©\tt\nKeyD\ttδ\ttΔ\ttΔ\ttδ\tt\tt\nKeyE\ttε\ttΕ\ttΕ\ttε\tt€\tt\nKeyF\ttφ\ttΦ\ttΦ\ttφ\tt\tt\nKeyG\ttγ\ttΓ\ttΓ\ttγ\tt\tt\nKeyH\ttη\ttΗ\ttΗ\ttη\tt\tt\nKeyI\ttι\ttΙ\ttΙ\ttι\tt\tt\nKeyJ\ttξ\ttΞ\ttΞ\ttξ\tt\tt\nKeyK\ttκ\ttΚ\ttΚ\ttκ\tt\tt\nKeyL\ttλ\ttΛ\ttΛ\ttλ\tt\tt\nKeyM\ttμ\ttΜ\ttΜ\ttμ\tt\tt\nKeyN\ttν\ttΝ\ttΝ\ttν\tt\tt\nKeyO\ttο\ttΟ\ttΟ\ttο\tt\tt\nKeyP\ttπ\ttΠ\ttΠ\ttπ\tt\tt\nKeyQ\tt;\tt:\tt;\tt:\tt\tt\nKeyR\ttρ\ttΡ\ttΡ\ttρ\tt®\tt\nKeyS\ttσ\ttΣ\ttΣ\ttσ\tt\tt\nKeyT\ttτ\ttΤ\ttΤ\ttτ\tt\tt\nKeyU\ttθ\ttΘ\ttΘ\ttθ\tt\tt\nKeyV\ttω\ttΩ\ttΩ\ttω\tt\tt\nKeyW\ttς\td΅\ttς\td΅\tt\tt\nKeyX\ttχ\ttΧ\ttΧ\ttχ\tt\tt\nKeyY\ttυ\ttΥ\ttΥ\ttυ\tt¥\tt\nKeyZ\ttζ\ttΖ\ttΖ\ttζ\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt±\tt\nPeriod\tt.\tt>\tt.\tt>\tt\tt\nQuote\tt'\tt\"\tt'\tt\"\tt\tt\nSemicolon\td΄\td¨\td΄\td¨\td΅\tt\nSlash\tt/\tt?\tt/\tt?\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.ro="Backquote\tt„\tt”\tt„\tt”\tt`\tt~\nBackslash\ttâ\ttÂ\ttÂ\ttâ\tt\\\tt|\nBracketLeft\ttă\ttĂ\ttĂ\ttă\tt[\tt{\nBracketRight\ttî\ttÎ\ttÎ\ttî\tt]\tt}\nComma\tt,\tt;\tt,\tt;\tt<\tt«\nDigit0\tt0\tt)\tt0\tt)\td˝\tt\nDigit1\tt1\tt!\tt1\tt!\td~\tt\nDigit2\tt2\tt@\tt2\tt@\tdˇ\tt\nDigit3\tt3\tt#\tt3\tt#\td^\tt\nDigit4\tt4\tt$\tt4\tt$\td˘\tt\nDigit5\tt5\tt%\tt5\tt%\td°\tt\nDigit6\tt6\tt^\tt6\tt^\td˛\tt\nDigit7\tt7\tt&\tt7\tt&\td`\tt\nDigit8\tt8\tt*\tt8\tt*\td˙\tt\nDigit9\tt9\tt(\tt9\tt(\td´\tt\nEqual\tt=\tt+\tt=\tt+\td¸\tt±\nIntlBackslash\tt\\\tt|\tt\\\tt|\tt\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt©\tt\nKeyD\ttd\ttD\ttD\ttd\ttđ\ttĐ\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\ttł\ttŁ\nKeyM\ttm\ttM\ttM\ttm\tt\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt§\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\ttß\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\td¨\tt–\nPeriod\tt.\tt:\tt.\tt:\tt>\tt»\nQuote\ttț\ttȚ\ttȚ\ttț\tt'\tt\"\nSemicolon\ttș\ttȘ\ttȘ\ttș\tt;\tt:\nSlash\tt/\tt?\tt/\tt?\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
DATA.fi="Backquote\ttö\ttÖ\ttÖ\ttö\tt\tt\nBackslash\tt§\tt½\tt§\tt½\tt\tt\nBracketLeft\td´\td`\td´\td`\tt\tt\nBracketRight\ttå\ttÅ\ttÅ\ttå\tt\tt\nComma\tt,\tt;\tt,\tt;\tt\tt\nDigit0\tt0\tt=\tt0\tt=\tt}\tt\nDigit1\tt1\tt!\tt1\tt!\tt\tt\nDigit2\tt2\tt\"\tt2\tt\"\tt@\tt\nDigit3\tt3\tt#\tt3\tt#\tt£\tt\nDigit4\tt4\tt¤\tt4\tt¤\tt$\tt\nDigit5\tt5\tt%\tt5\tt%\tt€\tt\nDigit6\tt6\tt&\tt6\tt&\tt\tt\nDigit7\tt7\tt/\tt7\tt/\tt{\tt\nDigit8\tt8\tt(\tt8\tt(\tt[\tt\nDigit9\tt9\tt)\tt9\tt)\tt]\tt\nEqual\tt+\tt?\tt+\tt?\tt\\\tt\nIntlBackslash\tt<\tt>\tt<\tt>\tt|\tt\nKeyA\tta\ttA\ttA\tta\tt\tt\nKeyB\ttb\ttB\ttB\ttb\tt\tt\nKeyC\ttc\ttC\ttC\ttc\tt\tt\nKeyD\ttd\ttD\ttD\ttd\tt\tt\nKeyE\tte\ttE\ttE\tte\tt€\tt\nKeyF\ttf\ttF\ttF\ttf\tt\tt\nKeyG\ttg\ttG\ttG\ttg\tt\tt\nKeyH\tth\ttH\ttH\tth\tt\tt\nKeyI\tti\ttI\ttI\tti\tt\tt\nKeyJ\ttj\ttJ\ttJ\ttj\tt\tt\nKeyK\ttk\ttK\ttK\ttk\tt\tt\nKeyL\ttl\ttL\ttL\ttl\tt\tt\nKeyM\ttm\ttM\ttM\ttm\ttµ\tt\nKeyN\ttn\ttN\ttN\ttn\tt\tt\nKeyO\tto\ttO\ttO\tto\tt\tt\nKeyP\ttp\ttP\ttP\ttp\tt\tt\nKeyQ\ttq\ttQ\ttQ\ttq\tt\tt\nKeyR\ttr\ttR\ttR\ttr\tt\tt\nKeyS\tts\ttS\ttS\tts\tt\tt\nKeyT\ttt\ttT\ttT\ttt\tt\tt\nKeyU\ttu\ttU\ttU\ttu\tt\tt\nKeyV\ttv\ttV\ttV\ttv\tt\tt\nKeyW\ttw\ttW\ttW\ttw\tt\tt\nKeyX\ttx\ttX\ttX\ttx\tt\tt\nKeyY\tty\ttY\ttY\tty\tt\tt\nKeyZ\ttz\ttZ\ttZ\ttz\tt\tt\nMinus\tt-\tt_\tt-\tt_\tt\tt\nPeriod\tt.\tt:\tt.\tt:\tt\tt\nQuote\ttä\ttÄ\ttÄ\ttä\tt\tt\nSemicolon\td¨\td^\td¨\td^\td~\tt\nSlash\tt'\tt*\tt'\tt*\tt\tt\nSpace\tt \tt \tt \tt \tt\tt"
local COMPOSE={
["´A"]="Á",
["´C"]="Ć",
["´E"]="É",
["´G"]="Ǵ",
["´I"]="Í",
["´K"]="Ḱ",
["´L"]="Ĺ",
["´M"]="Ḿ",
["´N"]="Ń",
["´O"]="Ó",
["´P"]="Ṕ",
["´R"]="Ŕ",
["´S"]="Ś",
["´U"]="Ú",
["´W"]="Ẃ",
["´Y"]="Ý",
["´Z"]="Ź",
["´a"]="á",
["´c"]="ć",
["´e"]="é",
["´g"]="ǵ",
["´i"]="í",
["´k"]="ḱ",
["´l"]="ĺ",
["´m"]="ḿ",
["´n"]="ń",
["´o"]="ó",
["´p"]="ṕ",
["´r"]="ŕ",
["´s"]="ś",
["´u"]="ú",
["´w"]="ẃ",
["´y"]="ý",
["´z"]="ź",
["´Â"]="Ấ",
["´Å"]="Ǻ",
["´Æ"]="Ǽ",
["´Ç"]="Ḉ",
["´Ê"]="Ế",
["´Ï"]="Ḯ",
["´Ô"]="Ố",
["´Õ"]="Ṍ",
["´Ø"]="Ǿ",
["´Ü"]="Ǘ",
["´â"]="ấ",
["´å"]="ǻ",
["´æ"]="ǽ",
["´ç"]="ḉ",
["´ê"]="ế",
["´ï"]="ḯ",
["´ô"]="ố",
["´õ"]="ṍ",
["´ø"]="ǿ",
["´ü"]="ǘ",
["´Ă"]="Ắ",
["´ă"]="ắ",
["´Ē"]="Ḗ",
["´ē"]="ḗ",
["´Ō"]="Ṓ",
["´ō"]="ṓ",
["´Ũ"]="Ṹ",
["´ũ"]="ṹ",
["´Ơ"]="Ớ",
["´ơ"]="ớ",
["´Ư"]="Ứ",
["´ư"]="ứ",
["ˇA"]="Ǎ",
["ˇC"]="Č",
["ˇD"]="Ď",
["ˇE"]="Ě",
["ˇG"]="Ǧ",
["ˇH"]="Ȟ",
["ˇI"]="Ǐ",
["ˇK"]="Ǩ",
["ˇL"]="Ľ",
["ˇN"]="Ň",
["ˇO"]="Ǒ",
["ˇR"]="Ř",
["ˇS"]="Š",
["ˇT"]="Ť",
["ˇU"]="Ǔ",
["ˇZ"]="Ž",
["ˇa"]="ǎ",
["ˇc"]="č",
["ˇd"]="ď",
["ˇe"]="ě",
["ˇg"]="ǧ",
["ˇh"]="ȟ",
["ˇi"]="ǐ",
["ˇj"]="ǰ",
["ˇk"]="ǩ",
["ˇl"]="ľ",
["ˇn"]="ň",
["ˇo"]="ǒ",
["ˇr"]="ř",
["ˇs"]="š",
["ˇt"]="ť",
["ˇu"]="ǔ",
["ˇz"]="ž",
["ˇÜ"]="Ǚ",
["ˇü"]="ǚ",
["ˇƷ"]="Ǯ",
["¨A"]="Ä",
["¨E"]="Ë",
["¨H"]="Ḧ",
["¨I"]="Ï",
["¨O"]="Ö",
["¨U"]="Ü",
["¨W"]="Ẅ",
["¨X"]="Ẍ",
["¨Y"]="Ÿ",
["¨a"]="ä",
["¨e"]="ë",
["¨h"]="ḧ",
["¨i"]="ï",
["¨o"]="ö",
["¨t"]="ẗ",
["¨u"]="ü",
["¨w"]="ẅ",
["¨x"]="ẍ",
["¨y"]="ÿ",
["¨Õ"]="Ṏ",
["¨õ"]="ṏ",
["¨Ū"]="Ṻ",
["¨ū"]="ṻ",
["^A"]="Â",
["^C"]="Ĉ",
["^E"]="Ê",
["^G"]="Ĝ",
["^H"]="Ĥ",
["^I"]="Î",
["^J"]="Ĵ",
["^O"]="Ô",
["^S"]="Ŝ",
["^U"]="Û",
["^W"]="Ŵ",
["^Y"]="Ŷ",
["^Z"]="Ẑ",
["^a"]="â",
["^c"]="ĉ",
["^e"]="ê",
["^g"]="ĝ",
["^h"]="ĥ",
["^i"]="î",
["^j"]="ĵ",
["^o"]="ô",
["^s"]="ŝ",
["^u"]="û",
["^w"]="ŵ",
["^y"]="ŷ",
["^z"]="ẑ",
["~A"]="Ã",
["~E"]="Ẽ",
["~I"]="Ĩ",
["~N"]="Ñ",
["~O"]="Õ",
["~U"]="Ũ",
["~V"]="Ṽ",
["~Y"]="Ỹ",
["~a"]="ã",
["~e"]="ẽ",
["~i"]="ĩ",
["~n"]="ñ",
["~o"]="õ",
["~u"]="ũ",
["~v"]="ṽ",
["~y"]="ỹ",
["~Â"]="Ẫ",
["~Ê"]="Ễ",
["~Ô"]="Ỗ",
["~â"]="ẫ",
["~ê"]="ễ",
["~ô"]="ỗ",
["~Ă"]="Ẵ",
["~ă"]="ẵ",
["~Ơ"]="Ỡ",
["~ơ"]="ỡ",
["~Ư"]="Ữ",
["~ư"]="ữ",
["˘A"]="Ă",
["˘E"]="Ĕ",
["˘G"]="Ğ",
["˘I"]="Ĭ",
["˘O"]="Ŏ",
["˘U"]="Ŭ",
["˘a"]="ă",
["˘e"]="ĕ",
["˘g"]="ğ",
["˘i"]="ĭ",
["˘o"]="ŏ",
["˘u"]="ŭ",
["˘Ȩ"]="Ḝ",
["˘ȩ"]="ḝ",
["°A"]="Å",
["°U"]="Ů",
["°a"]="å",
["°u"]="ů",
["°w"]="ẘ",
["°y"]="ẙ",
["˛A"]="Ą",
["˛E"]="Ę",
["˛I"]="Į",
["˛O"]="Ǫ",
["˛U"]="Ų",
["˛a"]="ą",
["˛e"]="ę",
["˛i"]="į",
["˛o"]="ǫ",
["˛u"]="ų",
["˛Ō"]="Ǭ",
["˛ō"]="ǭ",
["˙A"]="Ȧ",
["˙B"]="Ḃ",
["˙C"]="Ċ",
["˙D"]="Ḋ",
["˙E"]="Ė",
["˙F"]="Ḟ",
["˙G"]="Ġ",
["˙H"]="Ḣ",
["˙I"]="İ",
["˙M"]="Ṁ",
["˙N"]="Ṅ",
["˙O"]="Ȯ",
["˙P"]="Ṗ",
["˙R"]="Ṙ",
["˙S"]="Ṡ",
["˙T"]="Ṫ",
["˙W"]="Ẇ",
["˙X"]="Ẋ",
["˙Y"]="Ẏ",
["˙Z"]="Ż",
["˙a"]="ȧ",
["˙b"]="ḃ",
["˙c"]="ċ",
["˙d"]="ḋ",
["˙e"]="ė",
["˙f"]="ḟ",
["˙g"]="ġ",
["˙h"]="ḣ",
["˙m"]="ṁ",
["˙n"]="ṅ",
["˙o"]="ȯ",
["˙p"]="ṗ",
["˙r"]="ṙ",
["˙s"]="ṡ",
["˙t"]="ṫ",
["˙w"]="ẇ",
["˙x"]="ẋ",
["˙y"]="ẏ",
["˙z"]="ż",
["˙Ś"]="Ṥ",
["˙ś"]="ṥ",
["˙Š"]="Ṧ",
["˙š"]="ṧ",
["˙ſ"]="ẛ",
["˝O"]="Ő",
["˝U"]="Ű",
["˝o"]="ő",
["˝u"]="ű",
["¸C"]="Ç",
["¸D"]="Ḑ",
["¸E"]="Ȩ",
["¸G"]="Ģ",
["¸H"]="Ḩ",
["¸K"]="Ķ",
["¸L"]="Ļ",
["¸N"]="Ņ",
["¸R"]="Ŗ",
["¸S"]="Ş",
["¸T"]="Ţ",
["¸c"]="ç",
["¸d"]="ḑ",
["¸e"]="ȩ",
["¸g"]="ģ",
["¸h"]="ḩ",
["¸k"]="ķ",
["¸l"]="ļ",
["¸n"]="ņ",
["¸r"]="ŗ",
["¸s"]="ş",
["¸t"]="ţ",
["¸Ć"]="Ḉ",
["¸ć"]="ḉ",
["¸Ĕ"]="Ḝ",
["¸ĕ"]="ḝ",
["`A"]="À",
["`E"]="È",
["`I"]="Ì",
["`N"]="Ǹ",
["`O"]="Ò",
["`U"]="Ù",
["`W"]="Ẁ",
["`Y"]="Ỳ",
["`a"]="à",
["`e"]="è",
["`i"]="ì",
["`n"]="ǹ",
["`o"]="ò",
["`u"]="ù",
["`w"]="ẁ",
["`y"]="ỳ",
["`Â"]="Ầ",
["`Ê"]="Ề",
["`Ô"]="Ồ",
["`Ü"]="Ǜ",
["`â"]="ầ",
["`ê"]="ề",
["`ô"]="ồ",
["`ü"]="ǜ",
["`Ă"]="Ằ",
["`ă"]="ằ",
["`Ē"]="Ḕ",
["`ē"]="ḕ",
["`Ō"]="Ṑ",
["`ō"]="ṑ",
["`Ơ"]="Ờ",
["`ơ"]="ờ",
["`Ư"]="Ừ",
["`ư"]="ừ",
}

COMPOSE["´a"]="á"
COMPOSE["`a"]="à"
COMPOSE["̉a"]="ả"
COMPOSE["~a"]="ã"
COMPOSE["̣a"]="ạ"
COMPOSE["´ă"]="ắ"
COMPOSE["`ă"]="ằ"
COMPOSE["̉ă"]="ẳ"
COMPOSE["~ă"]="ẵ"
COMPOSE["̣ă"]="ặ"
COMPOSE["´â"]="ấ"
COMPOSE["`â"]="ầ"
COMPOSE["̉â"]="ẩ"
COMPOSE["~â"]="ẫ"
COMPOSE["̣â"]="ậ"
COMPOSE["´e"]="é"
COMPOSE["`e"]="è"
COMPOSE["̉e"]="ẻ"
COMPOSE["~e"]="ẽ"
COMPOSE["̣e"]="ẹ"
COMPOSE["´ê"]="ế"
COMPOSE["`ê"]="ề"
COMPOSE["̉ê"]="ể"
COMPOSE["~ê"]="ễ"
COMPOSE["̣ê"]="ệ"
COMPOSE["´i"]="í"
COMPOSE["`i"]="ì"
COMPOSE["̉i"]="ỉ"
COMPOSE["~i"]="ĩ"
COMPOSE["̣i"]="ị"
COMPOSE["´o"]="ó"
COMPOSE["`o"]="ò"
COMPOSE["̉o"]="ỏ"
COMPOSE["~o"]="õ"
COMPOSE["̣o"]="ọ"
COMPOSE["´ô"]="ố"
COMPOSE["`ô"]="ồ"
COMPOSE["̉ô"]="ổ"
COMPOSE["~ô"]="ỗ"
COMPOSE["̣ô"]="ộ"
COMPOSE["´ơ"]="ớ"
COMPOSE["`ơ"]="ờ"
COMPOSE["̉ơ"]="ở"
COMPOSE["~ơ"]="ỡ"
COMPOSE["̣ơ"]="ợ"
COMPOSE["´u"]="ú"
COMPOSE["`u"]="ù"
COMPOSE["̉u"]="ủ"
COMPOSE["~u"]="ũ"
COMPOSE["̣u"]="ụ"
COMPOSE["´ư"]="ứ"
COMPOSE["`ư"]="ừ"
COMPOSE["̉ư"]="ử"
COMPOSE["~ư"]="ữ"
COMPOSE["̣ư"]="ự"
COMPOSE["´y"]="ý"
COMPOSE["`y"]="ỳ"
COMPOSE["̉y"]="ỷ"
COMPOSE["~y"]="ỹ"
COMPOSE["̣y"]="ỵ"
COMPOSE["´A"]="Á"
COMPOSE["`A"]="À"
COMPOSE["̉A"]="Ả"
COMPOSE["~A"]="Ã"
COMPOSE["̣A"]="Ạ"
COMPOSE["´Ă"]="Ắ"
COMPOSE["`Ă"]="Ằ"
COMPOSE["̉Ă"]="Ẳ"
COMPOSE["~Ă"]="Ẵ"
COMPOSE["̣Ă"]="Ặ"
COMPOSE["´Â"]="Ấ"
COMPOSE["`Â"]="Ầ"
COMPOSE["̉Â"]="Ẩ"
COMPOSE["~Â"]="Ẫ"
COMPOSE["̣Â"]="Ậ"
COMPOSE["´E"]="É"
COMPOSE["`E"]="È"
COMPOSE["̉E"]="Ẻ"
COMPOSE["~E"]="Ẽ"
COMPOSE["̣E"]="Ẹ"
COMPOSE["´Ê"]="Ế"
COMPOSE["`Ê"]="Ề"
COMPOSE["̉Ê"]="Ể"
COMPOSE["~Ê"]="Ễ"
COMPOSE["̣Ê"]="Ệ"
COMPOSE["´I"]="Í"
COMPOSE["`I"]="Ì"
COMPOSE["̉I"]="Ỉ"
COMPOSE["~I"]="Ĩ"
COMPOSE["̣I"]="Ị"
COMPOSE["´O"]="Ó"
COMPOSE["`O"]="Ò"
COMPOSE["̉O"]="Ỏ"
COMPOSE["~O"]="Õ"
COMPOSE["̣O"]="Ọ"
COMPOSE["´Ô"]="Ố"
COMPOSE["`Ô"]="Ồ"
COMPOSE["̉Ô"]="Ổ"
COMPOSE["~Ô"]="Ỗ"
COMPOSE["̣Ô"]="Ộ"
COMPOSE["´Ơ"]="Ớ"
COMPOSE["`Ơ"]="Ờ"
COMPOSE["̉Ơ"]="Ở"
COMPOSE["~Ơ"]="Ỡ"
COMPOSE["̣Ơ"]="Ợ"
COMPOSE["´U"]="Ú"
COMPOSE["`U"]="Ù"
COMPOSE["̉U"]="Ủ"
COMPOSE["~U"]="Ũ"
COMPOSE["̣U"]="Ụ"
COMPOSE["´Ư"]="Ứ"
COMPOSE["`Ư"]="Ừ"
COMPOSE["̉Ư"]="Ử"
COMPOSE["~Ư"]="Ữ"
COMPOSE["̣Ư"]="Ự"
COMPOSE["´Y"]="Ý"
COMPOSE["`Y"]="Ỳ"
COMPOSE["̉Y"]="Ỷ"
COMPOSE["~Y"]="Ỹ"
COMPOSE["̣Y"]="Ỵ"
M.ids={"us","cz","cz_qwerty","sk","sk_qwerty","de","fr","es","it","pt","pt_br"}
M.names={"English (US)","Czech (QWERTZ)","Czech (QWERTY)","Slovak (QWERTZ)","Slovak (QWERTY)","German (QWERTZ)","French (AZERTY)","Spanish (Spain)","Italian","Portuguese (Portugal)","Portuguese (Brazil ABNT2)"}
M.ids[#M.ids+1]="ro";M.names[#M.names+1]="Romanian (Standard)"
M.ids[#M.ids+1]="ru";M.names[#M.names+1]="Russian"
M.ids[#M.ids+1]="uk";M.names[#M.names+1]="Ukrainian"
M.ids[#M.ids+1]="hu";M.names[#M.names+1]="Hungarian"
M.ids[#M.ids+1]="vi";M.names[#M.names+1]="Vietnamese"
M.ids[#M.ids+1]="pl";M.names[#M.names+1]="Polish (Programmers)"
M.ids[#M.ids+1]="tr";M.names[#M.names+1]="Turkish (Q)"
M.ids[#M.ids+1]="nl";M.names[#M.names+1]="Dutch"
M.ids[#M.ids+1]="sv";M.names[#M.names+1]="Swedish"
M.ids[#M.ids+1]="da";M.names[#M.names+1]="Danish"
M.ids[#M.ids+1]="no";M.names[#M.names+1]="Norwegian"
M.ids[#M.ids+1]="fi";M.names[#M.names+1]="Finnish"
M.ids[#M.ids+1]="el";M.names[#M.names+1]="Greek"
local order={};for i,name in ipairs(M.names) do order[#order+1]={id=M.ids[i],name=name} end
table.sort(order,function(a,b) return a.name<b.name end)
for i,item in ipairs(order) do M.ids[i]=item.id;M.names[i]=item.name end
local K={};K.__index=K
function M.new(id)
  local index=1;for i,id in ipairs(M.ids) do if id=="us" then index=i end end
  for i,v in ipairs(M.ids) do if v==id then index=i;break end end
  local k=setmetatable({id=M.ids[index],name=M.names[index],map={}},K)
  local data=DATA[k.id]
  if data then
    for line in data:gmatch("[^\n]+") do
      local fields={}
      for item in (line.."\t"):gmatch("([^\t]*)\t") do fields[#fields+1]=item end
      local code=table.remove(fields,1);k.map[code]=fields
    end
  end
  return k
end
function K:reset() self.pending=nil;self.right_alt=false end
function K:modifier(ev)
  if ev.code=="AltRight" then self.right_alt=ev.phase~="up" end
  if ev.code~="AltRight" and not (ev.mods and ev.mods.alt) then self.right_alt=false end
end
function K:feed(ev,caps)
  local code=ev.code or "";local m=ev.mods or {}
  local altgr=self.right_alt and m.alt and not m.meta
  if (m.ctrl or m.meta or m.alt) and not altgr then self.pending=nil;return nil,false end
  local value
  if self.id=="us" then
    if altgr then return nil,false end
    value=ev.text
    if value and caps and code:match("^Key[A-Z]$") then value=m.shift and value:lower() or value:upper() end
  else
    local fields=self.map[code]
    if fields then
      local layer=altgr and 5 or caps and 3 or 1
      if m.shift then layer=layer+1 end
      local raw=fields[layer]
      if raw:sub(1,1)=="d" then
        if ev.phase=="repeat" then return nil,true end
        return nil,true,raw:sub(2)
      end
      value=raw:sub(2)
    elseif code:match("^Numpad") then value=ev.text end
  end
  if not value or value=="" then
    if code:find("Arrow",1,true) or code=="Home" or code=="End" or code=="PageUp" or code=="PageDown" or code=="Enter" or code=="Tab" or code=="Delete" then self.pending=nil end
    return nil,false
  end
  return value,true
end
function K:shortcut(code)
  if self.id=="de" or self.id=="fr" then
    local fields=self.map[code];local letter=fields and fields[1]:sub(2)
    if letter and letter:match("^[a-z]$") then return "Key"..letter:upper() end
  end
  return code
end
local VIRTUAL={
 us={chars="'\"—…!?()",upper="'\"—…!?()",accents={"'","-"}},
 cz={chars="ěščřžýáíéúůďťň",upper="ĚŠČŘŽÝÁÍÉÚŮĎŤŇ",accents={"´","ˇ"}},
 sk={chars="ľščťžýáíéúäôňďŕĺ",upper="ĽŠČŤŽÝÁÍÉÚÄÔŇĎŔĹ",accents={"´","ˇ"}},
 de={chars="äöüßé",upper="ÄÖÜẞÉ",accents={"¨","^"}},
 fr={chars="àâæçéèêëîïôœùûüÿ",upper="ÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ",accents={"`","^"}},
 es={chars="áéíóúüñ¿¡",upper="ÁÉÍÓÚÜÑ¿¡",accents={"´","¨"}},
 it={chars="àèéìòóù",upper="ÀÈÉÌÒÓÙ",accents={"`","´"}},
 pt={chars="áàâãçéêíóôõúü",upper="ÁÀÂÃÇÉÊÍÓÔÕÚÜ",accents={"~","´"}},
 pt_br={chars="áàâãçéêíóôõúü",upper="ÁÀÂÃÇÉÊÍÓÔÕÚÜ",accents={"~","´"}},
}
VIRTUAL.ro={chars="ăâîșț",upper="ĂÂÎȘȚ",accents={"´","`"}}
VIRTUAL.ru={chars="йцукенгшщзхъфывапролджэячсмитьбюё",upper="ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ",accents={"´","`"}}
VIRTUAL.uk={chars="йцукенгшщзхїфівапролджєячсмитьбюґ",upper="ЙЦУКЕНГШЩЗХЇФІВАПРОЛДЖЄЯЧСМИТЬБЮҐ",accents={"´","`"}}
VIRTUAL.hu={chars="áéíóöőúüű",upper="ÁÉÍÓÖŐÚÜŰ",accents={"´","`"}}
VIRTUAL.vi={chars="ăâđêôơư´`̉~̣",upper="ĂÂĐÊÔƠƯ´`̉~̣",accents={"´","`","̉","~","̣"}}
VIRTUAL.pl={chars="ąćęłńóśźż",upper="ĄĆĘŁŃÓŚŹŻ",accents={"´","`"}}
VIRTUAL.tr={chars="çğıöşü",upper="ÇĞİÖŞÜ",accents={"´","`"}}
VIRTUAL.nl={chars="áàäéèëïöü",upper="ÁÀÄÉÈËÏÖÜ",accents={"´","`"}}
VIRTUAL.sv={chars="åäö",upper="ÅÄÖ",accents={"´","`"}}
VIRTUAL.da={chars="æøå",upper="ÆØÅ",accents={"´","`"}}
VIRTUAL.no={chars="æøå",upper="ÆØÅ",accents={"´","`"}}
VIRTUAL.fi={chars="äöå",upper="ÄÖÅ",accents={"´","`"}}
VIRTUAL.el={chars="ςερτυθιοπασδφγηξκλζχψωβνμ",upper="ΣΕΡΤΥΘΙΟΠΑΣΔΦΓΗΞΚΛΖΧΨΩΒΝΜ",accents={"´","`"}}
function M.virtual(id) return VIRTUAL[id] or VIRTUAL[id:sub(1,2)] or VIRTUAL.us end
function M.virtual_accent(id,label)
 if id=="us" then return false end
 local v=M.virtual(id);for _,accent in ipairs(v.accents) do if label==accent then return true end end;return false
end
function M.code(id) return id=="pt_br" and "BR" or id:sub(1,2):upper() end
function M.accent(letter,accent) return COMPOSE[accent..letter] end
return M
