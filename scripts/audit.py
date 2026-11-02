#!/usr/bin/env python3
"""Offline/privacy source policy check; intentionally fails on scope expansion."""
from pathlib import Path
import plistlib
import re
import subprocess

root = Path(__file__).resolve().parent.parent
sources = list((root / 'Msgbox').glob('*.swift'))
assert sources
text = '\n'.join(p.read_text() for p in sources)
for pattern in [r'\b(URLSession|URLRequest|NWConnection|NWListener|WebSocket|WKWebView|Network|Darwin\.socket)\b',
                r'https?://', r'AXUIElementSetAttributeValue|AXUIElementPerformAction|CGEventPost',
                r'kAXWindowsAttribute|kAXValueAttribute|kAXDescriptionAttribute|kAXTitleAttribute',
                r'AXUIElementCreateSystemWide|AXUIElementCopyElementAtPosition']:
    assert not re.search(pattern, text), f'Unexpected API/content: {pattern}'
imports = set(re.findall(r'^import (\w+)', text, flags=re.M))
assert imports <= {'AppKit', 'SwiftUI', 'Combine', 'Foundation', 'ApplicationServices', 'ServiceManagement'}, imports
plist = plistlib.loads((root / 'Msgbox/Info.plist').read_bytes())
assert plist['LSUIElement'] is True
assert not any('UsageDescription' in key for key in plist)
assert not list((root / 'Msgbox').glob('*.entitlements'))
assert not list(root.glob('**/Package.resolved'))
reader = (root / 'Msgbox/DockReader.swift').read_text()
assert 'AXUIElementCreateApplication(dockPID)' in reader
assert reader.count('AXUIElementCopyAttributeValue(') == 1
monitor = (root / 'Msgbox/Monitor.swift').read_text()
permission_action = monitor.split('func openAccessibilitySettings() {', 1)[1].split('\n    func ', 1)[0]
assert text.count('AXIsProcessTrustedWithOptions(') == permission_action.count('AXIsProcessTrustedWithOptions(') == 1
assert text.count('kAXTrustedCheckOptionPrompt') == permission_action.count('kAXTrustedCheckOptionPrompt') == 1
print(f'PASS: {len(sources)} Swift sources, native imports only; no network APIs/URLs, message/window attributes, AX writes, extra usage descriptions or entitlements. Permission prompt is confined to the user action.')
print('Limit: source policy checks are not a firewall or proof of absence of all possible traffic; runtime sampling is separate.')

app = root / 'build-release/Build/Products/Release/Msgbox.app'
if app.exists():
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    signed = subprocess.run(['codesign', '-d', '--entitlements', '-', str(app)], capture_output=True, check=True)
    entitlements = plistlib.loads(signed.stdout) if signed.stdout.strip() else {}
    assert not entitlements, entitlements
    details = subprocess.run(['codesign', '-dvv', str(app)], capture_output=True, text=True, check=True).stderr
    assert 'runtime)' in details, details
    assert 'Authority=Apple Development:' in details and 'Signature=adhoc' not in details, 'Release must have a stable local signing identity'
    requirement = subprocess.run(['codesign', '-d', '-r-', str(app)], capture_output=True, text=True, check=True).stdout
    assert 'anchor apple' in requirement and 'cdhash' not in requirement, requirement
    binary = app / 'Contents/MacOS/Msgbox'
    symbols = subprocess.run(['nm', '-u', str(binary)], capture_output=True, text=True, check=True).stdout
    assert not re.search(r'_NSURLSession|_socket$|_connect$|_getaddrinfo$|nw_connection', symbols, re.M)
    dependencies = subprocess.run(['otool', '-L', str(binary)], capture_output=True, text=True, check=True).stdout
    assert all(line.lstrip().startswith(('/System/Library/', '/usr/lib/')) for line in dependencies.splitlines() if line.startswith('\t'))
    print('PASS: Release has a stable Apple Development signature; hardened runtime; no entitlements; native system dependencies only; no direct network symbols found.')
    (root / 'logs/binary-audit.txt').write_text(details + '\nEntitlements: ' + repr(entitlements) + '\n' + dependencies)
