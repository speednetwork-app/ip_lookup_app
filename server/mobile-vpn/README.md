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
the pinned Xray version has **removed**. Do not work around this by disabling core
verification. Deployment is blocked until authoritative public certificates or
CA-valid node settings are available. No production change has been made.

For self-signed certificates, place operator-verified leaf certificate SHA-256
fingerprints in the private server file `storage/app/mobile-hy2-cert-pins.json`:

```json
{"7":{"host":"node.example.com","port":443,"server_name":"tls.example.com","sha256":"<64 hex digits of the verified leaf certificate>"}}
```

Do not copy this fixture to production. Fingerprints must come from an authenticated
management source, not an unauthenticated first-use network probe. Each entry must
match the node's original endpoint and SNI. The API returns verification enabled
with an exact certificate pin; absent/stale pins fail closed for insecure nodes.
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

Validation plan: Flutter tests; standalone PHP tests; Foundation-only Swift configuration
tests; pinned Xray loopback HY2 HTTP transfers (plain, Salamander, hopping/bandwidth)
and VLESS config startup via `tool/check_vpn_core.sh`; cloud iOS signed build.
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
