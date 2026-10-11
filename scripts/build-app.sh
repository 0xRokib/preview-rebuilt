#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product PreviewRebuilt
bin_dir="$(swift build -c release --show-bin-path)"
app="$PWD/dist/Preview Rebuilt.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/PreviewRebuilt" "$app/Contents/MacOS/PreviewRebuilt"
cp Resources/Info.plist "$app/Contents/Info.plist"
python3 - "$app/Contents/Info.plist" <<'PY'
import os, plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    info = plistlib.load(f)
for env, key in [('BUNDLE_IDENTIFIER', 'CFBundleIdentifier'), ('RELEASE_VERSION', 'CFBundleShortVersionString'), ('RELEASE_BUILD', 'CFBundleVersion'), ('SUPPORT_URL', 'PreviewRebuiltSupportURL')]:
    if os.environ.get(env):
        info[key] = os.environ[env]
if os.environ.get('RELEASE_ICON_FILE'):
    info['CFBundleIconFile'] = 'AppIcon'
with open(path, 'wb') as f:
    plistlib.dump(info, f)
PY
if [[ -n "${RELEASE_ICON_FILE:-}" ]]; then cp "$RELEASE_ICON_FILE" "$app/Contents/Resources/AppIcon.icns"; fi
if [[ -n "${RELEASE_LICENSE_FILE:-}" ]]; then cp "$RELEASE_LICENSE_FILE" "$app/Contents/Resources/LICENSE.txt"; fi
cp PRIVACY.md RELEASE_NOTES.md "$app/Contents/Resources/"
plutil -lint "$app/Contents/Info.plist"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
    printf 'Local development build only: ad-hoc signed, not notarized.\n'
fi
codesign --verify --strict "$app"
printf '\nBuilt: %s\n' "$app"
