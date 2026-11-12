# Set up Direct GitHub for inkWrite

The connection code is implemented and mock-tested. Live sign-in needs your own
GitHub App and a separate private documents repository. The editor's sync screen
comes in Phase 3; installing the current editor does not enable sign-in yet.

## 1. Create a documents repository

On GitHub, create a **private** repository, for example `inkwrite-docs`. Add a
README so its `main` branch exists. Keep this separate from the `inkWrite` source
repository. You can leave document creation to the later upload feature.

## 2. Register a personal GitHub App

Open [New GitHub App](https://github.com/settings/apps/new), or navigate through
Settings → Developer settings → GitHub Apps → New GitHub App.

Use these settings:

| Setting | Value |
| --- | --- |
| App name | A unique personal name, such as `inkWrite-Pavel` |
| Homepage URL | Your GitHub profile URL |
| Callback URL / Setup URL | Leave empty; this uses device flow |
| Expire user authorization tokens | Keep enabled |
| Request user authorization during installation | Leave unchecked |
| Enable Device Flow | Enable |
| Webhook → Active | Uncheck; no webhook service is used |
| Repository permissions → Contents | Read and write |
| Repository permissions → Metadata | Read-only (GitHub normally adds this) |
| Other repository/account/organization permissions | No access |
| Where can this App be installed? | Only on this account |

Create the App. No client secret or private key is needed for this device-flow
implementation. Copy the **Client ID** and numeric **App ID** from its settings.
These are public identifiers, different from access tokens/client secrets.

GitHub's [registration guide](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
describes these controls; labels may change slightly.

## 3. Install it on one repository

From the App settings, choose Install App and select your own account. Choose
**Only select repositories**, then select only your private documents repository.
Review the Contents read/write and Metadata read permissions before installing.
Do not choose all repositories or the inkWrite source repository.

This first implementation deliberately rejects extra installations/repositories
or additional App permissions. It checks that only the selected private repo is
accessible; requesting a repository ID alone is not accepted as proof of scope.
See GitHub's [installation access API](https://docs.github.com/en/rest/apps/installations).

## 4. Send these public setup values

- Public Client ID.
- Numeric App ID.
- Your GitHub login.
- Documents repository, for example `odklizec/inkwrite-docs`.
- Branch, normally `main`.

Do not send a client secret, private key, token, device code or authorization code.
The repository ID is optional; the client verifies and binds the returned ID.

## What sign-in will do

inkWrite will display GitHub's device verification address and a short code.
You enter that code yourself in a browser, check the App/account and approve.
The client then verifies your account, App permissions, private repo and branch
before allowing document operations. It rechecks access before each operation.
See [GitHub's device-flow documentation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app).

The access token stays in RAM. Refresh tokens are discarded. Disconnect, pause,
lock, exit or token expiry clears the local session; reconnect afterward. Memory
release is not a promise of cryptographic memory erasure. Nothing is saved as a
device credential. GitHub and repository collaborators can read uploaded files.

Disconnect only forgets the device session. To revoke the GitHub grant, open
GitHub Settings → Applications → Authorized GitHub Apps and revoke the App.
You can also uninstall it under Installed GitHub Apps to remove repository access.
No client secret is embedded to perform management operations from the device.

## After setup

Next: configure the public IDs, verify real HTTPS/auth on the test runtime and
device, then integrate the manual sync UI in Phase 3. Live auth, revoked-token
behavior, firmware networking/memory and physical-device acceptance are still
**NOT TESTED**. Current passing tests are synthetic; no real token was used.
