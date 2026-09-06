pragma Singleton
import QtQuick

QtObject {
    readonly property color primary:              "{{colors.primary.default.hex}}"
    readonly property color primaryFg:            "{{colors.on_primary.default.hex}}"
    readonly property color secondary:            "{{colors.secondary.default.hex}}"
    readonly property color secondaryFg:          "{{colors.on_secondary.default.hex}}"
    readonly property color tertiary:             "{{colors.tertiary.default.hex}}"
    readonly property color tertiaryFg:           "{{colors.on_tertiary.default.hex}}"
    readonly property color surface:              "{{colors.surface.default.hex}}"
    readonly property color surfaceFg:            "{{colors.on_surface.default.hex}}"
    readonly property color surfaceContainer:     "{{colors.surface_container.default.hex}}"
    readonly property color surfaceContainerHigh: "{{colors.surface_container_high.default.hex}}"
    readonly property color background:           "{{colors.background.default.hex}}"
    readonly property color outline:              "{{colors.outline.default.hex}}"
    readonly property color error:                "{{colors.error.default.hex}}"
    readonly property color errorOn:              "{{colors.on_error.default.hex}}"
}
