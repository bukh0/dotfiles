"""Real staged clipboard changes trigger the direct Git hook; unrelated files do not."""
from pathlib import Path
import re,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
pattern=re.search(r"files: '([^']+)'",(ROOT/'.pre-commit-config.yaml').read_text()).group(1)
assert re.search(pattern,'quickshell/clipboard/backend.py')
assert not re.search(pattern,'unrelated/file')
with tempfile.TemporaryDirectory(prefix='qs-hook-paths-') as directory:
 p=Path(directory);(p/'quickshell/tests').mkdir(parents=True)
 (p/'quickshell/tests/run.py').write_text('from pathlib import Path\nPath("called").touch()\n')
 subprocess.run(['git','init','-q',directory],check=True)
 def check(path,expected):
  file=p/path;file.parent.mkdir(parents=True,exist_ok=True);file.write_text('fixture\n')
  subprocess.run(['git','add','--',path],cwd=p,check=True)
  subprocess.run([sys.executable,str(ROOT/'tests/pre-commit')],cwd=p,check=True)
  assert (p/'called').exists()==expected
 check('unrelated/file',False)
 check('quickshell/clipboard/backend.py',True)
 print('PASS staged clipboard edits trigger both hook filters')
