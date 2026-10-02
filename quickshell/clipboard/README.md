# Clipboard popup

Standalone Quickshell application, launched by `~/.scripts/clipboard-menu.sh`
(existing Super+C binding). It does not add a bar component or require a bar
restart. Press the shortcut again to dismiss it. The process exits on close.

Uses `../components/Colors.qml` through a local symlink, so it follows the shell palette.
Requires Quickshell, Python 3, cliphist, wl-copy, and wtype; automatic paste also
uses Hyprland's active-window identity. The existing wl-paste watchers continue
to collect history.

- Type to search entry previews; multiple words match in any order.
- Up/Down and PageUp/PageDown select; Tab/Shift+Tab switch filters.
- Enter or double-click pastes into the previous app. Terminals receive
  Ctrl+Shift+V; other apps receive Ctrl+V. Apps with different paste bindings can
  use Copy and their own paste shortcut.
- Ctrl+Enter copies and closes without pasting.
- Ctrl+Delete deletes the selection; Clear history requires confirmation.
- Ctrl+R refreshes. Escape clears the query, then closes.

Text previews are limited to 32 KiB. Images up to 256 KiB are inlined; larger
images use `vipsthumbnail` to create a preview up to 1024×768, capped at 512 KiB
before base64 encoding. If thumbnailing fails, copying and pasting still work.
Copying always uses the complete original bytes. Previews use temporary files
and in-memory image URLs, with no persistent thumbnail cache. Clipboard values are
never interpolated into commands or rendered as rich text. Automatic paste is
skipped if the previously focused window is no longer active.

Run isolated tests with `python3 tests/test_backend.py` and
`python3 tests/test_ui.py`, and `python3 tests/test_service.py`. These never
modify the real clipboard/history.

API references: [Quickshell](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/)
and [cliphist](https://github.com/sentriz/cliphist).
