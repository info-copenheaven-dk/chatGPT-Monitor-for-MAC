#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
./scripts/build-app.sh release
archive="dist/ChatGPT-Monitor-0.2.0-arm64.zip"
codesign --verify --deep --strict 'dist/release/ChatGPT Monitor.app'
ditto -c -k --sequesterRsrc --keepParent 'dist/release/ChatGPT Monitor.app' "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
print "Klar: $archive"
