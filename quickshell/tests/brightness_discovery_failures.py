"""Failed backlight discovery must not publish valid-looking or stale stdout."""
import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
for missing_signal in (False, True):
 with tempfile.TemporaryDirectory(prefix='qs-brightness-failures-') as directory:
  p=Path(directory);(p/'mock').mkdir();(p/'mock/brightness').write_text('50\n')
  source=(ROOT/'components/BrightnessService.qml').read_text()
  source=source.replace('id: root','id: root\n    property alias discoveryProcess: discoverProc',1)
  source=source.replace('"/sys/class/backlight/"',repr(directory+'/')).replace('running: !root.available','running: false')
  if missing_signal:
   source=source.replace('onRunningChanged: if (!running && !started) discoverySettled.restart()', 'onRunningChanged: {}')
  (p/'BrightnessService.qml').write_text(source)
  (p/'qmldir').write_text('singleton BrightnessService 1.0 BrightnessService.qml\n')
  helper=p/'discover'
  helper.write_text('#!/bin/sh\nif [ "$1" = malformed ]; then printf "mock,backlight,50oops,50%%,100\\n"; exit 0; fi\nprintf "mock,backlight,50,50%%,100\\n"\nexit "$1"\n');helper.chmod(0o755)
  (p/'shell.qml').write_text('''import QtQuick
 import Quickshell
 import "."
 ShellRoot {
  property int phase: 0
  property int ticks: 0
  property int quiet: 0
  function beginDiscovery(command) {
   BrightnessService.available=false
   BrightnessService.discoveryProcess.command=command
   quiet=0
   BrightnessService.discover()
  }
  function check(ok,message) { if (!ok) { console.error("DISCOVERY FAIL",message); Qt.quit() }; return ok }
  Timer { interval: 30; repeat:true; running:true
   onTriggered: {
    if (++ticks > 200) { check(false,"timeout"); return }
    if (BrightnessService._discoveryInFlight || BrightnessService.discoveryProcess.running || ++quiet < 3) return
    switch (phase++) {
    case 0: beginDiscovery(["'''+str(helper)+'''", "0"]); break
    case 1:
     if (!check(BrightnessService.available,"successful discovery")) return
     beginDiscovery(["'''+str(helper)+'''", "1"]); break
    case 2:
     if (!check(!BrightnessService.available,"nonzero exit published valid-looking output")) return
     beginDiscovery(["/nonexistent/qs-brightness-discovery"]); break
    case 3:
     if (!check(!BrightnessService.available,"failed spawn reused collector")) return
     beginDiscovery(["'''+str(helper)+'''", "malformed"]); break
    case 4:
     if (!check(!BrightnessService.available,"malformed readings accepted")) return
     beginDiscovery(["'''+str(helper)+'''", "0"]); break
    case 5:
     if (!check(BrightnessService.available && BrightnessService.maxRaw===100,"recovery")) return
     console.log("DISCOVERY PASS"); Qt.quit()
    }
   }
  }
 }
 ''')
  r=subprocess.run(['quickshell','-p',str(p)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory,PATH=directory+':'+os.environ['PATH']),capture_output=True,text=True,timeout=10)
  output=r.stdout+r.stderr
  assert 'DISCOVERY PASS' in output and 'DISCOVERY FAIL' not in output,output
  print('PASS discovery success, nonzero stdout, failed spawn and recovery')
