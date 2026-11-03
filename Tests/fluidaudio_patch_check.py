#!/usr/bin/env python3
"""Exercise the compatibility patch's fail-closed behavior in a temporary repo."""
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('compat', ROOT / 'scripts/apply-fluidaudio-patch.py')
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)


def git(checkout, *arguments):
    return subprocess.run(['git', '-C', str(checkout), *arguments],
                          check=True, capture_output=True, text=True).stdout.strip()


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    checkout = root / '.build/checkouts/FluidAudio'
    checkout.mkdir(parents=True)
    source = checkout / 'fixture.swift'
    source.write_text('old\n')
    git(checkout, 'init', '-q')
    git(checkout, 'add', 'fixture.swift')
    git(checkout, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture')
    compat.REVISION = git(checkout, 'rev-parse', 'HEAD')
    compat.SOURCE_HASHES = {'fixture.swift': (
        hashlib.sha256(b'old\n').hexdigest(), hashlib.sha256(b'new\n').hexdigest())}
    pins = {'pins': [{'identity': 'fluidaudio', 'state': {
        'version': compat.VERSION, 'revision': compat.REVISION}}]}
    resolved = root / 'Package.resolved'
    resolved.write_text(json.dumps(pins))
    (root / 'patches').mkdir()
    patch = root / 'patches' / compat.PATCH_NAME
    patch.write_text('--- a/fixture.swift\n+++ b/fixture.swift\n@@ -1 +1 @@\n-old\n+new\n')

    source.chmod(0o444)
    assert 'Applied' in compat.apply_patch(root)
    assert source.read_text() == 'new\n'
    assert stat.S_IMODE(source.stat().st_mode) == 0o444
    assert 'already applied' in compat.apply_patch(root)

    source.chmod(0o644)
    source.write_text('unreviewed edit\n')
    try:
        compat.apply_patch(root)
    except ValueError as error:
        assert 'source changed' in str(error)
    else:
        raise AssertionError('unreviewed source accepted')
    assert source.read_text() == 'unreviewed edit\n'

    source.write_text('old\n')
    pins['pins'][0]['state']['version'] = '99.0.0'
    resolved.write_text(json.dumps(pins))
    try:
        compat.apply_patch(root)
    except ValueError as error:
        assert 'pin changed' in str(error)
    else:
        raise AssertionError('unreviewed pin accepted')
    assert source.read_text() == 'old\n'

    pins['pins'][0]['state']['version'] = compat.VERSION
    resolved.write_text(json.dumps(pins))
    patch.write_text('not a patch\n')
    try:
        compat.apply_patch(root)
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError('invalid patch accepted')
    assert source.read_text() == 'old\n'

print('FluidAudio compatibility patch checks passed.')
