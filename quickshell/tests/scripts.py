#!/usr/bin/env python3
"""Regression checks with a temporary HOME and mocked desktop commands."""
import os
from pathlib import Path
import subprocess
import tempfile
import shutil

# Override these paths to validate staged replacements before installation.
SCRIPTS = Path(os.environ.get('REVIEW_SCRIPTS_DIR', str(Path.home()/'.scripts')))
BACKUP = Path(os.environ.get('REVIEW_BACKUP_SCRIPT', str(Path.home()/'dotfiles/backup-dotfiles.sh')))
def run(args, env, ok=True, **kwargs):
    r = subprocess.run(args, env=env, text=True, capture_output=True, timeout=20, **kwargs)
    if ok:
        assert r.returncode == 0, (args, r.returncode, r.stdout, r.stderr)
    return r

def mock(directory, name, body):
    p = directory / name
    p.write_text('#!/bin/bash\n' + body + '\n')
    p.chmod(0o755)

with tempfile.TemporaryDirectory(prefix='script-regressions-') as directory:
    root = Path(directory)
    bins = root/'bin'; bins.mkdir()
    runtime = root/'runtime'; runtime.mkdir()
    home = root/'home'; home.mkdir()
    env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(root/'cache'), PATH=str(bins)+os.pathsep+os.environ['PATH'], TEST_ROOT=str(root))
    mock(bins, 'hyprctl', 'cat "$TEST_ROOT/window.json"')
    mock(bins, 'pkill', 'echo signal >> "$TEST_ROOT/signals"')
    for value in (1, 1, 0, 0):
        (root/'window.json').write_text('{"fullscreen":'+str(value)+'}')
        run(['bash',str(SCRIPTS/'fullscreen_toggle.sh')],env)
    assert (root/'signals').read_text().splitlines() == ['signal','signal']
    assert not (runtime/f'waybar-hidden-{os.getuid()}').exists()
    (root/'window.json').write_text('invalid-json')
    assert run(['bash',str(SCRIPTS/'fullscreen_toggle.sh')],env,False).returncode != 0
    print('PASS fullscreen enter/leave, idempotence, invalid JSON')
    mock(bins, 'sudo', 'exit 0')
    mock(bins, 'notify-send', 'exit 0')
    cache = root/'cache'; cache.mkdir()
    for text in ('', 'performance'):
        (cache/'perf-mode').write_text(text)
        run(['bash',str(SCRIPTS/'toggle-performance.sh')],env)
        assert (cache/'perf-mode').read_text().strip() == ('performance' if text=='' else 'powersave')
    print('PASS empty and unterminated power-profile state')
    repo = home/'dotfiles'; repo.mkdir()
    run(['git','init','-q',str(repo)],env)
    run(['git','-C',str(repo),'config','user.email','test@example.invalid'],env)
    run(['git','-C',str(repo),'config','user.name','Test'],env)
    (repo/'.scripts').mkdir()
    (repo/'.scripts/helper.sh').write_text('old\n')
    shutil.copy2(BACKUP,repo/'backup-dotfiles.sh')
    (repo/'unrelated').write_text('old\n')
    run(['git','-C',str(repo),'add','.'],env)
    run(['git','-C',str(repo),'commit','-qm','fixture'],env)
    (home/'.scripts').symlink_to(repo/'.scripts',target_is_directory=True)
    (repo/'.scripts/helper.sh').write_text('new\n')
    (repo/'.scripts/new.py').write_text('print(1)\n')
    (repo/'.scripts/test.d').write_text('dependency\n')
    (repo/'.scripts/.zsh_history').write_text('private\n')
    (repo/'unrelated').write_text('leave me unstaged\n')
    config = home/'.config/quickshell'; config.mkdir(parents=True)
    (config/'shell.qml').write_text('// fixture\n')
    (config/'link.qml').symlink_to('shell.qml')
    r = run(['bash',str(repo/'backup-dotfiles.sh')],env)
    staged = run(['git','-C',str(repo),'diff','--cached','--name-only'],env).stdout.splitlines()
    assert '.scripts/helper.sh' in staged and '.scripts/new.py' in staged, staged
    assert 'unrelated' not in staged and not any(x.endswith(('.d','.zsh_history')) for x in staged), staged
    assert (repo/'quickshell/link.qml').is_symlink()
    assert run(['bash',str(repo/'backup-dotfiles.sh'),'--push'],env,False).returncode == 1
    assert 're-run with --push' not in r.stdout
    print('PASS backup script staging, history/build exclusions, symlinks, unrelated-change isolation, staged-change guard')
