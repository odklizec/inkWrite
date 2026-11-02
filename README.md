# inkWrite

A quiet writing and journaling app for Xteink X4Pro and X4Classic. Current development build: **0.1.45**. Requires compatible Gancao firmware with XTApp API 2.18 support.

## Start writing

Pair a Bluetooth keyboard in the device settings, then open inkWrite. The main dock offers **New, Open, Save, Settings**. New offers today's journal, a Markdown page or a plain-text page. Ctrl+J opens or creates today's journal.

On Pro, open the on-screen keyboard through **Settings → Keyb. → On-screen keyboard** or swipe up from the bottom edge. Hide, Back or a downward swipe across the keyboard dismisses it. The large Space and tall Enter keys support touch writing. Classic can navigate the virtual keys with its direction buttons and OK.

## Languages and accents

Choose your languages with checkboxes in **Settings → Keyb.** English (US) is the default; at least one layout must stay selected. Tap the status keyboard icon or language abbreviation to switch among selected layouts, or press **Left Alt+Shift**. The abbreviation shows the active layout, not Bluetooth connection status.

Available: English US, Czech and Slovak QWERTZ/QWERTY, German, French, Spanish, Italian, Portuguese Portugal/Brazil, Romanian Standard, Russian, Ukrainian, Hungarian, Vietnamese, Polish Programmers, Turkish Q, Dutch, Swedish, Danish, Norwegian, Finnish and Greek. All are left-to-right.

Type the letter **before** the accent: `c` then `ˇ` becomes `č`; `e` then `´` becomes `é`. Unsupported combinations insert the accent literally. Accent replacement has its own undo step. Right Alt provides AltGr on supported layouts. Caps Lock is app-local and does not synchronize keyboard LEDs. The language popup pages when needed; use Prev/Next or arrow/page keys. German/French Ctrl shortcuts follow the printed letters. Bluetooth variants must match the selected layout; special ISO/ABNT keys depend on the positions exposed by firmware. On Brazilian layouts AltGr+Q also provides `/`. Vietnamese uses the standard physical layout and post-vowel tone marks on the virtual national row; no IME or dictionary is included.

## Touch selection and focus

- Tap text to position the caret.
- Double-tap a word to select it; triple-tap text to select its sentence.
- Double-tap empty writing space to toggle focus on or off.
- Swipe up/down in the document to browse. Typing returns to the editing caret.
- Focus hides the normal title and toolbars, retaining language, word count and the position indicator when needed. Settings → Focus and Ctrl+Shift+F also toggle it. Back or a long hold in the writing area exits focus.

Fast taps use the firmware's native double-tap event and captured touch timestamps. Sentence selection uses punctuation and newline boundaries; abbreviations and complex linguistic sentence rules are not parsed.

## Typography and orientation

Settings → Type offers font selection, size, line spacing and margins. A sample of up to five lines previews changes; controls stay anchored above the bottom bar. Fewer sample lines appear when space is constrained. Typography changes appearance only, not saved file contents.

Place `.ttf` fonts in the SD card's fonts folder and reopen the app. System sizes are 24/30 px; custom sizes are 20/24/28/32/36 px. Glyph coverage depends on the font. To bound memory use, at most eight custom font/size pairs are attempted per session; reopening resets that budget.

**Settings → Screen** or **Ctrl+Shift+S** toggles portrait and landscape. The choice is remembered for the next open; it applies only to inkWrite and does not change device settings.

## Files, saving and recovery

Documents are ordinary UTF-8 `.md` or `.txt` files in **`/AppFiles/inkwrite/`**. Open File includes rename and delete controls. Delete asks for confirmation. Renaming copies and verifies the file before removing the source; interruption can leave both files or a partial new copy. Keep the app open during rename.

Ctrl+S or Save writes to SD. Autosave runs after approximately five idle seconds or thirty dirty seconds. A failed autosave pauses retries until another edit or explicit save. A Saved label means the public write succeeded.

If a loaded file changed externally, saving creates a conflict copy instead of silently replacing it. Differing recovery text reopens as a recovered copy. Check and save recovered text. Protected/recovery errors block unsafe changes.

Back from the normal editor or its header X opens the close dialog. Unsaved changes offer Save or Discard, with Cancel available. Explicit Discard removes matching recovery; a failed save keeps the app open.

## Retrieve your writing

Save, power down the device, remove its SD card and copy `.md`/`.txt` files from `AppFiles/inkwrite/` using a card reader. Open them in a normal editor without conversion. Public documents survive app upgrades and uninstall; private recovery/preferences do not survive uninstall. Keep external file edits separate from editing in inkWrite.

Wireless export is optional future work and is not required for manual retrieval.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl+S | Save |
| Ctrl+N | New dated Markdown document |
| Ctrl+O | Open file |
| Ctrl+J | Today's journal |
| Ctrl+Z / Ctrl+Shift+Z | Undo / redo |
| Ctrl+A | Select all |
| Shift+movement | Extend selection |
| Ctrl+C / X / V | App-local copy / cut / paste |
| Ctrl+B / Ctrl+I | Bold / italic Markdown markers |
| Home / End | Current visual line start / end |
| Ctrl+Home / Ctrl+End | Document start / end |
| Ctrl+Left / Right | Move by word |
| PageUp / PageDown | Move by page |
| Ctrl+Shift+F | Toggle focus |
| Ctrl+Shift+S | Rotate screen |
| Left Alt+Shift | Next selected keyboard |
| Ctrl+R | Full refresh |
| Escape | More menu / return to writing |

## Current limits and release status

Editable documents are capped at **32 KiB**. Undo holds up to **100 groups / 32 KiB** of retained text; the app clipboard is capped at **8 KiB**. Editing is left-to-right UTF-8 source editing, not rendered Markdown or grapheme-cluster editing. Search, rendered preview and wireless export are not implemented.

The owner has confirmed working Bluetooth typing and the latest fast multi-tap gestures on Pro. Local tests and native previews provide additional evidence, but long-session memory, SD interruption and the full Classic/Pro hardware matrix are still release gates. See [release checklist](docs/RELEASE-CHECKLIST.md), [current status](docs/STATUS.md) and [technical handover](docs/HANDOVER.md). Older build notes are preserved in [development history](docs/DEVELOPMENT-HISTORY.md).


## Writing statistics

Open Settings → More → Statistics. Week and Month show daily typing-time bars; Year shows monthly bars. Switch periods on the same page using the tabs or arrow keys. Totals include words added, active typing time and foreground app time. Average/day divides typing time by elapsed calendar days in the current period, including days with no writing.

Typing time includes editing and a 30-second idle grace after input; time while paused/asleep is excluded. Words added count positive document-word increases from insertion, including paste; deletions do not subtract and undo/formatting do not add words. Existing documents are not backfilled. Invalid device dates pause recording. History retains up to 400 recorded days, stored privately without document text. Checkpoints are written about once a minute and on pause/exit; sudden power loss may lose the latest uncheckpointed statistics. Uninstall removes private statistics.

## 0.1.33 national virtual character row

Added language-specific direct characters below numbers, uppercase via Shift, and a More key for rows longer than nine characters. Czech/Slovak include their common accented letters; German ä/ö/ü/ß, French accented vowels/ç/œ/æ, Spanish accents/ñ/¿/¡, Italian accented vowels, and both Portuguese variants their accented vowels/ç. English US shows useful punctuation instead of Czech marks. Main accent controls now follow the selected layout: Czech/Slovak acute/caron, German diaeresis/circumflex, French grave/circumflex, Spanish acute/diaeresis, Italian grave/acute, Portuguese tilde/acute. Post-letter accent semantics retained. Six compact 44px rows occupy 264px; text and popup geometry share that height. No native fonts/buffers added.


## 0.1.34 Statistics shortcuts

Tap the word-count icon/number in the editor status area to open Statistics, including focus mode. Swipe left starting within 32 pixels of the right edge for the same page. Existing More route and Back return remain available; opening statistics preserves document, caret, selection and focus state and dismisses the virtual keyboard. No extra toolbar slot, fonts or buffers.


## 0.1.36 memory and allocation work

Reviewed the owner-supplied InkStream_memory.md and inkStream 1.0.54–1.0.57 implementation. The firmware allocator fix described in that correspondence is not assumed to be installed. inkWrite has no feed parser, networking or decompression, so those changes do not apply. Routine forced collections were already absent; only the explicit More memory diagnostic collects. Typing redraws and minute-level statistics checkpoints were already batched.

Buffer block construction now walks the original input rather than copying its shrinking tail. Single-block slices return directly without temporary closures/join tables, stop at the requested range, and byte/boundary/caret queries avoid string slices. UTF-8 boundaries, 32 KiB document limit, undo grouping/limits and exact source bytes are retained. No whole-document cache or extra native font/framebuffer allocations.

Pause/exit recovery records only the successfully saved document identity/revision, avoiding a second identical snapshot on immediate exit. New edits, a different document and any public-save attempt invalidate that reuse; failures are retried. Recovery-first public saves and external-edit/conflict checks remain intact. Read-back in these safety paths and rename verification is intentional, unlike inkStream's immutable body writes.

A deterministic 30,400-byte open/navigation/edit scenario reduced substring payload bytes from 533,721 to 92,804 (82.6%), substring calls from 2,427 to 295, joins from 1,902 to 1. Opening alone went from 466,716 substring bytes to 30,400. These are instrumented allocation-work counts, not native allocator, peak heap or physical typing-latency measurements. Full controller/UTF-8/save regressions: 74,741 assertions. Typing cache/batching: 31,816 assertions, unchanged stream measurements and frame count. Physical-device acceptance remains required.


## 0.1.37 Shortcuts and transient notices

Swipe right starting within 32 pixels of the left screen edge to open the paged Shortcuts reference, including focus mode. Back restores the editor and its focus state; More > Keyboard help remains available. Text, caret and selection are preserved. This uses the existing page renderer without slide animation or additional buffers. Font-picker notices and other transient messages dismiss on the next deliberate touch/key action; file-job guards, protected state and save-failure indicators remain. Pointer movement and trailing keyboard releases do not dismiss a newly created notice.



The first typing frame after idle is prepared immediately. Further keystrokes share a 30 ms grouping window; an unchanged window requests no extra refresh. More → Memory & timing shows session maximum app input, queue, layout, drawing and save durations. Input-to-draw ends when the app has drawn the frame; it excludes Bluetooth transmission and the screen refresh. These numbers are diagnostic measurements, not a promise of screen response speed.


