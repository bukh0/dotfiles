"""Missing desktop sources skip clearly; present but broken sources still fail."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-missing-integrations-') as directory:
    env = dict(os.environ, HOME=directory, PICKER_TEST_LAUNCHER=directory + '/picker-menu.sh',
               REVIEW_SCRIPTS_DIR=directory)
    result = subprocess.run([sys.executable, str(ROOT / 'tests/run.py'), 'picker_launcher', 'wallpaper_paths'],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.count('SKIP: external integration files unavailable:') == 2, result.stdout
    assert 'Skipped unavailable integrations: picker_launcher, wallpaper_paths' in result.stdout
    assert 'All selected suites passed.' not in result.stdout
    # Every external integration should survive a standalone Quickshell clone.
    other = ['wayclick_cleanup', 'cursor_sync', 'install', 'scripts', 'desktop_capture',
             'desktop_controls', 'desktop_audit', 'theme', 'clipboard_launcher', 'clipboard_store']
    result = subprocess.run([sys.executable, str(ROOT / 'tests/run.py'), *other],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.count('SKIP: external integration files unavailable:') == len(other), result.stdout
    Path(env['PICKER_TEST_LAUNCHER']).write_text('#!/bin/sh\nexit 1\n')
    result = subprocess.run([sys.executable, str(ROOT / 'tests/run.py'), 'picker_launcher'],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode != 0 and 'Failed suites: picker_launcher' in result.stderr
    assert 'SKIP:' not in result.stdout
print('PASS unavailable sources explicitly skip; available broken scripts fail')
