"""Exercise MusicService model/index publication with a synthetic MPRIS source."""
import os
from pathlib import Path
import subprocess
import tempfile
from qt_tools import qmltestrunner
from harness import stub_mpris

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="music-sync-") as directory:
    root = Path(directory)
    stub_mpris(root)
    source = (ROOT / "components/MusicService.qml").read_text()
    (root / "MusicService.qml").write_text(source)
    (root / "qmldir").write_text("singleton MusicService 1.0 MusicService.qml\n")
    (root / "tst_music.qml").write_text("""
import QtQuick
import QtTest
import "." as Config
TestCase {
    id: test
    name: "MusicSynchronization"
    property var changes: []
    property bool observing: false
    function player(name, status) {
        return {dbusName: name, identity: name, playbackState: status || 2}
    }
    function modelNames() {
        const names = []
        for (let i = 0; i < Config.MusicService.model.count; i++)
            names.push(Config.MusicService.model.get(i).player)
        return names
    }
    Connections {
        target: Config.MusicService
        function onSelectedIndexChanged() {
            if (!test.observing) return
            const service = Config.MusicService
            test.changes.push({index: service.selectedIndex, names: test.modelNames(),
                               selected: service.selectedPlayer})
        }
    }
    function init() {
        observing = false
        Config.MusicService.sourcePlayers = [player("a"), player("b"), player("c")]
        Config.MusicService.selectedPlayer = "b"
        changes = []
        observing = true
    }
    function verifyPublications() {
        for (const change of changes) {
            compare(change.names, modelNames(), "index must be published after model updates")
            if (change.names.length)
                compare(change.names[change.index], change.selected)
            else compare(change.index, 0)
        }
    }
    function test_playbackChangesKeepPageOrder() {
        Config.MusicService.sourcePlayers = [player("a"), player("b"), player("c", 1)]
        compare(Config.MusicService.selectedPlayer, "b")
        compare(Config.MusicService.selectedIndex, 1)
        compare(modelNames(), ["a", "b", "c"])
        compare(changes.length, 0)
        verifyPublications()
    }
    function test_filterPlayerctldProxy() {
        Config.MusicService.sourcePlayers = [player("org.mpris.MediaPlayer2.playerctld"), player("a")]
        compare(modelNames(), ["a"])
    }
    function test_removeSelected() {
        Config.MusicService.sourcePlayers = [player("a"), player("c")]
        compare(Config.MusicService.selectedPlayer, "a")
        compare(Config.MusicService.selectedIndex, 0)
        compare(changes.length, 1)
        verifyPublications()
    }
    function test_empty() {
        Config.MusicService.sourcePlayers = []
        compare(Config.MusicService.selectedPlayer, "")
        compare(Config.MusicService.selectedIndex, 0)
        compare(changes.length, 1)
        verifyPublications()
    }
    function test_userSelectionImmediate() {
        Config.MusicService.selectedPlayer = "c"
        compare(Config.MusicService.selectedIndex, 2)
        compare(changes.length, 1)
        verifyPublications()
    }
    function test_missingTitles() {
        for (const state of [0, 1, 2]) {
            Config.MusicService.sourcePlayers = [{dbusName: "mpv", identity: "mpv",
                playbackState: state, trackTitle: ""}]
            compare(Config.MusicService.model.get(0).title, state === 0 ? "Nothing playing" : "Unknown track")
        }
        Config.MusicService.sourcePlayers = [{dbusName: "mpv", playbackState: 1, trackTitle: "Live stream"}]
        compare(Config.MusicService.model.get(0).title, "Live stream")
    }
    function test_metadataKeepsIndex() {
        const rows = [player("a"), player("b"), player("c")]
        rows[1].trackTitle = "New title"
        Config.MusicService.sourcePlayers = rows
        compare(Config.MusicService.model.get(1).title, "New title")
        compare(Config.MusicService.selectedIndex, 1)
        compare(changes.length, 0)
    }
}
""")
    env = dict(os.environ, QML_IMPORT_PATH=str(root), QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    result = subprocess.run([qmltestrunner(), "-input", str(root / "tst_music.qml")],
                            env=env, capture_output=True, text=True, timeout=15)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
