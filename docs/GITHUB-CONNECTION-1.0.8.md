# Remembered GitHub connection — 1.0.8

The owner rejected having to authorize in a browser after every app start. The earlier RAM-only choice is replaced by an explicit optional remembered connection. No new service, App secret, permanent token or broader repository grant is needed.

## Once after upgrading

Open Settings > More > GitHub sync. Enable sync if needed. Choose **Remember connection on this device**, read the SD-storage explanation, then confirm **Remember on this device** (Cancel is selected initially). Connect and complete GitHub device authorization once. A current valid sign-in can also be saved when enabling Remember if a refresh token and valid device clock are available.

After closing/reopening inkWrite, opening GitHub sync automatically restores the saved access token and verifies the account/App/selected private repo/branch. Expired access tokens renew automatically through GitHub's refresh endpoint. Writing opens offline without loading credentials or making network requests; opening the sync panel starts restoration. No document uploads/downloads run automatically.

**Disconnect for now** ends the current RAM session and suppresses automatic reconnection for the rest of that app session; Connect can retry. It keeps an opted-in saved grant for a future launch. **Forget saved connection** cancels requests, disconnects and removes/verifies absence of github-connection.json. If removal fails, the app reports it and does not claim success. Turning all GitHub sync Off stops network use; use Forget if you also want to remove a saved credential. Revoking the GitHub App authorization invalidates access remotely.

## Missing-code correction

The sign-in URL and code now occupy separate lines. The app shows requesting, failure and expired-code states instead of asking for a code that is not available. Temporary host covers/pause no longer discard the pending code or RAM session; after return, the same unexpired code is redrawn. Leaving the app completely still destroys an incomplete device flow, so a subsequent Connect requests and displays a fresh code. This is separate from restoring an already remembered authorization, which needs no code.

## Storage and refresh behavior

XTApp public contract 09-私有文件.md documents app-private persistent storage, isolated from other apps but on SD. Section 26 explicitly provides no encryption/decryption, and no secure credential vault was verified. Remember therefore asks for in-app consent and accurately states that the reusable credential is **unencrypted on SD and recoverable by someone with the card**. It is not written to public document files, ctx.state, source, cloud Studio backups or logs. The boolean preference alone goes in state. Losing the card/device is a reason to revoke the App authorization through GitHub.

The bounded schema-1 credential record is tied to client/App/login/repo/branch/repository ID, verified account ID and repository ID. It stores access/refresh tokens and conservative wall-clock expirations. Invalid or retargeted records are refused and preserved for explicit Forget. Invalid/backward clocks block restoration without extending expiry. Restored credentials must pass all existing grant/privacy checks before document requests. Revoked/expired grants and identity/scope mismatches remove the saved credential. Offline/rate-limit failures preserve it, do not force browser login and do not trigger retry loops.

GitHub's current [refresh documentation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/refreshing-user-access-tokens) says device-flow user tokens can refresh without client_secret. Access tokens expire after eight hours; refresh tokens after six months. Refresh rotates both tokens. The replacement pair is atomically saved and read back before follow-up validation requests, so a later offline failure does not unnecessarily lose it. A crash or lost HTTP response after GitHub rotates but before the new pair can be persisted can still require reauthorization; this cannot be made transactional across device and GitHub. Revocation, expiry after prolonged inactivity, Forget, corrupted storage or a failed credential write can also require sign-in again.

## Verification and owner check

Desktop: 19/19 suites, 14,755 assertions. New coverage models fresh VM restoration, automatic refresh without secret/device-code request, rotation persistence, offline retry without loops, revoked/expired grants, account mismatch, clock errors, storage write/removal failures, malformed/oversized/retargeted records, fresh code on second app instance, code retained across pause and explicit Remember/Cancel consent with portrait/landscape/tall fonts. Existing local save/recovery and editor regressions pass.

Native Studio: synthetic app_id inkwrite.sessionfixture, Pro touch and Classic button navigation reach the Remember consent screen; Classic OK activates default Cancel. Reported fault null and Problems diagnostics empty; screenshots retained. No real user credential was read or written during verification. Native refresh/real repeated sign-in are not asserted by these layout checks. Physical-device automatic refresh and reentry acceptance remain NOT TESTED. On device: enable Remember, connect once, exit/reopen and enter sync; expect Connected without a browser code. Repeat after eight hours to exercise refresh. Forget, then Connect twice in separate runs; each manual sign-in must show its own fresh code. A system dialog covering the app should not erase an unexpired code. Report visible status text if any step fails; never send a token.
