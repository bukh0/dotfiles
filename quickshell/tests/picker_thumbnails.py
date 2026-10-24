"""Early thumbnail completion survives listing races and retries Qt's image cache."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='picker-thumbnails-') as directory:
    root = Path(directory)
    picker = root / 'picker'
    picker.mkdir()
    for name in ("PlainToolTip.qml", 'PickerView.qml', 'qmldir', 'Colors.qml'):
        shutil.copyfile(ROOT / 'picker' / name, picker / name)
    thumb = root / 'thumb #?&.svg'
    engine = root / 'engine'
    engine.write_text('''#!/usr/bin/env python3
import pathlib, sys, time
root = pathlib.Path(__file__).parent
thumb = root / 'thumb #?&.svg'
if sys.argv[1] == '--list-walls':
    time.sleep(0.5)
    print('/wall.png\\t' + str(thumb))
elif sys.argv[1] == '--thumbs':
    time.sleep(0.1)
    thumb.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="red"/></svg>')
    print(thumb)
''')
    engine.chmod(0o755)
    (root / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
 id: owner
 property bool early: false
 property bool failed: false
 function check(ok, message) { if (!ok) { failed = true; console.error("FAIL", message) } }
 function images(item) {
  let found = []
  for (const child of item.children || []) {
   if (String(child).startsWith("QQuickImage")) found.push(child)
   found = found.concat(images(child))
  }
  return found
 }
 Window {
  visible: true; width: 560; height: 600
  // Prime the cache with a missing image before the helper writes it.
  Image { id: missing; source: view.fileUrl(THUMB_PATH) }
  PickerView { id: view; anchors.fill: parent; bin: ENGINE
   onThumbnailReady: path => { if (view.walls.length === 0) owner.early = true }
  }
 }
 Timer { interval: 40; running: true; onTriggered: view.switchPage("Wallpapers") }
 Timer { interval: 900; running: true; onTriggered: {
  check(early, "fixture did not deliver thumbnail before listing")
  check(view.thumbUrl("/wall.png").endsWith("?retry=1"), "early completion lost")
  check(images(view).some(img => img.status === Image.Ready), "query URL did not reload local thumbnail")
  view.thumbnailReady(THUMB_PATH)
 } }
 Timer { interval: 1100; running: true; onTriggered: {
  check(view.thumbUrl("/wall.png").endsWith("?retry=2"), "repeat completion lost")
  check(images(view).some(img => img.status === Image.Ready), "repeat local thumbnail failed")
  view.thumbnails = ({})
  check(view.thumbUrl("/wall.png") === "", "missing mapping produced a relative query URL")
  console.log(failed ? "THUMBNAILS FAILED" : "THUMBNAILS PASS")
  Qt.quit()
 } }
}
'''.replace('THUMB_PATH', json.dumps(str(thumb))).replace('ENGINE', json.dumps(str(engine))))
    result = subprocess.run(['quickshell', '-p', str(root / 'shell.qml')],
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
                            capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'THUMBNAILS PASS' in output and 'FAIL' not in output, output
    print('PASS early completions, local query URLs, cache retry, and empty thumbnail mappings')
