#!/usr/bin/env python3
"""Scan Git candidates for common credential material; never print matching values."""
from pathlib import Path
import re
import subprocess

paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).split(b'\0')
patterns = [
    re.compile(rb'-----BEGIN ' + rb'(?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(rb'gh' + rb'[pousr]_[A-Za-z0-9]{30,}'),
    re.compile(rb'AK' + rb'IA[0-9A-Z]{16}'),
]
count = 0
bad = []
for raw in sorted(set(paths)):
    if not raw:
        continue
    p = Path(raw.decode())
    if not p.is_file():
        continue
    count += 1
    if p.suffix.lower() in ('.jks', '.keystore') or p.name in ('export_credentials.cfg', 'local.properties'):
        bad.append(str(p))
        continue
    data = p.read_bytes()
    if any(pattern.search(data) for pattern in patterns):
        bad.append(str(p))
if bad:
    raise SystemExit('FAIL: credential material or forbidden file detected in: ' + ', '.join(bad))
print(f'PASS: {count} Git candidate files scanned; no common credentials or signing files detected (limited pattern scan)')
