"""Partial buffered reads must refresh CPU, memory and temperature each sample."""
from pathlib import Path
import os
import selectors
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-sysmon-sampling-') as directory:
    p = Path(directory)
    source = (ROOT / 'native/sysmon.cpp').read_text()
    for name in ['stat', 'meminfo', 'net/dev']:
        source = source.replace('"/proc/' + name + '"', '"' + str(p / name.replace('/', '-')) + '"')
    (p / 'sysmon.cpp').write_text(source)
    subprocess.run(['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', '-Wpedantic', '-o', str(p / 'sysmon'), str(p / 'sysmon.cpp')], check=True)
    (p / 'net-dev').write_text('header\nheader\nlo: 0 0 0 0 0 0 0 0 0\n')
    def update(user, idle, available, temperature):
        # Rewrite the same inode; leave unread buffered data after each parsed value.
        (p / 'stat').write_text(f'cpu {user} 0 0 {idle} 0 0 0 0 0 0\ncpu0 1 2 3 4\n')
        (p / 'meminfo').write_text(f'MemTotal: 1000 kB\nMemAvailable: {available} kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\nCached: 123 kB\n')
        (p / 'temperature').write_text(str(temperature) + '\n')
    update(1000, 1000, 800, 45000)
    proc = subprocess.Popen([str(p / 'sysmon'), str(p / 'temperature')], stdout=subprocess.PIPE,
        text=True, env=dict(os.environ, XDG_CACHE_HOME=directory))
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            def sample():
                assert selector.select(4), 'missing sample'
                return proc.stdout.readline().rstrip('\n').split('\x1f')
            first = sample()
            assert first[0] == '20%' and first[7] == '45°C', first
            update(1499, 1501, 501, 81000)
            second = sample()
            expected = '50%'
            assert second[0] == expected and second[2] == expected and second[7:9] == ['81°C', '1'], second
            update(1500, 1501, 990, 40000)
            third = sample()
            assert third[0] == '1%' and third[2] == '100%' and third[7:9] == ['40°C', '0'], third
        print('PASS repeated partial reads refresh CPU/RAM/temperature and percentages round correctly')
    finally:
        proc.terminate(); proc.wait(timeout=5)
