#!/usr/bin/env python3
"""Exercise release failures with stub OS services and real bundle validation."""
from pathlib import Path
import os, plistlib, shutil, subprocess, tempfile
source=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='vaani-release-check-') as temporary:
    root=Path(temporary)
    (root/'scripts').mkdir(); (root/'Tests').mkdir(); (root/'bin').mkdir(); (root/'release').mkdir()
    shutil.copy2(source/'scripts/release.sh',root/'scripts/release.sh')
    shutil.copy2(source/'Tests/branding_check.py',root/'Tests/branding_check.py')
    def stub(path,body):
        file=root/path; file.parent.mkdir(parents=True,exist_ok=True)
        file.write_text('#!/bin/bash\nset -eu\n'+body+'\n'); file.chmod(0o755)
    stub('bin/xcrun','''if [[ "$2" == history && "${FAIL_STAGE:-}" == history ]]; then exit 1; fi
if [[ "$2" == submit && "${FAIL_STAGE:-}" == notarize ]]; then exit 1; fi
if [[ "$2" == staple && "${FAIL_STAGE:-}" == staple ]]; then exit 1; fi''')
    stub('bin/lipo','if [[ "${FAIL_STAGE:-}" == arch ]]; then echo x86_64; else echo arm64; fi')
    stub('bin/codesign','[[ "${FAIL_STAGE:-}" != signing ]]')
    stub('bin/spctl','[[ "${FAIL_STAGE:-}" != assessment ]]')
    stub('scripts/build-app.sh','''[[ "${FAIL_STAGE:-}" != build ]] || exit 1
app="$PWD/.build/Vaani.app"
mkdir -p "$app/Contents"
cp -R "$PWD/template/Contents/." "$app/Contents/"
echo "$app"''')
    stub('scripts/create-dmg.sh','[[ "${FAIL_STAGE:-}" != packaging ]] || exit 1\nprintf new-dmg > "$2"')
    template=root/'template/Contents'; (template/'MacOS').mkdir(parents=True); (template/'Resources/Licenses').mkdir(parents=True)
    (template/'MacOS/Vaani').write_bytes(b'executable')
    (template/'Resources/AppIcon.icns').write_bytes(b'icon')
    for name in ('Vaani-GPL-3.0.txt','BetterWispr-Apache-2.0.txt','THIRD_PARTY_NOTICES.md','Vaani-Provenance.md','Adapted-Code-Notices.txt','Argmax-MIT.txt','FluidAudio-Apache-2.0.txt'):
        (template/'Resources/Licenses'/name).write_bytes(b'x'*35149)
    valid={'CFBundleIdentifier':'io.github.aakashs11.vaani','CFBundleName':'Vaani','CFBundleDisplayName':'Vaani (वाणी)','CFBundleExecutable':'Vaani','NSMicrophoneUsageDescription':'Vaani records only after start.'}
    env=dict(os.environ,PATH=str(root/'bin')+':'+os.environ['PATH'],SIGNING_IDENTITY='Developer ID Application: Test Owner (TESTTEAM)',APPLE_TEAM_ID='TESTTEAM',NOTARY_PROFILE='test-profile')
    def run(**overrides):
        shutil.rmtree(root/'.build',ignore_errors=True)
        return subprocess.run(['bash','scripts/release.sh'],cwd=root,env=dict(env,**overrides),capture_output=True,text=True)
    marker=root/'release/Vaani-arm64.dmg'
    (template/'Info.plist').write_bytes(plistlib.dumps(valid))
    marker.write_bytes(b'previous-release')
    result=run(SIGNING_IDENTITY='')
    assert result.returncode and 'SIGNING_IDENTITY' in result.stderr
    assert marker.read_bytes()==b'previous-release'
    for stage in ('history','build','arch','signing','packaging','notarize','staple','assessment'):
        result=run(FAIL_STAGE=stage)
        assert result.returncode, (stage,result.stdout,result.stderr, (root/"scripts/build-app.sh").read_text())
        assert marker.read_bytes()==b'previous-release',stage
    for change in ({'CFBundleIdentifier':'org.betterwispr.app'},{'SUFeedURL':'https://example.invalid/upstream.xml'}):
        (template/'Info.plist').write_bytes(plistlib.dumps(valid|change))
        result=run()
        assert result.returncode and marker.read_bytes()==b'previous-release'
    (template/'Info.plist').write_bytes(plistlib.dumps(valid))
    result=run()
    assert result.returncode==0,(result.stdout,result.stderr)
    assert marker.read_bytes()==b'new-dmg'
    assert (root/'release/Vaani-arm64.dmg.sha256').is_file()
    assert not (root/'release/appcast.xml').exists()
    # Exercise actual DMG wrapper: successful verification is required before replacement.
    shutil.copy2(source/'scripts/create-dmg.sh',root/'scripts/create-dmg.sh')
    stub('bin/ditto','cp -R "$1" "$2"')
    stub('bin/hdiutil','''if [[ "$1" == create ]]; then
    [[ "${FAIL_STAGE:-}" != dmg-create ]] || exit 1
    for last; do :; done
    printf compressed > "$last"
elif [[ "$1" == verify ]]; then
    [[ "${FAIL_STAGE:-}" != dmg-verify ]] || exit 1
fi''')
    for stage in ('dmg-create','dmg-verify',''):
        marker.write_bytes(b'previous-release')
        result=subprocess.run(['bash','scripts/create-dmg.sh',str(root/'.build/Vaani.app'),str(marker)],cwd=root,env=dict(env,FAIL_STAGE=stage),capture_output=True,text=True)
        assert (result.returncode==0)==(stage==''),(stage,result.stderr)
        assert marker.read_bytes()==(b'compressed' if not stage else b'previous-release')
        assert not list((root/'release').glob('.vaani-dmg.*'))
print('Release checks passed: owner preflight, build/architecture/signing/package/notary/staple/assessment failures, wrong identity/feed, verified replacement, DMG failure cleanup.')
