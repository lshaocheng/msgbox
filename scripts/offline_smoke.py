#!/usr/bin/env python3
"""Additional per-process network denial; no persistent system policy changes."""
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent.parent
app = root / 'build-release/Build/Products/Release/Msgbox.app/Contents/MacOS/Msgbox'
assert app.is_file()
with (root / 'logs/offline-app.log').open('w') as output:
    process = subprocess.Popen(['/usr/bin/sandbox-exec', '-p', '(version 1)(allow default)(deny network*)', str(app)], stdout=output, stderr=output)
    try:
        time.sleep(20)
        assert process.poll() is None, f'Network-denied launch failed: {process.returncode}'
        print('PASS: Release app remained alive for 20 seconds with all direct network operations denied by a temporary process sandbox.')
        print('Scope: startup/idle only; no UI interaction; sandbox-exec is a deprecated development diagnostic, not a shipped dependency.')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
