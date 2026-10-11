#!/usr/bin/env python3
"""Fail closed on missing human release sign-offs. This cannot verify their truth."""
import re
import sys
from pathlib import Path

REQUIRED = (
    "dialogs", "permissions-and-forms", "large-corrupt-files", "keyboard-voiceover",
    "appearance-and-layout", "sharing-lifecycle", "macos-support", "legal-and-support",
)

def validate(text):
    missing = []
    for key in REQUIRED:
        match = re.search(rf"^PASS {re.escape(key)}: (.+)$", text, re.MULTILINE)
        if not match or len(match.group(1).strip()) < 20 or "TODO" in match.group(1).upper():
            missing.append(key)
    for key in ("Reviewer", "Date", "Version", "Build"):
        if not re.search(rf"^{key}: [^\s\n][^\n]*$", text, re.MULTILINE):
            missing.append(key)
    return missing

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: validate-release-qa.py QA_REPORT.md")
    missing = validate(Path(sys.argv[1]).read_text())
    if missing:
        sys.exit("Release blocked: missing QA evidence: " + ", ".join(missing))
    print("PASS: required human QA evidence fields present (not independently verified).")
