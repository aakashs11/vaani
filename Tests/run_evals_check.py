#!/usr/bin/env python3
"""Runner integration checks with a fake CLI and the real scorer."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    cli = root / 'fake-cli'
    cli.write_text('''#!/usr/bin/env python3
import json, sys
from pathlib import Path
manifest = Path(sys.argv[sys.argv.index('--bench') + 1])
for line in manifest.read_text().splitlines():
    row = json.loads(line)
    print(json.dumps(dict(id=row['id'], reference=row['reference'], hypothesis=row['reference'], seconds=1, cleaned=row['reference'], cleanupSeconds=.1)))
''')
    cli.chmod(0o755)
    (root / 'audio.wav').write_bytes(b'fixture')
    manifest = dict(id='a', audio=str(root / 'audio.wav'), reference='hello', reference_verified=True,
                    reference_source='test fixture', category='short', duration_seconds=1)
    (root / 'manifest.jsonl').write_text(json.dumps(manifest))
    baseline = dict(id='a', reference='hello', hypothesis='hello', seconds=1, cleaned='hello', cleanupSeconds=.1)
    (root / 'baseline.jsonl').write_text(json.dumps(baseline))
    suite = dict(name='first', manifest='manifest.jsonl', baseline='baseline.jsonl', model='installed', cleanup='light')
    config = root / 'config.json'
    config.write_text(json.dumps({'suites': [suite]}))
    def run(output):
        return subprocess.run([sys.executable, str(ROOT / 'scripts/run_evals.py'), '--config', str(config),
                               '--cli', str(cli), '--output', str(root / output)], capture_output=True, text=True)
    result = run('good')
    assert result.returncode == 0, result.stderr
    report = json.loads((root / 'good/report.json').read_text())
    assert report['passed'] and set(report['suites'][0]['scores']) == {'hypothesis', 'cleaned'}
    assert report['suites'][0]['manifest_sha256'] and report['suites'][0]['cli_sha256']
    assert run('good').returncode != 0  # Never overwrite previous results.
    config.write_text(json.dumps({'suites': [{**suite, 'name': 'missing', 'manifest': 'absent'}, suite]}))
    assert run('mixed').returncode != 0
    report = json.loads((root / 'mixed/report.json').read_text())
    assert not report['passed'] and len(report['suites']) == 2
    assert report['suites'][0]['error'] and report['suites'][1]['passed']
    (root / 'baseline.jsonl').write_text(json.dumps({**baseline, 'seconds': .5}))
    config.write_text(json.dumps({'suites': [suite]}))
    assert run('slow').returncode != 0
    report = json.loads((root / 'slow/report.json').read_text())
    assert not report['suites'][0]['scores']['hypothesis']['latency_gate']['passed']
    # Missing audio must fail before invoking the recognizer.
    (root / 'audio.wav').unlink()
    assert run('missing-audio').returncode != 0
    report = json.loads((root / 'missing-audio/report.json').read_text())
    assert 'missing audio asset' in report['suites'][0]['error']
    assert not list((root / 'missing-audio').glob('*.jsonl'))
    (root / 'audio.wav').write_bytes(b'fixture')
    (root / 'baseline.jsonl').write_text(json.dumps(baseline))
    # A nonzero recognizer exit remains an explicit failure, with diagnostic output.
    cli.write_text('#!/usr/bin/env python3\nimport sys\nprint("recognizer failed", file=sys.stderr)\nsys.exit(7)\n')
    assert run('cli-failed').returncode != 0
    report = json.loads((root / 'cli-failed/report.json').read_text())
    assert report['suites'][0]['cli_returncode'] == 7
    assert 'recognizer failed' in Path(report['suites'][0]['stderr']).read_text()
    # Invalid config must never silently turn into a passing empty run.
    config.write_text('{"suites": []}')
    assert run('empty').returncode != 0
print('Fresh eval runner checks passed.')
