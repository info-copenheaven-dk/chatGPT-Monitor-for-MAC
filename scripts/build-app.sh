#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
  print -u2 'Brug: scripts/build-app.sh [debug|release]'
  exit 1
fi
swift build -c "$configuration" --arch arm64
bin_path="$(swift build -c "$configuration" --arch arm64 --show-bin-path)"
app_path="dist/$configuration/ChatGPT Monitor.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_path/QuotaMonitor" "$app_path/Contents/MacOS/QuotaMonitor"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QuotaMonitor</string>
<key>CFBundleIdentifier</key><string>dk.local.chatgpt-monitor</string>
<key>CFBundleName</key><string>ChatGPT Monitor</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_path"
print "Bygget: $app_path"
