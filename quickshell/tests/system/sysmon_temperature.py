"""Recover from missing, invalid and replaced temperature nodes without restart."""
import os
from pathlib import Path
import selectors
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-temperature-') as directory:
    node = Path(directory) / 'temp'
    process = subprocess.Popen([str(ROOT / 'native/sysmon'), str(node)],
                               stdout=subprocess.PIPE, text=True,
                               env=dict(os.environ, XDG_CACHE_HOME=directory))
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            def sample():
                assert selector.select(5), 'No sysmon sample'
                fields = process.stdout.readline().rstrip('\n').split('\x1f')
                assert len(fields) == 11, fields
                return fields[7]
            assert sample() == 'N/A'
            node.write_text('42000\n')
            assert sample() == '42°C'
            replacement = node.with_suffix('.new')
            replacement.write_text('57000\n')
            replacement.replace(node)
            assert sample() == '57°C', 'Kept the old open inode'
            node.write_text('invalid\n')
            assert sample() == 'N/A'
            node.write_text('45000\n')
            assert sample() == '45°C'
        print('PASS temperature node recovery and replacement')
    finally:
        process.terminate()
        process.wait(timeout=5)
