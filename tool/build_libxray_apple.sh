#!/usr/bin/env bash
set -euo pipefail

LIBXRAY_REPOSITORY="https://github.com/XTLS/libXray.git"
LIBXRAY_COMMIT="756ef80f41903eaf7bbeeb38a0a1f802ec204464"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/ios/Frameworks"
OUTPUT_FRAMEWORK="$OUTPUT_DIR/LibXray.xcframework"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

git clone --filter=blob:none "$LIBXRAY_REPOSITORY" "$WORK_DIR/libXray"
git -C "$WORK_DIR/libXray" checkout --detach "$LIBXRAY_COMMIT"
test "$(git -C "$WORK_DIR/libXray" rev-parse HEAD)" = "$LIBXRAY_COMMIT"

python3 "$WORK_DIR/libXray/build/main.py" apple go
test -f "$WORK_DIR/libXray/LibXray.xcframework/Info.plist"

mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_FRAMEWORK"
cp -R "$WORK_DIR/libXray/LibXray.xcframework" "$OUTPUT_FRAMEWORK"
echo "Built LibXray.xcframework from $LIBXRAY_COMMIT"
