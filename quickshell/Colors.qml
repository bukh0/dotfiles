pragma Singleton
import QtQuick

QtObject {
    readonly property color primary: "#ac948c"
    readonly property color primaryFg: "#0b0b19"
    readonly property color secondary: "#a2948b"
    readonly property color secondaryFg: "#0b0b19"
    readonly property color tertiary: "#9c8c8c"
    readonly property color tertiaryFg: "#0b0b19"
    readonly property color surface: "#0b0b19"
    readonly property color surfaceFg: "#c2c2c5"
    readonly property color surfaceContainer: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.06))
    readonly property color surfaceContainerHigh: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.12))
    readonly property color background: "#0b0b19"
    readonly property color outline: "#5a5a6e"
    readonly property color error: "#F2B8B5"
    readonly property color errorOn: "#601410"
}
