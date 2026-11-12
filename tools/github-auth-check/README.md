# inkWrite GitHub sign-in check

Separate diagnostic app: `inkwrite.githubauthcheck`, API 2.18, net permission.
It has no document upload/download control and never calls a document read/write
operation. It performs only device-flow authorization and account/App/repository/
branch metadata checks. Local document/recovery storage is untouched.

Build from repository root:

`python scripts/build_auth_check.py --stage <new-directory>`

The builder includes the explicit ten Lua dependencies and a separate manifest.
Do not import the whole editor/test/probe repository as this app. Public setup is
in `domain/sync_config.lua`; it contains no secret. No token/device-code persistence.

## Test on the device

1. Open **inkWrite GitHub sign-in check** in My cloud workspace and install it on
   a device running **Gancao firmware** (required for API 2.x). Use this diagnostic,
   not the normal inkWrite editor. Its App ID is separate.
2. Connect the device to Wi-Fi and make sure its time is valid for HTTPS.
3. Open it, then tap **Connect** (Pro) or press **OK** (Classic).
4. If a code appears, open `https://github.com/login/device` yourself in a browser,
   enter the displayed code, review the App/account and authorize it. Do not paste
   any code/token in chat. Leave the diagnostic open while authorizing.
5. Report **Connected: odklizec** / **Selected private repository verified**, or
   the displayed HTTP/reason text. No document upload is performed.

**Disconnect** clears memory and cancels pending work. Back/Exit also clears the
session and exits. Pause/lock discards the session; reconnect afterward. Closing
the app does not revoke its GitHub grant; revoke through GitHub settings if needed.

## Current evidence

Owner supplied public client/App IDs and docs repo/main. Connector confirmed
private `odklizec/inkwrite-docs`, ID 1455886532, and existing main branch. This is
connector access, not proof that the new App is installed correctly.

Pro native preview renders and handles touch without a runtime fault; Studio
Problems showed zero errors/warnings/notes. Its HTTPS device-code request
returned **502** twice (second attempt added a safe numeric status diagnostic).
A separate desktop HTTPS request to the same GitHub endpoint with the public
client ID returned **200 and a valid device-flow response**. Codes were neither
printed nor saved. No token exchange or authorization occurred.

Classic native restart and Back exit also pass with fault null. Desktop suite:
16/16 passing, 14,448 assertions; seven sync/safety suites 368. The separate cloud
project is 803d9404-1aa3-469a-8547-96e7425bf08d, saved as version 0.0.2 (Studio
advanced the manifest during cloud Save). Main writer stays at cloud 1.0.6.

This points to the Studio network path as a likely limitation, not an established
device limitation. Actual device authorization/scope/expiry/revocation/heap remains
NOT TESTED. Do not count desktop endpoint reachability as firmware auth acceptance.
