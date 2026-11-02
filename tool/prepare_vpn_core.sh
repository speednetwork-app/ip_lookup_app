#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBXRAY_DIR="$1"
HYSTERIA_DIR="$(dirname "$LIBXRAY_DIR")/hysteria"
git clone --filter=blob:none https://github.com/apernet/hysteria.git "$HYSTERIA_DIR"
git -C "$HYSTERIA_DIR" checkout --detach ca8fbd874fd6ca82413948de6dc5924405e103e1
test "$(git -C "$HYSTERIA_DIR" rev-parse HEAD)" = ca8fbd874fd6ca82413948de6dc5924405e103e1
mkdir -p "$LIBXRAY_DIR/pikahy2/socks5"
cp "$PROJECT_ROOT/tool/hy2bridge/bridge.go" "$LIBXRAY_DIR/pikahy2/bridge.go"
cp "$PROJECT_ROOT/tool/hy2bridge/socks5/server.go" "$LIBXRAY_DIR/pikahy2/socks5/server.go"
cp "$PROJECT_ROOT/tool/hy2bridge/cgo_hy2.go" "$LIBXRAY_DIR/cgo_bridge/hy2.go"
if [ -f "$PROJECT_ROOT/tool/hy2bridge/bridge_test.go" ]; then
  cp "$PROJECT_ROOT/tool/hy2bridge/bridge_test.go" "$LIBXRAY_DIR/pikahy2/bridge_test.go"
fi
cd "$LIBXRAY_DIR"
go mod edit -require=github.com/apernet/hysteria/core/v2@v2.0.0 -replace=github.com/apernet/hysteria/core/v2=../hysteria/core
go mod edit -require=github.com/apernet/hysteria/extras/v2@v2.0.0 -replace=github.com/apernet/hysteria/extras/v2=../hysteria/extras
go mod tidy
