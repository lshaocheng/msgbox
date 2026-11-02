#!/usr/bin/env python3
"""Build and install the signed local app without silently changing its identity."""
import argparse
from datetime import datetime
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'build-release/Build/Products/Release/Msgbox.app'
INSTALLED = Path('/Applications/Msgbox.app')


def signature(app):
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '--all-architectures', str(app)], check=True)
    result = subprocess.run(['codesign', '-d', '-r-', '-vv', str(app)],
                            capture_output=True, text=True, check=True)
    return result.stdout + result.stderr


def signing_identity():
    result = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'],
                            capture_output=True, text=True, check=True)
    identities = re.findall(r'\b([0-9A-F]{40}) "Apple Development: [^"]+"', result.stdout)
    selected = os.environ.get('MSGBOX_SIGNING_IDENTITY')
    if selected:
        identities = [identity for identity in identities if identity == selected.upper()]
    if len(identities) != 1:
        raise ValueError('需要一个有效的 Apple Development 签名身份；多个身份时用 MSGBOX_SIGNING_IDENTITY 指定证书指纹。')
    identity = identities[0]
    certificates = subprocess.run(['security', 'find-certificate', '-a', '-c', 'Apple Development', '-p'],
                                  capture_output=True, text=True, check=True).stdout
    for certificate in re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', certificates, re.S):
        details = subprocess.run(['openssl', 'x509', '-noout', '-sha1', '-fingerprint',
                                  '-subject', '-nameopt', 'sep_multiline'], input=certificate,
                                 capture_output=True, text=True, check=True).stdout
        fingerprint = re.search(r'Fingerprint=([0-9A-F:]+)', details)
        team = re.search(r'^\s*OU\s*=\s*([A-Z0-9]+)\s*$', details, re.M)
        if fingerprint and fingerprint[1].replace(':', '') == identity and team:
            return identity, team[1]
    raise ValueError('无法从签名证书确认开发团队，保留已安装版本。')


def validate_update(candidate, installed, migrate=False):
    details = signature(candidate)
    if 'Authority=Apple Development:' not in details or 'Signature=adhoc' in details:
        raise ValueError('正式安装必须使用 Apple Development 证书签名，不能使用临时签名。')
    subprocess.run(['codesign', '--verify', '--strict', '--all-architectures',
                    '-R=anchor apple generic and identifier "local.msgbox.app"', str(candidate)], check=True)
    for app in [candidate, installed] if installed.exists() else [candidate]:
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != 'local.msgbox.app':
            raise ValueError('只能安装正式版 Msgbox，不能覆盖为调试版或其他应用。')
    if not installed.exists():
        return
    old = signature(installed)
    if 'Signature=adhoc' in old:
        if not migrate:
            raise ValueError('旧版为临时签名。首次迁移请加 --migrate-signature；此次可能需要重新授权。')
        return
    requirement = next((line.removeprefix('designated => ') for line in old.splitlines()
                        if line.startswith('designated => ')), None)
    if not requirement or 'anchor apple' not in requirement:
        raise ValueError('无法确认旧版签名身份，保留已安装版本。')
    subprocess.run(['codesign', '--verify', '--strict', '--all-architectures',
                    '-R=' + requirement, str(candidate)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--migrate-signature', action='store_true', help='仅首次从临时签名迁移时使用')
    args = parser.parse_args()
    identity, team = signing_identity()
    subprocess.run(['xcodebuild', '-project', 'Msgbox.xcodeproj', '-scheme', 'Msgbox',
                    '-configuration', 'Release', '-destination', 'platform=macOS',
                    '-derivedDataPath', 'build-release', f'CODE_SIGN_IDENTITY={identity}',
                    f'DEVELOPMENT_TEAM={team}', 'build', 'analyze'], cwd=ROOT, check=True)
    validate_update(APP, INSTALLED, args.migrate_signature)
    if subprocess.run(['pgrep', '-x', 'Msgbox'], capture_output=True).returncode == 0:
        raise ValueError('请先退出 Msgbox，再运行安装；已安装版本尚未改动。')
    # Stage on the same volume so replacement and rollback use atomic renames.
    with tempfile.TemporaryDirectory(prefix='.Msgbox-update-', dir=INSTALLED.parent) as temporary:
        staging = Path(temporary)
        candidate, previous = staging / 'Msgbox.app', staging / 'previous.app'
        subprocess.run(['ditto', str(APP), str(candidate)], check=True)
        validate_update(candidate, INSTALLED, args.migrate_signature)
        backup = ROOT / 'build/installed-backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f') / 'Msgbox.app'
        if INSTALLED.exists():
            backup.parent.mkdir(parents=True)
            subprocess.run(['ditto', str(INSTALLED), str(backup)], check=True)
            INSTALLED.rename(previous)
        try:
            candidate.rename(INSTALLED)
            signature(INSTALLED)
        except BaseException:
            if INSTALLED.exists():
                INSTALLED.rename(staging / 'failed.app')
            if previous.exists():
                previous.rename(INSTALLED)
            raise
    print('已安装 /Applications/Msgbox.app；旧版保存在忽略的 build/installed-backups/。')
    print('首次迁移签名可能需要授权一次；后续更新会校验并保持签名身份。')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'安装未完成：{error}')
