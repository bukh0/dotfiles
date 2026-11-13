import importlib.util
from pathlib import Path
import base64
root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('fixture', root / 'clipboard/tests/test_backend.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
fixture = module.ClipboardTest()
fixture.setUp()
try:
    for text in (b'GIF89a is the six-byte signature used by GIF files.', b'GIF87a', b'GIF89a1234567!', 'GIF89a😀é Unicode text'.encode()):
        ident = fixture.store(text)
        assert module.backend.preview(ident)['text'] == text.decode()
        module.backend.copy(ident)
        assert 'text/plain' in (fixture.path / 'mime').read_text()
    gif = base64.b64decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
    ident = fixture.store(gif)
    assert module.backend.preview(ident)['mime'] == 'image/gif'
    module.backend.copy(ident)
    assert (fixture.path / 'copied').read_bytes() == gif
finally:
    fixture.doCleanups()
