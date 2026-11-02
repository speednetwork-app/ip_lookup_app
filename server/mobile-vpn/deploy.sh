#!/usr/bin/env bash
set -euo pipefail
# Run only after reviewing the staged controller diff and passing CI.
STAGING=/tmp/pikayun-mobile-hy2-20261102
APP=/www/wwwroot/xflash_app
CONTROLLER="$APP/app/Http/Controllers/V1/User/MobileVpnConfigController.php"
SERVICE="$APP/app/Services/MobileHysteriaConfig.php"
PHP=/www/server/php/82/bin/php
EXPECTED_SHA=9c8faf5e646ecb22f78a80cba22ceb6e682ddcd4380edafbd9d8ba991849b7b6
printf '%s  %s\n' "$EXPECTED_SHA" "$CONTROLLER" | sha256sum -c -
test ! -e "$SERVICE"
test -s "$APP/storage/app/mobile-hy2-cert-pins.json"
"$PHP" -l "$STAGING/MobileVpnConfigController.php"
"$PHP" -l "$STAGING/MobileHysteriaConfig.php"
"$PHP" "$STAGING/config_test.php"
install -d -m 0700 /root/pikayun-backups
BACKUP="/root/pikayun-backups/mobile-hy2-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 0700 "$BACKUP"
cp -p "$CONTROLLER" "$BACKUP/MobileVpnConfigController.php"
sha256sum "$BACKUP/MobileVpnConfigController.php"
# Install the new helper first; only then expose the HY2 controller branch.
install -m 0644 -o www -g www "$STAGING/MobileHysteriaConfig.php" "$SERVICE.new-hy2"
mv "$SERVICE.new-hy2" "$SERVICE"
install -m 0644 -o www -g www "$STAGING/MobileVpnConfigController.php" "$CONTROLLER.new-hy2"
mv "$CONTROLLER.new-hy2" "$CONTROLLER"
"$PHP" -l "$CONTROLLER"
printf 'Backend deployed. Rollback controller backup: %s\n' "$BACKUP/MobileVpnConfigController.php"
