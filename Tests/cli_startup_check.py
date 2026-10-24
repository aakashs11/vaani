#!/usr/bin/env python3
"""Run the real CLI with a temporary macOS home and legacy workspace."""
from pathlib import Path
import json, os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
cli=root/'.build/arm64-apple-macosx/debug/VaaniCLI'
with tempfile.TemporaryDirectory(prefix='vaani-cli-startup-') as temporary:
    home=Path(temporary)
    support=home/'Library/Application Support'
    old=support/'BetterWispr'; new=support/'Vaani'
    old.mkdir(parents=True)
    payload=json.dumps({'version':1,'settings':{'selectedModelID':'whisper-tiny','language':'en','autoPaste':True,'saveHistory':True,'showCapsule':True,'launchAtLogin':False,'silenceThreshold':0.002,'soundEffects':False,'shortcut':{'keyCode':54,'modifiers':0,'key':'Right Command'}},'history':[],'vocabulary':[]}).encode()
    (old/'workspace.json').write_bytes(payload)
    env=dict(os.environ,CFFIXED_USER_HOME=str(home))
    listed=subprocess.run([str(cli),'--list-models'],env=env,capture_output=True,text=True,timeout=30)
    assert listed.returncode==0 and not new.exists()
    result=subprocess.run([str(cli),'--transcribe-file',str(home/'absent.wav'),'--model','whisper-tiny'],env=env,capture_output=True,text=True,timeout=30)
    assert (new/'workspace.json').is_file(), ('CLI model initialization must migrate legacy data before touching Vaani storage',result.stderr)
    assert (new/'workspace.json').read_bytes()==payload
    assert (old/'workspace.json').read_bytes()==payload
    assert (new/'.vaani-migration.json').is_file()
    assert result.returncode!=0, 'A missing model/audio must not cause a download or silent success'
print('CLI startup check passed: listing is read-only; model use migrates legacy workspace before provider storage; source/settings bytes unchanged.')
