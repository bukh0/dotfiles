"""Queued monitor refreshes drain after coalesced Wi-Fi scans."""
from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-monitor-queue-') as directory:
 p=Path(directory)
 source=(ROOT/'components/NetworkService.qml').read_text().replace('running: true','running: false').replace('Component.onCompleted: root.refresh()', 'Component.onCompleted: {}')
 source=source.replace('id: root','id: root\n    property int scansStarted: 0\n    property int pollsStarted: 0\n    property bool overlapped: false',1)
 source=source.replace('started = true; scanLaunchCheck.stop()', 'started = true; scanLaunchCheck.stop(); root.scansStarted++')
 source=source.replace('started = true; statusLaunchCheck.stop()', 'started = true; statusLaunchCheck.stop(); root.pollsStarted++; root.overlapped = root.overlapped || root.scanning || root._scanPending')
 (p/'NetworkService.qml').write_text(source)
 (p/'qmldir').write_text('singleton NetworkService 1.0 NetworkService.qml\n')
 mock=p/'nmcli';mock.write_text('''#!/bin/sh
case "$*" in
*SSID,SIGNAL,SECURITY*) sleep 0.2; printf 'Test:80:WPA2:no:wlan0\\n';;
'radio wifi') echo enabled;;
esac
''');mock.chmod(0o755)
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: {
  NetworkService.scan()
  NetworkService.scan()
  NetworkService._monitorPending=true
 }
 Timer { interval: 30; running:true; repeat:true; property int ticks:0
  onTriggered: {
   const n=NetworkService
   if (++ticks > 150) {console.error("QUEUE FAIL timeout", n._monitorPending);Qt.quit();return}
   if (n.scansStarted===2 && n.pollsStarted===1 && !n.scanning && !n._monitorPending) {
    console.log(n.overlapped ? "QUEUE FAIL overlapping status" : "QUEUE PASS");Qt.quit()
   }
  }
 }
}
''')
 r=subprocess.run(['quickshell','-p',str(p)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory,PATH=directory+':'+os.environ['PATH']),capture_output=True,text=True,timeout=8)
 output=r.stdout+r.stderr
 assert 'QUEUE PASS' in output and 'QUEUE FAIL' not in output,output
 print('PASS monitor refresh drains after two queued scans without overlapping them')
