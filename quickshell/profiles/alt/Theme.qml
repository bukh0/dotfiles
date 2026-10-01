pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property var installedFonts: Qt.fontFamilies()
    readonly property string fontMono: ["JetBrainsMono Nerd Font", "CaskaydiaCove Nerd Font", "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", "Symbols Nerd Font"].find(name => installedFonts.includes(name)) || "monospace"
    readonly property string fontUI: "sans-serif"
    readonly property string sysmonPath: Quickshell.shellPath("../../native/sysmon")

    readonly property int fontSizeXS: 10
    readonly property int fontSizeSM: 11
    readonly property int fontSizeBase: 12
    readonly property int fontSizeMD: 13
    readonly property int fontSizeLG: 14
    readonly property int fontSizeIcon: 16
    readonly property int fontSizeXL: 18

    readonly property int radiusSM: 3
    readonly property int radius: 5
    readonly property int radiusLG: 8
    readonly property int radiusXL: 12

    readonly property int spacingXS: 4
    readonly property int spacingSM: 8
    readonly property int spacing: 10
    readonly property int spacingMD: 12
    readonly property int spacingLG: 16
    readonly property int spacingXL: 22

    readonly property int barHeight: 35
    readonly property int barPaddingH: 16
    readonly property int barSectionGap: 18
    readonly property bool floatingBar: true
    readonly property int barOuterMargin: 7
    readonly property int barTotalHeight: floatingBar ? barHeight + barOuterMargin * 2 : barHeight
    readonly property int barPillRadius: 8
    readonly property int barPillPaddingH: 24
    readonly property int centerPillMinWidth: 180
    readonly property int centerPillExtraWidth: 80
    readonly property int pillHeight: 35
    readonly property int pillPaddingH: 24
    readonly property int workspaceSpacing: 4
    readonly property int workspaceMinWidth: 24
    readonly property int workspaceHorizontalPadding: 10
    readonly property int workspaceHeight: 30
    readonly property int workspaceRadius: 0
    readonly property int workspaceFontSize: 13
    readonly property int controlRadius: 8
    readonly property int mediaArtworkRadius: 10
    readonly property int mediaDotActiveWidth: 16
    readonly property int mediaDotWidth: 6
    readonly property int mediaDotHeight: 6
    readonly property int mediaDotRadius: 3

    readonly property real opacityMuted: 0.65
    readonly property real opacityFaint: 0.35
    readonly property real opacityHairline: 0.18

    readonly property int drawerWidth: 420
    readonly property int drawerPaddingV: 22
    readonly property int drawerPaddingH: 20
    readonly property int drawerSpacing: 14
    readonly property int panelRadius: 12
    readonly property int panelBorderAlpha: 30
    readonly property int panelPadding: 20
    readonly property int panelSpacing: 14
    readonly property int indicatorGap: 10
    readonly property int indicatorIconSize: 16
    readonly property int sliderTrackHeight: 5
    readonly property int sliderThumbSize: 14
    readonly property int notificationWidth: 380
    readonly property int notificationHeight: 560
    readonly property int notificationRadius: 12
    readonly property int notificationItemRadius: 10
    readonly property int popupWidth: 340
    readonly property int popupRadius: 12
    readonly property int toggleHeight: 48
    readonly property int toggleRadius: 10
    readonly property int toggleIconBox: 32
    readonly property int toggleIconSize: 18
    readonly property int mediaArtSize: 84
    readonly property int mediaControlSize: 34
}
