# HY2 support (2026-11-02)

The mobile config endpoint keeps schema version 1 and its existing country,
account, plan, quota, node-authorization, availability and no-store checks.
Only the Hysteria 2 branch is new. VLESS's response and native outbound are unchanged.

- `MobileHysteriaConfig.php` maps the existing ServerService password, TLS,
  Salamander, bandwidth and optional port range to a typed response.
- Parented nodes use the existing **active** `v2rayn-hy2-forward.json` mapping,
  matching node ID, code, host, port and parent. Missing/stale mappings fail closed;
  they never silently bypass the configured relay. A forwarded port does not hop.
- `MobileVpnConfigController.php` is the audited server controller plus this branch.
- `config_test.php` uses isolated fixtures, no database or network.
- `deploy.sh` verifies the original controller hash, lints and tests staged files,
  backs up the controller under `/root/pikayun-backups`, then atomically installs
  the helper and controller. No database schema, node, firewall, proxy server,
  subscription or billing settings are changed. A changed controller aborts deployment.
- To roll back, restore the controller from the printed backup path. The unused
  helper can stay in place; restoring the controller disables the new API branch.

Read-only verification found 39 accessible HY2 nodes, all matched existing relay
entries. Their current server settings all explicitly allow insecure TLS, which
the pinned Xray version has **removed**. The compatibility trial keeps Xray's TLS
verification intact and uses the official Hysteria client only for these nodes.
The API requires the explicit `hy2-insecure-v1` client capability. The app also
requires per-connection risk consent before starting an unverified connection.
Cancelling preserves the previous tunnel. This mode encrypts traffic but does
not authenticate the server and is vulnerable to active interception.

For self-signed certificates, place operator-verified leaf certificate SHA-256
fingerprints in the private server file `storage/app/mobile-hy2-cert-pins.json`:

```json
{"7":{"host":"node.example.com","port":443,"server_name":"tls.example.com","sha256":"<64 hex digits of the verified leaf certificate>"}}
```

Do not copy this fixture to production. Fingerprints must come from an authenticated
management source, not an unauthenticated first-use network probe. Each entry must
match the node's original endpoint and SNI. The API returns verification enabled
with an exact certificate pin. Without a valid pin, insecure nodes require the
explicit compatibility capability; older clients still fail closed.
No certificate private key is needed or sent to the app. Other clients' settings
are unchanged. Missing TLS flags always default to normal certificate verification.

A strict, unauthenticated QUIC TLS probe on 2026-11-02 did not verify any of the
39 relay entries. Several returned a certificate without subjectAltName; others
timed out. A timeout is not evidence of an invalid certificate. No account login,
HY2 proxy stream, unauthenticated certificate pin acceptance, or production write
was performed. The backend controller checksum remained
`9c8faf5e646ecb22f78a80cba22ceb6e682ddcd4380edafbd9d8ba991849b7b6`.

Client changes preserve HY2 selection on refresh, validate config node ID/protocol,
send the real app version, and disconnect/reconnect when selecting a different
line during an active VPN session. Fetch/validation failure preserves the previous
tunnel. Busy operations reject duplicate taps. Connection status still comes from iOS.

The compatibility bridge uses official Hysteria sources pinned to
`ca8fbd874fd6ca82413948de6dc5924405e103e1` and shares LibXray's single Go runtime.
It binds authenticated SOCKS5 only on loopback, forwards TCP and UDP, and closes
active associations on disconnect. It does not weaken VLESS or strict/pinned HY2.
The app displays the unverified-certificate warning using the native VPN config.

Validation plan: Flutter tests; standalone PHP tests; Foundation-only Swift configuration
tests; pinned Xray loopback HY2 HTTP transfers (plain, Salamander, hopping/bandwidth)
and VLESS config startup via `tool/check_vpn_core.sh`; cloud iOS signed build.
The same script tests the official compatibility client against an isolated,
self-signed loopback server, including TCP, UDP, wrong credentials, consent,
strict certificate rejection, pin mismatch and connection cleanup.
Real iPhone/iPad switching, public IP and background-network validation remain
device acceptance steps. No new TestFlight upload or App Store submission is
performed by the verification run (`upload_to_app_store=false`).

Verification run (source commit `bb97779`):
https://github.com/speednetwork-app/ip_lookup_app/actions/runs/41407674957
Flutter static analysis and all 57 tests passed locally; staged PHP lint/config
tests passed on PHP 8.2. Native Swift checks and all pinned-core loopback cases
passed in this run. Check the run's final result separately for iOS signing/build.

Pinned upstream implementation:
https://github.com/XTLS/Xray-core/tree/1b1647cd9ddf/proxy/hysteria
https://github.com/XTLS/Xray-core/blob/1b1647cd9ddf/infra/conf/transport_method.go
https://github.com/XTLS/Xray-core/blob/1b1647cd9ddf/infra/conf/transport_finalmask.go

## Compatibility trial verification and deployment

- Source `c28170f`: iOS signed **1.6.3 (18)** build passed:
  https://github.com/speednetwork-app/ip_lookup_app/actions/runs/41416859005
- Local Flutter analysis is clean and all **61 tests** pass. Cloud native Swift,
  official-client TCP/UDP/certificate-policy/lifecycle tests and the existing
  pinned-Xray HY2/VLESS regression checks passed. The signed IPA was generated;
  App Store Connect upload was explicitly disabled.
- On 2026-11-02 at 09:10:37 UTC, the two API files were deployed after lint,
  fixture tests and a verified backup of the original controller:
  `/root/pikayun-backups/mobile-hy2-20261102T091037Z/MobileVpnConfigController.php`.
  Its SHA-256 equals the original checksum recorded above. No database, node,
  relay manifest, firewall, billing or third-party client settings were changed.
- Post-deployment, the real Laravel autoloader and existing ServerService records
  passed a read-only contract check: 39 HY2 configs, 39 matching relay mappings,
  39 explicit unverified compatibility modes, zero mapping/config failures.
  All 39 reject clients lacking the compatibility capability. No user credentials
  were printed and no real-node proxy traffic was generated by this check.
- A physical iPhone/iPad test against real nodes is still required. Passing
  loopback tests is not proof that all 39 remote nodes are reachable or usable.

Official compatibility client source (MIT):
https://github.com/apernet/hysteria/tree/ca8fbd874fd6ca82413948de6dc5924405e103e1

## TestFlight upload

At the user's request, source `6fb38c3` was rebuilt and **1.6.3 (18)** uploaded
to App Store Connect on 2026-11-02 at 17:40 (Asia/Shanghai).
https://github.com/speednetwork-app/ip_lookup_app/actions/runs/41421988568

The workflow completed successfully, including native regression checks, static
analysis, signing, export and upload. Apple's uploader returned
`UPLOAD SUCCEEDED with no errors` (delivery UUID
`1d784dcd-b0f4-4398-9d72-9cfa8300eb19`). App Store Connect processing and TestFlight
availability have not been independently confirmed. No App Review submission or
App Store release was performed. Real-node device acceptance remains outstanding.
