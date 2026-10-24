"""Regression: destroying the panel does not cancel its password prompt."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests'))
fixture = ROOT / 'tests/focus.py'
source = fixture.read_text()
addition = '  function test_destroyPromptOwner() {\n   const component = Qt.createComponent("ControlPanel.qml")\n   compare(component.status, Component.Ready)\n   const owner = component.createObject(parent, {width:800, height:600, outputName:"unplugged", isOpen:true})\n   NetworkService.awaitingPasswordScreen = "unplugged"\n   NetworkService.awaitingPasswordFor = "Test wifi"\n   owner.destroy()\n   wait(20)\n   compare(NetworkService.awaitingPasswordFor, "", "destroyed output must release its password prompt")\n  }\n'
source = source.replace('  function test_musicArtworkPath() {', addition + '  function test_musicArtworkPath() {')
exec(compile(source, str(fixture), 'exec'), {'__file__': str(fixture), '__name__': '__main__'})
