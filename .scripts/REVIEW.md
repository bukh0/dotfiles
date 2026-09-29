# `~/.scripts` review

The review found several cross-script correctness and safety problems. The desktop brightness UI was covered in the separate Quickshell review; this pass covers the scripts that support it and the rest of `~/.scripts`.

- Quickshell autostart, switching and toggling now share the configured launcher. Process discovery is limited to the two configured profiles, so unrelated Quickshell instances are left alone.
- The `theme.switcher` and `wallpick` binaries now do their interactive work directly in C++; their shell entry points exec those binaries. The theme picker reuses the historical `~/.cache/wall-thumbs` entries and fills cache misses asynchronously. Theme outputs are staged before installation, and Matugen’s GTK output-name mismatch is handled.
- Wallpaper classification is shared by the three old entry points. Duplicate cleanup now archives byte-identical images only, and is opt-in. Resizing is also opt-in, bounded, avoids animated images, and keeps content-addressed originals. A managed-copy index avoids overwriting hand-edited theme images or deleting unrelated files; `--dry-run` is read-only.
- Cava no longer kills the caller's process group. Brightness-independent helpers also received targeted fixes for fullscreen state, clipboard pipelines, microphone/audio status, and power-profile state handling.
- WayClick process detection now matches the exact configured Python executable and runner argument, avoiding broad process-name matches.

Validation performed: shell syntax parsing, Python source compilation in memory, and warning-as-error builds of the two C++ launcher binaries. No runtime desktop integration checks were run.
