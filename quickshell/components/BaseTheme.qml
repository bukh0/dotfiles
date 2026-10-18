import QtQuick

// ── Theme ─────────────────────────────────────────────────────────────────
// Single source of truth for all visual design tokens.
// Edit values here; every component picks them up automatically.
QtObject {

    // ── Fonts ──────────────────────────────────────────────────────────
    readonly property var installedFonts: Qt.fontFamilies()
    property string fontMono: ["CaskaydiaCove Nerd Font", "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", "Symbols Nerd Font"].find(name => installedFonts.includes(name)) || "monospace"
    readonly property string fontUI:   "sans-serif"

    // ── Font sizes ─────────────────────────────────────────────────────
    readonly property int fontSizeXS:   10
    readonly property int fontSizeSM:   11
    readonly property int fontSizeBase: 12
    readonly property int fontSizeMD:   13
    readonly property int fontSizeLG:   14
    readonly property int fontSizeIcon: 16
    readonly property int fontSizeXL:   18

    // ── Corner radii ───────────────────────────────────────────────────
    readonly property int radiusSM:  3
    readonly property int radius:    5
    readonly property int radiusLG:  8
    readonly property int radiusXL: 12

    // ── Spacing ────────────────────────────────────────────────────────
    readonly property int spacingXS:  4
    readonly property int spacingSM:  8
    readonly property int spacing:   10
    readonly property int spacingMD: 12
    readonly property int spacingLG: 16
    readonly property int spacingXL: 22

    // ── Bar ────────────────────────────────────────────────────────────
    property int barHeight:       42
    readonly property int barPaddingH:     16
    readonly property int barSectionGap:   18
    property bool floatingBar:    false
    property int barOuterMargin:  0
    readonly property int barTotalHeight: floatingBar ? barHeight + barOuterMargin * 2 : barHeight
    property int barPillRadius:   5
    property int barPillPaddingH: 0
    property int centerPillMinWidth: 0
    property int centerPillExtraWidth: 0
    property int pillHeight:      30
    property int pillPaddingH:    22
    readonly property int workspaceSpacing: 4
    property int workspaceMinWidth: 22
    property int workspaceHorizontalPadding: 8
    property int workspaceHeight: 22
    property int workspaceRadius: 5
    property int workspaceFontSize: 14
    property int controlRadius: 4
    property int mediaArtworkRadius: 4
    property int mediaDotActiveWidth: 14
    property int mediaDotWidth: 4
    property int mediaDotHeight: 3
    property int mediaDotRadius: 1

    // ── Opacity ────────────────────────────────────────────────────────
    readonly property real opacityMuted:    0.65
    readonly property real opacityFaint:    0.35
    readonly property real opacityHairline: 0.18

    // ── Panel / drawer ─────────────────────────────────────────────────
    readonly property int drawerWidth:      420
    readonly property int drawerPaddingV:   22
    readonly property int drawerPaddingH:   20
    readonly property int drawerSpacing:    14
    readonly property int panelRadius:      12
    readonly property int panelBorderAlpha: 30
    readonly property int panelPadding:      20
    readonly property int panelSpacing:      14
    readonly property int indicatorGap:      10
    readonly property int indicatorIconSize: 16
    readonly property int sliderTrackHeight: 5
    readonly property int sliderThumbSize:   14
    readonly property int notificationWidth: 380
    readonly property int notificationHeight: 560
    readonly property int notificationRadius: 12
    readonly property int notificationItemRadius: 10
    readonly property int popupWidth:         340
    readonly property int popupRadius:        12
    property int toggleHeight:       36
    property int toggleRadius:       5
    property int toggleIconBox:      26
    readonly property int toggleIconSize:      18
    property int mediaArtSize:       72
    property int mediaControlSize:   32
}
