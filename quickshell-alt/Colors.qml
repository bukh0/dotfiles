pragma Singleton
import QtQuick

QtObject {
    readonly property color primary: "#5c5c5c"
    readonly property color primaryFg: "#090404"
    readonly property color secondary: "#545454"
    readonly property color secondaryFg: "#090404"
    readonly property color tertiary: "#4c4c4c"
    readonly property color tertiaryFg: "#090404"
    readonly property color surface: "#090404"
    readonly property color surfaceFg: "#c1c0c0"
    readonly property color surfaceContainer: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.06))
    readonly property color surfaceContainerHigh: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.12))
    readonly property color background: "#090404"
    readonly property color outline: "#665353"
    readonly property color error: "#F2B8B5"
    readonly property color errorOn: "#601410"
}
