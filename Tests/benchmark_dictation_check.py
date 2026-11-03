#!/usr/bin/env python3
"""Synthetic scoring checks only. No recordings or model inference."""
import copy
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from benchmark_dictation import compare, summarize, validate_manifest, word_edits

manifest = [dict(id='speech', audio='/local/speech.wav', reference='one two three',
                 reference_verified=True, reference_source='human listening', duration_seconds=3, category='numbers'),
            dict(id='silent', audio='/local/silent.wav', reference='', reference_verified=True,
                 reference_source='human listening', duration_seconds=12, category='silence')]
baseline = [dict(id='speech', reference='one two three', hypothesis='one', seconds=1),
            dict(id='silent', reference='', hypothesis='invented', seconds=2)]
candidate = [dict(id='silent', reference='', hypothesis='', seconds=2.2),
             dict(id='speech', reference='one two three', hypothesis='ONE two three!', seconds=1.1)]
validate_manifest(manifest)
assert word_edits('one two three'.split(), ['one']) == (0, 2, 0)
assert word_edits([], ['invented']) == (0, 0, 1)
report = summarize(manifest, baseline)
assert report['overall']['wer'] == 1
assert report['overall']['deletions'] == 2 and report['overall']['insertions'] == 1
assert report['overall']['exact_phrase_match_rate'] == 0
assert report['overall']['false_speech_rate'] == 1
assert report['overall']['latency_seconds'] == {'p50': 1, 'p95': 2}
assert set(report['by_duration']) == {'short_1_5s', 'medium_5_15s'}
paired = compare(manifest, baseline, candidate)
assert paired['latency_gate']['passed'] is True
assert paired['delta']['wer'] == -1
assert paired['candidate']['overall']['exact_phrase_match_rate'] == 1
assert [p['id'] for p in paired['pairs']] == ['speech', 'silent']
slow = copy.deepcopy(candidate)
slow[0]['seconds'] = 2.21
assert compare(manifest, baseline, slow)['latency_gate']['passed'] is False
empty = copy.deepcopy(baseline)
empty[0]['hypothesis'] = ''
assert summarize(manifest, empty)['overall']['empty_speech_rate'] == 1
for invalid in [manifest + [manifest[0]], [{**manifest[0], 'reference_verified': False}],
                [{**manifest[0], 'duration_seconds': float('nan')}]]:
    try:
        validate_manifest(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid manifest accepted')
for invalid in [candidate[:1], candidate + [candidate[0]],
                [{**candidate[0], 'seconds': -1}, candidate[1]],
                [candidate[0], {**candidate[1], 'reference': 'changed'}]]:
    try:
        summarize(manifest, invalid)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid run accepted')
cleaned = [{**r, 'cleaned': '', 'cleanupSeconds': .25} for r in baseline]
assert summarize(manifest, cleaned, 'cleaned')['overall']['empty_speech_rate'] == 1
assert summarize(manifest, cleaned, 'cleaned')['overall']['latency_seconds']['p95'] == 2.25
try:
    summarize(manifest, baseline, 'cleaned')
except ValueError:
    pass
else:
    raise AssertionError('missing cleanup accepted')
print('Dictation benchmark checks passed.')

# Check the CLI's report and failure codes using synthetic inputs.
import json
import subprocess
import tempfile
with tempfile.TemporaryDirectory() as folder:
    paths = [Path(folder) / name for name in ('manifest.jsonl', 'baseline.jsonl', 'candidate.jsonl')]
    for path, rows in zip(paths, (manifest, baseline, candidate)):
        path.write_text('\n'.join(json.dumps(r) for r in rows), encoding='utf-8')
    command = [sys.executable, str(Path(__file__).resolve().parents[1] / 'scripts/benchmark_dictation.py'),
               str(paths[0]), str(paths[1]), '--candidate', str(paths[2])]
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 0 and json.loads(result.stdout)['latency_gate']['passed']
    paths[2].write_text('\n'.join(json.dumps(r) for r in slow), encoding='utf-8')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 2 and not json.loads(result.stdout)['latency_gate']['passed']
    paths[2].write_text('{invalid', encoding='utf-8')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'invalid JSON' in result.stderr
print('Dictation benchmark CLI checks passed.')

# A minority category must not regress even if overall errors improve.
minority_manifest = [{**manifest[0], 'id': 'majority', 'category': 'majority'},
                     {**manifest[0], 'id': 'minority', 'category': 'minority', 'duration_seconds': .8}]
minority_before = [dict(id='majority', reference='one two three', hypothesis='', seconds=1),
                   dict(id='minority', reference='one two three', hypothesis='one two three', seconds=1)]
minority_after = [dict(id='majority', reference='one two three', hypothesis='one two three', seconds=1),
                  dict(id='minority', reference='one two three', hypothesis='one two', seconds=1)]
minority_report = compare(minority_manifest, minority_before, minority_after)
assert minority_report['delta']['wer'] < 0
assert not minority_report['accuracy_gate']['passed']
assert minority_report['accuracy_gate']['regressed_categories'] == ['minority']
assert minority_report['accuracy_improved'] is False
assert 'very_short_0_1s' in minority_report['baseline']['by_duration']
assert compare(manifest, baseline, baseline)['accuracy_gate']['passed']
assert compare(manifest, baseline, baseline)['accuracy_improved'] is False
assert compare(manifest, baseline, candidate)['accuracy_improved'] is True
silence_report = compare([manifest[1]], [candidate[0]], [candidate[0]])
assert silence_report['accuracy_gate']['passed']
assert silence_report['delta']['wer'] is None
assert silence_report['delta']['exact_phrase_match_rate'] is None
with tempfile.TemporaryDirectory() as folder:
    paths = [Path(folder) / name for name in ('manifest.jsonl', 'baseline.jsonl', 'candidate.jsonl')]
    for path, rows in zip(paths, (minority_manifest, minority_before, minority_after)):
        path.write_text('\n'.join(json.dumps(r) for r in rows), encoding='utf-8')
    result = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / 'scripts/benchmark_dictation.py'),
                             str(paths[0]), str(paths[1]), '--candidate', str(paths[2])], capture_output=True, text=True)
    assert result.returncode == 2 and not json.loads(result.stdout)['accuracy_gate']['passed']
print('Accuracy gate and very short clip checks passed.')
