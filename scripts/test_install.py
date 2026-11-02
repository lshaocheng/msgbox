"""Exercise installation checks against real signatures without installing anything."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from install import APP, signature, signing_identity, validate_update


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.copy = Path(self.temporary.name) / 'Msgbox.app'
        shutil.copytree(APP, self.copy)

    def test_signed_update_preserves_identity(self):
        validate_update(self.copy, APP)

    def test_adhoc_candidate_cannot_replace_installed_app(self):
        subprocess.run(['codesign', '--force', '--sign', '-', str(self.copy)], check=True, capture_output=True)
        with self.assertRaises(ValueError):
            validate_update(self.copy, APP, migrate=True)

    def test_adhoc_migration_requires_explicit_flag(self):
        subprocess.run(['codesign', '--force', '--sign', '-', str(self.copy)], check=True, capture_output=True)
        with self.assertRaises(ValueError):
            validate_update(APP, self.copy)
        validate_update(APP, self.copy, migrate=True)

    def test_tampered_app_is_rejected(self):
        info = self.copy / 'Contents/Info.plist'
        data = plistlib.loads(info.read_bytes())
        data['CFBundleVersion'] = 'tampered'
        info.write_bytes(plistlib.dumps(data))
        with self.assertRaises(subprocess.CalledProcessError):
            validate_update(self.copy, APP)

    def test_missing_install_is_allowed(self):
        validate_update(APP, Path(self.temporary.name) / 'not-installed.app')

    def test_different_certificate_requirement_is_rejected(self):
        details = signature(APP)
        other = 'designated => anchor apple generic and certificate leaf = H"' + '0' * 40 + '"'
        with patch('install.signature', side_effect=[details, other]):
            with self.assertRaises(subprocess.CalledProcessError):
                validate_update(APP, self.copy)

    def test_missing_signing_identity_stops_before_build(self):
        with patch('install.subprocess.run', return_value=subprocess.CompletedProcess([], 0, stdout='0 valid identities found')):
            with self.assertRaises(ValueError):
                signing_identity()

    def test_signing_team_comes_from_certificate_not_display_name(self):
        fingerprint = 'A' * 40
        outputs = [f'1) {fingerprint} "Apple Development: Test (PERSONID)"',
                   '-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----',
                   f'sha1 Fingerprint={":".join(["AA"] * 20)}\nsubject=\n    OU=ACTUALTEAM\n']
        with patch('install.os.environ', {}), patch('install.subprocess.run', side_effect=[
            subprocess.CompletedProcess([], 0, stdout=output) for output in outputs
        ]):
            self.assertEqual(signing_identity(), (fingerprint, 'ACTUALTEAM'))


if __name__ == '__main__':
    unittest.main()
