#!/usr/bin/env python3
"""Compare saved VaaniCLI --bench runs against a verified local JSONL manifest."""
import argparse
import json
import math
import sys
from pathlib import Path

from evaluate_transcripts import evaluate, normalize, read_rows


def positive_number(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def index_rows(rows):
    indexed = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('id'), str) or not row['id'].strip():
            raise ValueError('each row must have a nonempty string id')
        if row['id'] in indexed:
            raise ValueError(f"duplicate id: {row['id']}")
        indexed[row['id']] = row
    if not indexed:
        raise ValueError('input contains no rows')
    return indexed


def validate_manifest(rows):
    index_rows(rows)
    for row in rows:
        if row.get('reference_verified') is not True or not isinstance(row.get('reference'), str):
            raise ValueError(f"{row['id']}: requires verified reference text")
        for key in ('reference_source', 'category', 'audio'):
            if not isinstance(row.get(key), str) or not row[key].strip():
                raise ValueError(f"{row['id']}: requires {key}")
        if not Path(row['audio']).is_absolute():
            raise ValueError(f"{row['id']}: audio must be an absolute local path")
        if not positive_number(row.get('duration_seconds')):
            raise ValueError(f"{row['id']}: duration_seconds must be finite and positive")


def word_edits(reference, hypothesis):
    """Return S/D/I from minimum-cost alignment; ties prefer S, then D, then I."""
    if len(reference) * len(hypothesis) > 25_000_000:
        raise ValueError('utterance too long: split at matching audio boundaries before scoring')
    previous = [(0, 0, j) for j in range(len(hypothesis) + 1)]
    for i, left in enumerate(reference, 1):
        current = [(0, i, 0)]
        for j, right in enumerate(hypothesis, 1):
            s, d, ins = previous[j - 1]
            diagonal = (s + (left != right), d, ins)
            s, d, ins = previous[j]
            deletion = (s, d + 1, ins)
            s, d, ins = current[-1]
            insertion = (s, d, ins + 1)
            current.append(min((diagonal, deletion, insertion), key=sum))
        previous = current
    return previous[-1]


def duration_group(seconds):
    return 'very_short_0_1s' if seconds <= 1 else 'short_1_5s' if seconds <= 5 else 'medium_5_15s' if seconds <= 15 else 'long_over_15s'


def score(rows):
    report = evaluate(rows)
    edits = [word_edits(normalize(r['reference']).split(), normalize(r['hypothesis']).split()) for r in rows]
    report.update(zip(('substitutions', 'deletions', 'insertions'), map(sum, zip(*edits))))
    speech = [r for r in rows if r['reference'].strip()]
    report['exact_phrase_match_rate'] = sum(normalize(r['reference']) == normalize(r['hypothesis']) for r in speech) / len(speech) if speech else None
    report['empty_speech_rate'] = sum(not r['hypothesis'].strip() for r in speech) / len(speech) if speech else None
    report['false_speech_rate'] = report['silence_output_rate']
    times = sorted(r['seconds'] for r in rows)
    report['latency_seconds'] = {name: times[math.ceil(len(times) * q) - 1] for name, q in [('p50', .5), ('p95', .95)]}
    return report


def summarize(manifest, run, text_field="hypothesis"):
    if text_field not in ("hypothesis", "cleaned"):
        raise ValueError("text_field must be hypothesis or cleaned")
    validate_manifest(manifest)
    results = index_rows(run)
    if set(results) != {r['id'] for r in manifest}:
        raise ValueError('run IDs must match manifest exactly')
    rows = []
    for clip in manifest:
        result = results[clip['id']]
        if result.get('reference') != clip['reference']:
            raise ValueError(f"{clip['id']}: result reference differs from manifest")
        if not isinstance(result.get('hypothesis'), str) or not positive_number(result.get('seconds')):
            raise ValueError(f"{clip['id']}: requires hypothesis string and finite positive seconds")
        elapsed = result['seconds']
        if text_field == 'cleaned':
            cleanup = result.get('cleanupSeconds')
            if not isinstance(result.get('cleaned'), str) or type(cleanup) not in (int, float) or not math.isfinite(cleanup) or cleanup < 0:
                raise ValueError(f"{clip['id']}: requires cleaned text and finite nonnegative cleanupSeconds")
            elapsed += cleanup
        rows.append({**clip, 'hypothesis': result[text_field], 'seconds': elapsed})
    report = {'text_field': text_field, 'overall': score(rows)}
    for field, key in [('category', 'by_category'), ('duration', 'by_duration')]:
        groups = {}
        for row in rows:
            value = row['category'] if field == 'category' else duration_group(row['duration_seconds'])
            groups.setdefault(value, []).append(row)
        report[key] = {name: score(group) for name, group in sorted(groups.items())}
    return report


def compare(manifest, baseline, candidate, text_field="hypothesis"):
    before, after = summarize(manifest, baseline, text_field), summarize(manifest, candidate, text_field)
    ratios = {q: after['overall']['latency_seconds'][q] / before['overall']['latency_seconds'][q] for q in ('p50', 'p95')}
    delta = {key: after['overall'][key] - before['overall'][key] if before['overall'][key] is not None else None
             for key in ('wer', 'exact_phrase_match_rate', 'empty_speech_rate', 'false_speech_rate', 'deletions', 'insertions')}
    left, right = index_rows(baseline), index_rows(candidate)
    pairs = []
    for clip in manifest:
        a, b = left[clip['id']], right[clip['id']]
        reference = normalize(clip['reference']).split()
        pairs.append({'id': clip['id'], 'word_error_delta': sum(word_edits(reference, normalize(b[text_field]).split())) - sum(word_edits(reference, normalize(a[text_field]).split())),
                      'seconds_delta': b['seconds'] - a['seconds'] + (b['cleanupSeconds'] - a['cleanupSeconds'] if text_field == 'cleaned' else 0)})
    guarded_counts = ('word_errors', 'silent_clips_with_output')
    def regresses(a, b):
        return any(b[key] > a[key] for key in guarded_counts)
    regressed_categories = [name for name in before['by_category']
                            if regresses(before['by_category'][name], after['by_category'][name])]
    accuracy_passed = not regresses(before['overall'], after['overall']) and not regressed_categories
    improved = accuracy_passed and any(after['overall'][key] < before['overall'][key] for key in guarded_counts)
    return {'baseline': before, 'candidate': after, 'delta': delta, 'pairs': pairs,
            'accuracy_gate': {'passed': bool(accuracy_passed), 'guarded_counts': list(guarded_counts),
                              'regressed_categories': regressed_categories},
            'accuracy_improved': bool(improved),
            'latency_gate': {'maximum_ratio': 1.1, 'ratios': ratios, 'passed': all(r <= 1.1 for r in ratios.values())}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('--candidate', type=Path)
    parser.add_argument('--text-field', choices=('hypothesis', 'cleaned'), default='hypothesis')
    args = parser.parse_args()
    try:
        manifest, baseline = list(read_rows(args.manifest)), list(read_rows(args.baseline))
        report = compare(manifest, baseline, list(read_rows(args.candidate)), args.text_field) if args.candidate else summarize(manifest, baseline, args.text_field)
        print(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False))
        return 2 if args.candidate and not (report['latency_gate']['passed'] and report['accuracy_gate']['passed']) else 0
    except (OSError, ValueError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
