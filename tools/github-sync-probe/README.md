# Isolated phase 0 HTTPS probe

This is a separate diagnostic app (`inkwrite.phase0.probe`), not inkWrite's sync
engine. It never reads or writes app files/state, accepts no token, and sends
only fixed dummy data. No network request runs until OK or a tap. A second input
while busy does not start another request. Back cancels/exits; pause cancels;
reopen to repeat the sequence. Results are seven bounded in-memory summaries.

1. Run `npm install --ignore-scripts` in the repository, then
   `npm run test:probe`. `npm test` also runs all unchanged editor regressions;
   the loaded cloud baseline has known failures documented in the audit.
2. Set `origin` in `config.lua` to a disposable **HTTPS origin** implementing
   httpbin's `/anything`, `/bytes/49152`, `/bytes/131073`, `/status/401` routes.
   `https://httpbin.org` is an example; no real request to it was made in this
   task. Public echo services can change/rate-limit/strip headers; do not infer a
   device API failure from an unverified endpoint. Never enter a real secret.
3. Preview/install this folder as a separate app using compatible API 2.18
   Gancao firmware. Do not overwrite the original inkWrite Studio project.
   Native preview source upload requires the pending owner approval.
4. Run each case with OK or tap, on Classic and Pro separately. Record host/
   firmware/API, status, byte count, pass/echo flags and whether it was preview
   or physical hardware. A PASS against mocks certifies only adapter logic.
5. Reopen/repeat under offline, invalid device clock, TLS failure and interrupted
   Wi-Fi conditions. Do not bypass certificate validation. The overflow sample
   can allocate up to 128 KiB in the host: run only in this diagnostic, with no
   writing session open. Measure heap before/after on real firmware separately.

`/anything` must echo JSON `{method, headers, data}` with the exact fixed request
body and the dummy Authorization and content-type headers. Case-insensitive
header names are accepted. Echo JSON must be ≤4096 B. Byte routes must return
exactly the named count; overflow must report `err=limit_exceeded`, total bytes
greater than 131072 and retained body no larger than 131072. HTTP 401 must be
received as an HTTP response, not confused with a network failure. No redirects
are followed or retried.

Current evidence: 93 mock assertions pass; native preview and both physical
variants **NOT TESTED**. The preview upload was rejected by automatic approval
review; no source was uploaded through another route. No installer is claimed.
