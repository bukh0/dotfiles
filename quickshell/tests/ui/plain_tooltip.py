"""External labels stay literal when the shared tooltip is reused or updated."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-plain-tooltip-') as directory:
 p=Path(directory)
 shutil.copyfile(ROOT/'components/PlainToolTip.qml',p/'PlainToolTip.qml')
 (p/'tst_tooltip.qml').write_text('''import QtQuick
import QtQuick.Controls
import QtTest
Item {
 width: 500; height: 200
 PlainToolTip { id: tip; text: "<b>SSID & title</b>" }
 PlainToolTip { id: nowrap; textWrapMode: Text.NoWrap }
 TestCase { name:"PlainToolTip"; when:windowShown
  function test_externalText() {
   compare(tip.contentItem.textFormat,Text.PlainText)
   compare(tip.contentItem.text,"<b>SSID & title</b>")
   tip.text="<img src='https://invalid.example/image'>"
   compare(tip.contentItem.text,tip.text)
   compare(tip.contentItem.textFormat,Text.PlainText)
   compare(tip.popupType,Popup.Window)
  }
  function test_wrapping() {
   compare(tip.contentItem.wrapMode,Text.Wrap)
   compare(nowrap.contentItem.wrapMode,Text.NoWrap)
  }
 }
}
''')
 r=subprocess.run([qmltestrunner(),'-input',str(p)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 assert r.returncode==0,r.stdout+r.stderr
 print('PASS literal external text, updates, wrapping and separate popup policy')
