#!/usr/bin/env python3
"""Run core regressions, selected suites, or discover all isolated suites."""
import argparse
import os
import sys
from pathlib import Path
# Keep test imports and child interpreters from leaving bytecode in the config.
sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
from harness import run_suite

HERE = Path(__file__).resolve().parent
LIVE = {'profile_load', 'wayland_surfaces'}
DEFAULT = ['core', 'focus', 'music_sync', 'network_cancel', 'volume_sink', 'prompt_owner', 'picker_cancel', 'picker_screen', 'plain_tooltip', 'brightness_discovery_failures', 'network_monitor_queue', 'clipboard_backend', 'clipboard_service', 'clipboard_ui']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('suites', nargs='*', help='suite names without .py')
parser.add_argument('--all', action='store_true', help='discover all isolated suites')
parser.add_argument('--live', action='store_true', help='also allow suites that create desktop surfaces')
parser.add_argument('--list', action='store_true', help='list available suites without running')
args = parser.parse_args()
available = {}
for path in sorted(HERE.glob('*/*.py')):
    if path.stem in available:
        parser.error(f'Duplicate suite name: {path.stem}')
    available[path.stem] = path
available.update({'clipboard_' + p.stem.removeprefix('test_'): p
                  for p in (HERE.parent / 'clipboard/tests').glob('test_*.py')})
if args.list:
    for name in sorted(available):
        print(name + (' (requires --live)' if name in LIVE else ''))
    raise SystemExit(0)
selected = args.suites or (sorted(available) if args.all else DEFAULT)
failures = []
for name in selected:
    if name not in available:
        parser.error(f'Unknown suite: {name}')
    if name in LIVE and not args.live:
        if args.suites:
            parser.error(f'{name} requires --live')
        continue
    if not run_suite(available[name]):
        failures.append(name)
if failures:
    raise SystemExit('Failed suites: ' + ', '.join(failures))
print('All selected suites passed.')
