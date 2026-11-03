#!/usr/bin/env python3
"""Apply the reviewed Unified repetition fix to the exact pinned dependency.

No resolution or downloads happen here. Run after swift package resolve and
before building. Source drift fails closed rather than guessing patch context.
"""
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys

VERSION = '0.17.5'
REVISION = '0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7'
PATCH_NAME = 'fluidaudio-0.17.5-unified-repetition.patch'
SOURCE_HASHES = {
    'Sources/FluidAudio/ASR/Parakeet/Unified/UnifiedAsrManager.swift': (
        'ee3e32c676f0033037bf79acb89be33da2d1bfb998cdef7ee40da44db41e808f',
        '2e0f39bf54e5693d7e92f8826d4bc3abef9da85140a8b93d0adda767f073e9eb'),
    'Sources/FluidAudio/ASR/Parakeet/SlidingWindow/TDT/ChunkProcessor.swift': (
        '7fc01637cf3d8ef5cb51ecb09806ca2546b0c203f85626ac024da8d4f05de787',
        '7fe7a1a914d254025e3c163dfeef1ff13cbd34381e7431d79fa6b748d7c5283d'),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply_patch(root):
    checkout = root / '.build/checkouts/FluidAudio'
    resolved = json.loads((root / 'Package.resolved').read_text())
    pins = [p for p in resolved['pins'] if p['identity'].lower() == 'fluidaudio']
    if len(pins) != 1 or pins[0]['state'] != {'revision': REVISION, 'version': VERSION}:
        raise ValueError('FluidAudio pin changed. Review the compatibility patch before building.')
    revision = subprocess.run(['git', '-C', str(checkout), 'rev-parse', 'HEAD'],
                              check=True, text=True, capture_output=True).stdout.strip()
    if revision != REVISION:
        raise ValueError('FluidAudio checkout does not match the reviewed revision.')
    actual = {name: digest(checkout / name) for name in SOURCE_HASHES}
    if all(actual[name] == hashes[1] for name, hashes in SOURCE_HASHES.items()):
        return 'FluidAudio repetition patch already applied.'
    if not all(actual[name] == hashes[0] for name, hashes in SOURCE_HASHES.items()):
        raise ValueError('FluidAudio source changed or is partially patched. Refusing to overwrite it.')
    patch = root / 'patches' / PATCH_NAME
    command = ['git', '-C', str(checkout), 'apply']
    subprocess.run([*command, '--check', str(patch)], check=True, capture_output=True)
    # SwiftPM checkouts can have read-only source files. Preserve their modes.
    modes = {name: (checkout / name).stat().st_mode for name in SOURCE_HASHES}
    try:
        for name, mode in modes.items():
            (checkout / name).chmod(mode | stat.S_IWUSR)
        subprocess.run([*command, str(patch)], check=True, capture_output=True)
    finally:
        for name, mode in modes.items():
            (checkout / name).chmod(mode)
    if not all(digest(checkout / name) == hashes[1] for name, hashes in SOURCE_HASHES.items()):
        raise ValueError('Patched FluidAudio source did not match the reviewed hashes.')
    return 'Applied reviewed FluidAudio single-window repetition patch.'


if __name__ == '__main__':
    try:
        print(apply_patch(Path(__file__).resolve().parent.parent))
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(1)
