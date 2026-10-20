"""Render plain notification punctuation without losing supported formatting."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from qt_tools import qmltestrunner

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='notification-body-') as directory:
    root = Path(directory)
    shutil.copyfile(ROOT / 'components/NotificationBody.js', root / 'NotificationBody.js')
    (root / 'tst_body.qml').write_text('''import QtQuick
import QtTest
import "NotificationBody.js" as Body
Item {
 Text { id: plain; textFormat: Text.PlainText; font.pixelSize: 16 }
 Text { id: styled; textFormat: Text.StyledText; font.pixelSize: 16 }
 TestCase {
  name: "NotificationBody"
  function test_plainPunctuation() {
   for (const input of ["vector<int>", "user@example.com <User Name>", "a < b && c > d", "unfinished <", "A & B", "<script>alert(1)</script>"]) {
    plain.text = input
    styled.text = Body.styled(input)
    compare(styled.implicitWidth,plain.implicitWidth,input)
    compare(styled.implicitHeight,plain.implicitHeight,input)
   }
  }
  function test_apostropheAndNumericEntities() {
   for (const pair of [["it&apos;s", "it's"], ["it&#39;s", "it's"], ["it&#x27;s", "it's"], ["&#x1f600;", "😀"]]) {
    plain.text = pair[1]
    styled.text = Body.styled(pair[0])
    compare(styled.implicitWidth,plain.implicitWidth,pair[0])
    compare(styled.implicitHeight,plain.implicitHeight,pair[0])
   }
  }
  function test_formattingAndEntities() {
   compare(Body.styled('<b>bold</b> <i>italic</i><br/>A &amp; B'), '<b>bold</b> <i>italic</i><br/>A &amp; B')
   plain.text = '<int> & "quoted"'
   styled.text = Body.styled('&lt;int&gt; &amp; &quot;quoted&quot;')
   compare(styled.implicitWidth,plain.implicitWidth)
   compare(Body.styled('<img alt="a > b" src="https://example.invalid/x"><a href="https://example.invalid">link</a>'), '<a href="https://example.invalid">link</a>')
   compare(Body.styled('<a href="file:///tmp/test">file</a>'), 'file')
   compare(Body.styled('<a href="javascript:alert(1)">bad</a>'), 'bad')
   compare(Body.styled('<a href="https://example.invalid/?a=1&amp;b=2">web</a>'), '<a href="https://example.invalid/?a=1&amp;b=2">web</a>')
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', str(root / 'tst_body.qml')],
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
                            capture_output=True, text=True, timeout=10)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
