# Quickshell configuration

The bar has two launch profiles, `default` and `alt`. Each profile owns its visual tokens and `qmldir`; its QML component links point to the shared implementations.

```text
components/          Shared QML components and shell root
profiles/default/    Default profile theme and module entry points
profiles/alt/        Alternate profile theme and module entry points
native/              sysmon C++ source, Makefile, and compiled helper
picker/              Theme and wallpaper picker
clipboard/           Clipboard browser and byte-safe Python bridge
run.sh               Profile launcher (`run.sh [default|alt]`)
reload.sh            Launcher alias
tests/               Isolated regression fixtures
```

Use `./run.sh` for the default profile and `./run.sh alt` for the alternate profile. `native/Makefile` builds `native/sysmon`; both profiles resolve the helper from there.

Music state lives in `MusicService.qml` and updates through native MPRIS signals. Closing the control panel releases its widgets while retaining the music model.

`~/.scripts/picker-menu.sh` builds the theme helper on demand. All theme application goes through `theme.switcher --apply THEME [WALLPAPER]`; `wallpick.sh` remains a compatibility wrapper. The helper uses OpenSSL for cache hashes and `vipsthumbnail` for previews. Generated binaries and dependency files are ignored by Git.

Run `python3 tests/run.py`, `python3 tests/launcher.py`, `python3 tests/picker.py`, and `python3 tests/theme.py` for the main regressions. Clipboard tests are in `clipboard/tests/`. The theme suite includes a 1,600-image queue stress test with a mock thumbnailer; it uses temporary directories and mock desktop commands.
