# inkWrite 1.0.25 - 20 November 2026

Split screen supports two independent documents in normal and focus modes,
with top/bottom or left/right panes and 1:1, 2:1 and 1:2 ratios. New/Open/Save
and journal operations follow the visibly marked active pane. Both documents
keep independent selection, undo, scrolling, recovery and autosave.

Auto: follow screen is the default and first setting below Back to writing:
portrait uses top/bottom; landscape uses left/right. An explicit direction
remains fixed across rotation and reopening. Select Auto to release it.

- Ctrl+Shift+S: single -> 1:1 -> 2:1 -> 1:2 -> single.
- Ctrl+Shift+R: rotate screen. Ctrl+S still saves; Ctrl+R still refreshes.
- Ctrl+Shift+P: split settings. Ctrl+Tab: switch active pane.
- Classic Left/Right: select A/B; focus OK: split settings.
- Pro: tap a header to activate; hold a header for split settings.

The owner reported hardware testing good on 20 November 2026. Automated
checks cover recovery failures, both-session Save/Discard, hidden documents,
remote update ownership and stale callbacks. A complete power-loss and SD
failure matrix is not claimed. Once split recovery slots are used, older
single-pane builds cannot load those slots; save both documents before any
downgrade. Public Markdown/text files remain ordinary SD files.

Canonical Studio app: inkWrite (inkwrite), project
bc6ebcee-26df-4d19-b814-b9e488605d51. API 2.26 / compatible Gancao firmware.
Original icons, cover and cloud-only setup guide references are preserved.

This is the final saved release after Studio patch-version reconciliation.
Studio documentation entries are retained; new binary screenshots are excluded
from text-source imports. The self-contained HTML guide keeps its illustrations.
