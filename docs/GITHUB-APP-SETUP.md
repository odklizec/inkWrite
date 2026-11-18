# Set up Direct GitHub for inkWrite

Build 1.0.20 includes in-app setup. Use your own personal GitHub App and a
separate private documents repository. No hosted companion, client secret,
private key or permanent token is required.

## 1. Create a documents repository

On GitHub, create a **private** repository, for example `inkwrite-docs`. Add a
README so its `main` branch exists. Keep this separate from the `inkWrite` source
repository. inkWrite uploads documents into its `documents/` folder.

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

## 3. Install it on selected repositories

From the App settings, choose Install App and select your own account. Choose
**Only select repositories**, then select only your private documents repository.
Review the Contents read/write and Metadata read permissions before installing.
Do not choose all repositories or the inkWrite source repository.

New setups list up to 100 selected repositories belonging to the signed-in
personal account, showing only private repositories with push access. Additional
App permissions and All repositories are rejected. Existing legacy connections
retain their original one-repository checks until set up again.

## 4. Enter the public values in inkWrite

Open **Settings > More > GitHub sync > GitHub setup / change repository**.
On a fresh install, GitHub sync opens setup immediately.

1. Enter the public **Client ID**, numeric **App ID**, and your **GitHub login**.
2. Choose **Sign in and choose repository**.
3. Scan the QR or open `github.com/login/device`, enter the displayed code and approve.
4. Select your private documents repository and existing branch.
5. Review the destination and choose **Save and use this setup**.
6. Optionally enable **Remember connection on this device** after reading its SD-storage notice.

Enter these public values in the app; there is no need to send them in chat or
edit source code. Never enter a client secret, private key or access token.
See [setup behavior, limits and checks](GITHUB-GENERAL-SETUP-1.0.20.md).

## What sign-in will do

inkWrite will display GitHub's device verification address and a short code.
You enter that code yourself in a browser, check the App/account and approve.
The client then verifies your account, App permissions, private repo and branch
before allowing document operations. It rechecks access before each operation.
See [GitHub's device-flow documentation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app).

Build 1.0.8 offers **Remember connection on this device** with explicit consent before saving reusable access/refresh credentials in app-private, unencrypted SD storage. A person with access to the card can recover them. Without this option, credentials remain in RAM. Temporary system covers preserve the RAM session and pending code; true exit clears RAM. **Forget saved connection** removes the credential file and disconnects; **Disconnect for now** ends the current RAM session but keeps an opted-in saved connection for next launch. GitHub-side revocation remains available. GitHub and repository collaborators can read uploaded files.

Keep expiring tokens enabled. GitHub now documents refresh without a client secret for tokens created via device flow. Do not send or embed an App secret, disable expiration, or create a permanent token for this correction. See [1.0.8 connection notes](GITHUB-CONNECTION-1.0.8.md).

Disconnect only forgets the device session. To revoke the GitHub grant, open
GitHub Settings → Applications → Authorized GitHub Apps and revoke the App.
You can also uninstall it under Installed GitHub Apps to remove repository access.
No client secret is embedded to perform management operations from the device.

## After setup

Manual sync, version history, conflict review and optional automatic uploads use
the selected destination. Switching setups leaves automatic uploads Off and
keeps the old destination's queue and sync records isolated. Existing owner
configuration is migrated without moving its records or reconnecting merely
because of this update. This new setup flow is covered by synthetic tests and
Studio preview; physical-device setup with another account remains to be tested.
