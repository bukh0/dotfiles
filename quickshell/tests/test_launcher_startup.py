"""The launcher accepts a cold start longer than its former ten-second limit."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-startup-') as directory:
    stage = Path(directory)
    shutil.copy(root / 'run.sh', stage)
    profile = stage / 'profiles/default'
    profile.mkdir(parents=True)
    for name in ('shell.qml', 'Theme.qml'):
        (profile / name).write_text('// fixture\n')
    bindir = stage / 'bin'
    bindir.mkdir()
    (bindir / 'make').write_text('#!/bin/sh\nexit 0\n')
    (bindir / 'quickshell').write_text('''#!/usr/bin/env python3
import time
time.sleep(11)
print('Configuration Loaded', flush=True)
time.sleep(60)
''')
    for command in bindir.iterdir():
        command.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CACHE_HOME=directory,
               PATH=str(bindir) + os.pathsep + os.environ['PATH'])
    pidfile = stage / f'quickshell-{os.getuid()}-default.pid'
    try:
        result = subprocess.run(['bash', str(stage / 'run.sh')], env=env, capture_output=True, text=True, timeout=20)
        assert result.returncode == 0, result.stdout + result.stderr
        assert pidfile.exists(), 'Launcher removed a healthy instance PID'
        os.kill(int(pidfile.read_text()), 0)
    finally:
        if pidfile.exists():
            try:
                os.kill(int(pidfile.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass
print('PASS delayed startup retains the healthy shell')
