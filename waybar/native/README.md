# Hyprland workspace compatibility

These presets use `cffi/workspaces` because Waybar 0.15's built-in workspace
buttons send legacy dispatch commands. This module sends Lua focus actions,
with a legacy fallback, using the compositor's IPC socket. It keeps the
`#workspaces button` styles and the presets' formats and persistent lists.
All current presets use `all-outputs: true`; special workspaces are hidden.

Build after changing the source or replacing GTK/jsoncpp libraries:

```sh
make -C ~/.config/waybar/native
make -C ~/.config/waybar/native check
```

The module subscribes to compositor events, keeps GTK updates on the UI thread,
and retries disconnected IPC connections. Restart Waybar after rebuilding.
The checks exercise actual request generation with a simulated IPC transport;
live compositor interaction must be checked in the desktop session.

Waybar's CFFI v2 interface and original click handler:
- https://github.com/Alexays/Waybar/blob/0.15.0/include/modules/cffi.hpp
- https://github.com/Alexays/Waybar/blob/0.15.0/src/modules/hyprland/workspace.cpp

Before these changes, all preset files were copied to
`/tmp/waybar-before-workspace-fix`. The old directory symlink was saved in
`/tmp/waybar-link-backup-29qzbhmr/waybar`; the dotfiles source remains intact.
