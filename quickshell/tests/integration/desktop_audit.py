"""Regression tests for audited desktop actions; all external actions are mocked.

Set REVIEW_FIX_MANIFEST to exercise staged files instead of installed configs.
"""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile

home = Path.home()
manifest = json.loads(Path(os.environ['REVIEW_FIX_MANIFEST']).read_text()) if os.environ.get('REVIEW_FIX_MANIFEST') else []
staged = {row['path']: Path(row['stage']) for row in manifest}
def source(relative):
    path = home / relative
    return staged.get(str(path), path)

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness import require_external_files
require_external_files(*(source(name) for name in ['.scripts/configs.sh', '.scripts/gamemode-toggle.sh', '.scripts/fullscreen_toggle.sh', '.scripts/audio-mute-toggle.sh', '.scripts/mic-toggle.sh', '.config/hypr/keybinds.lua', '.config/wlogout/layout']))

with tempfile.TemporaryDirectory(prefix='desktop-audit-test-') as directory:
    root = Path(directory)
    bins = root / 'bin'; bins.mkdir()
    fakehome = root / 'home'; fakehome.mkdir()
    env = dict(os.environ, HOME=str(fakehome), PATH=str(bins)+':'+os.environ['PATH'], XDG_RUNTIME_DIR=str(root), TEST_ROOT=str(root))
    log = root / 'log'
    def mock(name, body):
        p = bins / name
        p.write_text('#!/bin/bash\n'+body+'\n'); p.chmod(0o755)
    def run(relative, extra=None, ok=True):
        result = subprocess.run(['bash', str(source(relative))], env=env | (extra or {}), capture_output=True, text=True, timeout=8)
        assert (result.returncode == 0) == ok, result
        return result
    def lines():
        return log.read_text().splitlines() if log.exists() else []
    mock('notify-send', 'echo "notify $*" >> "$TEST_ROOT/log"')
    mock('pkill', 'echo stopped >> "$TEST_ROOT/log"')
    mock('waybar', 'echo launched >> "$TEST_ROOT/log"')
    mock('rofi', '''input=$(cat)
if [[ "$*" == *"Select Waybar Layout"* ]]; then
 printf '%s\\n' "$input" > "$TEST_ROOT/layouts"
 echo "$PICK"
else
 echo '2. Waybar'
fi''')
    layouts = root / 'layouts-real'; layouts.mkdir()
    config = fakehome / '.config'; config.mkdir()
    (config / 'waybar').symlink_to(layouts)
    for name in ('Original', 'Valid', 'Incomplete'):
        (layouts / name).mkdir()
        (layouts / name / 'config.jsonc').write_text('{}')
        if name != 'Incomplete': (layouts / name / 'style.css').write_text('')
    for name in ('config.jsonc', 'style.css'):
        (layouts / name).symlink_to('Original/'+name)
    for choice in ('Missing', '../Valid', 'Incomplete'):
        log.unlink(missing_ok=True)
        run('.scripts/configs.sh', {'PICK': choice}, ok=False)
        assert 'stopped' not in lines() and 'launched' not in lines(), lines()
        for name in ('config.jsonc', 'style.css'):
            assert (layouts / name).resolve() == layouts / 'Original' / name
    log.unlink(missing_ok=True)
    run('.scripts/configs.sh', {'PICK': ''})
    assert not lines()
    run('.scripts/configs.sh', {'PICK': 'Valid'})
    assert 'Valid' in (root / 'layouts').read_text().splitlines()
    for name in ('config.jsonc', 'style.css'):
        assert (layouts / name).resolve() == layouts / 'Valid' / name
    assert 'stopped' in lines() and 'launched' in lines(), lines()
    print('PASS symlinked layout discovery, valid selection, cancellation, invalid and incomplete presets')

    mock('systemctl', '''echo "systemctl $*" >> "$TEST_ROOT/log"
case "$2" in
 is-active) [[ -e "$TEST_ROOT/active" ]];;
 show) echo 4321;;
 stop) [[ "${FAIL_STOP:-0}" == 0 ]] || exit 1; rm -f "$TEST_ROOT/active";;
 *) exit 1;;
esac''')
    mock('systemd-run', '''echo "systemd-run $*" >> "$TEST_ROOT/log"
[[ "${FAIL_START:-0}" == 0 ]] || exit 1
touch "$TEST_ROOT/active"''')
    mock('gamemoded', '''echo "gamemoded $*" >> "$TEST_ROOT/log"
if [[ "${REGISTERED:-1}" == 1 ]]; then echo 'gamemode is active and [4321] registered'; else echo 'gamemode is active but [4321] not registered'; fi''')
    mock('sleep', 'exit 0')
    log.unlink()
    run('.scripts/gamemode-toggle.sh')
    assert any('--request' in line and 'KillSignal=SIGINT' in line for line in lines())
    assert any('Manual request enabled' in line for line in lines())
    assert not any('gamemoded.service' in line for line in lines())
    log.unlink()
    run('.scripts/gamemode-toggle.sh')
    assert not (root / 'active').exists()
    assert any('Manual request disabled' in line for line in lines())
    for extra in ({'REGISTERED':'0'}, {'FAIL_START':'1'}):
        log.unlink()
        run('.scripts/gamemode-toggle.sh', extra, ok=False)
        assert not (root / 'active').exists()
        assert not any('Manual request enabled' in line for line in lines())
    (root / 'active').touch(); log.unlink()
    run('.scripts/gamemode-toggle.sh', {'FAIL_STOP':'1'}, ok=False)
    assert not any('Manual request disabled' in line for line in lines())
    print('PASS owned GameMode request, registration check, enable/disable failures; daemon untouched')

    mock('hyprctl', 'printf "%s\\n" "$@" > "$TEST_ROOT/dispatch"')
    decoder=json.JSONDecoder(); text=source('.config/wlogout/layout').read_text()
    while text.strip():
        entry, end=decoder.raw_decode(text.lstrip()); text=text.lstrip()[end:]
        if entry['label']=='logout':
            result=subprocess.run(['sh','-c',entry['action']],env=env,capture_output=True,timeout=3)
            assert result.returncode==0
            assert (root/'dispatch').read_text().splitlines()==['dispatch','hl.dsp.exit()']
    run('.scripts/fullscreen_toggle.sh')
    assert (root/'dispatch').read_text().splitlines()==['dispatch','hl.dsp.window.fullscreen({ action = "toggle" })']
    print('PASS logout and fullscreen pass each Lua action as one argument')

    # Exercise commands extracted from the actual active bindings, not just unused helpers.
    mock('wpctl', '''echo "wpctl $*" >> "$TEST_ROOT/log"
if [[ "$1" == get-volume ]]; then echo 'Volume: 0.5 [MUTED]'; fi''')
    mock('swayosd-client', 'echo "osd $*" >> "$TEST_ROOT/log"')
    mock('sudo', 'cat >/dev/null')
    mock('brightnessctl', 'exit 0')
    scriptdir=fakehome/'.scripts'; scriptdir.mkdir()
    for helper in ('audio-mute-toggle.sh','mic-toggle.sh'):
        p=scriptdir/helper;p.write_text((home/'.scripts'/helper).read_text());p.chmod(0o755)
    bindings=source('.config/hypr/keybinds.lua').read_text()
    for key,device in [('XF86AudioMute','SINK'),('XF86AudioMicMute','SOURCE')]:
        command=re.search(r'hl.bind\("'+key+r'",\s*hl.dsp.exec_cmd\("([^"]+)"\)',bindings)[1]
        log.unlink()
        result=subprocess.run(['bash','-c',command],env=env,capture_output=True,text=True,timeout=3)
        assert result.returncode==0,result
        assert lines()[:2]==[f'wpctl set-mute @DEFAULT_AUDIO_{device}@ toggle',f'wpctl get-volume @DEFAULT_AUDIO_{device}@'],lines()
        assert lines()[2].startswith('osd --custom-message '),lines()
    print('PASS actual mute bindings use synchronous helpers before OSD')
