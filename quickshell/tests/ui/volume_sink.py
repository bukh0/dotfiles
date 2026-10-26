"""Regression: an old drag changes the replacement audio sink."""
from pathlib import Path
import os, re, subprocess, tempfile
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from qt_tools import qmltestrunner
from harness import stub_colors
with tempfile.TemporaryDirectory(prefix='qs-volume-audit-') as directory:
 p=Path(directory)
 for name in ['VolumeSlider.qml','SliderRow.qml','BaseTheme.qml']:
  source=(ROOT/'components'/name).read_text()
  source=re.sub(r'^import Quickshell.*\n','',source,flags=re.M)
  source=source.replace('id: dragMa','id: dragMa; objectName: "dragArea"')
  (p/name).write_text(source)
 stub_colors(p/'Colors.qml')
 (p/'Theme.qml').write_text('pragma Singleton\nimport QtQuick\nBaseTheme {}\n')
 (p/'Pipewire.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var defaultAudioSink: null }\n')
 (p/'PwObjectTracker.qml').write_text('import QtQuick\nQtObject { property var objects: [] }\n')
 (p/'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\nsingleton Pipewire 1.0 Pipewire.qml\n')
 (p/'tst_volume.qml').write_text('''import QtQuick
import QtTest
import "."
Item {
 width: 600; height: 200
 QtObject { id: firstAudio; property real volume: 0.8; property bool muted: false }
 QtObject { id: secondAudio; property real volume: 0.2; property bool muted: false }
 QtObject { id: firstSink; property var audio: firstAudio }
 QtObject { id: secondSink; property var audio: secondAudio }
 VolumeSlider { id: volume; width: 400; x: 50; y: 50 }
 TestCase {
  name: "SinkChangeDuringDrag"; when: windowShown
  function test_amplifiedVolumeKeepsDragScale() {
   Pipewire.defaultAudioSink = firstSink
   firstAudio.volume = 3.0
   const area = findChild(volume, "dragArea")
   mousePress(area, area.width / 2, area.height / 2)
   wait(100)
   fuzzyCompare(firstAudio.volume, 1.5, 0.02)
   mouseRelease(area, area.width / 2, area.height / 2)
   fuzzyCompare(firstAudio.volume, 1.5, 0.02, "release changed volume without pointer movement")
  }
  function test_oldGestureDoesNotWriteNewSink() {
   Pipewire.defaultAudioSink = firstSink
   const area = findChild(volume, "dragArea")
   verify(!!area)
   mousePress(area, area.width * 0.8, area.height / 2)
   wait(100)
   Pipewire.defaultAudioSink = secondSink
   compare(secondAudio.volume, 0.2)
   mouseMove(area, area.width * 0.9, area.height / 2)
   wait(100)
   compare(secondAudio.volume, 0.2, "movement after abort wrote to new sink")
   mouseRelease(area, area.width * 0.8, area.height / 2)
   compare(secondAudio.volume, 0.2, "release from old sink overwrote replacement sink")
  }
 }
}
''')
 r=subprocess.run([qmltestrunner(),'-input',str(p/'tst_volume.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 print(r.stdout+r.stderr)
 raise SystemExit(r.returncode)
