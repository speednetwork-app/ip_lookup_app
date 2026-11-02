#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
swiftc "$PROJECT_ROOT/ios/PacketTunnel/TunnelConfiguration.swift" \
  "$PROJECT_ROOT/test/native_vpn_configuration.swift" -o "$WORK_DIR/check-native"
"$WORK_DIR/check-native" > "$WORK_DIR/fixtures.json"
git clone --filter=blob:none https://github.com/XTLS/libXray.git "$WORK_DIR/libXray"
git -C "$WORK_DIR/libXray" checkout --detach 756ef80f41903eaf7bbeeb38a0a1f802ec204464
bash "$PROJECT_ROOT/tool/prepare_vpn_core.sh" "$WORK_DIR/libXray"
cd "$WORK_DIR/libXray"
go test ./pikahy2 -count=1 -timeout=90s
go run "$PROJECT_ROOT/tool/check_vpn_core.go" < "$WORK_DIR/fixtures.json"
