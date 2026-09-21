pragma Singleton
import QtQuick

// ── Theme ─────────────────────────────────────────────────────────────────
// Single source of truth for all visual design tokens.
// Edit values here; every component picks them up automatically.
QtObject {

    // ── Fonts ──────────────────────────────────────────────────────────
    readonly property string fontMono: "CaskaydiaCove Nerd Font"
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
    readonly property int barHeight:       42
    readonly property int barPaddingH:     16
    readonly property int barSectionGap:   18

    // ── Opacity ────────────────────────────────────────────────────────
    readonly property real opacityMuted:    0.65
    readonly property real opacityFaint:    0.35
    readonly property real opacityHairline: 0.18

    // ── Panel / drawer ─────────────────────────────────────────────────
    readonly property int drawerWidth:      420
    readonly property int drawerPaddingV:   22
    readonly property int drawerPaddingH:   20
    readonly property int drawerSpacing:    14
}
