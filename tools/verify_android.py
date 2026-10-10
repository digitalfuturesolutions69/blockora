#!/usr/bin/env python3
"""Verify fresh Android export identity, manifest, permissions, bridge, and signing."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

SDK = Path(os.environ['ANDROID_HOME'])
TOOLS = SDK / 'build-tools/36.1.0'
A = '{http://schemas.android.com/apk/res/android}'
ALLOWED_PERMISSIONS = {
    'android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE',
    'com.android.vending.BILLING',
    # Required by Google SDK transport/WorkManager background jobs.
    'android.permission.WAKE_LOCK',
    # AGP/AndroidX-generated signature-level self permission; no runtime prompt.
    'com.digitalfuturesolutions.blockora.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

def check(condition, message):
    if not condition:
        raise SystemExit('FAIL: ' + message)

apk = Path('builds/blockora-debug.apk')
aab = Path('builds/blockora-test.aab')
for archive in (apk, aab):
    check(archive.exists() and archive.stat().st_size > 0, f'{archive} exists')
    with zipfile.ZipFile(archive) as z:
        check(z.testzip() is None, f'{archive} ZIP integrity')
        dex_names = [n for n in z.namelist() if n.endswith('.dex')]
        dex = b''.join(z.read(n) for n in dex_names)
        for marker in (b'BlockoraPlatform', b'com/google/android/gms/ads', b'com/android/billingclient'):
            check(marker in dex, f'{archive} packaged class {marker.decode()}')
        check(any('/arm64-v8a/' in n and n.endswith('.so') for n in z.namelist()), 'ARM64 native library')
        if archive == aab:
            check('BundleConfig.pb' in z.namelist(), 'AAB bundle config')
            check(not any(n.startswith('META-INF/') and n.endswith(('.RSA', '.DSA', '.EC')) for n in z.namelist()), 'test AAB intentionally unsigned')
    print(f'{archive}: size={archive.stat().st_size}, sha256={hashlib.sha256(archive.read_bytes()).hexdigest()}')

badging = run(str(TOOLS / 'aapt'), 'dump', 'badging', str(apk))
check("package: name='com.digitalfuturesolutions.blockora'" in badging, 'APK application ID')
check("sdkVersion:'26'" in badging, 'APK minimum SDK 26')
check("targetSdkVersion:'36'" in badging, 'APK target SDK 36')
permissions = set(re.findall(r"uses-permission: name='([^']+)'", badging))
check(permissions <= ALLOWED_PERMISSIONS, 'APK unexpected permissions: ' + str(permissions - ALLOWED_PERMISSIONS))
run(str(TOOLS / 'apksigner'), 'verify', str(apk))
print('PASS: APK package, SDKs, permission allowlist, debug signature')

bundletool = Path(os.environ.get('BUNDLETOOL_JAR', '/workspace/toolchains/bundletool-1.18.3.jar'))
check(hashlib.sha256(bundletool.read_bytes()).hexdigest() == 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29', 'bundletool SHA256')
run('java', '-jar', str(bundletool), 'validate', '--bundle=' + str(aab))
manifest = run('java', '-jar', str(bundletool), 'dump', 'manifest', '--bundle=' + str(aab))
Path('builds/aab-manifest.xml').write_text(manifest)
root = ET.fromstring(manifest)
check(root.get('package') == 'com.digitalfuturesolutions.blockora', 'AAB application ID')
uses_sdk = root.find('uses-sdk')
check(uses_sdk.get(A + 'minSdkVersion') == '26', 'AAB minimum SDK 26')
check(uses_sdk.get(A + 'targetSdkVersion') == '36', 'AAB target SDK 36')
activity = root.find('application/activity')
check(activity is not None and activity.get(A + 'screenOrientation') in ('portrait', '1'), 'portrait activity')
manifest_permissions = {p.get(A + 'name') for p in root.findall('uses-permission')}
check(manifest_permissions <= ALLOWED_PERMISSIONS, 'AAB unexpected permissions: ' + str(manifest_permissions - ALLOWED_PERMISSIONS))
metadata = {p.get(A + 'name'): p.get(A + 'value') for p in root.findall('application/meta-data')}
check(metadata.get('org.godotengine.plugin.v2.BlockoraPlatform') == 'com.digitalfuturesolutions.blockora.platform.BlockoraPlatform', 'Godot v2 bridge metadata')
check(metadata.get('com.google.android.gms.ads.APPLICATION_ID') == 'ca-app-pub-3940256099942544~3347511713', 'official Google test app ID')
check(metadata.get('com.google.android.gms.ads.DELAY_APP_MEASUREMENT_INIT') == 'true', 'defer ad measurement')
print('PASS: bundletool validation, AAB SDKs, portrait, permissions, v2 plugin and test AdMob ID')
print('Permissions:', ', '.join(sorted(manifest_permissions)))
