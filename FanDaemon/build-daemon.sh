#!/bin/sh
#
# Compila el daemon privilegiado de FanCTL y lo coloca dentro del bundle de la
# app en las rutas que espera SMAppService:
#   - Contents/Helpers/FanDaemon            (binario)
#   - Contents/Library/LaunchDaemons/com.jg.FanCTL.daemon.plist
#
# El daemon se firma ad-hoc; cuando el bundle se firma con el certificado de
# desarrollo, esa firma anidada queda sellada como código anidado.
set -e

HELPERS_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/../Helpers"
LAUNCHD_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/../Library/LaunchDaemons"
DAEMON_BIN="$HELPERS_DIR/FanDaemon"
DAEMON_SRC="$SRCROOT/FanDaemon"

mkdir -p "$HELPERS_DIR" "$LAUNCHD_DIR"
rm -f "$DAEMON_BIN"

swiftc -O \
    -module-name FanDaemon \
    -import-objc-header "$SRCROOT/FanCTL/sensors/FanCTL-Bridging-Header.h" \
    "$DAEMON_SRC/main.swift" \
    "$DAEMON_SRC/DaemonService.swift" \
    "$DAEMON_SRC/FanDaemonProtocol.swift" \
    "$DAEMON_SRC/DaemonSMCClient.swift" \
    -o "$DAEMON_BIN"

codesign --force --sign - "$DAEMON_BIN"

cat > "$LAUNCHD_DIR/com.jg.FanCTL.daemon.plist" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.jg.FanCTL.daemon</string>
	<key>BundleProgram</key>
	<string>Contents/Helpers/FanDaemon</string>
	<key>AssociatedBundleIdentifiers</key>
	<array>
		<string>com.jg.FanCTL</string>
	</array>
	<key>MachServices</key>
	<dict>
		<key>com.jg.FanCTL.daemon</key>
		<true/>
	</dict>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PLISTEOF

echo "FanCTL: daemon compilado en $DAEMON_BIN"
