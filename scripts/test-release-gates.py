#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('qa', ROOT / 'scripts/validate-release-qa.py')
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)

class ReleaseGateTests(unittest.TestCase):
    def report(self):
        return ('Reviewer: Synthetic Tester\nDate: 2026-01-01\nVersion: 0.1.0\nBuild: 1\n' +
                '\n'.join('PASS ' + k + ': Synthetic validator evidence; not an actual release signoff.' for k in qa.REQUIRED))
    def test_template_rejected(self):
        self.assertTrue(qa.validate((ROOT / 'release/QA_TEMPLATE.md').read_text()))
    def test_complete_fields(self):
        self.assertEqual(qa.validate(self.report()), [])
    def test_every_signoff_required(self):
        for key in qa.REQUIRED:
            with self.subTest(key=key):
                self.assertIn(key, qa.validate(self.report().replace('PASS ' + key + ':', 'TODO ' + key + ':')))
    def test_empty_metadata_rejected(self):
        self.assertIn('Reviewer', qa.validate(self.report().replace('Reviewer: Synthetic Tester', 'Reviewer: ')))
    def test_missing_identity_blocks_before_build(self):
        env = os.environ.copy()
        env.pop('SIGNING_IDENTITY', None)
        result = subprocess.run(['bash', 'scripts/public-release.sh', '--check'], cwd=ROOT, env=env,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Release blocked', result.stderr)
        self.assertNotIn('Building', result.stdout)
    def test_unknown_mode_rejected(self):
        result = subprocess.run(['bash', 'scripts/public-release.sh', '--publish'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Use --check', result.stderr)

if __name__ == '__main__':
    unittest.main()
