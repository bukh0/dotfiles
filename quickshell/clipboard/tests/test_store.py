import os,subprocess,tempfile
from pathlib import Path
script=os.environ.get('CLIPBOARD_STORE_SCRIPT', str(Path.home()/'.scripts/clipboard-store.sh'))
with tempfile.TemporaryDirectory() as d:
 p=Path(d)
 (p/'wl-paste').write_text('#!/bin/sh\nprintf "%s\\n" "$TEST_TYPES"\n')
 (p/'cliphist').write_text('#!/bin/sh\ncat > "$TEST_ROOT/stored"\n')
 for f in p.iterdir():f.chmod(0o755)
 env=dict(os.environ,PATH=d+os.pathsep+os.environ['PATH'],TEST_ROOT=d,TEST_TYPES='text/plain')
 for state,types,expected in [('data','text/plain',True),('sensitive','text/plain',False),('data','text/plain\nx-kde-passwordManagerHint',False),('nil','text/plain',False)]:
  (p/'stored').unlink(missing_ok=True)
  subprocess.run(['bash',script],input=b'fixture',env=dict(env,CLIPBOARD_STATE=state,TEST_TYPES=types),check=True)
  assert (p/'stored').exists()==expected
 print('PASS clipboard sensitive-state and password-manager MIME exclusions')
