pragma Singleton
import QtQuick
import Quickshell

BaseTheme {
    readonly property string sysmonPath: Quickshell.shellPath("../../native/sysmon")
    fontMono: ["JetBrainsMono Nerd Font", "CaskaydiaCove Nerd Font", "Symbols Nerd Font Mono", "Symbols Nerd Font"].find(name => installedFonts.includes(name)) || "monospace"
    barHeight: 35
    floatingBar: true
    barOuterMargin: 7
    barPillRadius: 8
    barPillPaddingH: 24
    centerPillMinWidth: 180
    centerPillExtraWidth: 80
    pillHeight: 35
    pillPaddingH: 24
    workspaceMinWidth: 24
    workspaceHorizontalPadding: 10
    workspaceHeight: 30
    workspaceRadius: 0
    workspaceFontSize: 13
    controlRadius: 8
    mediaArtworkRadius: 10
    mediaDotActiveWidth: 16
    mediaDotWidth: 6
    mediaDotHeight: 6
    mediaDotRadius: 3
    toggleHeight: 48
    toggleRadius: 10
    toggleIconBox: 32
    mediaArtSize: 84
    mediaControlSize: 34
}
