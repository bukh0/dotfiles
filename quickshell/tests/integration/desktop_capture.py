"""Exercise screenshot keybindings and profile indicators without desktop effects."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

SCRIPTS = Path(os.environ.get('REVIEW_SCRIPTS_DIR', str(Path.home() / '.scripts')))
KEYBINDS = Path(os.environ.get('REVIEW_KEYBINDS', str(Path.home() / '.config/hypr/keybinds.lua')))
with tempfile.TemporaryDirectory(prefix='desktop-capture-') as directory:
    root = Path(directory)
    bins = root / 'bin'
    bins.mkdir()
    home = root / 'home'
    home.mkdir()
    cache = root / 'cache'
    cache.mkdir()
    env = dict(os.environ, HOME=str(home), XDG_CACHE_HOME=str(cache),
               PATH=str(bins) + ':' + os.environ['PATH'], TEST_ROOT=str(root))
    def mock(name, body):
        path = bins / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)
    mock('slurp', '[[ ${CANCEL:-0} == 0 ]] || exit 1; printf "%s" "${GEOMETRY-1,2 300x400}"')
    mock('grim', '''printf '%s\\n' "$@" >> "$TEST_ROOT/captures"
[[ ${FAIL_CAPTURE:-0} == 0 ]] || exit 1
printf 'image' > "${@: -1}"''')
    mock('notify-send', 'echo notified >> "$TEST_ROOT/notices"')
    # Pin the timestamp: two captures within one second must not overwrite.
    mock('date', 'echo 20261026-120000')
    source = KEYBINDS.read_text()
    def capture(mode, extra=None):
        if 'screenshot.sh' in source:
            assert 'screenshot.sh region' in source and 'screenshot.sh full' in source
            args = ['bash', str(SCRIPTS / 'screenshot.sh'), mode]
        else:
            commands = re.findall(r"hl\.dsp\.exec_cmd\('(FILE=.*)'\)\)", source)
            command = next(c for c in commands if ('slurp' in c) == (mode == 'region'))
            args = ['bash', '-c', command]
        return subprocess.run(args, env=env | (extra or {}), capture_output=True, text=True, timeout=5)
    for extra in ({'CANCEL': '1'}, {'GEOMETRY': ''}):
        result = capture('region', extra)
        assert not (root / 'captures').exists(), 'cancelled/empty selection still invoked grim'
        assert not (root / 'notices').exists()
    result = capture('full')
    assert result.returncode == 0, result.stderr
    images = list((home / 'Pictures/Screenshots').glob('*.png'))
    assert len(images) == 1 and images[0].read_text() == 'image'
    result = capture('region')
    assert result.returncode == 0, result.stderr
    assert len(list((home / 'Pictures/Screenshots').glob('*.png'))) == 2, 'same-second captures overwrite'
    assert '-g\n1,2 300x400\n' in (root / 'captures').read_text()
    notices = (root / 'notices').read_text()
    result = capture('full', {'FAIL_CAPTURE': '1'})
    assert result.returncode != 0
    assert len(list((home / 'Pictures/Screenshots').glob('*.png'))) == 2
    assert (root / 'notices').read_text() == notices
    print('PASS cancellation, empty selection, directory creation, unique names and capture failure cleanup')
    state = cache / 'perf-mode'
    for value, expected in [('performance', '󰓅'), ('powersave', '󰌪'), ('auto', '󰾅'), ('', '󰾅'), ('unknown', '󰾅')]:
        for suffix in ('', '\n'):
            state.write_text(value + suffix)
            result = subprocess.run(['bash', str(SCRIPTS / 'performance-status.sh')], env=env,
                                    capture_output=True, text=True, timeout=5)
            assert result.stdout.strip() == expected, (value, suffix, result)
    state.unlink()
    result = subprocess.run(['bash', str(SCRIPTS / 'performance-status.sh')], env=env,
                            capture_output=True, text=True, timeout=5)
    assert result.stdout.strip() == '󰾅' and not result.stderr, result
    print('PASS profile indicator for missing, empty, invalid and unterminated state')
