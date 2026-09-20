pragma Singleton
import QtQuick

QtObject {
    readonly property color primary: "#b5937b"
    readonly property color primaryFg: "#05050d"
    readonly property color secondary: "#5971ac"
    readonly property color secondaryFg: "#05050d"
    readonly property color tertiary: "#5b4b4e"
    readonly property color tertiaryFg: "#05050d"
    readonly property color surface: "#05050d"
    readonly property color surfaceFg: "#c0c0c2"
    readonly property color surfaceContainer: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.06))
    readonly property color surfaceContainerHigh: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.12))
    readonly property color background: "#05050d"
    readonly property color outline: "#555567"
    readonly property color error: "#F2B8B5"
    readonly property color errorOn: "#601410"
}
