#!/usr/bin/env python3
"""Link focused checks against the actual debug package objects, without Swift Testing."""
from pathlib import Path
import shlex, subprocess, sys
root = Path(__file__).resolve().parent.parent
build = root / '.build/arm64-apple-macosx/debug'
objects = shlex.split((build / 'BetterWispr.product/Objects.LinkFileList').read_text())
objects = [p for p in objects if '/BetterWispr.build/' not in p]
output = build / 'microphone-startup-check'
command = ['swiftc', '-swift-version', '6', '-enable-bare-slash-regex', '-parse-as-library',
           '-module-cache-path', str(root / '.build/microphone-module-cache'),
           '-I', str(build / 'Modules'), '-F', str(build),
           str(root / 'Tests/MicrophoneStartupCheck.swift'), *objects,
           '-o', str(output)]
for wrapper in ['FastClusterWrapper', 'MachTaskSelfWrapper']:
    command.extend(['-I', str(root / '.build/checkouts/FluidAudio/Sources' / wrapper / 'include')])
nemo = root / '.build/artifacts/fluidaudio/NemoTextProcessing/NemoTextProcessing.xcframework/macos-arm64_x86_64'
command.extend(['-I', str(nemo / 'Headers'), '-I', str(nemo / 'Headers/CNemoTextProcessing')])
command.extend(str(p) for p in nemo.glob('*.a'))
command.extend(['-lc++'])
result = subprocess.run(command, cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
subprocess.run([str(output), *sys.argv[1:]], cwd=root, check=True)
