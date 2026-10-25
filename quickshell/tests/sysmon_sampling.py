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
    for name in ['stat', 'meminfo', 'net/dev', 'cpuinfo']:
        source = source.replace('"/proc/' + name + '"', '"' + str(p / name.replace('/', '-')) + '"')
    (p / 'cpuinfo').write_text('model name: Fixture\x1fCPU\n')
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
        stderr=subprocess.PIPE, text=True, env=dict(os.environ, XDG_CACHE_HOME=directory))
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            def sample():
                assert selector.select(4), 'missing sample'
                return proc.stdout.readline().rstrip('\n').split('\x1f')
            first = sample()
            assert len(first) == 11 and first[3].endswith('Fixture CPU'), first
            assert first[0] == '20%' and first[7] == '45°C', first
            update(1499, 1501, 501, 81000)
            second = sample()
            expected = '50%'
            assert second[0] == expected and second[2] == expected and second[7:9] == ['81°C', '1'], second
            update(1500, 1501, 990, 40000)
            third = sample()
            assert third[0] == '1%' and third[2] == '100%' and third[7:9] == ['40°C', '0'], third
        with selectors.DefaultSelector() as errors:
            errors.register(proc.stderr, selectors.EVENT_READ)
            def expect_error():
                assert errors.select(4), 'missing read error'
                assert 'failed to read' in proc.stderr.readline()
            def resumed():
                with selectors.DefaultSelector() as output:
                    output.register(proc.stdout, selectors.EVENT_READ)
                    assert output.select(4), 'no recovery sample'
                    row = proc.stdout.readline().rstrip('\n').split('\x1f')
                    assert len(row) == 11, ('daemon exited after a transient read', proc.poll())
                    return row
            # The failed RAM sample must not advance the CPU baseline.
            update(1600, 1501, 1200, 40000)
            expect_error()
            update(2000, 2001, 500, 40000)
            assert resumed()[2] == '50%'
            # A truncated CPU record is invalid too, even with the cpu prefix.
            (p / 'stat').write_text('cpu 1\n')
            expect_error()
            update(2500, 2501, 500, 40000)
            assert resumed()[2] == '50%'
            (p / 'net-dev').write_text('')
            expect_error()
            (p / 'net-dev').write_text('header\nheader\nlo: 0 0 0 0 0 0 0 0 0\n')
            assert len(resumed()) == 11
        print('PASS transient CPU/RAM/network read failures preserve the process and recover')
        print('PASS repeated partial reads refresh CPU/RAM/temperature and percentages round correctly')
    finally:
        proc.terminate(); proc.wait(timeout=5)
