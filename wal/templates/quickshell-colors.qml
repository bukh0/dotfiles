pragma Singleton
import QtQuick

QtObject {{
    readonly property color primary: "{color6}"
    readonly property color primaryFg: "{background}"
    readonly property color secondary: "{color5}"
    readonly property color secondaryFg: "{background}"
    readonly property color tertiary: "{color4}"
    readonly property color tertiaryFg: "{background}"
    readonly property color surface: "{background}"
    readonly property color surfaceFg: "{foreground}"
    readonly property color surfaceContainer: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.06))
    readonly property color surfaceContainerHigh: Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, 0.12))
    readonly property color background: "{background}"
    readonly property color outline: "{color8}"
    readonly property color error: "#F2B8B5"
    readonly property color errorOn: "#601410"
}}
