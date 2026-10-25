"""Cold picker launcher paths: no build when current, rebuild when stale."""
import os
from pathlib import Path
import subprocess
import tempfile

LAUNCHER = Path(os.environ.get('PICKER_TEST_LAUNCHER', str(Path.home()/'.scripts/picker-menu.sh')))
with tempfile.TemporaryDirectory(prefix='picker-launcher-') as d:
    p = Path(d)
    config = p/'config/quickshell/picker'
    config.mkdir(parents=True)
    (config/'shell.qml').touch()
    scripts = p/'.scripts'; scripts.mkdir()
    bins = p/'bin'; bins.mkdir()
    def script(path, body):
        path.write_text('#!/bin/bash\n'+body+'\n'); path.chmod(0o755)
    script(bins/'quickshell', 'printf "qs %s\\n" "$*" >> "$TEST_LOG"\nif [[ $1 == ipc ]]; then exit "${IPC_STATUS:-1}"; fi')
    script(bins/'make', 'echo make >> "$TEST_LOG"')
    engine = scripts/'theme.switcher'
    script(engine, 'exit 0')
    source = scripts/'theme.switcher.cpp'; source.touch()
    makefile = scripts/'makefile'; makefile.touch()
    os.utime(source, (100,100)); os.utime(makefile, (100,100)); os.utime(engine, (200,200))
    log = p/'calls'
    env = dict(os.environ, HOME=d, XDG_CONFIG_HOME=str(p/'config'), XDG_CACHE_HOME=str(p/'cache'), XDG_RUNTIME_DIR=d,
               TEST_LOG=str(log), PATH=str(bins)+':'+os.environ['PATH'])
    def run():
        log.unlink(missing_ok=True)
        subprocess.run(['bash',str(LAUNCHER)],env=env,check=True)
        return log.read_text().splitlines()
    calls = run()
    assert len(calls)==2 and calls[0].endswith('call picker dismiss') and calls[1].startswith('qs -d -n -p '), calls
    os.utime(source,(300,300))
    assert 'make' in run()
    engine.unlink()
    assert 'make' in run()
    env['IPC_STATUS']='0'
    calls=run()
    assert len(calls)==1 and calls[0].endswith('call picker dismiss'), calls
    print('PASS current engine skips make, stale/missing engine builds, existing picker dismisses without launch')
