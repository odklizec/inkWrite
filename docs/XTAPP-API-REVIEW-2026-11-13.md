# XTApp API review — 13 November 2026

Requested official URL: https://xtapp-ai.xteink.cc/docs?doc=v2-spec-00 . Direct browser access redirected toward port 8000 and failed; the normal trailing-slash URL returned nginx 403. The web reader could not retrieve it either. Therefore this review cannot certify the latest website revision or claim that there are no newer additions.

The official XTApp connector returned authoritative public 2.x contract sections through 2.18. Queries for 2.19 network and 2.20 runtime returned no authoritative results. Keep manifest.api 2.18, the newest verified version. Sources: contract/v2/spec-en/00-总则.md line 58; 14-联网.md lines 1, 60 and 93; private storage 09. GitHub tree behavior was checked against https://docs.github.com/en/rest/git/trees .

Useful verified capabilities:

- HTTPS PUT, custom headers and 1–60 second request deadlines (2.18): already used by the bounded GitHub adapter. Only one outstanding host request; cancelled requests can keep the slot briefly. Fail visibly and let the user retry; never retry a write automatically.
- keep_wifi(ms) (2.4): adopted for a short 30-second grace during explicit manual operations; close/disconnect sets zero. This affects only Wi-Fi automatically enabled by the host, and does not turn it on by itself or turn off user-enabled Wi-Fi.
- File-backed network responses (2.18): reviewed, not needed for this 32 KiB MVP. GitHub Contents returns JSON/base64 requiring validation/decoding; writing that HTTP body directly over a document would be wrong. Keep bounded in-memory validation then import a fresh local copy.
- Storage writes are atomic, but there is no verified exclusive-create/CAS API. Downloads check absence immediately before writing and verify read-back. Simultaneous external writes in the remaining check/write window cannot be ruled out. Do not externally edit the SD folder while importing.

No unverified networking APIs or newer manifest requirement were introduced. Device HTTPS still depends on a valid clock and firmware certificates. WebSockets or larger streamed transfers would not improve manual GitHub Contents operations.
