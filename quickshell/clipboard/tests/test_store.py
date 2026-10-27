import os,subprocess,tempfile
from pathlib import Path
script=os.environ.get('CLIPBOARD_STORE_SCRIPT', str(Path.home()/'.scripts/clipboard-store.sh'))
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tests'))
from harness import require_external_files
require_external_files(script)

with tempfile.TemporaryDirectory() as d:
 p=Path(d)
 (p/'wl-paste').write_text('#!/bin/sh\ntouch "$TEST_ROOT/queried"\nprintf "%s\\n" "$TEST_TYPES"\n')
 (p/'cliphist').write_text('#!/bin/sh\ncat > "$TEST_ROOT/stored"\n')
 for f in p.iterdir():f.chmod(0o755)
 env=dict(os.environ,PATH=d+os.pathsep+os.environ['PATH'],TEST_ROOT=d,XDG_RUNTIME_DIR=d,TEST_TYPES='text/plain')
 # The state belongs to captured stdin; TEST_TYPES represents a newer offer.
 for state,types,expected in [('data','text/plain',True),('sensitive','text/plain',False),('data','text/plain\nx-kde-passwordManagerHint',True),('nil','text/plain',False),('clear','text/plain',False),('unknown','text/plain',False),('', 'text/plain',False),(None,'text/plain',False)]:
  (p/'stored').unlink(missing_ok=True)
  case_env=dict(env,TEST_TYPES=types)
  case_env.pop('CLIPBOARD_STATE',None)
  if state is not None: case_env['CLIPBOARD_STATE']=state
  subprocess.run(['bash',script],input=b'fixture',env=case_env,check=True)
  assert (p/'stored').exists()==expected
  if expected: assert (p/'stored').read_bytes()==b'fixture'
 assert not (p/'queried').exists(), 'storage must not query a different clipboard offer'
 # Large ignored offers must be fully consumed, not cut off by a closed pipe.
 ignored_env=dict(env,CLIPBOARD_STATE='sensitive')
 proc=subprocess.Popen(['bash',script],stdin=subprocess.PIPE,env=ignored_env)
 payload=b'x' * (2 * 1024 * 1024)
 assert proc.stdin.write(payload)==len(payload)
 proc.stdin.close()
 assert proc.wait(timeout=5)==0
 # Concurrent writers must never enter cliphist together.
 (p/'cliphist').write_text('#!/bin/sh\nmkdir "$TEST_ROOT/active" || exit 91\ncat >/dev/null\nsleep 0.1\nrmdir "$TEST_ROOT/active"\n')
 jobs=[subprocess.Popen(['bash',script],stdin=subprocess.PIPE,env=dict(env,CLIPBOARD_STATE='data')) for _ in range(4)]
 for job in jobs:
  job.stdin.write(b'fixture')
  job.stdin.close()
 assert all(job.wait(timeout=5)==0 for job in jobs)
 print('PASS same-offer state filtering, changing clipboard types, and unknown/missing-state exclusion')
