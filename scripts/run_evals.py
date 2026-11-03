#!/usr/bin/env python3
"""Run every configured local benchmark with fresh candidate CLI output."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from benchmark_dictation import compare, validate_manifest
from evaluate_transcripts import read_rows


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def local_path(value, root):
    if not isinstance(value, str) or not value.strip():
        raise ValueError('asset paths must be nonempty strings')
    path = Path(value).expanduser()
    return (root / path).resolve() if not path.is_absolute() else path.resolve()


def run_suite(suite, index, config_root, cli, output, timeout):
    report = {'name': suite.get('name', f'suite-{index}') if isinstance(suite, dict) else f'suite-{index}', 'passed': False}
    try:
        if not isinstance(suite, dict):
            raise ValueError('suite must be an object')
        name = suite.get('name')
        if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', name):
            raise ValueError('suite name must contain only letters, numbers, underscores or hyphens')
        if 'candidate' in suite:
            raise ValueError('candidate files are unsupported: every run must generate fresh CLI results')
        model = suite.get('model')
        if not isinstance(model, str) or not model.strip() or model.startswith('-'):
            raise ValueError('suite requires an explicit installed model ID')
        cleanup = suite.get('cleanup', 'none')
        if cleanup not in ('none', 'light'):
            raise ValueError('cleanup must be none or light for local evals')
        fields = suite.get('text_fields', ['hypothesis', 'cleaned'] if cleanup == 'light' else ['hypothesis'])
        if not isinstance(fields, list) or not fields or any(f not in ('hypothesis', 'cleaned') for f in fields):
            raise ValueError('text_fields must be a nonempty list of hypothesis and/or cleaned')
        fields = list(dict.fromkeys(fields))
        if cleanup == 'light':
            fields = ['hypothesis', 'cleaned']
        elif 'cleaned' in fields:
            raise ValueError('cleaned scoring requires cleanup light')
        manifest_path = local_path(suite.get('manifest'), config_root)
        baseline_path = local_path(suite.get('baseline'), config_root)
        manifest, baseline = list(read_rows(manifest_path)), list(read_rows(baseline_path))
        validate_manifest(manifest)
        for clip in manifest:
            if not Path(clip['audio']).is_file():
                raise ValueError(f"missing audio asset for {clip['id']}: {clip['audio']}")
        # Validate every baseline before spending time on inference.
        for field in fields:
            compare(manifest, baseline, baseline, field)
        if not cli.is_file() or not os.access(cli, os.X_OK):
            raise ValueError(f'CLI is missing or not executable: {cli}')
        report.update(model=model, cleanup=cleanup, manifest=str(manifest_path), baseline=str(baseline_path),
                      manifest_sha256=sha256(manifest_path), baseline_sha256=sha256(baseline_path),
                      cli=str(cli), cli_sha256=sha256(cli))
        prefix = f'{index:03d}-{name}'
        candidate = output / f'{prefix}.jsonl'
        stderr = output / f'{prefix}.stderr.txt'
        command = [str(cli), '--bench', str(manifest_path), '--model', model]
        if cleanup != 'none':
            command += ['--cleanup', cleanup]
        if 'language' in suite:
            language = suite['language']
            if not isinstance(language, str) or not language.strip() or language.startswith('-'):
                raise ValueError('language must be a nonempty language code or auto')
            command += ['--language', language]
        report.update(command=command, candidate=str(candidate), stderr=str(stderr))
        started = time.monotonic()
        try:
            with candidate.open('x', encoding='utf-8') as stdout_file, stderr.open('x', encoding='utf-8') as stderr_file:
                process = subprocess.run(command, stdout=stdout_file, stderr=stderr_file, timeout=timeout)
        finally:
            report['process_wall_seconds'] = time.monotonic() - started
        report['cli_returncode'] = process.returncode
        if process.returncode:
            raise ValueError(f'CLI exited {process.returncode}; see {stderr}')
        results = list(read_rows(candidate))
        scores = {field: compare(manifest, baseline, results, field) for field in fields}
        report['scores'] = scores
        report['passed'] = all(s['accuracy_gate']['passed'] and s['latency_gate']['passed'] for s in scores.values())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        report['error'] = str(error)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--cli', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--timeout', type=float, default=600, help='maximum seconds per suite (default: 600)')
    args = parser.parse_args()
    try:
        if not math.isfinite(args.timeout) or args.timeout <= 0:
            raise ValueError('timeout must be finite and positive')
        config_path = args.config.expanduser().resolve()
        config = json.loads(config_path.read_text(encoding='utf-8'))
        if not isinstance(config, dict) or not isinstance(config.get('suites'), list) or not config['suites']:
            raise ValueError('config requires a nonempty suites list')
        output = args.output.expanduser().resolve()
        output.mkdir(parents=True, exist_ok=False)
        report = {'created_at': datetime.now(timezone.utc).isoformat(), 'config': str(config_path),
                  'config_sha256': sha256(config_path), 'suites': []}
        for index, suite in enumerate(config['suites'], 1):
            report['suites'].append(run_suite(suite, index, config_path.parent, args.cli.expanduser().resolve(), output, args.timeout))
        report['passed'] = all(s['passed'] for s in report['suites'])
        (output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False, allow_nan=False) + '\n', encoding='utf-8')
        print(f"{'PASS' if report['passed'] else 'FAIL'}: {output / 'report.json'}")
        return 0 if report['passed'] else 2
    except (OSError, ValueError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
