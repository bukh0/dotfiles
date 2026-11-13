"""Preserve notification line breaks while retaining safe StyledText markup."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from qt_tools import qmltestrunner
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-body-') as directory:
    p = Path(directory)
    shutil.copy(root/'components/NotificationBody.js', p)
    (p/'tst_body.qml').write_text('''import QtQuick
import QtTest
import "NotificationBody.js" as Body
Item {
 Text { id: body; width: 500; textFormat: Text.StyledText; wrapMode: Text.Wrap }
 TestCase {
  name: "NotificationBody"; when: windowShown
  function test_lineBreaks() {
   body.text = Body.styled("First\\nSecond")
   tryCompare(body, "lineCount", 2)
   body.text = Body.styled("First\\r\\n\\r\\nThird")
   tryCompare(body, "lineCount", 3)
   compare(Body.styled("<b>First\\nSecond</b><br>Third"), "<b>First<br>Second</b><br>Third")
  }
  function test_markupSafety() {
   compare(Body.styled('<a href="https://example.com">One\\nTwo</a>'), '<a href="https://example.com">One<br>Two</a>')
   compare(Body.styled('<a href="javascript:alert(1)">bad</a>'), 'bad')
   compare(Body.styled('<img src="https://example.com/image">safe\\n<script>'), 'safe<br>&lt;script&gt;')
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', directory],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stdout+result.stderr
print('PASS multiline StyledText, CRLF, blank lines, safe links and markup')
