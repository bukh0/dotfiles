#!/usr/bin/env python3
import json, os, colorsys

WAL_JSON = os.path.expanduser("~/.cache/wal/colors.json")
OUT_DIR = os.path.expanduser("~/.config/hypr/themes/pywal/generated")

def hex_to_hsl(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)

def hsl_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#{:02x}{:02x}{:02x}".format(round(r * 255), round(g * 255), round(b * 255))

def shade(hexcolor, dl):
    h, l, s = hex_to_hsl(hexcolor)
    l = max(0.0, min(1.0, l + dl))
    return hsl_to_hex(h, l, s)

def stripped(h):
    return h.lstrip("#")

def contrast_on(hexcolor):
    h, l, s = hex_to_hsl(hexcolor)
    return "#111111" if l > 0.6 else "#f2f2f2"

def main():
    with open(WAL_JSON) as f:
        data = json.load(f)
    c = data["colors"]
    sp = data["special"]

    bg, fg = sp["background"], sp["foreground"]
    primary = c["color4"]
    secondary = c["color5"]
    tertiary = c["color6"]
    error = c["color1"]

    roles = {
        "primary": primary,
        "on_primary": contrast_on(primary),
        "secondary": secondary,
        "on_secondary": contrast_on(secondary),
        "secondary_container": shade(secondary, -0.25),
        "on_secondary_container": contrast_on(shade(secondary, -0.25)),
        "tertiary": tertiary,
        "on_tertiary": contrast_on(tertiary),
        "surface": bg,
        "on_surface": fg,
        "on_surface_variant": shade(fg, -0.15),
        "surface_container": shade(bg, 0.04),
        "surface_container_high": shade(bg, 0.08),
        "surface_container_highest": shade(bg, 0.12),
        "background": bg,
        "outline": shade(fg, -0.35),
        "error": error,
        "on_error": contrast_on(error),
        "error_container": shade(error, -0.25),
        "on_error_container": contrast_on(shade(error, -0.25)),
    }

    os.makedirs(OUT_DIR, exist_ok=True)

    def w(name, content):
        tmp = os.path.join(OUT_DIR, name + ".tmp")
        with open(tmp, "w") as f:
            f.write(content)
        os.replace(tmp, os.path.join(OUT_DIR, name))

    w("waybar.css", f"""\
@define-color primary {roles['primary']};
@define-color on_primary {roles['on_primary']};
@define-color secondary {roles['secondary']};
@define-color on_secondary {roles['on_secondary']};
@define-color tertiary {roles['tertiary']};
@define-color on_tertiary {roles['on_tertiary']};
@define-color surface {roles['surface']};
@define-color on_surface {roles['on_surface']};
@define-color surface_container {roles['surface_container']};
@define-color surface_container_high {roles['surface_container_high']};
@define-color error {roles['error']};
@define-color on_error {roles['on_error']};
@define-color outline {roles['outline']};
""")

    w("swaync.css", f"""\
@define-color surface {roles['surface']};
@define-color on_surface {roles['on_surface']};
@define-color surface_container {roles['surface_container']};
@define-color surface_container_high {roles['surface_container_high']};
@define-color outline {roles['outline']};
@define-color primary {roles['primary']};
@define-color on_primary {roles['on_primary']};
@define-color error {roles['error']};
@define-color on_error {roles['on_error']};
""")

    w("hyprlock.conf", f"""\
$primary = rgb({stripped(roles['primary'])})
$background = rgb({stripped(roles['background'])})
$foreground = rgb({stripped(roles['on_surface'])})
$error = rgb({stripped(roles['error'])})
""")

    w("wlogout.css", f"""\
@define-color background-col {roles['background']};
@define-color on-surface-col {roles['on_surface']};
@define-color surface-col {roles['surface']};
@define-color primary-col {roles['primary']};
@define-color background-transparent alpha(@background-col, 0.85);
@define-color surface-transparent alpha(@surface-col, 0.55);
@define-color primary-transparent alpha(@primary-col, 0.75);
""")

    w("quickshell-colors.qml", f"""\
pragma Singleton
import QtQuick

QtObject {{
    readonly property color primary: "{roles['primary']}"
    readonly property color primaryFg: "{roles['on_primary']}"
    readonly property color secondary: "{roles['secondary']}"
    readonly property color secondaryFg: "{roles['on_secondary']}"
    readonly property color tertiary: "{roles['tertiary']}"
    readonly property color tertiaryFg: "{roles['on_tertiary']}"
    readonly property color surface: "{roles['surface']}"
    readonly property color surfaceFg: "{roles['on_surface']}"
    readonly property color surfaceContainer: "{roles['surface_container']}"
    readonly property color surfaceContainerHigh: "{roles['surface_container_high']}"
    readonly property color background: "{roles['background']}"
    readonly property color outline: "{roles['outline']}"
    readonly property color error: "{roles['error']}"
    readonly property color errorOn: "{roles['on_error']}"
}}
""")

if __name__ == "__main__":
    main()
