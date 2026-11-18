# Conflict review and replacement - 1.0.18

## Find and read the versions

A **GitHub !** badge in the writing header means a known conflict or held upload needs attention. It remains visible in focus mode. Tap it, or press Ctrl+G while it is present. You can also select a Review filename under Automatic uploads, choose Review both versions from a conflict, or use Review current document versions on the main GitHub sync page.

The indicator reports information discovered by a sync attempt; it is not continuous monitoring of GitHub. If GitHub changed but no check has run yet, open manual Sync/Review to discover it.

Opening review saves current local edits successfully before fetching GitHub. The review screen shows the filename and byte sizes. **Read local version** and **Read GitHub version** display separate read-only source pages. Prev/Next and direction keys move through the text; Back returns to the choices. These viewers do not edit the document, merge it, or show a highlighted diff.

## Keep one version

- **Use GitHub version locally...** opens a confirmation with Cancel selected. **Replace local version** fetches GitHub again, verifies that local and remote match what you reviewed, writes and verifies a `before-sync-###.md`/`.txt` backup of local text, protects recovery, and replaces the local file/editor. Open the backup through the ordinary file library if needed.
- **Keep local version on GitHub...** also starts on Cancel. **Overwrite GitHub version** rechecks both sides and first writes/verifies a `github-before-###.md`/`.txt` backup of GitHub's reviewed contents on SD. It uploads local text using that remote blob SHA as a write precondition. GitHub retains its normal commit history; no force-push occurs. A missing remote can be recreated only after explicitly reviewing and confirming its absence.

If either side changes while reviewing, refresh both versions and decide again. If a backup cannot be saved, replacement stops. A refused or ambiguous network response never implies success; check GitHub again. If only the sync-record checkpoint fails after a successful replacement, the result says so and keeps the backup. A subsequent manual check can reconcile equal bytes without another upload.

Successful resolution clears the corresponding pending upload/alert. Copy choices in the existing conflict flow are still available when you want to preserve both versions under separate names.

## Safety and limits

Documents remain capped at 32 KiB UTF-8 Markdown/plain text. Reviews are read-only snapshots and release their content on leaving. Reviewing another queued file preserves the active editor; active unsaved text is saved first. Unrelated recovery or ambiguous case aliases block replacement. SD APIs provide atomic file writes but no compare-and-swap: do not edit the same card externally during an operation. Backups consume SD file slots; no backups are automatically deleted.

## Acceptance steps

Use a disposable file: upload A, edit GitHub to B, edit inkWrite to C and let automatic upload detect the conflict. Check the badge without opening settings, read B and C, cancel each confirmation and verify neither copy changed. Then test each replacement direction separately, checking exact backup contents. Edit GitHub again while a confirmation is open: overwrite must be refused. Repeat with unsaved edits, accented/CRLF text, 32 KiB content, offline/revoked access, failed SD writes, focus mode, Classic buttons and Pro touch.

Desktop verification covers 28 suites / 16,052 assertions (full regression plus final targeted sync checks). A native synthetic Pro flow exercised the real writer, read-only UI and local replacement, and verified the original 96-byte draft in its backup. The preview had no network permission and used a synthetic GitHub adapter. Real repository replacement and physical interruption/power-loss behavior remain device acceptance.
