pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Resolve alongside the module, including profile/picker symlinks.
    property FileView paletteFile: FileView {
        path: Qt.resolvedUrl("colors.json")
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: palette
            property string primary: "#acc7ff"
            property string primaryFg: "#0d2f5f"
            property string secondary: "#bec6dc"
            property string secondaryFg: "#283041"
            property string tertiary: "#ddbce0"
            property string tertiaryFg: "#3f2844"
            property string surface: "#111318"
            property string surfaceFg: "#e2e2e9"
            property string surfaceContainer: "#1e2025"
            property string surfaceContainerHigh: "#282a2f"
            property string background: "#111318"
            property string outline: "#8e9099"
            property string error: "#ffb4ab"
            property string errorOn: "#690005"
        }
    }

    readonly property color primary: palette.primary
    readonly property color primaryFg: palette.primaryFg
    readonly property color secondary: palette.secondary
    readonly property color secondaryFg: palette.secondaryFg
    readonly property color tertiary: palette.tertiary
    readonly property color tertiaryFg: palette.tertiaryFg
    readonly property color surface: palette.surface
    readonly property color surfaceFg: palette.surfaceFg
    readonly property color surfaceContainer: palette.surfaceContainer || Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.06))
    readonly property color surfaceContainerHigh: palette.surfaceContainerHigh || Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.12))
    readonly property color background: palette.background
    readonly property color outline: palette.outline
    readonly property color error: palette.error
    readonly property color errorOn: palette.errorOn
}
