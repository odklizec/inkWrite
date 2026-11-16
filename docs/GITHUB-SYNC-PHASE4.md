# Phase 4 - Document history and restore (1.0.14)

## Use it

1. Open **Settings > More > GitHub sync** and connect if needed.
2. Choose **Version history: current document**. Unsaved editor changes are left alone. Alternatively Browse remote documents, select a filename, then choose **Version history**.
3. Entries show commit date, short commit ID and the first line of the commit message. **Older versions** and **Newer versions** change GitHub pages; footer Prev/Next moves through controls when a screen is small.
4. Select a version. Cancel is selected initially. Choose **Restore as new local copy** to retrieve that exact commit's document.
5. The result names the new `restore-###.md` or `.txt` file. Return to writing, then use Open to inspect it. The active file, unsaved buffer, recovery and other copies remain intact. No commit is made by restoring.

## Acceptance on your device

Use a disposable document with several GitHub versions. Compare the listed dates/messages and restored bytes against GitHub. Check Older/Newer, Cancel and Back using touch and buttons. Restore an accented document with CRLF line endings, then try while the current document has unsaved edits: those edits must remain unchanged. Repeating Restore must allocate another copy. Offline/revoked access, missing historical files or a full SD card must produce a failure without modifying the original.

## Bounds and behavior

- Five entries per network page; one page retained in RAM. At most 20 pages / 100 recent versions. The last full page explicitly reports the limit. Refresh latest history starts a fresh snapshot.
- Pages use the immutable branch-head SHA captured on the first request. A new commit does not shift older pages while browsing. The branch and private-repository authorization are still revalidated for every operation.
- Commit SHA selects the revision; Contents blob SHA validates the returned file representation. They are separate identities. Historical restores never update the live branch's local sync checkpoint.
- Existing 32 KiB UTF-8 Markdown/plain-text and safe-filename rules apply. Deleted-at-that-commit files, malformed/oversized responses and unsupported content are refused. GitHub's path history is used; automatic tracking across renames and a full Git history engine are outside this phase.
- The existing 48 KiB response bound also applies to commit metadata. Very large commit messages can exceed it: the page fails safely rather than buffering without a limit.
- No automatic retry, remote writes/deletes, merge or automatic sync. Phase 5 still requires a separate decision.

## Evidence and limits

24/24 automated suites pass, 15,793 assertions. The new integration suite checks 48 history-specific cases using actual session/auth/transport/import/UI modules and synthetic GitHub/SD data. A synthetic native Pro touch restore created a file with the expected 31 bytes; history/confirmation/result screens were inspected. Direction keys work; native simulator OK reports unsupported, so its acceptance is covered by desktop tests only. Real repository comparison, physical devices, suspend/power-loss and SD interruption remain owner acceptance. No real credentials or private documents were inspected in these tests.
