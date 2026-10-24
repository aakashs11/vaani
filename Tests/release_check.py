#!/usr/bin/env python3
"""Check the real release preflight without touching signing services or user data."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temporary:
    directory=Path(temporary)
    marker=directory/'keep.dmg'
    marker.write_bytes(b'previous release')
    env=dict(os.environ, RELEASE_DIR=str(directory))
    for name in ('SIGNING_IDENTITY','APPLE_TEAM_ID','NOTARY_PROFILE'):
        env.pop(name,None)
    result=subprocess.run(['bash',str(root/'scripts/release.sh')],env=env,capture_output=True,text=True)
    assert result.returncode != 0, 'Release must reject missing owner credentials'
    assert 'SIGNING_IDENTITY' in result.stderr, result.stderr
    assert marker.read_bytes()==b'previous release'
    result=subprocess.run(['bash',str(root/'scripts/release.sh'),'--setup-notary'],env=env,capture_output=True,text=True)
    assert result.returncode != 0 and 'APPLE_TEAM_ID' in result.stderr
print('Release preflight checks passed: explicit owner credentials, no artifact loss on failure.')
