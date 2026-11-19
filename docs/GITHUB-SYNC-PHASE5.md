# Phase 5 - Optional automatic uploads (1.0.17)

## Enable it

1. Open **Settings > More > GitHub sync > Automatic uploads: Off**.
2. Read the explanation and select **Enable automatic uploads**. This is separate from enabling manual GitHub sync and does not upload the existing library.
3. Choose a delay of **15, 30 or 60 seconds** (30 by default). Return to the writer; automatic transfers are suspended while the GitHub screen is open.
4. Edit and save a disposable document. Explicit Save/Ctrl+S and successful autosave can queue it. Leave inkWrite open and idle for the chosen delay; at least ten seconds without input is also required.
5. If disconnected, use Connect once. Remembered grants can restore/renew without browser approval. Automatic work never starts a new device-approval flow; if authorization is required, connect manually and use Retry pending uploads.

Automatic uploads start Off. Local Saved always refers to SD saving, not a GitHub promise. Remote changes are held for review; use the existing manual Sync/copy/update choices. Nothing is downloaded automatically.

## Pending files and retries

The Automatic uploads page shows a count, status and pending/review filenames. Select a file for guidance. **Retry pending uploads** explicitly resets held entries and the retry budget; a fresh remote check still runs, so a conflict cannot silently overwrite GitHub. Successful manual Sync clears the matching queued version. **Clear upload queue** removes pending markers only, never local documents or GitHub files. Turning automatic uploads Off stops sending and retains the queue.

At most 16 filenames/fingerprints are stored. Repeated saves of one document coalesce; no document bodies or tokens are kept in the queue. A full queue asks you to clear space and save the omitted document again. It is bound to the configured repository and branch, capped at 16 KiB and checksummed. Corrupt or concurrently changed queue data stops automatic sending until reviewed/reset.

Transient failures get at most two automatic retries, after 30 seconds and two minutes. Rate-limited requests wait at least one hour instead. Each retry fetches GitHub first; an upload that succeeded despite a lost response does not create another commit. Three failures hold the entry until explicit retry or a newly saved version. Conflicts remain held even when autosave runs again.

Typing cancels an active automatic operation. Pause/exit cancels network work and preserves pending markers. Transfers run only in the foreground writer; closing, sleep and lock screen do not run a background service. Queue checkpoints run on idle ticks and normal pause/exit. Sudden power loss before a checkpoint can lose a pending marker; the local document remains saved and saving again requeues it. This release does not implement multi-device merges, deletion/rename propagation or a whole-library sweep.

## Device acceptance

Use disposable files in the configured private repository:

- Enable, save, wait in the writer and compare the GitHub bytes. Save unchanged text again: no duplicate commit should appear.
- Type while an upload is pending/in progress. Writing and SD saving must remain responsive; a later idle check should upload the latest saved version.
- Disconnect Wi-Fi, save and close normally. Reopen, restore connectivity and check the pending list/retry behavior.
- Change the same file on GitHub while editing locally. Automatic upload must hold it for review and preserve both sides.
- Test Remember refresh, revoked grants, full SD/private storage, 32 KiB accented documents, repeated opens, suspend and controlled power loss. Check Classic buttons and Pro touch in both orientations.

## Verification

27/27 desktop suites pass, 15,913 assertions. Actual App/session/auth/transport modules run against synthetic GitHub/SD fixtures; existing editor/typing regressions also pass. Native Pro enable/delay/Back layout was checked in a separate app with no networking permission. Hardware Wi-Fi interruption, background latency/memory, power loss and real repository acceptance remain unverified. No real credential or private document was inspected during implementation.
