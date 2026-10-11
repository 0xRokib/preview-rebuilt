# Public release workflow

These tools prepare local candidates; they never publish to a website, store or repository. Running `--notarize` explicitly submits the application to Apple. Do not run it until you authorize that submission and complete release QA.

## Required owner decisions

1. Choose a product-owned reverse-DNS identifier and original `.icns` icon.
2. Supply an approved license file and a live HTTPS support URL. This repository deliberately does not choose ownership or licensing for you.
3. Complete `QA_TEMPLATE.md` against the candidate; use real evidence, not generated sign-offs. Set its Version/Build to match the intended artifact.
4. Review the non-sandboxed design or implement and test App Sandbox separately. `reviewed-unsandboxed` records a decision; it does not add protection.
5. Configure a Developer ID Application identity and a notarytool Keychain profile locally. Never paste passwords, private keys or Apple tokens into chat or environment variables.

Set these non-secret values in your local shell:

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Organization (TEAMID)"
export BUNDLE_IDENTIFIER="com.yourorganization.previewrebuilt"
export RELEASE_VERSION="0.1.0"
export RELEASE_BUILD="1"
export SUPPORT_URL="https://yourorganization.tld/support"
export RELEASE_LICENSE_FILE="/absolute/path/to/approved-license.txt"
export RELEASE_ICON_FILE="/absolute/path/to/owned-icon.icns"
export QA_REPORT="/absolute/path/to/completed-qa.md"
export SANDBOX_POLICY="reviewed-unsandboxed"
export NOTARY_PROFILE="your-local-keychain-profile-name"
bash scripts/public-release.sh --check
bash scripts/public-release.sh --prepare
# Explicitly submits the bundle to Apple; never publishes publicly:
# Use a fresh build number/output directory after preparing an earlier candidate.
bash scripts/public-release.sh --notarize
```

`--check` fails before building when prerequisites are absent. `--prepare` signs/tests and emits an explicitly NOT-NOTARIZED local ZIP. `--notarize` signs/tests, submits, requires Accepted status, staples, verifies Gatekeeper and emits an arm64 ZIP plus SHA-256 checksum. Existing release output directories are never overwritten. Re-run QA for the exact version/build; checks verify fields, not their truth. Always test the final archive on a clean Mac before publishing.

Local default builds remain ad-hoc signed and unsuitable for public distribution. Signing/notarization paths cannot be verified without your identity and profile. Notarization is malware screening, not proof of functional correctness, privacy or full Preview parity.
