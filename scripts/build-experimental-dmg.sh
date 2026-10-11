#!/bin/bash
# Local experimental packaging only. Does not create a GitHub release or bypass Gatekeeper.
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/dist/Preview Rebuilt.app"
[[ -d "$app" ]] || { printf 'Build the app first: bash scripts/verify.sh\n' >&2; exit 1; }
codesign --verify --strict "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[[ "$(lipo -archs "$app/Contents/MacOS/PreviewRebuilt")" == arm64 ]] || {
    printf 'This experimental package supports arm64 only.\n' >&2; exit 1;
}
output="$PWD/dist/Preview-Rebuilt-$version-experimental-arm64.dmg"
[[ ! -e "$output" ]] || { printf 'DMG already exists; inspect it before replacing.\n' >&2; exit 1; }
staging="$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Preview Rebuilt.app"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/LICENSE.txt"
cp PRIVACY.md RELEASE_NOTES.md "$staging/"
printf '%s\n' \
    'Preview Rebuilt — EXPERIMENTAL ARM64 BUILD' \
    '' \
    'Independent open-source project; not affiliated with Apple.' \
    'Ad-hoc signed, NOT notarized. macOS Gatekeeper may refuse to open it.' \
    'Do not disable Gatekeeper or remove quarantine to bypass a failed security assessment.' \
    'If blocked, build from reviewed source instead: https://github.com/0xRokib/preview-rebuilt' \
    '' \
    'Apple Silicon only. macOS 13 minimum is declared but not verified on every supported OS.' \
    'Drag Preview Rebuilt.app to Applications. Original documents are not automatically saved.' \
    'Experimental: no autosave, full Preview parity, verified redaction, sandbox or production certification.' \
    'Back up documents. App-managed edits stay in memory until exported and can be lost in a crash.' \
    > "$staging/READ-ME-FIRST.txt"
hdiutil create -volname 'Preview Rebuilt Experimental' -srcfolder "$staging" -format UDZO "$output"
hdiutil verify "$output"
(cd dist && shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256")
printf '\nExperimental DMG: %s\n' "$output"
