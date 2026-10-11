#!/bin/bash
# Public artifact preparation. Notarization is an explicit, separate action; never publishes.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { printf 'Release blocked: %s\n' "$1" >&2; exit 1; }
mode="${1:---check}"
case "$mode" in --check|--prepare|--notarize) ;; *) fail 'Use --check, --prepare, or --notarize.' ;; esac

[[ "${SIGNING_IDENTITY:-}" == "Developer ID Application: "* ]] || fail 'Set SIGNING_IDENTITY to a local Developer ID Application identity.'
[[ "${BUNDLE_IDENTIFIER:-}" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*){2,}$ ]] || fail 'Set a product-owned reverse-DNS BUNDLE_IDENTIFIER.'
[[ "$BUNDLE_IDENTIFIER" != local.* && "$BUNDLE_IDENTIFIER" != com.example.* ]] || fail 'Placeholder bundle identifiers cannot be released.'
[[ "${RELEASE_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Set RELEASE_VERSION (major.minor.patch).'
[[ "${RELEASE_BUILD:-}" =~ ^[1-9][0-9]*$ ]] || fail 'Set a positive RELEASE_BUILD.'
[[ "${SUPPORT_URL:-}" == https://* && "$SUPPORT_URL" != *example.com* ]] || fail 'Set a real HTTPS SUPPORT_URL.'
[[ -f "${RELEASE_LICENSE_FILE:-}" && -s "$RELEASE_LICENSE_FILE" ]] || fail 'Supply your approved RELEASE_LICENSE_FILE; no license is chosen automatically.'
[[ -f "${RELEASE_ICON_FILE:-}" && "$RELEASE_ICON_FILE" == *.icns && -s "$RELEASE_ICON_FILE" ]] || fail 'Supply a product-owned RELEASE_ICON_FILE (.icns).'
[[ -f "${QA_REPORT:-}" && -s "$QA_REPORT" ]] || fail 'Supply a completed QA_REPORT using release/QA_TEMPLATE.md.'
python3 scripts/validate-release-qa.py "$QA_REPORT"
python3 - "$QA_REPORT" "$RELEASE_VERSION" "$RELEASE_BUILD" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
for key, expected in [('Version', sys.argv[2]), ('Build', sys.argv[3])]:
    match = re.search(rf'^{key}: (.+)$', text, re.MULTILINE)
    if not match or match.group(1).strip() != expected:
        sys.exit(f'Release blocked: QA {key} does not match candidate.')
PY
[[ "${SANDBOX_POLICY:-}" == reviewed-unsandboxed ]] || fail 'Set SANDBOX_POLICY=reviewed-unsandboxed only after reviewing the current non-sandboxed design.'
[[ "${NOTARY_PROFILE:-}" != '' ]] || fail 'Set NOTARY_PROFILE to a local notarytool Keychain profile name (not a password).'
for tool in notarytool stapler; do xcrun --find "$tool" >/dev/null || fail "Missing $tool."; done
# Do not print identities or Keychain contents. Only test that the requested valid identity exists.
security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null || fail 'Requested valid code-signing identity is not available in the local Keychain.'
printf 'PASS: release prerequisites. This does not establish QA truth or notarization acceptance.\n'
[[ "$mode" != --check ]] || exit 0

# Run all automated gates against the exact configured build. Does not submit anything remotely.
export SIGNING_IDENTITY BUNDLE_IDENTIFIER RELEASE_VERSION RELEASE_BUILD
export RELEASE_ICON_FILE RELEASE_LICENSE_FILE SUPPORT_URL
bash scripts/verify.sh
app="$PWD/dist/Preview Rebuilt.app"
metadata="$(codesign -dv --verbose=4 "$app" 2>&1)"
[[ "$metadata" == *'Authority=Developer ID Application:'* && "$metadata" == *'runtime'* && "$metadata" == *'Timestamp='* ]] || fail 'Bundle must have Developer ID, hardened runtime, and secure timestamp.'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "$BUNDLE_IDENTIFIER" ]] || fail 'Bundle identifier mismatch.'
# Keep local output clearly distinct from accepted public artifacts.
output="$PWD/dist/release-$RELEASE_VERSION-$RELEASE_BUILD"
[[ ! -e "$output" ]] || fail 'Release output already exists; use a new build number or inspect it manually.'
mkdir -m 700 "$output"
cp "$QA_REPORT" "$output/QA_REPORT.md"
cp "$RELEASE_LICENSE_FILE" "$output/LICENSE.txt"
cp PRIVACY.md "$output/PRIVACY.md"
cp RELEASE_NOTES.md "$output/RELEASE_NOTES.md"
archive="$output/Preview-Rebuilt-$RELEASE_VERSION-arm64-NOT-NOTARIZED.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
if [[ "$mode" == --prepare ]]; then
    shasum -a 256 "$archive" > "$output/SHA256SUMS.txt"
    printf 'Prepared local signed archive: %s\nNOT FOR DISTRIBUTION: notarization is still required.\n' "$archive"
    exit 0
fi
# Explicit --notarize sends the application to Apple's notarization service, not to the public.
xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$output/notarization.json"
python3 - "$output/notarization.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
if result.get('status') != 'Accepted':
    sys.exit('Release blocked: Apple did not accept notarization. Inspect local notarization.json.')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --strict "$app"
spctl --assess --type execute "$app"
public_archive="$output/Preview-Rebuilt-$RELEASE_VERSION-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$public_archive"
shasum -a 256 "$public_archive" > "$output/SHA256SUMS.txt"
printf 'Notarized local candidate: %s\nTest this exact archive on a clean Mac before publishing. No public upload performed.\n' "$public_archive"
