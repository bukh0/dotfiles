"""Small shared helpers for isolated config regressions."""
import json
from pathlib import Path
import sys


def require_external_files(*paths):
    missing = [str(path) for path in paths if not Path(path).is_file()]
    if missing:
        print('SKIP missing external integration: ' + ', '.join(missing))
        sys.exit(77)


def stub_colors(path):
    palette = json.loads((Path(__file__).resolve().parents[1] / 'components/colors.json').read_text())
    Path(path).write_text('pragma Singleton\nimport QtQuick\nQtObject {\n' + ''.join(
        f' property color {key}: {json.dumps(value)}\n' for key, value in palette.items()) + ''.join(f' readonly property color {name}: Qt.alpha({base}, {alpha})\n' for name, base, alpha in [('muted','surfaceFg',.6),('faint','surfaceFg',.4),('hover','surfaceFg',.08),('press','surfaceFg',.14),('hairline','outline',.2)]) + '}\n')
