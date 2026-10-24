#!/usr/bin/env python3
"""Inspect the actual app bundle rather than source spelling."""
import plistlib, sys
from pathlib import Path
app=Path(sys.argv[1]).resolve()
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='io.github.aakashs11.vaani'
assert info['CFBundleName']=='Vaani' and info['CFBundleExecutable']=='Vaani'
assert (app/'Contents/MacOS/Vaani').is_file()
assert not (app/'Contents/MacOS/BetterWispr').exists(), 'Stale upstream executable in generated bundle'
assert (app/'Contents/Resources/AppIcon.icns').stat().st_size>0
assert 'SUFeedURL' not in info and 'SUPublicEDKey' not in info
for key,value in info.items():
    if key.endswith('UsageDescription'):
        assert 'BetterWispr' not in value
        assert 'Vaani' in value
licenses=app/'Contents/Resources/Licenses'
for name in ('Vaani-GPL-3.0.txt','BetterWispr-Apache-2.0.txt','THIRD_PARTY_NOTICES.md','Vaani-Provenance.md','Adapted-Code-Notices.txt','Argmax-MIT.txt','FluidAudio-Apache-2.0.txt'):
    assert (licenses/name).stat().st_size>100, name
assert (licenses/'Vaani-GPL-3.0.txt').stat().st_size>30000
for p in app.rglob('*'):
    assert p.name not in ('workspace.json','events.jsonl','DictationEvidence'), p
print('Bundle checks passed: Vaani identity/executable/icon, permission descriptions, no upstream feed, complete notices, no private workspace.')
