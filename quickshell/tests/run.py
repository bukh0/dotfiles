#!/usr/bin/env python3
"""Run the regression suites actually present in this checkout."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('suites', nargs='*')
parser.add_argument('--all', action='store_true')
parser.add_argument('--list', action='store_true')
args = parser.parse_args()
suites = {}
for directory, prefix in ((root / 'tests', ''), (root / 'clipboard/tests', 'clipboard_')):
    for path in sorted(directory.rglob('test_*.py')):
        name = prefix + path.stem.removeprefix('test_')
        if name in suites:
            raise SystemExit('Duplicate suite: ' + name)
        suites[name] = path
if args.list:
    print('\n'.join(suites))
    raise SystemExit(0)
unknown = set(args.suites) - suites.keys()
if unknown:
    parser.error('Unknown suites: ' + ', '.join(sorted(unknown)))
selected = args.suites or list(suites)
env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1',
           PYTHONPATH=str(root / 'tests') + os.pathsep + os.environ.get('PYTHONPATH', ''))
passed = skipped = failed = 0
for name in selected:
    try:
        result = subprocess.run([sys.executable, str(suites[name])], env=env,
                                text=True, capture_output=True, timeout=90)
        if result.returncode == 77:
            skipped += 1
            print('SKIP', name, result.stdout.strip(), flush=True)
        elif result.returncode:
            failed += 1
            print('FAIL', name, '\n' + result.stdout + result.stderr, flush=True)
        else:
            passed += 1
            print('PASS', name, flush=True)
    except subprocess.TimeoutExpired:
        failed += 1
        print('FAIL', name, '(timed out)', flush=True)
print(f'{passed} passed; {skipped} skipped; {failed} failed')
raise SystemExit(bool(failed))
