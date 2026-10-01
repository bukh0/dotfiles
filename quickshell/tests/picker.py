import os, tempfile, pathlib,subprocess,shutil
ROOT=pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='picker-test-') as d:
 p=pathlib.Path(d);(p/'picker').mkdir();(p/'profiles').mkdir();shutil.copytree(ROOT/'profiles/default',p/'profiles/default');shutil.copytree(ROOT/'profiles/alt',p/'profiles/alt')
 for n in ('PickerView.qml','qmldir','Colors.qml'):shutil.copyfile(ROOT/'picker'/n,p/'picker'/n)
 mock=p/'engine';mock.write_text('''#!/bin/sh
case "$1" in
--list-walls) printf '/tmp/wall.png\\t/tmp/thumb.jpg\\n';;
--list-themes) printf 'Matugen\\n';;
--thumbs) exit 0;;
--apply) printf 'specific apply failure\\n' >&2; exit 1;;
esac
''');mock.chmod(0o755)
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
 Window { visible: true; width: 900; height: 600
  PickerView { id: view; anchors.fill: parent; bin: "'''+str(mock)+'''" }
 }
 Timer { interval: 500; running: true; repeat: true; property int step: 0
  onTriggered: {
   if (step++ === 0) view.apply("Matugen", "/tmp/wall.png")
   else {
    if (view.busy || view.error !== "specific apply failure") console.error("PICKER FAIL", view.error)
    else console.log("PICKER PASS")
    Qt.quit()
   }
  }
 }
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d)
 r=subprocess.run(['quickshell','-p',str(p/'shell.qml')],env=env,capture_output=True,text=True,timeout=10)
 print(r.stdout+r.stderr)
 assert 'PICKER PASS' in r.stdout+r.stderr
