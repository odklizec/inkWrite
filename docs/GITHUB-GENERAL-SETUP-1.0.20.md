# General GitHub setup - 1.0.20

The GitHub sync page now has **GitHub setup / change repository**. Fresh installs
open setup automatically with empty fields. Existing configured owner installs
retain their public IDs, destination, saved grant and original metadata/queue.
No hosted service is involved. Each user registers and installs their own
personal GitHub App with device flow, Contents write and Metadata read, using
selected repositories; initialize the private repository with a README.

## In the app

Enter the public Client ID, numeric App ID and expected GitHub login. Sign in
using the displayed code/QR. inkWrite verifies the actual account and matching
personal installation, then lists accessible private writable repositories and
existing branches. Choose a destination and explicitly Save. Local documents
are never uploaded, downloaded, replaced or deleted by setup. Cancel discards
the separate candidate RAM session and preserves the current configuration.
The candidate sign-in becomes the active session after Save, avoiding a second
approval. Remember remains an explicit choice with the existing unencrypted SD
notice. Setup storage itself contains public identifiers only.

Saved setups appear below the setup fields; choosing one asks for confirmation
and uses its isolated records. Access is verified again when connecting or
performing operations. New setups permit multiple selected repositories and
other unrelated App installations, while document URLs remain restricted to the
chosen repository's documents folder and branch. Legacy mode stays strict until
reconfigured.

## Switching and failures

The app flushes the old pending queue and disconnects before committing the new
public configuration. Four additional slots plus a migrated legacy slot cap
storage growth. Each has a separate credential, sync-record and upload-queue
file; returning to the same App/account/repository ID/name/branch reuses its
slot. Old files and ordinary local documents are preserved. Automatic uploads
start Off and Remember consent is requested again on every switch. Enable them
only after checking the destination and retained queue.

The public setup manifest is bounded, checksummed and read back after writing.
A failed/ambiguous commit blocks sync until reopening. A revision marker turns
sync/Remember/automatic uploads Off if power loss leaves old preferences with a
new manifest. Corrupt setup fails closed; it never silently selects the owner's
repository. Repair requires recovering the private setup manifest from backup;
local writing remains available. No destructive reset or profile deletion is
provided in this version.

## Limits and acceptance

Personal account repositories only; up to 20 visible installations, 100 selected
repositories, and 100 branch results, 10 per request. Empty repositories need a
README first. Branch names use inkWrite's existing supported ASCII subset.
Account, installation, permission and expired-code errors give retry guidance.
No org onboarding, App registration, public shared App, or server is introduced.

Automated tests use synthetic GitHub responses, never real tokens or private
documents. They cover the whole UI/Auth/Session handoff, remembered credentials,
wrong account/permissions, forged/stale choices, failure during final binding,
profile isolation, migration, bounded profiles, corrupt/failed/ambiguous storage
and interrupted activation. The owner saved this implementation as cloud version 1.0.21, verified on
2026-11-19. Native preview, a second account and physical-device switching
still need acceptance.

Device checks:

1. Existing install: verify current connection still works without redoing setup.
2. Open setup and Cancel; verify destination, local text and pending queue remain.
3. Enter your own public IDs/login, sign in, pick private repo and branch, then Save.
4. Verify destination, connection, and Automatic uploads Off; opt into Remember.
5. Close/reopen and check renewal. Test one manual upload using disposable text.
6. Switch to a different branch/repo. Check old pending uploads do not run there.
7. Return to the first saved setup and verify its queue/records remain separate.
