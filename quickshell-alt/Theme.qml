pragma Singleton
import QtQuick

// ── Theme ─────────────────────────────────────────────────────────────────
// Single source of truth for all visual design tokens.
// Edit values here; every component picks them up automatically.
QtObject {

    // ── Fonts ──────────────────────────────────────────────────────────
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontUI:   "sans-serif"
}
