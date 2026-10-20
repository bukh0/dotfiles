pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell.Services.Mpris

QtObject {
    id: service
    property var sourcePlayers: Mpris.players.values
    property string selectedPlayer: ""
    property int _selectedIndex: 0
    readonly property int selectedIndex: _selectedIndex
    property bool _synchronizing: false
    property ListModel model: ListModel {}
    readonly property var snapshot: sourcePlayers.filter(p => !/^org\.mpris\.MediaPlayer2\.playerctld(?:\.|$)/i.test(p.dbusName)).map(p => ({
        player: p.dbusName,
        playerName: p.identity || p.dbusName,
        title: p.trackTitle || (p.playbackState === MprisPlaybackState.Stopped ? "Nothing playing" : "Unknown track"),
        artist: p.trackArtist || "",
        album: p.trackAlbum || "",
        artUrl: p.trackArtUrl || "",
        status: p.playbackState === MprisPlaybackState.Playing ? "Playing"
            : p.playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped"
    })).sort((a, b) => {
        const spotify = Number(b.playerName.toLowerCase().includes("spotify")) - Number(a.playerName.toLowerCase().includes("spotify"))
        return spotify || a.playerName.localeCompare(b.playerName) || a.player.localeCompare(b.player)
    })
    onSnapshotChanged: synchronize()
    onSelectedPlayerChanged: if (!_synchronizing) updateSelectedIndex()
    function updateSelectedIndex() {
        if (!model) return
        let index = 0
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).player === selectedPlayer) { index = i; break }
        }
        _selectedIndex = index
    }
    function initialize() {} // Touch the singleton once at shell startup.
    function findPlayer(name) { return sourcePlayers.find(p => p.dbusName === name) || null }
    function synchronize() {
        if (!model) return
        const rows = snapshot
        _synchronizing = true
        for (let i = model.count - 1; i >= 0; i--)
            if (!rows.some(p => p.player === model.get(i).player)) model.remove(i)
        for (let i = 0; i < rows.length; i++) {
            let previous = -1
            for (let j = i; j < model.count; j++)
                if (model.get(j).player === rows[i].player) { previous = j; break }
            if (previous < 0) model.insert(i, rows[i])
            else {
                if (previous !== i) model.move(previous, i, 1)
                for (const key of Object.keys(rows[i]))
                    if (model.get(i)[key] !== rows[i][key]) model.setProperty(i, key, rows[i][key])
            }
        }
        // Publish selection only after the rendered model has its final order.
        // Keep the visible player stable across sorting and metadata changes.
        // Once it disappears, remember the replacement rather than snapping back.
        if (!rows.some(p => p.player === selectedPlayer))
            selectedPlayer = rows.length ? rows[0].player : ""
        _synchronizing = false
        updateSelectedIndex()
    }
    Component.onCompleted: synchronize()
}
