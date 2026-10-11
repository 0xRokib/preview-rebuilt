#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n scripts/build-app.sh scripts/public-release.sh scripts/verify.sh
python3 scripts/test-release-gates.py
swift build --product PreviewRebuilt
PREVIEW_FIXTURE_DIR="$PWD/.build/fixtures" swift run PreviewSmoke
bash scripts/build-app.sh
app="$PWD/dist/Preview Rebuilt.app"
plutil -lint "$app/Contents/Info.plist"
codesign --verify --strict "$app"
"$app/Contents/MacOS/PreviewRebuilt" --ui-smoke-test "$PWD/.build/fixtures/sample.pdf"
"$app/Contents/MacOS/PreviewRebuilt" --ui-smoke-test "$PWD/.build/fixtures/sample.tiff"
printf '\nPASS: automated release verification (manual release gates still required)\n'
