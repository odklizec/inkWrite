# Simpler direct GitHub sync - 1.0.13

The owner requested the suggestions from "Compare Draftling and inkWrite" (13 November 2026), then chose "Keep direct device sign-in; simplify setup without a hosted service". This supersedes the comparison's optional hosted companion suggestion.

## What changed

- **Sync this document** is the first, outlined action; **Ctrl+G** runs it from the editor. It saves local edits using the existing safe save path, checks GitHub and uploads when safe. Equal bytes need no upload.
- Status says **Saved locally**, **Unsaved local changes**, **Changes waiting to upload**, **Up to date at last sync**, or **Remote changes found**. This is cached outside drawing; the last-sync label does not claim continuous remote monitoring.
- If only GitHub changed since the recorded common version, offer **Update local document** and **Download as local copy**, with Cancel selected initially. Update fetches and verifies the selected remote SHA again, verifies the local editor revision and disk bytes, keeps an exact `before-sync-###.md`/`.txt` backup, protects recovery, writes and verifies the document, then checkpoints metadata. New text replaces the editor without adding typing statistics. Conflicts still offer copies and never silently choose a side.
- First connection offers **Remember and connect** or **Connect for this session only**. The SD credential disclosure appears before the choice. Remembered connections renew while GitHub allows; QR remains available when approval is required. No hosted service, client secret, permanent authorization promise or automatic transfer after sign-in.
- One footer Back remains on the main sync screen. Nested Cancel/Back controls remain.

## Try it

1. Open a saved disposable document, press Ctrl+G or choose Sync this document, connect if needed, then choose Sync again. Check the file in the private repository's `documents/` folder.
2. Change it locally and Sync. Sync once more without edits: it should report Up to date without uploading.
3. Change only the GitHub copy, reopen Sync and choose Sync this document. Choose Update local document. Check the new text and the exact old text in the local `before-sync-###` file. Cancel should leave the document unchanged.
4. Change both copies. Sync must offer copy choices and preserve originals.
5. Reopen after Remember, then test session-only and Forget separately. QR should still open GitHub approval if required.

Use disposable files for device acceptance. Transfers remain manual, one document at a time, limited to 32 KiB UTF-8 Markdown/plain text. No full Git history, library reconciliation or background retries were added. SD API has no compare-and-swap; external card edits must not run concurrently with an update. Backup/recovery reduces interruption risk, but hardware power-loss behavior is not established by desktop tests.

## Verification

Automated integration tests cover unified upload/equal/remote update/conflict, exact accented CRLF bytes, backup and metadata, dirty edits, changed remote SHA, unrelated recovery, SD failures, pause and failed metadata writes. UI tests cover connection choice, approval, navigation, shortcut and unchanged editor bytes. Final test counts, native preview evidence, cloud export hashes and commit are supplied in the delivery verification artifact. Physical Classic/Pro and real repository transfers remain owner acceptance.
