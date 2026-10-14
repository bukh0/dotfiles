"""Check real sysmon parsing with USB tethering and excluded tunnel counters."""
from pathlib import Path
import os
import selectors
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-sysmon-network-') as directory:
    p = Path(directory)
    counters = p / 'net-dev'
    source = (ROOT / 'native/sysmon.cpp').read_text().replace('"/proc/net/dev"', '"' + str(counters) + '"')
    (p / 'sysmon.cpp').write_text(source)
    subprocess.run(['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', '-Wpedantic', '-o', str(p / 'sysmon'), str(p / 'sysmon.cpp')], check=True)
    def write_interfaces(entries):
        counters.write_text('Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets\n' +
            ''.join(f'{name}: {value} 0 0 0 0 0 0 0 {value} 0 0 0 0 0 0 0\n'
                    for name, value in entries))
    def write(usb, tunnel):
        write_interfaces([('usb0', usb), ('lo', tunnel), ('wg0', tunnel), ('tun0', tunnel)])
    write(1000, 1000)
    process = subprocess.Popen([str(p / 'sysmon'), 'none'], env=dict(os.environ, XDG_CACHE_HOME=directory), stdout=subprocess.PIPE, text=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            def sample():
                assert selector.select(4), 'sysmon did not produce a sample'
                return process.stdout.readline().rstrip('\n').split('\x1f')
            assert sample()[4:6] == ['0 B/s', '0 B/s']
            write(101000, 1001000)
            usb_sample = sample()
            assert all(value.endswith(' K/s') for value in usb_sample[4:6]), usb_sample
            write(101000, 2001000)
            assert sample()[4:6] == ['0 B/s', '0 B/s'], 'Loopback/tunnel traffic was double-counted'
            # Joining interfaces contribute no historic counters.
            write_interfaces([('usb0', 101000), ('wlan0', 100000000)])
            assert sample()[4:6] == ['0 B/s', '0 B/s'], 'New interface created a spike'
            # Removing USB must not conceal the surviving Wi-Fi traffic.
            write_interfaces([('wlan0', 100100000)])
            assert all(v.endswith(' K/s') for v in sample()[4:6]), 'Unplug concealed live traffic'
            write_interfaces([('wlan0', 100200000), ('usb0', 9000000000)])
            assert all(v.endswith(' K/s') for v in sample()[4:6]), 'Reattached USB created a spike'
            write_interfaces([('usb0', 0), ('wlan0', 100300000)])
            assert all(v.endswith(' K/s') for v in sample()[4:6]), 'Reset counters concealed another interface'
            write_interfaces([('usb0', 100000), ('wlan0', 100300000)])
            assert all(v.endswith(' K/s') for v in sample()[4:6]), 'Reset interface did not recover'
        print('PASS: USB, tunnel exclusion, interface addition/removal, reset and recovery')
    finally:
        process.terminate()
        process.wait(timeout=5)
